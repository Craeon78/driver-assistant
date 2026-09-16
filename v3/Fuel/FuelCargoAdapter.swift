import Foundation

public struct FuelLoadEvidenceRecord: Codable, Sendable, Equatable {
    public let cargoTransactionID: CanonicalID
    public let evidence: FuelLoadEvidence

    public init(cargoTransactionID: CanonicalID, evidence: FuelLoadEvidence) {
        self.cargoTransactionID = cargoTransactionID
        self.evidence = evidence
    }
}

public struct FuelCommittedState: Codable, Sendable, Equatable {
    public var ledger: CargoLedger
    public var fuelEvents: [FuelStateEvent]
    public var loadEvidence: [FuelLoadEvidenceRecord]

    public init(ledger: CargoLedger, fuelEvents: [FuelStateEvent] = [], loadEvidence: [FuelLoadEvidenceRecord] = []) {
        self.ledger = ledger
        self.fuelEvents = fuelEvents
        self.loadEvidence = loadEvidence
    }
}

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

public struct FuelTransferCommit: Codable, Sendable, Equatable {
    public let cargoTransaction: CargoTransaction
    public let destinationFuelStateEvent: FuelStateEvent

    public init(cargoTransaction: CargoTransaction, destinationFuelStateEvent: FuelStateEvent) {
        self.cargoTransaction = cargoTransaction
        self.destinationFuelStateEvent = destinationFuelStateEvent
    }
}

public enum FuelCargoHandshakeError: Error, Equatable {
    case cargoTransactionMustBeLoad
    case cargoProductMismatch
    case compartmentMismatch
    case timingMismatch
    case provenanceMismatch
    case invalidFuelEntry
    case cargoTransactionMustBeTransfer
}

/// Fuel-facing commands translated onto the generic 5A Cargo ledger.
/// There is deliberately no second Fuel ledger: FuelCommittedState groups the generic
/// ledger with Fuel-only evidence/history so the caller cannot accidentally drop either.
public enum FuelCargoAdapter {
    public static func prepareLoad(
        product: FuelProduct,
        litres: Double,
        evidence: FuelLoadEvidence,
        into compartmentID: CanonicalID,
        occurredAt: Date,
        provenance: EventProvenance = .driverEntered,
        note: String? = nil
    ) -> FuelLoadCommit {
        let cargo = CargoTransaction(kind: .load, cargo: product.cargoKind, units: litres, destinationCompartmentID: compartmentID, occurredAt: occurredAt, provenance: provenance, note: note)
        let fuel = FuelStateEvent(kind: .productEntered, compartmentID: compartmentID, productID: product.id, family: product.family, occurredAt: occurredAt, provenance: provenance, note: note)
        return FuelLoadCommit(cargoTransaction: cargo, fuelStateEvent: fuel, loadEvidence: evidence)
    }

    /// Rejects decoded/directly-created handshakes whose independently valid halves do not
    /// describe the same physical load.
    public static func validate(_ commit: FuelLoadCommit) throws {
        let cargo = commit.cargoTransaction
        let fuel = commit.fuelStateEvent
        guard cargo.kind == .load else { throw FuelCargoHandshakeError.cargoTransactionMustBeLoad }
        guard fuel.kind == .productEntered, let productID = fuel.productID, fuel.family != nil else { throw FuelCargoHandshakeError.invalidFuelEntry }
        guard cargo.cargo.id == productID else { throw FuelCargoHandshakeError.cargoProductMismatch }
        guard cargo.destinationCompartmentID == fuel.compartmentID else { throw FuelCargoHandshakeError.compartmentMismatch }
        guard cargo.occurredAt == fuel.occurredAt else { throw FuelCargoHandshakeError.timingMismatch }
        guard cargo.provenance == fuel.provenance else { throw FuelCargoHandshakeError.provenanceMismatch }
    }

    public static func committing(_ commit: FuelLoadCommit, to state: FuelCommittedState) throws -> FuelCommittedState {
        try validate(commit)
        var candidate = state
        try candidate.ledger.append(commit.cargoTransaction)
        candidate.fuelEvents.append(commit.fuelStateEvent)
        candidate.loadEvidence.append(FuelLoadEvidenceRecord(cargoTransactionID: commit.cargoTransaction.id, evidence: commit.loadEvidence))
        _ = try FuelProjector.project(cargoLedger: candidate.ledger, fuelEvents: candidate.fuelEvents)
        return candidate
    }

    /// Compatibility entry point for callers that have not yet adopted FuelCommittedState.
    /// Evidence is still returned in the state rather than discarded.
    public static func committing(_ commit: FuelLoadCommit, to ledger: CargoLedger, fuelEvents: [FuelStateEvent], loadEvidence: [FuelLoadEvidenceRecord] = []) throws -> FuelCommittedState {
        try committing(commit, to: FuelCommittedState(ledger: ledger, fuelEvents: fuelEvents, loadEvidence: loadEvidence))
    }

    public static func delivery(product: FuelProduct, litres: Double, from compartmentID: CanonicalID, occurredAt: Date, provenance: EventProvenance = .driverEntered, destinationDescription: String? = nil) -> CargoTransaction {
        CargoTransaction(kind: .unload, cargo: product.cargoKind, units: litres, sourceCompartmentID: compartmentID, occurredAt: occurredAt, provenance: provenance, note: destinationDescription)
    }

    /// Fuel transfer is a handshake because the destination acquires Fuel chemical history
    /// even though quantity truth remains a generic Cargo transfer.
    public static func prepareTransfer(product: FuelProduct, litres: Double, from sourceID: CanonicalID, to destinationID: CanonicalID, occurredAt: Date, provenance: EventProvenance = .driverEntered, note: String? = nil) -> FuelTransferCommit {
        let cargo = CargoTransaction(kind: .transfer, cargo: product.cargoKind, units: litres, sourceCompartmentID: sourceID, destinationCompartmentID: destinationID, occurredAt: occurredAt, provenance: provenance, note: note)
        let fuel = FuelStateEvent(kind: .productEntered, compartmentID: destinationID, productID: product.id, family: product.family, occurredAt: occurredAt, provenance: provenance, note: note)
        return FuelTransferCommit(cargoTransaction: cargo, destinationFuelStateEvent: fuel)
    }

    public static func committing(_ commit: FuelTransferCommit, to state: FuelCommittedState) throws -> FuelCommittedState {
        let cargo = commit.cargoTransaction
        let fuel = commit.destinationFuelStateEvent
        guard cargo.kind == .transfer else { throw FuelCargoHandshakeError.cargoTransactionMustBeTransfer }
        guard fuel.kind == .productEntered, let productID = fuel.productID, fuel.family != nil else { throw FuelCargoHandshakeError.invalidFuelEntry }
        guard cargo.cargo.id == productID else { throw FuelCargoHandshakeError.cargoProductMismatch }
        guard cargo.destinationCompartmentID == fuel.compartmentID else { throw FuelCargoHandshakeError.compartmentMismatch }
        guard cargo.occurredAt == fuel.occurredAt else { throw FuelCargoHandshakeError.timingMismatch }
        guard cargo.provenance == fuel.provenance else { throw FuelCargoHandshakeError.provenanceMismatch }
        var candidate = state
        try candidate.ledger.append(cargo)
        candidate.fuelEvents.append(fuel)
        _ = try FuelProjector.project(cargoLedger: candidate.ledger, fuelEvents: candidate.fuelEvents)
        return candidate
    }

    public static func correction(of target: CargoTransaction, occurredAt: Date, provenance: EventProvenance = .driverEntered, note: String? = nil) -> CargoTransaction {
        CargoTransaction(kind: .correction, cargo: target.cargo, units: target.units, sourceCompartmentID: target.destinationCompartmentID, destinationCompartmentID: target.sourceCompartmentID, occurredAt: occurredAt, provenance: provenance, correctsTransactionID: target.id, note: note)
    }
}
