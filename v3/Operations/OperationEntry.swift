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
    /// Optional immutable evidence produced by Core/Vehicle integration.
    /// Operations consumes this evidence; it does not own ODO or GPS truth.
    public var distanceEvidence: VehicleDistanceEvidence?
    public var occurredAt: Date
    public var recordedAt: Date
    public var provenance: EventProvenance

    public init(
        id: CanonicalID = .fresh(),
        kind: OperationKind,
        start: Date,
        end: Date? = nil,
        vehicleCombination: VehicleCombinationSnapshot,
        distanceEvidence: VehicleDistanceEvidence? = nil,
        occurredAt: Date? = nil,
        recordedAt: Date = Date(),
        provenance: EventProvenance = .driverEntered
    ) {
        self.id = id
        self.kind = kind
        self.start = start
        self.end = end
        self.vehicleCombination = vehicleCombination
        self.distanceEvidence = distanceEvidence
        self.occurredAt = occurredAt ?? start
        self.recordedAt = recordedAt
        self.provenance = provenance
    }

    public var isOpen: Bool { end == nil }

    /// Attaches already-produced distance evidence only when it belongs to this
    /// operation's powered vehicle. Returns false rather than rewriting truth.
    @discardableResult
    public mutating func attachDistanceEvidence(_ evidence: VehicleDistanceEvidence) -> Bool {
        guard kind == .drive,
              evidence.poweredVehicleID == vehicleCombination.chassis.id,
              distanceEvidence == nil else { return false }
        distanceEvidence = evidence
        return true
    }
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

    @discardableResult
    public mutating func close(id: CanonicalID, at end: Date) -> Bool {
        guard let index = entries.firstIndex(where: { $0.id == id }),
              entries[index].isOpen,
              end >= entries[index].start else { return false }
        entries[index].end = end
        return true
    }

    @discardableResult
    public mutating func attachDistanceEvidence(operationID: CanonicalID, evidence: VehicleDistanceEvidence) -> Bool {
        guard let index = entries.firstIndex(where: { $0.id == operationID }) else { return false }
        return entries[index].attachDistanceEvidence(evidence)
    }

    public var current: OperationEntry? {
        entries.last(where: { $0.isOpen })
    }
}
