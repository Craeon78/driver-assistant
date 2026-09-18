import Foundation

/// A signed accounting discrepancy between projected Cargo state and observed physical truth.
/// Positive means more physical cargo was observed/moved than the projection explained.
/// Negative means less physical cargo was observed than the projection expected.
///
/// Variance is evidence only. It is never deliverable inventory and is never replayed into
/// CargoLedger compartment balances.
public struct CargoVarianceEntry: Identifiable, Codable, Sendable, Equatable {
    public let id: CanonicalID
    public let cargo: CargoKind
    public let quantityDelta: Double
    public let occurredAt: Date
    public let recordedAt: Date
    public let provenance: EventProvenance
    public let relatedCargoTransactionID: CanonicalID?
    public let relatedOperationID: CanonicalID?
    public let resultingKnownUnits: Double
    public let note: String?

    public init(
        id: CanonicalID = .fresh(),
        cargo: CargoKind,
        quantityDelta: Double,
        occurredAt: Date,
        recordedAt: Date = Date(),
        provenance: EventProvenance = .driverEntered,
        relatedCargoTransactionID: CanonicalID? = nil,
        relatedOperationID: CanonicalID? = nil,
        resultingKnownUnits: Double,
        note: String? = nil
    ) {
        self.id = id
        self.cargo = cargo
        self.quantityDelta = quantityDelta
        self.occurredAt = occurredAt
        self.recordedAt = recordedAt
        self.provenance = provenance
        self.relatedCargoTransactionID = relatedCargoTransactionID
        self.relatedOperationID = relatedOperationID
        self.resultingKnownUnits = resultingKnownUnits
        self.note = note
    }
}

public enum CargoVarianceLedgerError: Error, Equatable {
    case zeroVariance
    case negativeResultingPhysicalState
    case duplicateEntryID
}

/// Append-only accounting of discrepancies. Deliberately separate from CargoLedger:
/// this ledger can explain and later analyse variance, but cannot be dipped into for a delivery.
public struct CargoVarianceLedger: Codable, Sendable, Equatable {
    public private(set) var entries: [CargoVarianceEntry]

    public init(entries: [CargoVarianceEntry] = []) throws {
        self.entries = []
        for entry in entries.sorted(by: Self.order) {
            try append(entry)
        }
    }

    public init(from decoder: Decoder) throws {\n        let container = try decoder.container(keyedBy: CodingKeys.self)\n        let decoded = try container.decode([CargoVarianceEntry].self, forKey: .entries)\n        do { self = try CargoVarianceLedger(entries: decoded) }\n        catch { throw DecodingError.dataCorruptedError(forKey: .entries, in: container, debugDescription: "Cargo variance ledger failed validated replay: \\(error)") }\n    }\n\n    public func encode(to encoder: Encoder) throws {\n        var container = encoder.container(keyedBy: CodingKeys.self)\n        try container.encode(entries, forKey: .entries)\n    }\n\n    public mutating func append(_ entry: CargoVarianceEntry) throws {
        guard abs(entry.quantityDelta) > 0.000001 else { throw CargoVarianceLedgerError.zeroVariance }
        guard entry.resultingKnownUnits >= -0.000001 else { throw CargoVarianceLedgerError.negativeResultingPhysicalState }
        guard !entries.contains(where: { $0.id == entry.id }) else { throw CargoVarianceLedgerError.duplicateEntryID }
        entries.append(entry)
        entries.sort(by: Self.order)
    }

    /// Accounting total only. This value must never be interpreted as available Cargo.
    public func netVariance(cargoID: CanonicalID? = nil) -> Double {
        entries
            .filter { cargoID == nil || $0.cargo.id == cargoID }
            .reduce(0) { $0 + $1.quantityDelta }
    }

    private static func order(_ a: CargoVarianceEntry, _ b: CargoVarianceEntry) -> Bool {
        if a.occurredAt != b.occurredAt { return a.occurredAt < b.occurredAt }
        if a.recordedAt != b.recordedAt { return a.recordedAt < b.recordedAt }
        return a.id.raw.uuidString < b.id.raw.uuidString
    }
}

public struct CargoReconciliation: Codable, Sendable, Equatable {
    public let id: CanonicalID
    public let compartmentID: CanonicalID
    public let cargo: CargoKind
    public let calculatedUnits: Double
    public let confirmedPhysicalUnits: Double
    public let occurredAt: Date
    public let provenance: EventProvenance
    public let relatedOperationID: CanonicalID?

    public init(id: CanonicalID = .fresh(), compartmentID: CanonicalID, cargo: CargoKind, calculatedUnits: Double, confirmedPhysicalUnits: Double, occurredAt: Date, provenance: EventProvenance = .driverEntered, relatedOperationID: CanonicalID? = nil) {
        self.id = id
        self.compartmentID = compartmentID
        self.cargo = cargo
        self.calculatedUnits = calculatedUnits
        self.confirmedPhysicalUnits = confirmedPhysicalUnits
        self.occurredAt = occurredAt
        self.provenance = provenance
        self.relatedOperationID = relatedOperationID
    }
}

public enum CargoReconciliationError: Error, Equatable {
    case unknownCompartment
    case cargoMismatch
    case staleCalculatedState
    case negativePhysicalState
    case noVariance\n    case backdatedBoundary
}

/// Reconciliation establishes physical truth without pretending cargo moved.
public enum CargoReconciler {
    public static func reconcile(_ request: CargoReconciliation, cargoLedger: CargoLedger, varianceLedger: CargoVarianceLedger) throws -> (cargoLedger: CargoLedger, varianceLedger: CargoVarianceLedger, variance: CargoVarianceEntry) {
        guard request.confirmedPhysicalUnits >= 0 else { throw CargoReconciliationError.negativePhysicalState }\n        if let latest = cargoLedger.transactions.max(by: {\n            if $0.occurredAt != $1.occurredAt { return $0.occurredAt < $1.occurredAt }\n            if $0.recordedAt != $1.recordedAt { return $0.recordedAt < $1.recordedAt }\n            return $0.id.raw.uuidString < $1.id.raw.uuidString\n        }), request.occurredAt < latest.occurredAt { throw CargoReconciliationError.backdatedBoundary }
        let state: CargoCompartmentState
        do { state = try cargoLedger.state(compartmentID: request.compartmentID) }
        catch { throw CargoReconciliationError.unknownCompartment }

        let current = state.quantity?.units ?? 0
        if let currentCargo = state.quantity?.cargo, currentCargo.id != request.cargo.id { throw CargoReconciliationError.cargoMismatch }
        guard abs(current - request.calculatedUnits) < 0.000001 else { throw CargoReconciliationError.staleCalculatedState }

        let delta = request.confirmedPhysicalUnits - request.calculatedUnits
        guard abs(delta) > 0.000001 else { throw CargoReconciliationError.noVariance }

        var candidateCargo = cargoLedger
        let boundary = CargoTransaction(id: request.id, kind: .reconcile, cargo: request.cargo, units: request.confirmedPhysicalUnits, sourceCompartmentID: request.compartmentID, occurredAt: request.occurredAt, provenance: request.provenance, note: "confirmed physical reconciliation boundary")
        try candidateCargo.append(boundary)

        var candidateVariance = varianceLedger
        let entry = CargoVarianceEntry(cargo: request.cargo, quantityDelta: delta, occurredAt: request.occurredAt, provenance: request.provenance, relatedCargoTransactionID: boundary.id, relatedOperationID: request.relatedOperationID, resultingKnownUnits: request.confirmedPhysicalUnits)
        try candidateVariance.append(entry)
        return (candidateCargo, candidateVariance, entry)
    }
}
