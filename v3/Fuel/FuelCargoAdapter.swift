import Foundation

public struct FuelLoadCommit: Codable, Sendable, Equatable {
    public let cargoTransaction: CargoTransaction
    public let fuelStateEvent: FuelStateEvent
    public let loadEvidence: FuelLoadEvidence

    public init(cargoTransaction: CargoTransaction, fuelStateEvent: FuelStateEvent, loadEvidence: FuelLoadEvidence) {
        self.cargoTransaction = cargoTransaction
        self.fuelStateEvent = fuelStateEvent
        self.loadEvidence = loadEvidence
    }
}

/// Fuel-facing commands translated onto the generic 5A Cargo ledger.
/// There is deliberately no second Fuel ledger.
public enum FuelCargoAdapter {
    /// A load is prepared as one handshake object: Cargo quantity truth + Fuel chemical
    /// state + load-specific density evidence. Callers persist/commit this unit together.
    public static func prepareLoad(
        product: FuelProduct,
        litres: Double,
        evidence: FuelLoadEvidence,
        into compartmentID: CanonicalID,
        occurredAt: Date,
        provenance: EventProvenance = .driverEntered,
        note: String? = nil
    ) -> FuelLoadCommit {
        let cargo = CargoTransaction(
            kind: .load,
            cargo: product.cargoKind,
            units: litres,
            destinationCompartmentID: compartmentID,
            occurredAt: occurredAt,
            provenance: provenance,
            note: note
        )
        let fuel = FuelStateEvent(
            kind: .productEntered,
            compartmentID: compartmentID,
            productID: product.id,
            family: product.family,
            occurredAt: occurredAt,
            provenance: provenance,
            note: note
        )
        return FuelLoadCommit(cargoTransaction: cargo, fuelStateEvent: fuel, loadEvidence: evidence)
    }

    /// Validates against a copy first. The caller receives both updated truths only if
    /// the generic Cargo ledger accepts the load. No half-mutated ledger escapes on failure.
    public static func committing(
        _ commit: FuelLoadCommit,
        to ledger: CargoLedger,
        fuelEvents: [FuelStateEvent]
    ) throws -> (ledger: CargoLedger, fuelEvents: [FuelStateEvent]) {
        var candidateLedger = ledger
        try candidateLedger.append(commit.cargoTransaction)
        var candidateEvents = fuelEvents
        candidateEvents.append(commit.fuelStateEvent)
        _ = try FuelProjector.project(cargoLedger: candidateLedger, fuelEvents: candidateEvents)
        return (candidateLedger, candidateEvents)
    }

    public static func delivery(
        product: FuelProduct,
        litres: Double,
        from compartmentID: CanonicalID,
        occurredAt: Date,
        provenance: EventProvenance = .driverEntered,
        destinationDescription: String? = nil
    ) -> CargoTransaction {
        CargoTransaction(kind: .unload, cargo: product.cargoKind, units: litres, sourceCompartmentID: compartmentID, occurredAt: occurredAt, provenance: provenance, note: destinationDescription)
    }

    public static func transfer(
        product: FuelProduct,
        litres: Double,
        from sourceID: CanonicalID,
        to destinationID: CanonicalID,
        occurredAt: Date,
        provenance: EventProvenance = .driverEntered,
        note: String? = nil
    ) -> CargoTransaction {
        CargoTransaction(kind: .transfer, cargo: product.cargoKind, units: litres, sourceCompartmentID: sourceID, destinationCompartmentID: destinationID, occurredAt: occurredAt, provenance: provenance, note: note)
    }

    public static func correction(
        of target: CargoTransaction,
        occurredAt: Date,
        provenance: EventProvenance = .driverEntered,
        note: String? = nil
    ) -> CargoTransaction {
        CargoTransaction(kind: .correction, cargo: target.cargo, units: target.units, sourceCompartmentID: target.destinationCompartmentID, destinationCompartmentID: target.sourceCompartmentID, occurredAt: occurredAt, provenance: provenance, correctsTransactionID: target.id, note: note)
    }
}
