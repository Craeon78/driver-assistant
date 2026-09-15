//======================================
// MARK: - WorkRestEntry (V3 Driver)
//======================================
//
// © 2026 Cory Russell Olsen. All rights reserved.
//
// Atomic work/rest interval on the Driver ledger.
// Kind is binary only — Operations must not leak in here.
//
// Phase: Chunk 3a — Ledger spine
//======================================

import Foundation

public enum WorkRestKind: String, Codable, Sendable, CaseIterable {
    case work
    case rest
}

public struct WorkRestEntry: Identifiable, Codable, Sendable, Equatable {
    public let id: CanonicalID
    public var kind: WorkRestKind
    public var start: Date
    /// nil = open (in progress). Overnight-open stays one entry across midnight.
    public var end: Date?
    /// Required for stationary-rest rules later; default true for rest, false for work.
    public var stationaryRest: Bool
    public var occurredAt: Date
    public var recordedAt: Date
    public var provenance: EventProvenance

    public init(
        id: CanonicalID = .fresh(),
        kind: WorkRestKind,
        start: Date,
        end: Date? = nil,
        stationaryRest: Bool? = nil,
        occurredAt: Date? = nil,
        recordedAt: Date = Date(),
        provenance: EventProvenance = .driverEntered
    ) {
        self.id = id
        self.kind = kind
        self.start = start
        self.end = end
        self.stationaryRest = stationaryRest ?? (kind == .rest)
        self.occurredAt = occurredAt ?? start
        self.recordedAt = recordedAt
        self.provenance = provenance
    }

    public var isOpen: Bool { end == nil }

    public func duration(asOf now: Date) -> TimeInterval {
        let effectiveEnd = end ?? now
        return max(effectiveEnd.timeIntervalSince(start), 0)
    }
}
