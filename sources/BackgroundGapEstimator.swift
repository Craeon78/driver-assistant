
import Foundation

import CoreLocation

import MapKit

  

// © 2026 Cory Russell Olsen. All rights reserved.

//======================================

// MARK: - BackgroundGapEstimator

//======================================

//

// Purpose:

// - Estimate distance traveled during an app background gap.

// - Advisory only: NEVER feeds correction factor learning.

// - Used to populate the "amber triangle" card / suggestion UI.

//

// Inputs:

// - start/end coordinate + timestamps (captured on background/foreground transitions)

// - optional quality flags (accuracy, stale, etc) can be layered later

//

// Outputs:

// - BackgroundGapEstimate (distance, method, confidence, suggestedOdoDeltaKm)

//

// Notes:

// - If routing fails/unavailable, falls back to straight-line * multiplier.

// - Caller decides whether to apply, prompt, or ignore.

//======================================

  

enum GapEstimateMethod: String, Codable {

    case route

    case straightLineFallback

    case none

}

  

enum GapConfidence: String, Codable {

    case high

    case medium

    case low

    case none

}

  

struct BackgroundGapEstimate: Codable, Identifiable {

    let id: UUID

    let createdAt: Date

    let startAt: Date

    let endAt: Date

    let gapSeconds: TimeInterval

    let startCoord: CodableCoordinate 

    let endCoord: CodableCoordinate

    let straightLineMeters: Double

    let estimatedMeters: Double

    let method: GapEstimateMethod

    let confidence: GapConfidence

    /// Rounded km suggestion for UI (odo delta suggestion), derived from estimatedMeters.

    let suggestedOdoDeltaKm: Int

    /// Human-readable audit note for debug/log UI.

    let note: String

    init(

        id: UUID = UUID(),

        createdAt: Date = Date(),

        startAt: Date,

        endAt: Date,

        startCoord: CodableCoordinate,

        endCoord: CodableCoordinate,

        straightLineMeters: Double,

        estimatedMeters: Double,

        method: GapEstimateMethod,

        confidence: GapConfidence,

        note: String

    ) {

        self.id = id

        self.createdAt = createdAt

        self.startAt = startAt

        self.endAt = endAt

        self.gapSeconds = max(0, endAt.timeIntervalSince(startAt))

        self.startCoord = startCoord

        self.endCoord = endCoord

        self.straightLineMeters = max(0, straightLineMeters)

        self.estimatedMeters = max(0, estimatedMeters)

        self.method = method

        self.confidence = confidence

        self.suggestedOdoDeltaKm = Int((self.estimatedMeters / 1000.0).rounded())

        self.note = note

    }

}

  

final class BackgroundGapEstimator {

    struct Tunables: Codable {

        /// Only consider a "gap event" if background duration exceeds this.

        var minGapSeconds: TimeInterval = 45

        /// Only consider a "gap event" if the straight-line displacement exceeds this.

        var minStraightLineMeters: Double = 800

        /// If routing fails, multiply straight-line by this as a crude road-factor.

        var fallbackMultiplier: Double = 1.2

        /// If straight-line is huge, flag as manual review recommended.

        var manualReviewThresholdKm: Double = 50

        /// Timeout for routing attempts.

        var routeTimeoutSeconds: TimeInterval = 6

    }

    private let t: Tunables

    init(tunables: Tunables = Tunables()) {

        self.t = tunables

    }

    // MARK: - Public API

    /// Main entrypoint.

    /// Calls completion on main queue.

    func estimateIfQualifies(

        startAt: Date,

        startCoord: CLLocationCoordinate2D,

        endAt: Date,

        endCoord: CLLocationCoordinate2D,

        completion: @escaping (BackgroundGapEstimate?) -> Void

    ) {

        let gapSeconds = max(0, endAt.timeIntervalSince(startAt))

        guard gapSeconds >= t.minGapSeconds else {

            DispatchQueue.main.async { completion(nil) }

            return

        }

        let startLoc = CLLocation(latitude: startCoord.latitude, longitude: startCoord.longitude)

        let endLoc   = CLLocation(latitude: endCoord.latitude, longitude: endCoord.longitude)

        let straightLine = endLoc.distance(from: startLoc)

        guard straightLine >= t.minStraightLineMeters else {

            DispatchQueue.main.async { completion(nil) }

            return

        }

        // Try route first (preferred, when available).

        estimateByRouting(

            startCoord: startCoord,

            endCoord: endCoord,

            timeoutSeconds: t.routeTimeoutSeconds

        ) { [weak self] routeMeters in

            guard let self else {

                DispatchQueue.main.async { completion(nil) }

                return

            }

            if let routeMeters, routeMeters.isFinite, routeMeters > 0 {

                let confidence: GapConfidence = .high

                let note = self.makeNote(

                    gapSeconds: gapSeconds,

                    straightLineMeters: straightLine,

                    estimatedMeters: routeMeters,

                    method: .route

                )

                let estimate = BackgroundGapEstimate(

                    startAt: startAt,

                    endAt: endAt,

                    startCoord: CodableCoordinate(startCoord),

                    endCoord: CodableCoordinate(endCoord),

                    straightLineMeters: straightLine,

                    estimatedMeters: routeMeters,

                    method: .route,

                    confidence: confidence,

                    note: note

                )

                DispatchQueue.main.async { completion(estimate) }

            } else {

                // Fallback: straight-line × multiplier

                let est = straightLine * self.t.fallbackMultiplier

                let confidence: GapConfidence = .low

                let note = self.makeNote(

                    gapSeconds: gapSeconds,

                    straightLineMeters: straightLine,

                    estimatedMeters: est,

                    method: .straightLineFallback

                )

                let estimate = BackgroundGapEstimate(

                    startAt: startAt,

                    endAt: endAt,

                    startCoord: CodableCoordinate(startCoord),

                    endCoord: CodableCoordinate(endCoord),

                    straightLineMeters: straightLine,

                    estimatedMeters: est,

                    method: .straightLineFallback,

                    confidence: confidence,

                    note: note

                )

                DispatchQueue.main.async { completion(estimate) }

            }

        }

    }

    // MARK: - Routing

    private func estimateByRouting(

        startCoord: CLLocationCoordinate2D,

        endCoord: CLLocationCoordinate2D,

        timeoutSeconds: TimeInterval,

        completion: @escaping (Double?) -> Void

    ) {

        let req = MKDirections.Request()

        req.source = MKMapItem(placemark: MKPlacemark(coordinate: startCoord))

        req.destination = MKMapItem(placemark: MKPlacemark(coordinate: endCoord))

        req.transportType = .automobile

        req.requestsAlternateRoutes = false

        let directions = MKDirections(request: req)

        var finished = false

        // Timeout guard

        let timeout = DispatchWorkItem {

            guard !finished else { return }

            finished = true

            directions.cancel()

            completion(nil)

        }

        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + timeoutSeconds, execute: timeout)

        directions.calculate { response, error in

            guard !finished else { return }

            finished = true

            timeout.cancel()

            if let route = response?.routes.first {

                completion(route.distance)

            } else {

                completion(nil)

            }

        }

    }

    // MARK: - Note builder

    private func makeNote(

        gapSeconds: TimeInterval,

        straightLineMeters: Double,

        estimatedMeters: Double,

        method: GapEstimateMethod

    ) -> String {

        let gapMins = Int((gapSeconds / 60.0).rounded())

        let slKm = straightLineMeters / 1000.0

        let estKm = estimatedMeters / 1000.0

        let big = estKm >= t.manualReviewThresholdKm

        let review = big ? " • manual review recommended (>\(Int(t.manualReviewThresholdKm))km)" : ""

        return "gap≈\(gapMins)m • straight≈\(String(format: "%.1f", slKm))km • est≈\(String(format: "%.1f", estKm))km • method=\(method.rawValue)\(review)"

    }

}
