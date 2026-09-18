import Foundation

public enum Chunk5DVarianceGateTests {
    public static func run() -> [String] {
        var results = ["=== V3 Chunk 5D.1 Cargo Reconciliation / Variance Gate ==="]
        func check(_ label: String, _ condition: @autoclosure () -> Bool) { results.append("\(label): \(condition() ? "PASS" : "FAIL")") }
        func succeeds(_ block: () throws -> Bool) -> Bool { (try? block()) == true }

        let compartment = CanonicalID.fresh()
        let cargo = TestBulkCargo(name: "XLS fixture", kilogramsPerUnit: 0.84).erased
        let t0 = Date(timeIntervalSince1970: 1_758_200_000)
        let limits = [CargoCompartmentLimit(compartmentID: compartment, capacityUnits: 8000)]

        check("Moongalba: physical 5580 delivery, calculated 5501, empty boundary => +79 variance", succeeds {
            var ledger = try CargoLedger(limits: limits)
            // Calculated state can only account for 5501 L. Physical evidence later establishes
            // that 5580 L moved and the truck is empty. Record only explainable movement here;
            // reconciliation conserves the unexplained +79 without inventing inventory.
            try ledger.append(CargoTransaction(kind: .load, cargo: cargo, units: 5501, destinationCompartmentID: compartment, occurredAt: t0))
            let movement = CargoTransaction(kind: .unload, cargo: cargo, units: 5501, sourceCompartmentID: compartment, occurredAt: t0.addingTimeInterval(1), note: "physical delivery total observed 5580 L")
            try ledger.append(movement)
            var variance = try CargoVarianceLedger()
            // At the physical empty boundary the calculated state is already zero; +79 is
            // physical movement beyond the prior projection, not extra deliverable inventory.
            try variance.append(CargoVarianceEntry(cargo: cargo, quantityDelta: 79, occurredAt: t0.addingTimeInterval(2), relatedCargoTransactionID: movement.id, resultingKnownUnits: 0))
            return try ledger.state(compartmentID: compartment).quantity == nil
                && variance.netVariance(cargoID: cargo.id) == 79
                && movement.units == 5501
        })

        check("Inverse: calculated 71 remains but physical empty => reconcile to zero and -71 variance, no fake unload", succeeds {
            var ledger = try CargoLedger(limits: limits)
            try ledger.append(CargoTransaction(kind: .load, cargo: cargo, units: 5501, destinationCompartmentID: compartment, occurredAt: t0))
            try ledger.append(CargoTransaction(kind: .unload, cargo: cargo, units: 5430, sourceCompartmentID: compartment, occurredAt: t0.addingTimeInterval(1)))
            let movementCount = ledger.transactions.filter { $0.kind == .unload }.count
            var variance = try CargoVarianceLedger()
            let outcome = try CargoReconciler.reconcile(
                CargoReconciliation(compartmentID: compartment, cargo: cargo, calculatedUnits: 71, confirmedPhysicalUnits: 0, occurredAt: t0.addingTimeInterval(2)),
                cargoLedger: ledger, varianceLedger: variance
            )
            variance = outcome.varianceLedger
            return try outcome.cargoLedger.state(compartmentID: compartment).quantity == nil
                && outcome.cargoLedger.transactions.filter { $0.kind == .unload }.count == movementCount
                && outcome.cargoLedger.transactions.last?.kind == .reconcile
                && variance.netVariance(cargoID: cargo.id) == -71
        })

        check("Reconcile may establish positive physical state but variance itself is not inventory", succeeds {
            var ledger = try CargoLedger(limits: limits)
            try ledger.append(CargoTransaction(kind: .load, cargo: cargo, units: 1000, destinationCompartmentID: compartment, occurredAt: t0))
            let outcome = try CargoReconciler.reconcile(
                CargoReconciliation(compartmentID: compartment, cargo: cargo, calculatedUnits: 1000, confirmedPhysicalUnits: 1100, occurredAt: t0.addingTimeInterval(1)),
                cargoLedger: ledger, varianceLedger: try CargoVarianceLedger()
            )
            return try outcome.cargoLedger.state(compartmentID: compartment).quantity?.units == 1100
                && outcome.variance.netVariance(cargoID: cargo.id) == 100
        })

        check("Positive variance alone cannot be dipped into for delivery", succeeds {
            var ledger = try CargoLedger(limits: limits)
            var variance = try CargoVarianceLedger()
            try variance.append(CargoVarianceEntry(cargo: cargo, quantityDelta: 79, occurredAt: t0, resultingKnownUnits: 0))
            do {
                try ledger.append(CargoTransaction(kind: .unload, cargo: cargo, units: 79, sourceCompartmentID: compartment, occurredAt: t0.addingTimeInterval(1)))
                return false
            } catch CargoLedgerError.insufficientQuantity {
                return variance.netVariance(cargoID: cargo.id) == 79
            }
        })

        check("Reconciliation survives Cargo and Variance replay", succeeds {
            var ledger = try CargoLedger(limits: limits)
            try ledger.append(CargoTransaction(kind: .load, cargo: cargo, units: 1000, destinationCompartmentID: compartment, occurredAt: t0))
            let outcome = try CargoReconciler.reconcile(CargoReconciliation(compartmentID: compartment, cargo: cargo, calculatedUnits: 1000, confirmedPhysicalUnits: 900, occurredAt: t0.addingTimeInterval(1)), cargoLedger: ledger, varianceLedger: try CargoVarianceLedger())
            let cargoReplay = try JSONDecoder().decode(CargoLedger.self, from: JSONEncoder().encode(outcome.cargoLedger))
            let varianceReplay = try JSONDecoder().decode(CargoVarianceLedger.self, from: JSONEncoder().encode(outcome.varianceLedger))
            return try cargoReplay.state(compartmentID: compartment).quantity?.units == 900
                && cargoReplay.transactions.last?.kind == .reconcile
                && varianceReplay.netVariance(cargoID: cargo.id) == -100
        })

        results.append("---")
        results.append(results.contains(where: { $0.hasSuffix("FAIL") }) ? "GATE FAIL" : "GATE PASS")
        return results
    }
}
