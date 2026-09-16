import Foundation

/// Fuel-facing commands translated onto the generic 5A Cargo ledger.
/// There is deliberately no second Fuel ledger.
public enum FuelCargoAdapter {
    public static func load(
        product: FuelProduct,
        litres: Double,
        into compartmentID: CanonicalID,
        occurredAt: Date,
        provenance: EventProvenance = .driverEntered,
        note: String? = nil
    ) -> CargoTransaction {
        CargoTransaction(
            kind: .load,
            cargo: product.cargoKind,
            units: litres,
            destinationCompartmentID: compartmentID,
            occurredAt: occurredAt,
            provenance: provenance,
            note: note
        )
    }

    public static func delivery(
        product: FuelProduct,
        litres: Double,
        from compartmentID: CanonicalID,
        occurredAt: Date,
        provenance: EventProvenance = .driverEntered,
        destinationDescription: String? = nil
    ) -> CargoTransaction {
        CargoTransaction(
            kind: .unload,
            cargo: product.cargoKind,
            units: litres,
            sourceCompartmentID: compartmentID,
            occurredAt: occurredAt,
            provenance: provenance,
            note: destinationDescription
        )
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
        CargoTransaction(
            kind: .transfer,
            cargo: product.cargoKind,
            units: litres,
            sourceCompartmentID: sourceID,
            destinationCompartmentID: destinationID,
            occurredAt: occurredAt,
            provenance: provenance,
            note: note
        )
    }

    /// Generic Cargo correction is an immutable inverse of the original transaction.
    /// A replacement fact, if required, is appended separately after this inverse.
    public static func correction(
        of target: CargoTransaction,
        occurredAt: Date,
        provenance: EventProvenance = .driverEntered,
        note: String? = nil
    ) -> CargoTransaction {
        CargoTransaction(
            kind: .correction,
            cargo: target.cargo,
            units: target.units,
            sourceCompartmentID: target.destinationCompartmentID,
            destinationCompartmentID: target.sourceCompartmentID,
            occurredAt: occurredAt,
            provenance: provenance,
            correctsTransactionID: target.id,
            note: note
        )
    }
}
