import Foundation

/// A reconciliation is a physical-state boundary, not cargo movement.
/// It preserves what arithmetic said, what physical evidence established, and the discrepancy.
/// The discrepancy is accounting evidence only and is never deliverable inventory.
public struct CargoReconciliationEvent: Identifiable, Codable, Sendable, Equatable {
    public let id: CanonicalID
    public let compartmentID: CanonicalID
    public let cargo: CargoKind
    public let calculatedUnitsBefore: Double
    public let confirmedPhysicalUnitsAfter: Double
    /// Optional independently observed movement discrepancy.
    /// Example: calculated 5,501 L available, meter proves 5,580 L delivered, confirmed empty => +79 L.
    public let observedMovementVariance: Double?
    public let occurredAt: Date
    public let recordedAt: Date
    public let provenance: EventProvenance
    public let relatedCargoTransactionID: CanonicalID?
    public let relatedOperationID: CanonicalID?
    public let note: String?

    public init(id: CanonicalID = .fresh(), compartmentID: CanonicalID, cargo: CargoKind, calculatedUnitsBefore: Double, confirmedPhysicalUnitsAfter: Double, observedMovementVariance: Double? = nil, occurredAt: Date, recordedAt: Date = Date(), provenance: EventProvenance = .driverEntered, relatedCargoTransactionID: CanonicalID? = nil, relatedOperationID: CanonicalID? = nil, note: String? = nil) {
        self.id=id; self.compartmentID=compartmentID; self.cargo=cargo
        self.calculatedUnitsBefore=calculatedUnitsBefore; self.confirmedPhysicalUnitsAfter=confirmedPhysicalUnitsAfter
        self.observedMovementVariance=observedMovementVariance; self.occurredAt=occurredAt; self.recordedAt=recordedAt
        self.provenance=provenance; self.relatedCargoTransactionID=relatedCargoTransactionID
        self.relatedOperationID=relatedOperationID; self.note=note
    }

    public var quantityDelta: Double {
        observedMovementVariance ?? (confirmedPhysicalUnitsAfter - calculatedUnitsBefore)
    }
}

public enum CargoReconciliationError: Error, Equatable {
    case negativeCalculatedState, negativePhysicalState, noVariance, duplicateEventID
}

/// Append-only reconciliation evidence. "Variance ledger" is a projection of these events,
/// not a second inventory ledger.
public struct CargoReconciliationLog: Codable, Sendable, Equatable {
    public private(set) var events: [CargoReconciliationEvent]
    private enum CodingKeys: String, CodingKey { case events }

    public init(events: [CargoReconciliationEvent] = []) throws {
        self.events=[]
        for e in events.sorted(by:Self.order) { try append(e) }
    }
    public init(from decoder: Decoder) throws {
        let c=try decoder.container(keyedBy:CodingKeys.self)
        do { self=try CargoReconciliationLog(events:c.decode([CargoReconciliationEvent].self,forKey:.events)) }
        catch { throw DecodingError.dataCorruptedError(forKey:.events,in:c,debugDescription:"Cargo reconciliation log failed validated replay: \(error)") }
    }
    public func encode(to encoder: Encoder) throws { var c=encoder.container(keyedBy:CodingKeys.self); try c.encode(events,forKey:.events) }
    public mutating func append(_ e: CargoReconciliationEvent) throws {
        guard e.calculatedUnitsBefore >= 0 else { throw CargoReconciliationError.negativeCalculatedState }
        guard e.confirmedPhysicalUnitsAfter >= 0 else { throw CargoReconciliationError.negativePhysicalState }
        guard abs(e.quantityDelta) > 0.000001 else { throw CargoReconciliationError.noVariance }
        guard !events.contains(where:{$0.id==e.id}) else { throw CargoReconciliationError.duplicateEventID }
        events.append(e); events.sort(by:Self.order)
    }
    /// Query/projection only. Never feed this value into Cargo availability.
    public func netVariance(cargoID: CanonicalID? = nil) -> Double {
        events.filter{cargoID==nil || $0.cargo.id==cargoID}.reduce(0){$0+$1.quantityDelta}
    }
    private static func order(_ a:CargoReconciliationEvent,_ b:CargoReconciliationEvent)->Bool { if a.occurredAt != b.occurredAt{return a.occurredAt<b.occurredAt}; if a.recordedAt != b.recordedAt{return a.recordedAt<b.recordedAt}; return a.id.raw.uuidString<b.id.raw.uuidString }
}

/// Current physical Cargo is a projection of movement truth plus reconciliation boundaries.
/// The CargoLedger itself remains movement-only and immutable.
public struct ReconciledCargoState: Codable, Sendable, Equatable {
    public let compartmentID: CanonicalID
    public let quantity: CargoQuantity?
}

public enum CargoStateReconciler {
    public static func currentState(ledger: CargoLedger, reconciliationLog: CargoReconciliationLog, compartmentID: CanonicalID) throws -> ReconciledCargoState {
        let base = try ledger.state(compartmentID: compartmentID)
        guard let boundary = reconciliationLog.events.filter({$0.compartmentID==compartmentID}).max(by: {
            if $0.occurredAt != $1.occurredAt { return $0.occurredAt < $1.occurredAt }
            if $0.recordedAt != $1.recordedAt { return $0.recordedAt < $1.recordedAt }
            return $0.id.raw.uuidString < $1.id.raw.uuidString
        }) else { return ReconciledCargoState(compartmentID:compartmentID,quantity:base.quantity) }

        // 5D permits a boundary only at the current edge. Later movement replay across historical
        // boundaries belongs in the unified EventLog work; do not silently invent ordering here.
        if let later = ledger.transactions.filter({$0.sourceCompartmentID==compartmentID || $0.destinationCompartmentID==compartmentID}).max(by: {$0.occurredAt<$1.occurredAt}), later.occurredAt > boundary.occurredAt {
            return ReconciledCargoState(compartmentID:compartmentID,quantity:base.quantity)
        }
        let q = boundary.confirmedPhysicalUnitsAfter <= 0.000001 ? nil : CargoQuantity(cargo:boundary.cargo,units:boundary.confirmedPhysicalUnitsAfter)
        return ReconciledCargoState(compartmentID:compartmentID,quantity:q)
    }
}
