import Foundation

public enum Chunk5DVarianceGateTests {
    public static func run() -> [String] {
        var results: [String] = ["=== V3 Chunk 5D.1 Cargo Variance Gate ==="]
        func check(_ label: String, _ condition: @autoclosure () -> Bool) {
            results.append("\(label): \(condition() ? "PASS" : "FAIL")")
        }
        func succeeds(_ block: () throws -> Bool) -> Bool { (try? block()) == true }

        let compartment = CanonicalID.fresh()
        let cargo = TestBulkCargo(name: "XLS fixture", kilogramsPerUnit: 0.84).erased
        let t0 = Date(timeIntervalSince1970: 1_758_200_000)

        check("Moongalba +79 is conserved outside deliverable Cargo", succeeds {
            var cargoLedger = try CargoLedger(limits: [CargoCompartmentLimit(compartmentID: compartment, capacityUnits: 8000)])
            try cargoLedger.append(CargoTransaction(kind: .load, cargo: cargo, units: 5501, destinationCompartmentID: compartment, occurredAt: t0))
            try cargoLedger.append(CargoTransaction(kind: .unload, cargo: cargo, units: 5501, sourceCompartmentID: compartment, occurredAt: t0.addingTimeInterval(1)))

            var variance = try CargoVarianceLedger()
            try variance.append(CargoVarianceEntry(cargo: cargo, quantityDelta: 79, occurredAt: t0.addingTimeInterval(2), resultingKnownUnits: 0))

            return try cargoLedger.state(compartmentID: compartment).quantity == nil
                && variance.netVariance(cargoID: cargo.id) == 79
        })

        check("Positive variance cannot be dipped into for a later delivery", succeeds {
            var cargoLedger = try CargoLedger(limits: [CargoCompartmentLimit(compartmentID: compartment, capacityUnits: 8000)])
            var variance = try CargoVarianceLedger()
            try variance.append(CargoVarianceEntry(cargo: cargo, quantityDelta: 79, occurredAt: t0, resultingKnownUnits: 0))
            do {
                try cargoLedger.append(CargoTransaction(kind: .unload, cargo: cargo, units: 79, sourceCompartmentID: compartment, occurredAt: t0.addingTimeInterval(1)))
                return false
            } catch CargoLedgerError.insufficientQuantity {
                return variance.netVariance(cargoID: cargo.id) == 79
            } catch {
                return false
            }
        })

        check("Negative variance records missing expected stock without negative Cargo", succeeds {
            var cargoLedger = try CargoLedger(limits: [CargoCompartmentLimit(compartmentID: compartment, capacityUnits: 8000)])
            try cargoLedger.append(CargoTransaction(kind: .load, cargo: cargo, units: 5501, destinationCompartmentID: compartment, occurredAt: t0))
            try cargoLedger.append(CargoTransaction(kind: .unload, cargo: cargo, units: 5430, sourceCompartmentID: compartment, occurredAt: t0.addingTimeInterval(1)))
            let expectedRemainder = try cargoLedger.state(compartmentID: compartment).quantity?.units
            guard expectedRemainder == 71 else { return false }

            // Physical observation establishes empty. Existing Cargo cannot be made negative;
            // the unexplained -71 is retained in the separate accounting ledger.
            try cargoLedger.append(CargoTransaction(kind: .unload, cargo: cargo, units: 71, sourceCompartmentID: compartment, occurredAt: t0.addingTimeInterval(2)))
            var variance = try CargoVarianceLedger()
            try variance.append(CargoVarianceEntry(cargo: cargo, quantityDelta: -71, occurredAt: t0.addingTimeInterval(2), resultingKnownUnits: 0))

            return try cargoLedger.state(compartmentID: compartment).quantity == nil
                && variance.netVariance(cargoID: cargo.id) == -71
        })

        check("Variance survives encode/decode as accounting truth", succeeds {
            var original = try CargoVarianceLedger()
            try original.append(CargoVarianceEntry(cargo: cargo, quantityDelta: 79, occurredAt: t0, resultingKnownUnits: 0))
            try original.append(CargoVarianceEntry(cargo: cargo, quantityDelta: -20, occurredAt: t0.addingTimeInterval(1), resultingKnownUnits: 0))
            let data = try JSONEncoder().encode(original)
            let replay = try JSONDecoder().decode(CargoVarianceLedger.self, from: data)
            return replay.entries.count == 2 && replay.netVariance(cargoID: cargo.id) == 59
        })

        results.append("---")
        results.append(results.contains(where: { $0.hasSuffix("FAIL") }) ? "GATE FAIL" : "GATE PASS")
        return results
    }
}
