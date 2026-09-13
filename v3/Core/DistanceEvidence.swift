//======================================
// MARK: - DistanceEvidence (V3 Core)
//======================================
//
// © 2026 Cory Russell Olsen. All rights reserved.
//
// Canonical interface for distance evidence.
// Downstream domains consume this; they never reach into raw GPS state.
//
// Phase: Chunk 2 — Distance truth engine
//======================================

import Foundation

public enum DistanceSource: String, Codable, Sendable {
    case raw
    case filtered
    case odoAnchor          // pure ODO interval (no GPS used)
    case correctedGPS       // GPS adjusted by learned factor
}

/// One closed interval of distance evidence between two anchors (or start of span).
public struct DistanceInterval: Identifiable, Codable, Sendable, Equatable {
    public let id: CanonicalID
    public let startAnchor: ODOAnchor?
    public let endAnchor: ODOAnchor
    public let odoDeltaKm: Double
    public let gpsRawKm: Double?
    public let gpsFilteredKm: Double?
    public let chosenSource: DistanceSource
    public let chosenKm: Double
    public let correctionFactorUsed: Double?
    public let closedAt: Date

    public init(
        id: CanonicalID = .fresh(),
        startAnchor: ODOAnchor?,
        endAnchor: ODOAnchor,
        odoDeltaKm: Double,
        gpsRawKm: Double? = nil,
        gpsFilteredKm: Double? = nil,
        chosenSource: DistanceSource,
        chosenKm: Double,
        correctionFactorUsed: Double? = nil,
        closedAt: Date = Date()
    ) {
        self.id = id
        self.startAnchor = startAnchor
        self.endAnchor = endAnchor
        self.odoDeltaKm = odoDeltaKm
        self.gpsRawKm = gpsRawKm
        self.gpsFilteredKm = gpsFilteredKm
        self.chosenSource = chosenSource
        self.chosenKm = chosenKm
        self.correctionFactorUsed = correctionFactorUsed
        self.closedAt = closedAt
    }
}

/// Protocol that any distance engine must satisfy.
/// Callers depend only on this contract.
public protocol DistanceEvidenceEngine: AnyObject {
    /// Current learned correction factor (1.0 = no correction).
    var effectiveCorrectionFactor: Double { get }

    /// Ingest a location sample. Returns whether it was accepted.
    func ingestLocation(_ location: CLLocationLike) -> Bool

    /// Driver has entered a new ODO reading. Closes the current span.
    func handleODOAnchor(_ anchor: ODOAnchor) -> DistanceInterval?

    /// All closed intervals so far (oldest first).
    func closedIntervals() -> [DistanceInterval]

    /// Reset for a new shift / test.
    func reset()
}

/// Minimal location shape so we are not permanently tied to CoreLocation in tests.
public protocol CLLocationLike {
    var coordinate: (latitude: Double, longitude: Double) { get }
    var horizontalAccuracy: Double { get }
    var timestamp: Date { get }
    var speed: Double { get }          // m/s, negative if invalid
    func distance(from other: CLLocationLike) -> Double
}
