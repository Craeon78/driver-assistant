import Foundation

public enum OperationKind: String, Codable, Sendable, CaseIterable {
    case drive
    case stop
    case load
    case unload
    case transfer
    case wait
    case maintenance
    case incident
}

public struct OperationEntry: Identifiable, Codable, Sendable, Equatable {
    public let id: CanonicalID
    public var kind: OperationKind
    public var start: Date
    public var end: Date?
    public let vehicleCombination: VehicleCombinationSnapshot
    public var occurredAt: Date
    public var recordedAt: Date
    public var provenance: EventProvenance

    public init(
        id: CanonicalID = .fresh(),
        kind: OperationKind,
        start: Date,
        end: Date? = nil,
        vehicleCombination: VehicleCombinationSnapshot,
        occurredAt: Date? = nil,
        recordedAt: Date = Date(),
        provenance: EventProvenance = .driverEntered
    ) {
        self.id = id
        self.kind = kind
        self.start = start
        self.end = end
        self.vehicleCombination = vehicleCombination
        self.occurredAt = occurredAt ?? start
        self.recordedAt = recordedAt
        self.provenance = provenance
    }

    public var isOpen: Bool { end == nil }
}

public struct OperationsLedger: Codable, Sendable, Equatable {
    public private(set) var entries: [OperationEntry]

    public init(entries: [OperationEntry] = []) {
        self.entries = entries.sorted { $0.start < $1.start }
    }

    public mutating func append(_ entry: OperationEntry) {
        entries.append(entry)
        entries.sort { $0.start < $1.start }
    }

    /// Closes an open operation only. Returns false for unknown IDs, repeated closes,
    /// or an end timestamp before the operation began. Historical corrections belong
    /// in an explicit provenance-preserving correction path rather than this lifecycle action.
    @discardableResult
    public mutating func close(id: CanonicalID, at end: Date) -> Bool {
        guard let index = entries.firstIndex(where: { $0.id == id }),
              entries[index].isOpen,
              end >= entries[index].start else { return false }
        entries[index].end = end
        return true
    }

    public var current: OperationEntry? {
        entries.last(where: { $0.isOpen })
    }
}
