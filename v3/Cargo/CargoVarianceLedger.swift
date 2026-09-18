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

    public mutating func append(_ entry: CargoVarianceEntry) throws {
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
