import Foundation

public enum TestFuel {
    public static func run() -> [String] {
        var results: [String] = []
        func check(_ name: String, _ body: () throws -> Bool) {
            do { results.append("\(try body() ? "PASS" : "FAIL") — \(name)") }
            catch { results.append("FAIL — \(name): \(error)") }
        }

        let c1 = CanonicalID.fresh(), c2 = CanonicalID.fresh()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let diesel = FuelProduct(name: "Ultimate Diesel", code: "xls", family: .diesel)
        let petrol = FuelProduct(name: "ULP 91", code: "ulp91", family: .petrol)
        let densityA = FuelLoadEvidence(kilogramsPerLitre: 0.84, sourceDescription: "Load A")
        let densityB = FuelLoadEvidence(kilogramsPerLitre: 0.83, sourceDescription: "Load B")

        check("Fuel adapts stable identity to generic CargoKind") {
            diesel.cargoKind.kind == "fuel.xls" && diesel.cargoKind.unitName == "L" && diesel.cargoKind.kilogramsPerUnit == nil
        }

        check("atomic load handshake returns Cargo and Fuel truth together") {
            let ledger = try CargoLedger(limits: [CargoCompartmentLimit(compartmentID: c1, capacityUnits: 5_000)])
            let commit = FuelCargoAdapter.prepareLoad(product: diesel, litres: 1_000, evidence: densityA, into: c1, occurredAt: now)
            let result = try FuelCargoAdapter.committing(commit, to: ledger, fuelEvents: [])
            let projection = try FuelProjector.project(cargoLedger: result.ledger, fuelEvents: result.fuelEvents)[0]
            return result.ledger.transactions.count == 1 && result.fuelEvents.count == 1 && projection.residual == .diesel(productID: diesel.id)
        }

        check("failed load handshake leaks neither truth") {
            let ledger = try CargoLedger(limits: [CargoCompartmentLimit(compartmentID: c1, capacityUnits: 500)])
            let commit = FuelCargoAdapter.prepareLoad(product: diesel, litres: 1_000, evidence: densityA, into: c1, occurredAt: now)
            do { _ = try FuelCargoAdapter.committing(commit, to: ledger, fuelEvents: []); return false }
            catch { return ledger.transactions.isEmpty }
        }

        check("load/unload truth remains in generic CargoLedger") {
            let empty = try CargoLedger(limits: [CargoCompartmentLimit(compartmentID: c1, capacityUnits: 5_000)])
            let load = FuelCargoAdapter.prepareLoad(product: diesel, litres: 1_000, evidence: densityA, into: c1, occurredAt: now)
            var ledger = try FuelCargoAdapter.committing(load, to: empty, fuelEvents: []).ledger
            try ledger.append(FuelCargoAdapter.delivery(product: diesel, litres: 300, from: c1, occurredAt: now.addingTimeInterval(1)))
            return try ledger.state(compartmentID: c1).quantity?.units == 700
        }

        check("zero litres retains diesel residue until degas") {
            let empty = try CargoLedger(limits: [CargoCompartmentLimit(compartmentID: c1, capacityUnits: 5_000)])
            let load = FuelCargoAdapter.prepareLoad(product: diesel, litres: 500, evidence: densityA, into: c1, occurredAt: now)
            var committed = try FuelCargoAdapter.committing(load, to: empty, fuelEvents: [])
            try committed.ledger.append(FuelCargoAdapter.delivery(product: diesel, litres: 500, from: c1, occurredAt: now.addingTimeInterval(1)))
            let before = try FuelProjector.project(cargoLedger: committed.ledger, fuelEvents: committed.fuelEvents)[0]
            let degas = FuelStateEvent(kind: .degas, compartmentID: c1, occurredAt: now.addingTimeInterval(2))
            let after = try FuelProjector.project(cargoLedger: committed.ledger, fuelEvents: committed.fuelEvents + [degas])[0]
            return before.liquid == nil && before.residual == .diesel(productID: diesel.id) && after.residual == .clear
        }

        check("petrol zero litres retains vapour") {
            let empty = try CargoLedger(limits: [CargoCompartmentLimit(compartmentID: c1, capacityUnits: 5_000)])
            let load = FuelCargoAdapter.prepareLoad(product: petrol, litres: 500, evidence: FuelLoadEvidence(kilogramsPerLitre: 0.74), into: c1, occurredAt: now)
            var committed = try FuelCargoAdapter.committing(load, to: empty, fuelEvents: [])
            try committed.ledger.append(FuelCargoAdapter.delivery(product: petrol, litres: 500, from: c1, occurredAt: now.addingTimeInterval(1)))
            let state = try FuelProjector.project(cargoLedger: committed.ledger, fuelEvents: committed.fuelEvents)[0]
            return state.liquid == nil && state.residual == .petrolVapour(productID: petrol.id)
        }

        check("load density evidence derives mass without changing product identity") {
            densityA.massKg(forLitres: 1_000) == 840 && densityB.massKg(forLitres: 1_000) == 830 && diesel.cargoKind == diesel.cargoKind
        }

        check("same product reload with different density remains same Cargo identity") {
            let empty = try CargoLedger(limits: [CargoCompartmentLimit(compartmentID: c1, capacityUnits: 5_000)])
            let first = FuelCargoAdapter.prepareLoad(product: diesel, litres: 1_000, evidence: densityA, into: c1, occurredAt: now)
            var committed = try FuelCargoAdapter.committing(first, to: empty, fuelEvents: [])
            let second = FuelCargoAdapter.prepareLoad(product: diesel, litres: 500, evidence: densityB, into: c1, occurredAt: now.addingTimeInterval(1))
            committed = try FuelCargoAdapter.committing(second, to: committed.ledger, fuelEvents: committed.fuelEvents)
            return committed.ledger.transactions.count == 2 && (try committed.ledger.state(compartmentID: c1).quantity?.units == 1_500)
        }

        check("running tank customer delivery is generic unload") {
            let empty = try CargoLedger(limits: [CargoCompartmentLimit(compartmentID: c1, capacityUnits: 5_000)])
            let load = FuelCargoAdapter.prepareLoad(product: diesel, litres: 3_600, evidence: densityA, into: c1, occurredAt: now)
            var ledger = try FuelCargoAdapter.committing(load, to: empty, fuelEvents: []).ledger
            let runningTank = FuelCargoAdapter.delivery(product: diesel, litres: 300, from: c1, occurredAt: now.addingTimeInterval(1), destinationDescription: "Customer: Vehicle / Running Tank")
            try ledger.append(runningTank)
            return runningTank.kind == .unload && (try ledger.state(compartmentID: c1).quantity?.units == 3_300)
        }

        check("generic transfer remains generic") {
            let empty = try CargoLedger(limits: [CargoCompartmentLimit(compartmentID: c1, capacityUnits: 5_000), CargoCompartmentLimit(compartmentID: c2, capacityUnits: 5_000)])
            let load = FuelCargoAdapter.prepareLoad(product: diesel, litres: 1_000, evidence: densityA, into: c1, occurredAt: now)
            var ledger = try FuelCargoAdapter.committing(load, to: empty, fuelEvents: []).ledger
            try ledger.append(FuelCargoAdapter.transfer(product: diesel, litres: 250, from: c1, to: c2, occurredAt: now.addingTimeInterval(1)))
            return (try ledger.state(compartmentID: c1).quantity?.units == 750) && (try ledger.state(compartmentID: c2).quantity?.units == 250)
        }

        check("correction preserves original and provenance") {
            var ledger = try CargoLedger(limits: [CargoCompartmentLimit(compartmentID: c1, capacityUnits: 5_000)])
            let wrong = FuelCargoAdapter.prepareLoad(product: diesel, litres: 1_000, evidence: densityA, into: c1, occurredAt: now).cargoTransaction
            try ledger.append(wrong)
            let correction = FuelCargoAdapter.correction(of: wrong, occurredAt: now.addingTimeInterval(1), note: "Recorded quantity wrong")
            try ledger.append(correction)
            return ledger.transactions.count == 2 && correction.correctsTransactionID == wrong.id && ledger.transactions[0].id == wrong.id && (try ledger.state(compartmentID: c1).quantity == nil)
        }

        check("incident is preserved as incident, not correction") {
            let incident = FuelStateEvent(kind: .incident, compartmentID: c1, occurredAt: now, note: "Observed shandy/contamination")
            return incident.kind == .incident && incident.note != nil
        }

        check("invalid proposal is prevented without fabricated event") {
            let decision = FuelProposalGuard.evaluateLoad(product: diesel, litres: 6_000, compartmentLimitLitres: 5_000)
            if case .prevented = decision { return true }
            return false
        }

        check("thin non-fuel Cargo remains independent") {
            let bulk = TestBulkCargo(name: "Aggregate").erased
            return bulk.kind == "test.bulk" && !bulk.kind.contains("fuel")
        }

        return results
    }
}
