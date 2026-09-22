import Foundation

public struct CargoReconciliationEvent: Identifiable, Codable, Sendable, Equatable {
    public let id: CanonicalID
    public let compartmentID: CanonicalID
    public let cargo: CargoKind
    public let calculatedUnitsBefore: Double
    public let confirmedPhysicalUnitsAfter: Double
    public let observedMovementVariance: Double?
    public let occurredAt: Date
    public let recordedAt: Date
    public let provenance: EventProvenance
    public let relatedCargoTransactionID: CanonicalID?
    public let relatedOperationID: CanonicalID?
    public let note: String?

    public init(id: CanonicalID = .fresh(), compartmentID: CanonicalID, cargo: CargoKind, calculatedUnitsBefore: Double, confirmedPhysicalUnitsAfter: Double, observedMovementVariance: Double? = nil, occurredAt: Date, recordedAt: Date = Date(), provenance: EventProvenance = .driverEntered, relatedCargoTransactionID: CanonicalID? = nil, relatedOperationID: CanonicalID? = nil, note: String? = nil) {
        self.id=id; self.compartmentID=compartmentID; self.cargo=cargo; self.calculatedUnitsBefore=calculatedUnitsBefore
        self.confirmedPhysicalUnitsAfter=confirmedPhysicalUnitsAfter; self.observedMovementVariance=observedMovementVariance
        self.occurredAt=occurredAt; self.recordedAt=recordedAt; self.provenance=provenance
        self.relatedCargoTransactionID=relatedCargoTransactionID; self.relatedOperationID=relatedOperationID; self.note=note
    }
    public var quantityDelta: Double { observedMovementVariance ?? (confirmedPhysicalUnitsAfter - calculatedUnitsBefore) }
}

public enum CargoReconciliationError: Error, Equatable {
    case negativeCalculatedState, negativePhysicalState, noVariance, duplicateEventID
    case unknownCompartment, staleCalculatedState, cargoMismatch, insufficientQuantity, capacityExceeded, invalidMovement
}

public struct CargoReconciliationLog: Codable, Sendable, Equatable {
    public private(set) var events: [CargoReconciliationEvent]
    private enum CodingKeys: String, CodingKey { case events }
    public init(events:[CargoReconciliationEvent]=[]) throws { self.events=[]; for e in events.sorted(by:Self.order){try append(e)} }
    public init(from decoder:Decoder)throws{let c=try decoder.container(keyedBy:CodingKeys.self); do{self=try CargoReconciliationLog(events:c.decode([CargoReconciliationEvent].self,forKey:.events))}catch{throw DecodingError.dataCorruptedError(forKey:.events,in:c,debugDescription:"Cargo reconciliation log failed validated replay: \(error)")}}
    public func encode(to encoder:Encoder)throws{var c=encoder.container(keyedBy:CodingKeys.self);try c.encode(events,forKey:.events)}
    public mutating func append(_ e:CargoReconciliationEvent)throws{
        guard e.calculatedUnitsBefore >= 0 else{throw CargoReconciliationError.negativeCalculatedState}
        guard e.confirmedPhysicalUnitsAfter >= 0 else{throw CargoReconciliationError.negativePhysicalState}
        guard abs(e.quantityDelta)>0.000001 else{throw CargoReconciliationError.noVariance}
        guard !events.contains(where:{$0.id==e.id}) else{throw CargoReconciliationError.duplicateEventID}
        events.append(e);events.sort(by:Self.order)
    }
    public func netVariance(cargoID:CanonicalID?=nil)->Double{events.filter{cargoID==nil || $0.cargo.id==cargoID}.reduce(0){$0+$1.quantityDelta}}
    fileprivate static func order(_ a:CargoReconciliationEvent,_ b:CargoReconciliationEvent)->Bool{if a.occurredAt != b.occurredAt{return a.occurredAt<b.occurredAt};if a.recordedAt != b.recordedAt{return a.recordedAt<b.recordedAt};return a.id.raw.uuidString<b.id.raw.uuidString}
}

public struct ReconciledCargoState: Codable, Sendable, Equatable {
    public let compartmentID:CanonicalID
    public let quantity:CargoQuantity?
}

/// Replays physical movement and reconciliation boundaries chronologically.
/// Reconciliation changes the physical baseline; its signed variance is never added to inventory.
public enum CargoStateReconciler {
    private struct Item { let occurredAt:Date; let recordedAt:Date; let id:String; let transaction:CargoTransaction?; let boundary:CargoReconciliationEvent? }

    public static func currentState(ledger:CargoLedger,reconciliationLog:CargoReconciliationLog,compartmentID:CanonicalID)throws->ReconciledCargoState {
        guard let limit=ledger.limits.first(where:{$0.compartmentID==compartmentID}) else{throw CargoReconciliationError.unknownCompartment}
        let txItems=ledger.transactions.filter{$0.sourceCompartmentID==compartmentID || $0.destinationCompartmentID==compartmentID}.map{Item(occurredAt:$0.occurredAt,recordedAt:$0.recordedAt,id:$0.id.raw.uuidString,transaction:$0,boundary:nil)}
        let boundaryItems=reconciliationLog.events.filter{$0.compartmentID==compartmentID}.map{Item(occurredAt:$0.occurredAt,recordedAt:$0.recordedAt,id:$0.id.raw.uuidString,transaction:nil,boundary:$0)}
        let ordered=(txItems+boundaryItems).sorted{a,b in if a.occurredAt != b.occurredAt{return a.occurredAt<b.occurredAt};if a.recordedAt != b.recordedAt{return a.recordedAt<b.recordedAt};return a.id<b.id}
        var quantity:CargoQuantity?
        var appliedTransactions:[CargoTransaction]=[]

        func signedEffect(_ transaction:CargoTransaction)->Double {
            var effect=0.0
            if transaction.destinationCompartmentID==compartmentID { effect += transaction.units }
            if transaction.sourceCompartmentID==compartmentID { effect -= transaction.units }
            return effect
        }

        func add(_ units:Double,cargo:CargoKind)throws{
            if let q=quantity,q.cargo != cargo{throw CargoReconciliationError.cargoMismatch}
            let next=(quantity?.units ?? 0)+units
            guard next<=limit.capacityUnits+0.000001 else{throw CargoReconciliationError.capacityExceeded}
            quantity=CargoQuantity(cargo:quantity?.cargo ?? cargo,units:next)
        }
        func remove(_ units:Double,cargo:CargoKind)throws{
            guard let q=quantity,q.cargo==cargo,q.units+0.000001>=units else{throw CargoReconciliationError.insufficientQuantity}
            let next=q.units-units;quantity=next<=0.000001 ? nil:CargoQuantity(cargo:q.cargo,units:next)
        }

        for item in ordered {
            if let t=item.transaction {
                switch t.kind {
                case .load:
                    if t.destinationCompartmentID==compartmentID{try add(t.units,cargo:t.cargo)}
                case .unload:
                    if t.sourceCompartmentID==compartmentID{try remove(t.units,cargo:t.cargo)}
                case .transfer:
                    if t.sourceCompartmentID==compartmentID{try remove(t.units,cargo:t.cargo)}
                    if t.destinationCompartmentID==compartmentID{try add(t.units,cargo:t.cargo)}
                case .correction:
                    if t.sourceCompartmentID==compartmentID{try remove(t.units,cargo:t.cargo)}
                    if t.destinationCompartmentID==compartmentID{try add(t.units,cargo:t.cargo)}
                }
                appliedTransactions.append(t)
            } else if let e=item.boundary {
                let current=quantity?.units ?? 0
                if let q=quantity,q.cargo.id != e.cargo.id{throw CargoReconciliationError.cargoMismatch}
                // A correction can be recorded after this observation while
                // replaying beside its original movement. Validate the saved
                // calculated-before value against knowledge available when the
                // boundary was recorded, then keep the physical boundary as the
                // later authoritative state.
                let laterRecordedCorrectionEffect=appliedTransactions
                    .filter{$0.provenance == .corrected && $0.recordedAt > e.recordedAt}
                    .reduce(0.0){$0+signedEffect($1)}
                let calculatedAsKnown=current-laterRecordedCorrectionEffect
                guard abs(calculatedAsKnown-e.calculatedUnitsBefore)<0.000001 else{throw CargoReconciliationError.staleCalculatedState}
                guard e.confirmedPhysicalUnitsAfter<=limit.capacityUnits+0.000001 else{throw CargoReconciliationError.capacityExceeded}
                quantity=e.confirmedPhysicalUnitsAfter<=0.000001 ? nil:CargoQuantity(cargo:e.cargo,units:e.confirmedPhysicalUnitsAfter)
                appliedTransactions=[]
            }
        }
        return ReconciledCargoState(compartmentID:compartmentID,quantity:quantity)
    }
}
