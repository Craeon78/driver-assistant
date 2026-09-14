//======================================
// MARK: - Breadcrumb Retention (V3 Core)
//======================================
//
// © 2026 Cory Russell Olsen. All rights reserved.
//
// Chunk 2b: semantic retention routing for accepted GPS evidence.
// Core owns retention execution; later domains may supply evidence used to
// classify an interval, but Core does not own Sites, Operations or Cargo truth.
//======================================

import Foundation

public enum BreadcrumbRetentionClass: String, Codable, Sendable, CaseIterable {
    /// Ordinary transit. Eligible for aggressive thinning.
    case normal

    /// Stop/start or low-speed road behaviour where more geometry is useful.
    case traffic

    /// Destination-like / yard-like evidence. Until Sites exists, this remains
    /// a provisional spatial class rather than confirmed site truth.
    case yardCandidate

    /// Evidence whose operational meaning is not yet safe to resolve.
    /// Destructive thinning is prohibited until later reconciliation.
    case unresolved
}

public enum BreadcrumbRetentionDisposition: Sendable, Equatable {
    /// Persist a thinned line using the supplied policy.
    case thin(ThinningPolicy)

    /// Preserve the dense evidence because another representation will consume
    /// it later (for example a future site footprint / polygon).
    case preserveForSemanticResolution

    /// Preserve the dense evidence because the app lacks authority to decide.
    case preserveUnresolved
}

public enum BreadcrumbRetentionRouter {

    /// Field-backed candidate policies from the 2026-09-14 thinning experiment.
    /// These are defaults for Chunk 2b testing, not permanent universal constants.
    public static let normalPolicy = ThinningPolicy(
        minTimeInterval: 60,
        minDistanceMeters: 100,
        minHeadingChangeDegrees: 45,
        keepStopTransitions: true,
        keepKeyEvents: true,
        maxPointsPerKm: 0
    )

    public static let trafficPolicy = ThinningPolicy(
        minTimeInterval: 15,
        minDistanceMeters: 25,
        minHeadingChangeDegrees: 25,
        keepStopTransitions: true,
        keepKeyEvents: true,
        maxPointsPerKm: 0
    )

    public static func disposition(for retentionClass: BreadcrumbRetentionClass) -> BreadcrumbRetentionDisposition {
        switch retentionClass {
        case .normal:
            return .thin(normalPolicy)
        case .traffic:
            return .thin(trafficPolicy)
        case .yardCandidate:
            return .preserveForSemanticResolution
        case .unresolved:
            return .preserveUnresolved
        }
    }

    /// Applies only the destructive-safe part of the retention contract.
    /// Yard candidates and unresolved evidence are returned dense and unchanged.
    public static func materialize(
        trail: BreadcrumbTrail,
        as retentionClass: BreadcrumbRetentionClass
    ) -> [BreadcrumbPoint] {
        switch disposition(for: retentionClass) {
        case .thin(let policy):
            return BreadcrumbThinner.thin(trail, policy: policy)
        case .preserveForSemanticResolution, .preserveUnresolved:
            return trail.points
        }
    }
}
