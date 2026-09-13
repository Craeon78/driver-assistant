//======================================
// MARK: - ODOAnchor (V3 Core)
//======================================
//
// © 2026 Cory Russell Olsen. All rights reserved.
//
// Driver-entered odometer reading is the authoritative distance anchor.
// GPS evidence is reconciled against these anchors; never the reverse.
//
// Phase: Chunk 2 — Distance truth engine
//======================================

import Foundation

/// A driver-entered odometer observation.
/// This is truth. Everything else is evidence.
public struct ODOAnchor: Identifiable, Codable, Sendable, Equatable {
    public let id: CanonicalID
    public let km: Int                    // whole kilometres as entered by driver
    public let recordedAt: Date           // when the driver entered it
    public let occurredAt: Date           // nominal time of the reading (usually same)
    public let provenance: EventProvenance

    public init(
        id: CanonicalID = .fresh(),
        km: Int,
        recordedAt: Date = Date(),
        occurredAt: Date? = nil,
        provenance: EventProvenance = .driverEntered
    ) {
        self.id = id
        self.km = km
        self.recordedAt = recordedAt
        self.occurredAt = occurredAt ?? recordedAt
        self.provenance = provenance
    }
}
