//======================================
// MARK: - DistanceEngine (V3 Core)
//======================================
//
// © 2026 Cory Russell Olsen. All rights reserved.
//
// Canonical distance truth engine.
// ODO anchors close spans. GPS is evidence only.
// Learning of correction factor is preserved from V2 behaviour.
//
// Phase: Chunk 2 — Distance truth engine
//======================================

import Foundation

public final class DistanceEngine: DistanceEvidenceEngine {

    // MARK: - Public state
    public private(set) var effectiveCorrectionFactor: Double = 1.0

    // MARK: - Private span state
    private var previousLocation: CLLocationLike?
    private var rawMeters: Double = 0
    private var filteredMeters: Double = 0
    private var currentStartAnchor: ODOAnchor?
    private var closed: [DistanceInterval] = []
    private var spanCount: Int = 0

    private let tuning: GPSFilterTuning
    private let factorMin: Double = 0.70
    private let factorMax: Double = 1.30

    public init(tuning: GPSFilterTuning = .default) {
        self.tuning = tuning
    }

    // MARK: - DistanceEvidenceEngine

    public func ingestLocation(_ location: CLLocationLike) -> Bool {
        let result = GPSFilter.evaluate(
            newLocation: location,
            previousLocation: previousLocation,
            tuning: tuning
        )

        switch result {
        case .accept(let delta):
            rawMeters += location.distance(from: previousLocation ?? location) // raw always accumulates geometric
            // For first point previous is nil, delta is 0; subsequent use filter delta
            if previousLocation != nil {
                filteredMeters += delta
            }
            previousLocation = location
            return true
        default:
            return false
        }
    }

    public func handleODOAnchor(_ anchor: ODOAnchor) -> DistanceInterval? {
        let odoDelta: Double
        if let start = currentStartAnchor {
            odoDelta = Double(anchor.km - start.km)
        } else {
            // First anchor of the shift — open the span, no interval yet
            currentStartAnchor = anchor
            rawMeters = 0
            filteredMeters = 0
            previousLocation = nil
            return nil
        }

        guard odoDelta > 0 else { return nil }

        let rawKm = rawMeters / 1000.0
        let filteredKm = filteredMeters / 1000.0

        // Choose best GPS evidence against ODO truth
        let errorRaw = abs(odoDelta - rawKm)
        let errorFiltered = abs(odoDelta - filteredKm)
        let chosenSource: DistanceSource
        let chosenKm: Double
        if errorRaw <= errorFiltered {
            chosenSource = .raw
            chosenKm = rawKm
        } else {
            chosenSource = .filtered
            chosenKm = filteredKm
        }

        // Learn correction factor (V2 behaviour preserved)
        let windowFactor = odoDelta / max(chosenKm, 0.001)
        let alpha = learningRate()
        let updated = effectiveCorrectionFactor * (1 - alpha) + windowFactor * alpha
        effectiveCorrectionFactor = clamp(updated, min: factorMin, max: factorMax)

        let interval = DistanceInterval(
            startAnchor: currentStartAnchor,
            endAnchor: anchor,
            odoDeltaKm: odoDelta,
            gpsRawKm: rawKm,
            gpsFilteredKm: filteredKm,
            chosenSource: chosenSource,
            chosenKm: chosenKm,
            correctionFactorUsed: effectiveCorrectionFactor,
            closedAt: anchor.recordedAt
        )
        closed.append(interval)
        spanCount += 1

        // Open next span from this anchor
        currentStartAnchor = anchor
        rawMeters = 0
        filteredMeters = 0
        previousLocation = nil

        return interval
    }

    public func closedIntervals() -> [DistanceInterval] {
        closed
    }

    public func reset() {
        previousLocation = nil
        rawMeters = 0
        filteredMeters = 0
        currentStartAnchor = nil
        closed = []
        spanCount = 0
        effectiveCorrectionFactor = 1.0
    }

    // MARK: - Private

    private func learningRate() -> Double {
        // Simplified maturity from V2
        if spanCount < 3 { return 0.35 }
        if spanCount < 10 { return 0.18 }
        return 0.06
    }

    private func clamp(_ value: Double, min lower: Double, max upper: Double) -> Double {
        Swift.max(lower, Swift.min(upper, value))
    }
}
