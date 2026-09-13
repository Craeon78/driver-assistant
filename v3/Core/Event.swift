//======================================
// MARK: - Event (V3 Core)
//======================================
//
// © 2026 Cory Russell Olsen. All rights reserved.
//
// Event spine: the single source of truth for what happened.
// Supports distinct occurrence time vs recording time, provenance,
// and later correction/supersession relationships.
//
// Phase: Chunk 1 — Silent spine
//======================================

import Foundation

/// Provenance of an event. Driver-entered always outranks inference.
public enum EventProvenance: String, Codable, Sendable {
    case driverEntered
    case inferred
    case system
    case corrected
    case imported
}

/// Minimal event that can be persisted and replayed.
/// Domain-specific payloads will be added by later chunks via associated values or type erasure.
public struct Event: Identifiable, Codable, Sendable, Equatable {
    public let id: CanonicalID
    public let occurredAt: Date          // when the real-world thing happened
    public let recordedAt: Date          // when the system learned about it
    public let provenance: EventProvenance
    public let kind: String              // temporary string discriminator; will become typed later
    public let payload: Data?            // opaque for now; later chunks own typed payloads

    public init(
        id: CanonicalID = .fresh(),
        occurredAt: Date,
        recordedAt: Date = Date(),
        provenance: EventProvenance,
        kind: String,
        payload: Data? = nil
    ) {
        self.id = id
        self.occurredAt = occurredAt
        self.recordedAt = recordedAt
        self.provenance = provenance
        self.kind = kind
        self.payload = payload
    }
}

// MARK: - Common fabricated kinds (Chunk 1 only)

public extension Event {
    static func shiftStarted(at date: Date, provenance: EventProvenance = .driverEntered) -> Event {
        Event(occurredAt: date, provenance: provenance, kind: "shift.started")
    }

    static func shiftEnded(at date: Date, provenance: EventProvenance = .driverEntered) -> Event {
        Event(occurredAt: date, provenance: provenance, kind: "shift.ended")
    }

    static func note(_ text: String, at date: Date) -> Event {
        let data = try? JSONEncoder().encode(["text": text])
        return Event(occurredAt: date, provenance: .driverEntered, kind: "note", payload: data)
    }
}
