import Foundation

public enum CargoLedgerError: Error, Equatable {
    case nonPositiveQuantity
    case unknownSourceCompartment
    case unknownDestinationCompartment
    case invalidEndpoints
    case sameTransferCompartment
    case insufficientQuantity
    case capacityExceeded
    case mixedCargo
    case correctionTargetMissing
    case correctionTargetAlreadyCorrected
    case duplicateCompartmentLimit
    case duplicateTransactionID
}

/// Append-only cargo truth. Current compartment contents are derived by validated replay.
public struct CargoLedger: Codable, Sendable, Equatable {
    public let limits: [CargoCompartmentLimit]
    public private(set) var transactions: [CargoTransaction]

    public init(limits: [CargoCompartmentLimit], transactions: [CargoTransaction] = []) throws {
        var seenCompartments = Set<CanonicalID>()
        for limit in limits {
            guard seenCompartments.insert(limit.compartmentID).inserted else {
                throw CargoLedgerError.duplicateCompartmentLimit
            }
        }
        self.limits = limits
        self.transactions = []
        for transaction in transactions.sorted(by: Self.order) {
            try append(transaction)
        }
    }

    private enum CodingKeys: String, CodingKey { case limits, transactions }

    /// Persistence is not a privileged path. Decoded history is rebuilt through
    /// the same invariant checks as live appends before becoming usable truth.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedLimits = try container.decode([CargoCompartmentLimit].self, forKey: .limits)
        let decodedTransactions = try container.decode([CargoTransaction].self, forKey: .transactions)
        do {
            self = try CargoLedger(limits: decodedLimits, transactions: decodedTransactions)
        } catch {
            throw DecodingError.dataCorruptedError(
                forKey: .transactions,
                in: container,
                debugDescription: "Cargo ledger failed validated replay: \(error)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(limits, forKey: .limits)
        try container.encode(transactions, forKey: .transactions)
    }

    public mutating func append(_ transaction: CargoTransaction) throws {
        guard transaction.units > 0 else { throw CargoLedgerError.nonPositiveQuantity }
        guard !transactions.contains(where: { $0.id == transaction.id }) else { throw CargoLedgerError.duplicateTransactionID }
        try validateShape(transaction)
        if transaction.kind == .correction { try validateCorrection(transaction) }
        var candidate = transactions
        candidate.append(transaction)
        try Self.project(limits: limits, transactions: candidate)
        transactions.append(transaction)
        transactions.sort(by: Self.order)
    }

    public func state(compartmentID: CanonicalID) throws -> CargoCompartmentState {
        guard limits.contains(where: { $0.compartmentID == compartmentID }) else { throw CargoLedgerError.unknownDestinationCompartment }
        let projection = try Self.project(limits: limits, transactions: transactions)
        return CargoCompartmentState(compartmentID: compartmentID, quantity: projection[compartmentID])
    }

    public func allStates() throws -> [CargoCompartmentState] {
        let projection = try Self.project(limits: limits, transactions: transactions)
        return limits.map { CargoCompartmentState(compartmentID: $0.compartmentID, quantity: projection[$0.compartmentID]) }
    }

    public func currentCargoMassKg() throws -> Double? {
        let quantities = try allStates().compactMap(\.quantity)
        guard quantities.allSatisfy({ $0.massKg != nil }) else { return nil }
        return quantities.compactMap(\.massKg).reduce(0, +)
    }

    private func validateShape(_ t: CargoTransaction) throws {
        let known: (CanonicalID?) -> Bool = { id in id.map { wanted in limits.contains { $0.compartmentID == wanted } } ?? false }
        switch t.kind {
        case .load:
            guard t.sourceCompartmentID == nil, known(t.destinationCompartmentID) else { throw CargoLedgerError.invalidEndpoints }
        case .unload:
            guard known(t.sourceCompartmentID), t.destinationCompartmentID == nil else { throw CargoLedgerError.invalidEndpoints }
        case .transfer:
            guard known(t.sourceCompartmentID), known(t.destinationCompartmentID) else { throw CargoLedgerError.invalidEndpoints }
            guard t.sourceCompartmentID != t.destinationCompartmentID else { throw CargoLedgerError.sameTransferCompartment }
        case .correction:
            guard t.correctsTransactionID != nil else { throw CargoLedgerError.correctionTargetMissing }
        }
    }

    private func validateCorrection(_ t: CargoTransaction) throws {
        guard let targetID = t.correctsTransactionID,
              let target = transactions.first(where: { $0.id == targetID }) else { throw CargoLedgerError.correctionTargetMissing }
        guard !transactions.contains(where: { $0.correctsTransactionID == targetID }) else { throw CargoLedgerError.correctionTargetAlreadyCorrected }
        // A correction is an exact persisted inverse of the target; descriptor,
        // units and endpoints must all match so mass/unit semantics cannot drift.
        guard t.cargo == target.cargo,
              t.units == target.units,
              t.sourceCompartmentID == target.destinationCompartmentID,
              t.destinationCompartmentID == target.sourceCompartmentID else { throw CargoLedgerError.invalidEndpoints }
    }

    private static func order(_ a: CargoTransaction, _ b: CargoTransaction) -> Bool {
        if a.occurredAt != b.occurredAt { return a.occurredAt < b.occurredAt }
        if a.recordedAt != b.recordedAt { return a.recordedAt < b.recordedAt }
        return a.id.raw.uuidString < b.id.raw.uuidString
    }

    private static func project(limits: [CargoCompartmentLimit], transactions: [CargoTransaction]) throws -> [CanonicalID: CargoQuantity] {
        var state: [CanonicalID: CargoQuantity] = [:]
        var capacity: [CanonicalID: Double] = [:]
        for limit in limits {
            guard capacity[limit.compartmentID] == nil else { throw CargoLedgerError.duplicateCompartmentLimit }
            capacity[limit.compartmentID] = limit.capacityUnits
        }

        func remove(_ units: Double, cargo: CargoKind, from id: CanonicalID) throws {
            guard let current = state[id], current.cargo == cargo, current.units + 0.000001 >= units else { throw CargoLedgerError.insufficientQuantity }
            let remaining = current.units - units
            if remaining <= 0.000001 { state[id] = nil }
            else { state[id] = CargoQuantity(cargo: current.cargo, units: remaining) }
        }
        func add(_ units: Double, cargo: CargoKind, to id: CanonicalID) throws {
            guard let cap = capacity[id] else { throw CargoLedgerError.unknownDestinationCompartment }
            if let current = state[id], current.cargo != cargo { throw CargoLedgerError.mixedCargo }
            let next = (state[id]?.units ?? 0) + units
            guard next <= cap + 0.000001 else { throw CargoLedgerError.capacityExceeded }
            state[id] = CargoQuantity(cargo: state[id]?.cargo ?? cargo, units: next)
        }

        for t in transactions.sorted(by: order) {
            switch t.kind {
            case .load:
                guard let destination = t.destinationCompartmentID else { throw CargoLedgerError.invalidEndpoints }
                try add(t.units, cargo: t.cargo, to: destination)
            case .unload:
                guard let source = t.sourceCompartmentID else { throw CargoLedgerError.invalidEndpoints }
                try remove(t.units, cargo: t.cargo, from: source)
            case .transfer:
                guard let source = t.sourceCompartmentID, let destination = t.destinationCompartmentID else { throw CargoLedgerError.invalidEndpoints }
                try remove(t.units, cargo: t.cargo, from: source)
                try add(t.units, cargo: t.cargo, to: destination)
            case .correction:
                if let source = t.sourceCompartmentID { try remove(t.units, cargo: t.cargo, from: source) }
                if let destination = t.destinationCompartmentID { try add(t.units, cargo: t.cargo, to: destination) }
            }
        }
        return state
    }
}
