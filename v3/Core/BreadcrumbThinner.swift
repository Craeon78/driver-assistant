//======================================
// MARK: - BreadcrumbThinner (V3 Core)
//======================================
//
// © 2026 Cory Russell Olsen. All rights reserved.
//
// Deterministic thinning of a dense trail according to a live-tunable policy.
// Always preserves key events and stop transitions.
//
// Phase: Chunk 2b — Breadcrumb thinning
//======================================

import Foundation

public struct ThinningPolicy: Sendable, Equatable {
    /// Keep a point if at least this many seconds have passed since the last kept point.
    public var minTimeInterval: TimeInterval
    /// Keep a point if it is at least this far (metres) from the last kept point.
    public var minDistanceMeters: Double
    /// Keep a point if heading has changed by at least this many degrees.
    public var minHeadingChangeDegrees: Double
    /// Always keep stop/start transitions.
    public var keepStopTransitions: Bool
    /// Always keep key events (ODO, load, manual pins).
    public var keepKeyEvents: Bool
    /// Hard cap: never keep more than this many points per kilometre of trail (0 = no cap).
    public var maxPointsPerKm: Double

    public init(
        minTimeInterval: TimeInterval = 15,
        minDistanceMeters: Double = 25,
        minHeadingChangeDegrees: Double = 25,
        keepStopTransitions: Bool = true,
        keepKeyEvents: Bool = true,
        maxPointsPerKm: Double = 0
    ) {
        self.minTimeInterval = minTimeInterval
        self.minDistanceMeters = minDistanceMeters
        self.minHeadingChangeDegrees = minHeadingChangeDegrees
        self.keepStopTransitions = keepStopTransitions
        self.keepKeyEvents = keepKeyEvents
        self.maxPointsPerKm = maxPointsPerKm
    }

    public static let `default` = ThinningPolicy()
}

public enum BreadcrumbThinner {

    /// Returns the thinned subset of points that survive the policy.
    public static func thin(_ trail: BreadcrumbTrail, policy: ThinningPolicy) -> [BreadcrumbPoint] {
        guard !trail.points.isEmpty else { return [] }

        var kept: [BreadcrumbPoint] = []
        var lastKept: BreadcrumbPoint?
        var cumulativeMeters: Double = 0

        for point in trail.points {
            // Always-keep rules first
            if policy.keepKeyEvents && point.isKeyEvent {
                kept.append(point)
                if let prev = lastKept {
                    cumulativeMeters += haversine(prev, point)
                }
                lastKept = point
                continue
            }
            if policy.keepStopTransitions && point.isStopTransition {
                kept.append(point)
                if let prev = lastKept {
                    cumulativeMeters += haversine(prev, point)
                }
                lastKept = point
                continue
            }

            guard let prev = lastKept else {
                // First ordinary point
                kept.append(point)
                lastKept = point
                continue
            }

            let dt = point.timestamp.timeIntervalSince(prev.timestamp)
            let dist = haversine(prev, point)
            let headingDelta = headingChange(from: prev, to: point)

            let timeOK = dt >= policy.minTimeInterval
            let distOK = dist >= policy.minDistanceMeters
            let headingOK = headingDelta >= policy.minHeadingChangeDegrees

            if timeOK || distOK || headingOK {
                // Optional density cap
                if policy.maxPointsPerKm > 0 && cumulativeMeters > 0 {
                    let currentDensity = Double(kept.count) / (cumulativeMeters / 1000.0)
                    if currentDensity > policy.maxPointsPerKm && !timeOK && !headingOK {
                        continue // too dense, skip unless time or heading forced it
                    }
                }
                kept.append(point)
                cumulativeMeters += dist
                lastKept = point
            }
        }

        return kept
    }

    // MARK: - Geometry helpers

    private static func haversine(_ a: BreadcrumbPoint, _ b: BreadcrumbPoint) -> Double {
        let R = 6_371_000.0
        let dLat = (b.latitude - a.latitude) * .pi / 180
        let dLon = (b.longitude - a.longitude) * .pi / 180
        let lat1 = a.latitude * .pi / 180
        let lat2 = b.latitude * .pi / 180
        let h = sin(dLat/2)*sin(dLat/2) + cos(lat1)*cos(lat2)*sin(dLon/2)*sin(dLon/2)
        return 2 * R * asin(min(1, sqrt(h)))
    }

    private static func headingChange(from a: BreadcrumbPoint, to b: BreadcrumbPoint) -> Double {
        guard let c1 = a.courseDegrees, let c2 = b.courseDegrees else { return 0 }
        var delta = abs(c2 - c1)
        if delta > 180 { delta = 360 - delta }
        return delta
    }
}
