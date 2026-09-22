import Foundation

public enum CargoLedgerError: Error, Equatable {
    case nonPositiveQuantity, unknownSourceCompartment, unknownDestinationCompartment, invalidEndpoints
    case sameTransferCompartment, insufficientQuantity, capacityExceeded, mixedCargo
    case correctionTargetMissing, correctionTargetAlreadyCorrected, duplicateCompartmentLimit, duplicateTransactionID, reconciliationRequired
}

public struct CargoLedger: Codable, Sendable, Equatable {
    public let limits: [CargoCompartmentLimit]
    public private(set) var transactions: [CargoTransaction]
    public private(set) var requiresReconciliationForReplay: Bool

    public init(limits: [CargoCompartmentLimit], transactions: [CargoTransaction] = []) throws {
        var seen = Set<CanonicalID>()
        for limit in limits { guard seen.insert(limit.compartmentID).inserted else { throw CargoLedgerError.duplicateCompartmentLimit } }
        self.limits=limits; self.transactions=[]; self.requiresReconciliationForReplay=false
        for t in transactions.sorted(by: Self.order) { try append(t) }
    }
    private enum CodingKeys: String, CodingKey { case limits, transactions, requiresReconciliationForReplay }
    public init(from decoder: Decoder) throws {
        let c=try decoder.container(keyedBy:CodingKeys.self)
        let decodedLimits=try c.decode([CargoCompartmentLimit].self,forKey:.limits)
        let decodedTransactions=try c.decode([CargoTransaction].self,forKey:.transactions)
        let reconciliationAware=try c.decodeIfPresent(Bool.self,forKey:.requiresReconciliationForReplay) ?? false
        if !reconciliationAware {
            do { self=try CargoLedger(limits:decodedLimits,transactions:decodedTransactions) }
            catch { throw DecodingError.dataCorruptedError(forKey:.transactions,in:c,debugDescription:"Cargo ledger failed validated replay: \\(error)") }
            return
        }
        var seenLimits=Set<CanonicalID>()
        for limit in decodedLimits { guard seenLimits.insert(limit.compartmentID).inserted else { throw DecodingError.dataCorruptedError(forKey:.limits,in:c,debugDescription:"Duplicate compartment limit") } }
        self.limits=decodedLimits; self.transactions=[]; self.requiresReconciliationForReplay=true
        do {
            for t in decodedTransactions.sorted(by:Self.order) {
                guard t.units > 0 else { throw CargoLedgerError.nonPositiveQuantity }
                guard !transactions.contains(where:{$0.id==t.id}) else { throw CargoLedgerError.duplicateTransactionID }
                try validateShape(t); if t.kind == .correction { try validateCorrection(t) }
                transactions.append(t)
            }
        } catch { throw DecodingError.dataCorruptedError(forKey:.transactions,in:c,debugDescription:"Reconciliation-aware cargo ledger failed structural replay: \\(error)") }
    }
    public func encode(to encoder: Encoder) throws { var c=encoder.container(keyedBy:CodingKeys.self); try c.encode(limits,forKey:.limits); try c.encode(transactions,forKey:.transactions); try c.encode(requiresReconciliationForReplay,forKey:.requiresReconciliationForReplay) }

    public mutating func append(_ t: CargoTransaction) throws {
        guard t.units > 0 else { throw CargoLedgerError.nonPositiveQuantity }
        guard !transactions.contains(where:{$0.id==t.id}) else { throw CargoLedgerError.duplicateTransactionID }
        try validateShape(t); if t.kind == .correction { try validateCorrection(t) }
        var candidate=transactions; candidate.append(t); _=try Self.project(limits:limits,transactions:candidate)
        transactions.append(t); transactions.sort(by:Self.order)
    }

    public mutating func append(_ t: CargoTransaction, reconciliationLog: CargoReconciliationLog) throws {
        if reconciliationLog.events.isEmpty { try append(t); return }
        guard t.units > 0 else { throw CargoLedgerError.nonPositiveQuantity }
        guard !transactions.contains(where:{$0.id==t.id}) else { throw CargoLedgerError.duplicateTransactionID }
        try validateShape(t)
        if t.kind == .correction { try validateCorrection(t) }
        let previousTransactions=transactions
        let previousFlag=requiresReconciliationForReplay
        transactions.append(t); transactions.sort(by:Self.order); requiresReconciliationForReplay=true
        do {
            for limit in limits {
                _ = try CargoStateReconciler.currentState(ledger:self,reconciliationLog:reconciliationLog,compartmentID:limit.compartmentID)
            }
        } catch {
            transactions=previousTransactions; requiresReconciliationForReplay=previousFlag
            throw error
        }
    }

    /// Appends the reversal and corrected replacement as one validated replay
    /// unit. A historical Load correction may otherwise fail while the ledger
    /// temporarily contains only the reversal and later unloads.
    public mutating func appendCorrectionPair(
        reversal: CargoTransaction,
        replacement: CargoTransaction,
        reconciliationLog: CargoReconciliationLog
    ) throws {
        guard reversal.units > 0, replacement.units > 0 else { throw CargoLedgerError.nonPositiveQuantity }
        guard reversal.id != replacement.id,
              !transactions.contains(where: { $0.id == reversal.id || $0.id == replacement.id }) else {
            throw CargoLedgerError.duplicateTransactionID
        }
        guard reversal.kind == .correction else { throw CargoLedgerError.invalidEndpoints }
        try validateShape(reversal)
        try validateCorrection(reversal)
        try validateShape(replacement)
        guard let targetID = reversal.correctsTransactionID,
              let target = transactions.first(where: { $0.id == targetID }),
              replacement.kind == target.kind,
              replacement.cargo == target.cargo,
              replacement.sourceCompartmentID == target.sourceCompartmentID,
              replacement.destinationCompartmentID == target.destinationCompartmentID,
              replacement.correctsTransactionID == nil else {
            throw CargoLedgerError.invalidEndpoints
        }

        let previousTransactions = transactions
        let previousFlag = requiresReconciliationForReplay
        transactions.append(contentsOf: [reversal, replacement])
        transactions.sort(by: Self.order)
        do {
            if reconciliationLog.events.isEmpty {
                _ = try Self.project(limits: limits, transactions: transactions)
            } else {
                requiresReconciliationForReplay = true
                for limit in limits {
                    _ = try CargoStateReconciler.currentState(ledger: self, reconciliationLog: reconciliationLog, compartmentID: limit.compartmentID)
                }
            }
        } catch {
            transactions = previousTransactions
            requiresReconciliationForReplay = previousFlag
            throw error
        }
    }

    public func state(compartmentID: CanonicalID) throws -> CargoCompartmentState {
        guard !requiresReconciliationForReplay else { throw CargoLedgerError.reconciliationRequired }
        guard limits.contains(where:{$0.compartmentID==compartmentID}) else { throw CargoLedgerError.unknownDestinationCompartment }
        return CargoCompartmentState(compartmentID:compartmentID,quantity:try Self.project(limits:limits,transactions:transactions)[compartmentID])
    }
    public func allStates() throws -> [CargoCompartmentState] { guard !requiresReconciliationForReplay else { throw CargoLedgerError.reconciliationRequired }; let p=try Self.project(limits:limits,transactions:transactions); return limits.map{CargoCompartmentState(compartmentID:$0.compartmentID,quantity:p[$0.compartmentID])} }
    public func currentCargoMassKg() throws -> Double? { let q=try allStates().compactMap(\.quantity); guard q.allSatisfy({$0.massKg != nil}) else{return nil}; return q.compactMap(\.massKg).reduce(0,+) }

    private func validateShape(_ t: CargoTransaction) throws {
        let known:(CanonicalID?)->Bool={id in id.map{wanted in limits.contains{$0.compartmentID==wanted}} ?? false}
        switch t.kind {
        case .load: guard t.sourceCompartmentID==nil,known(t.destinationCompartmentID) else{throw CargoLedgerError.invalidEndpoints}
        case .unload: guard known(t.sourceCompartmentID),t.destinationCompartmentID==nil else{throw CargoLedgerError.invalidEndpoints}
        case .transfer: guard known(t.sourceCompartmentID),known(t.destinationCompartmentID) else{throw CargoLedgerError.invalidEndpoints}; guard t.sourceCompartmentID != t.destinationCompartmentID else{throw CargoLedgerError.sameTransferCompartment}
        case .correction: guard t.correctsTransactionID != nil else{throw CargoLedgerError.correctionTargetMissing}
        }
    }
    private func validateCorrection(_ t: CargoTransaction) throws {
        guard let id=t.correctsTransactionID,let target=transactions.first(where:{$0.id==id}) else{throw CargoLedgerError.correctionTargetMissing}
        guard !transactions.contains(where:{$0.correctsTransactionID==id}) else{throw CargoLedgerError.correctionTargetAlreadyCorrected}
        guard t.cargo==target.cargo,t.units==target.units,t.sourceCompartmentID==target.destinationCompartmentID,t.destinationCompartmentID==target.sourceCompartmentID else{throw CargoLedgerError.invalidEndpoints}
    }
    private static func order(_ a:CargoTransaction,_ b:CargoTransaction)->Bool { if a.occurredAt != b.occurredAt{return a.occurredAt<b.occurredAt}; if a.recordedAt != b.recordedAt{return a.recordedAt<b.recordedAt}; return a.id.raw.uuidString<b.id.raw.uuidString }
    private static func project(limits:[CargoCompartmentLimit],transactions:[CargoTransaction]) throws -> [CanonicalID:CargoQuantity] {
        var state:[CanonicalID:CargoQuantity]=[:]; var capacity:[CanonicalID:Double]=[:]
        for l in limits { guard capacity[l.compartmentID]==nil else{throw CargoLedgerError.duplicateCompartmentLimit}; capacity[l.compartmentID]=l.capacityUnits }
        func remove(_ units:Double,cargo:CargoKind,from id:CanonicalID)throws{guard let cur=state[id],cur.cargo==cargo,cur.units+0.000001>=units else{throw CargoLedgerError.insufficientQuantity}; let r=cur.units-units; state[id]=r<=0.000001 ? nil:CargoQuantity(cargo:cur.cargo,units:r)}
        func add(_ units:Double,cargo:CargoKind,to id:CanonicalID)throws{guard let cap=capacity[id] else{throw CargoLedgerError.unknownDestinationCompartment}; if let cur=state[id],cur.cargo != cargo{throw CargoLedgerError.mixedCargo}; let n=(state[id]?.units ?? 0)+units; guard n<=cap+0.000001 else{throw CargoLedgerError.capacityExceeded}; state[id]=CargoQuantity(cargo:state[id]?.cargo ?? cargo,units:n)}
        for t in transactions.sorted(by:order) {
            switch t.kind {
            case .load: guard let d=t.destinationCompartmentID else{throw CargoLedgerError.invalidEndpoints}; try add(t.units,cargo:t.cargo,to:d)
            case .unload: guard let s=t.sourceCompartmentID else{throw CargoLedgerError.invalidEndpoints}; try remove(t.units,cargo:t.cargo,from:s)
            case .transfer: guard let s=t.sourceCompartmentID,let d=t.destinationCompartmentID else{throw CargoLedgerError.invalidEndpoints}; try remove(t.units,cargo:t.cargo,from:s); try add(t.units,cargo:t.cargo,to:d)
            case .correction: if let s=t.sourceCompartmentID{try remove(t.units,cargo:t.cargo,from:s)}; if let d=t.destinationCompartmentID{try add(t.units,cargo:t.cargo,to:d)}
            }
        }
        return state
    }
}
