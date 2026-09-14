//======================================
// MARK: - BreadcrumbEpisodeClassifier (Chunk 2b test instrument)
//======================================
//
// © 2026 Cory Russell Olsen. All rights reserved.
//
// PROVISIONAL / HARNESS-ONLY CLASSIFIER.
// This file exists to test whether currently available spatial + motion evidence
// can differentiate useful retention classes before Sites/Road Packs exist.
// It does NOT create Driver, Operations or Site truth.
//======================================

import Foundation

public struct SimulatedSegmentBoundary: Identifiable, Sendable, Equatable {
    public let id: CanonicalID
    public let timestamp: Date

    public init(id: CanonicalID = .fresh(), timestamp: Date) {
        self.id = id
        self.timestamp = timestamp
    }
}

public struct BreadcrumbEpisodeFeatures: Sendable, Equatable {
    public let startedAt: Date
    public let endedAt: Date
    public let durationSeconds: TimeInterval
    public let pointCount: Int
    public let pathDistanceMeters: Double
    public let displacementMeters: Double
    public let linearity: Double
    public let maxRadiusFromStartMeters: Double
    public let stoppedFraction: Double
    public let cumulativeHeadingChangeDegrees: Double
    public let nearSegmentBoundary: Bool
}

public struct ClassifiedBreadcrumbEpisode: Identifiable, Sendable, Equatable {
    public let id: CanonicalID
    public let startIndex: Int
    public let endIndex: Int
    public let retentionClass: BreadcrumbRetentionClass
    public let features: BreadcrumbEpisodeFeatures
    public let reasons: [String]

    public init(
        id: CanonicalID = .fresh(),
        startIndex: Int,
        endIndex: Int,
        retentionClass: BreadcrumbRetentionClass,
        features: BreadcrumbEpisodeFeatures,
        reasons: [String]
    ) {
        self.id = id
        self.startIndex = startIndex
        self.endIndex = endIndex
        self.retentionClass = retentionClass
        self.features = features
        self.reasons = reasons
    }
}

public struct BreadcrumbClassificationTunables: Sendable, Equatable {
    /// <= ~15 km/h is treated as low-movement evidence for this experiment.
    public var lowMovementSpeedMps: Double = 4.2

    /// A contiguous low-movement run shorter than this is ignored as noise.
    public var minimumEpisodeSeconds: TimeInterval = 20

    /// Short gaps between low-movement fixes may be merged into one episode.
    public var mergeGapSeconds: TimeInterval = 20

    /// Segment starts/ends within this window are considered nearby evidence.
    public var boundaryWindowSeconds: TimeInterval = 180

    /// Long dwell is evidence, never truth by itself.
    public var longDwellSeconds: TimeInterval = 300

    /// Low linearity indicates compact/manoeuvring movement rather than road progress.
    public var compactLinearityThreshold: Double = 0.55

    /// A compact episode should remain roughly local to its entry point.
    public var compactRadiusMeters: Double = 350

    /// High stopped fraction strengthens roadside-break / destination ambiguity.
    public var highStoppedFraction: Double = 0.60

    /// Heading churn strengthens yard/manoeuvring evidence.
    public var manoeuvringHeadingDegrees: Double = 120

    public init() {}
}

public enum BreadcrumbEpisodeClassifier {

    /// Detects only low-movement episodes. Ordinary points outside these episodes are
    /// implicitly NORMAL for the purpose of the Chunk 2b differentiation test.
    public static func classify(
        trail: BreadcrumbTrail,
        boundaries: [SimulatedSegmentBoundary],
        tunables: BreadcrumbClassificationTunables = .init()
    ) -> [ClassifiedBreadcrumbEpisode] {
        guard trail.points.count >= 2 else { return [] }

        let ranges = lowMovementRanges(points: trail.points, tunables: tunables)
        return ranges.compactMap { range in
            classifyRange(range, points: trail.points, boundaries: boundaries, tunables: tunables)
        }
    }

    private static func lowMovementRanges(
        points: [BreadcrumbPoint],
        tunables: BreadcrumbClassificationTunables
    ) -> [ClosedRange<Int>] {
        var ranges: [ClosedRange<Int>] = []
        var start: Int?
        var lastLow: Int?

        for index in points.indices {
            let point = points[index]
            let isLow = point.speedMps < 0 || point.speedMps <= tunables.lowMovementSpeedMps

            if isLow {
                if start == nil { start = index }
                lastLow = index
                continue
            }

            guard let currentStart = start, let previousLow = lastLow else { continue }

            // Keep the episode open across a brief faster sample/gap.
            let gap = point.timestamp.timeIntervalSince(points[previousLow].timestamp)
            if gap <= tunables.mergeGapSeconds { continue }

            if let accepted = validatedRange(currentStart...previousLow, points: points, minimumSeconds: tunables.minimumEpisodeSeconds) {
                ranges.append(accepted)
            }
            start = nil
            lastLow = nil
        }

        if let currentStart = start, let previousLow = lastLow,
           let accepted = validatedRange(currentStart...previousLow, points: points, minimumSeconds: tunables.minimumEpisodeSeconds) {
            ranges.append(accepted)
        }

        return ranges
    }

    private static func validatedRange(
        _ range: ClosedRange<Int>,
        points: [BreadcrumbPoint],
        minimumSeconds: TimeInterval
    ) -> ClosedRange<Int>? {
        guard range.lowerBound < points.count, range.upperBound < points.count else { return nil }
        let duration = points[range.upperBound].timestamp.timeIntervalSince(points[range.lowerBound].timestamp)
        return duration >= minimumSeconds ? range : nil
    }

    private static func classifyRange(
        _ range: ClosedRange<Int>,
        points: [BreadcrumbPoint],
        boundaries: [SimulatedSegmentBoundary],
        tunables: BreadcrumbClassificationTunables
    ) -> ClassifiedBreadcrumbEpisode? {
        let slice = Array(points[range])
        guard let first = slice.first, let last = slice.last else { return nil }

        let duration = max(0, last.timestamp.timeIntervalSince(first.timestamp))
        let path = pathDistance(slice)
        let displacement = haversine(first, last)
        let linearity = path > 1 ? min(1, displacement / path) : 0
        let radius = slice.map { haversine(first, $0) }.max() ?? 0
        let stoppedCount = slice.filter { $0.speedMps >= 0 && $0.speedMps < 0.8 }.count
        let stoppedFraction = slice.isEmpty ? 0 : Double(stoppedCount) / Double(slice.count)
        let headingChange = cumulativeHeadingChange(slice)
        let nearBoundary = boundaries.contains { boundary in
            let toStart = abs(boundary.timestamp.timeIntervalSince(first.timestamp))
            let toEnd = abs(boundary.timestamp.timeIntervalSince(last.timestamp))
            return min(toStart, toEnd) <= tunables.boundaryWindowSeconds
        }

        let features = BreadcrumbEpisodeFeatures(
            startedAt: first.timestamp,
            endedAt: last.timestamp,
            durationSeconds: duration,
            pointCount: slice.count,
            pathDistanceMeters: path,
            displacementMeters: displacement,
            linearity: linearity,
            maxRadiusFromStartMeters: radius,
            stoppedFraction: stoppedFraction,
            cumulativeHeadingChangeDegrees: headingChange,
            nearSegmentBoundary: nearBoundary
        )

        let compact = linearity <= tunables.compactLinearityThreshold || radius <= tunables.compactRadiusMeters
        let manoeuvring = headingChange >= tunables.manoeuvringHeadingDegrees
        let longDwell = duration >= tunables.longDwellSeconds
        let mostlyStopped = stoppedFraction >= tunables.highStoppedFraction

        // Boundary + low movement is the deliberate neon marker being tested.
        if nearBoundary && (compact || manoeuvring || duration >= 60) {
            return ClassifiedBreadcrumbEpisode(
                startIndex: range.lowerBound,
                endIndex: range.upperBound,
                retentionClass: .yardCandidate,
                features: features,
                reasons: [
                    "low-movement episode near simulated segment boundary",
                    compact ? "compact/local spatial pattern" : "sustained low movement",
                    manoeuvring ? "heading churn suggests manoeuvring" : ""
                ].filter { !$0.isEmpty }
            )
        }

        // A destination-like or break-like pattern appearing mid-segment must not be
        // silently called traffic. Preserve it for later driver/domain reconciliation.
        if !nearBoundary && ((longDwell && compact) || mostlyStopped || (compact && manoeuvring && duration >= 120)) {
            return ClassifiedBreadcrumbEpisode(
                startIndex: range.lowerBound,
                endIndex: range.upperBound,
                retentionClass: .unresolved,
                features: features,
                reasons: [
                    "destination/break-like evidence appears mid-segment",
                    longDwell ? "long dwell" : "",
                    compact ? "compact/local spatial pattern" : "",
                    mostlyStopped ? "high stopped fraction" : "",
                    manoeuvring ? "heading churn suggests manoeuvring" : ""
                ].filter { !$0.isEmpty }
            )
        }

        // Remaining low-movement road-like episodes are provisionally traffic.
        return ClassifiedBreadcrumbEpisode(
            startIndex: range.lowerBound,
            endIndex: range.upperBound,
            retentionClass: .traffic,
            features: features,
            reasons: [
                "low-movement episode inside continuing segment",
                linearity > tunables.compactLinearityThreshold ? "road-like linear progress" : "insufficient destination evidence"
            ]
        )
    }

    private static func pathDistance(_ points: [BreadcrumbPoint]) -> Double {
        guard points.count >= 2 else { return 0 }
        return zip(points, points.dropFirst()).reduce(0) { partial, pair in
            partial + haversine(pair.0, pair.1)
        }
    }

    private static func haversine(_ a: BreadcrumbPoint, _ b: BreadcrumbPoint) -> Double {
        let radius = 6_371_000.0
        let dLat = (b.latitude - a.latitude) * .pi / 180
        let dLon = (b.longitude - a.longitude) * .pi / 180
        let lat1 = a.latitude * .pi / 180
        let lat2 = b.latitude * .pi / 180
        let h = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * radius * asin(min(1, sqrt(h)))
    }

    private static func cumulativeHeadingChange(_ points: [BreadcrumbPoint]) -> Double {
        guard points.count >= 2 else { return 0 }
        var total = 0.0
        for pair in zip(points, points.dropFirst()) {
            guard let a = pair.0.courseDegrees, let b = pair.1.courseDegrees else { continue }
            var delta = abs(b - a)
            if delta > 180 { delta = 360 - delta }
            total += delta
        }
        return total
    }
}
