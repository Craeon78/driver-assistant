import Foundation

public enum OperationKind: String, Codable, Sendable, CaseIterable { case drive, stop, load, unload, transfer, wait, maintenance, incident }

public struct OperationEntry: Identifiable, Codable, Sendable, Equatable {
    public let id: CanonicalID
    public var kind: OperationKind
    public var start: Date
    public var end: Date?
    public let vehicleCombination: VehicleCombinationSnapshot
    public private(set) var distanceEvidence: VehicleDistanceEvidence?
    public var occurredAt: Date
    public var recordedAt: Date
    public var provenance: EventProvenance

    public init(id: CanonicalID = .fresh(), kind: OperationKind, start: Date, end: Date? = nil, vehicleCombination: VehicleCombinationSnapshot, occurredAt: Date? = nil, recordedAt: Date = Date(), provenance: EventProvenance = .driverEntered) {
        self.id = id; self.kind = kind; self.start = start; self.end = end
        self.vehicleCombination = vehicleCombination; self.distanceEvidence = nil
        self.occurredAt = occurredAt ?? start; self.recordedAt = recordedAt; self.provenance = provenance
    }

    public var isOpen: Bool { end == nil }

    @discardableResult
    public mutating func attachDistanceEvidence(_ evidence: VehicleDistanceEvidence) -> Bool {
        guard kind == .drive, evidence.poweredVehicleID == vehicleCombination.chassis.id, distanceEvidence == nil else { return false }
        distanceEvidence = evidence; return true
    }

    private enum CodingKeys: String, CodingKey { case id, kind, start, end, vehicleCombination, distanceEvidence, occurredAt, recordedAt, provenance }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(CanonicalID.self, forKey: .id); kind = try c.decode(OperationKind.self, forKey: .kind)
        start = try c.decode(Date.self, forKey: .start); end = try c.decodeIfPresent(Date.self, forKey: .end)
        vehicleCombination = try c.decode(VehicleCombinationSnapshot.self, forKey: .vehicleCombination)
        occurredAt = try c.decode(Date.self, forKey: .occurredAt); recordedAt = try c.decode(Date.self, forKey: .recordedAt)
        provenance = try c.decode(EventProvenance.self, forKey: .provenance)
        let evidence = try c.decodeIfPresent(VehicleDistanceEvidence.self, forKey: .distanceEvidence)
        if let evidence {
            guard kind == .drive, evidence.poweredVehicleID == vehicleCombination.chassis.id else {
                throw DecodingError.dataCorruptedError(forKey: .distanceEvidence, in: c, debugDescription: "Distance evidence must belong to this Drive operation's powered vehicle")
            }
        }
        distanceEvidence = evidence
    }
}

public struct OperationsLedger: Codable, Sendable, Equatable {
    public private(set) var entries: [OperationEntry]
    public init(entries: [OperationEntry] = []) { self.entries = entries.sorted { $0.start < $1.start } }
    public mutating func append(_ entry: OperationEntry) { entries.append(entry); entries.sort { $0.start < $1.start } }
    @discardableResult public mutating func close(id: CanonicalID, at end: Date) -> Bool {
        guard let i = entries.firstIndex(where: { $0.id == id }), entries[i].isOpen, end >= entries[i].start else { return false }
        entries[i].end = end; return true
    }
    @discardableResult public mutating func attachDistanceEvidence(operationID: CanonicalID, evidence: VehicleDistanceEvidence) -> Bool {
        guard !entries.contains(where: { $0.distanceEvidence?.interval.id == evidence.interval.id }),
              let i = entries.firstIndex(where: { $0.id == operationID }) else { return false }
        return entries[i].attachDistanceEvidence(evidence)
    }
    public var current: OperationEntry? { entries.last(where: { $0.isOpen }) }
}
