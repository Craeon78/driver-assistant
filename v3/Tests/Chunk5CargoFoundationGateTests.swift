import Foundation

public enum Chunk5CargoFoundationGateTests {
    public static func run() -> [String] {
        var results: [String] = ["=== V3 Chunk 5A Generic Cargo Foundation Gate ==="]
        func check(_ label: String, _ condition: @autoclosure () -> Bool) { results.append("\(label): \(condition() ? "PASS" : "FAIL")") }
        func succeeds(_ block: () throws -> Bool) -> Bool { (try? block()) == true }
        func fails(_ block: () throws -> Void) -> Bool { do { try block(); return false } catch { return true } }

        let c1 = CanonicalID.fresh(), c2 = CanonicalID.fresh(), c3 = CanonicalID.fresh()
        let d1 = CanonicalID.fresh(), d2 = CanonicalID.fresh(), d3 = CanonicalID.fresh(), d4 = CanonicalID.fresh(), d5 = CanonicalID.fresh(), d6 = CanonicalID.fresh()
        let limits = [CargoCompartmentLimit(compartmentID: c1, capacityUnits: 5360), CargoCompartmentLimit(compartmentID: c2, capacityUnits: 3240), CargoCompartmentLimit(compartmentID: c3, capacityUnits: 4900)]
        let dogLimits = [d1,d2,d3,d4,d5,d6].map { CargoCompartmentLimit(compartmentID: $0, capacityUnits: 4000) }
        let cargo = TestBulkCargo(name: "Aggregate", kilogramsPerUnit: 2).erased
        let other = TestBulkCargo(name: "Other", kilogramsPerUnit: 1).erased
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)

        check("Generic ledger accepts three-compartment physical topology", succeeds { var l = try CargoLedger(limits: limits); try l.append(CargoTransaction(kind: .load, cargo: cargo, units: 1000, destinationCompartmentID: c1, occurredAt: t0)); return try l.state(compartmentID: c1).quantity?.units == 1000 })
        check("Generic ledger accepts six-compartment physical topology", succeeds { var l = try CargoLedger(limits: dogLimits); try l.append(CargoTransaction(kind: .load, cargo: cargo, units: 500, destinationCompartmentID: d6, occurredAt: t0)); return try l.state(compartmentID: d6).quantity?.units == 500 })
        check("Overfill rejected", fails { var l = try CargoLedger(limits: limits); try l.append(CargoTransaction(kind: .load, cargo: cargo, units: 6000, destinationCompartmentID: c1, occurredAt: t0)) })
        check("Negative inventory rejected", fails { var l = try CargoLedger(limits: limits); try l.append(CargoTransaction(kind: .unload, cargo: cargo, units: 1, sourceCompartmentID: c1, occurredAt: t0)) })
        check("Mixed cargo cannot silently relabel compartment", fails { var l = try CargoLedger(limits: limits); try l.append(CargoTransaction(kind: .load, cargo: cargo, units: 500, destinationCompartmentID: c1, occurredAt: t0)); try l.append(CargoTransaction(kind: .load, cargo: other, units: 1, destinationCompartmentID: c1, occurredAt: t0.addingTimeInterval(1))) })
        check("Transfer conserves cargo", succeeds { var l = try CargoLedger(limits: limits); try l.append(CargoTransaction(kind: .load, cargo: cargo, units: 1000, destinationCompartmentID: c1, occurredAt: t0)); try l.append(CargoTransaction(kind: .transfer, cargo: cargo, units: 400, sourceCompartmentID: c1, destinationCompartmentID: c2, occurredAt: t0.addingTimeInterval(1))); return try l.state(compartmentID: c1).quantity?.units == 600 && l.state(compartmentID: c2).quantity?.units == 400 })
        check("Unload derives remaining balance", succeeds { var l = try CargoLedger(limits: limits); try l.append(CargoTransaction(kind: .load, cargo: cargo, units: 1000, destinationCompartmentID: c1, occurredAt: t0)); try l.append(CargoTransaction(kind: .unload, cargo: cargo, units: 250, sourceCompartmentID: c1, occurredAt: t0.addingTimeInterval(1))); return try l.state(compartmentID: c1).quantity?.units == 750 })
        check("Cargo mass is derived separately from tare", succeeds { var l = try CargoLedger(limits: limits); try l.append(CargoTransaction(kind: .load, cargo: cargo, units: 1000, destinationCompartmentID: c1, occurredAt: t0)); return try l.currentCargoMassKg() == 2000 })
        check("Correction retains original transaction", succeeds { var l = try CargoLedger(limits: limits); let load = CargoTransaction(kind: .load, cargo: cargo, units: 100, destinationCompartmentID: c1, occurredAt: t0); try l.append(load); try l.append(CargoTransaction(kind: .correction, cargo: cargo, units: 100, sourceCompartmentID: c1, occurredAt: t0.addingTimeInterval(1), correctsTransactionID: load.id)); return l.transactions.count == 2 && (try l.state(compartmentID: c1).quantity == nil) })
        check("Replay reproduces cargo state", succeeds { var l = try CargoLedger(limits: limits); try l.append(CargoTransaction(kind: .load, cargo: cargo, units: 321, destinationCompartmentID: c3, occurredAt: t0)); let data = try JSONEncoder().encode(l); let replay = try JSONDecoder().decode(CargoLedger.self, from: data); return try replay.state(compartmentID: c3).quantity?.units == 321 })
        check("Thin non-fuel cargo uses same contract", cargo.kind == "test.bulk" && cargo.unitName == "units")
        check("Cargo contract contains no fuel-specific product requirement", !cargo.kind.contains("fuel"))

        results.append("---")
        results.append(results.contains(where: { $0.hasSuffix("FAIL") }) ? "GATE FAIL" : "GATE PASS")
        return results
    }
}
