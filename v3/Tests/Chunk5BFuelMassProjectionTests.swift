import Foundation

public enum Chunk5BFuelMassProjectionTests {
    public static func run() -> [String] {
        var results: [String] = []
        func check(_ name: String, _ body: () throws -> Bool) {
            do { results.append("\(try body() ? "PASS" : "FAIL") — \(name)") }
            catch { results.append("FAIL — \(name): \(error)") }
        }

        let c1 = CanonicalID.fresh()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let diesel = FuelProduct(name: "Ultimate Diesel", code: "xls", family: .diesel)
        let densityA = FuelLoadEvidence(kilogramsPerLitre: 0.84, sourceDescription: "Load A")
        let densityB = FuelLoadEvidence(kilogramsPerLitre: 0.83, sourceDescription: "Load B")

        check("single evidenced load projects authoritative derived mass") {
            let ledger = try CargoLedger(limits: [CargoCompartmentLimit(compartmentID: c1, capacityUnits: 5_000)])
            let initial = FuelCommittedState(ledger: ledger)
            let load = FuelCargoAdapter.prepareLoad(product: diesel, litres: 1_000, evidence: densityA, into: c1, occurredAt: now)
            let committed = try FuelCargoAdapter.committing(load, to: initial)
            let mass = try FuelMassProjector.project(committed).first { $0.compartmentID == c1 }
            return mass?.litres == 1_000 && mass?.massKg == 840 && mass?.kilogramsPerLitre == 0.84
        }

        check("different-density reload projects weighted current mass") {
            let ledger = try CargoLedger(limits: [CargoCompartmentLimit(compartmentID: c1, capacityUnits: 5_000)])
            var committed = FuelCommittedState(ledger: ledger)
            committed = try FuelCargoAdapter.committing(FuelCargoAdapter.prepareLoad(product: diesel, litres: 1_000, evidence: densityA, into: c1, occurredAt: now), to: committed)
            committed = try FuelCargoAdapter.committing(FuelCargoAdapter.prepareLoad(product: diesel, litres: 500, evidence: densityB, into: c1, occurredAt: now.addingTimeInterval(1)), to: committed)
            let mass = try FuelMassProjector.project(committed).first { $0.compartmentID == c1 }
            return mass?.litres == 1_500 && mass?.massKg == 1_255
        }

        check("partial delivery removes proportional mass without inventing density") {
            let ledger = try CargoLedger(limits: [CargoCompartmentLimit(compartmentID: c1, capacityUnits: 5_000)])
            var committed = FuelCommittedState(ledger: ledger)
            committed = try FuelCargoAdapter.committing(FuelCargoAdapter.prepareLoad(product: diesel, litres: 1_000, evidence: densityA, into: c1, occurredAt: now), to: committed)
            committed = try FuelCargoAdapter.committing(FuelCargoAdapter.prepareLoad(product: diesel, litres: 500, evidence: densityB, into: c1, occurredAt: now.addingTimeInterval(1)), to: committed)
            try committed.ledger.append(FuelCargoAdapter.delivery(product: diesel, litres: 300, from: c1, occurredAt: now.addingTimeInterval(2)))
            let mass = try FuelMassProjector.project(committed).first { $0.compartmentID == c1 }
            let expected = 1_255.0 * (1_200.0 / 1_500.0)
            return mass?.litres == 1_200 && abs((mass?.massKg ?? 0) - expected) < 0.000_001
        }

        check("missing density evidence fails visibly") {
            var ledger = try CargoLedger(limits: [CargoCompartmentLimit(compartmentID: c1, capacityUnits: 5_000)])
            let load = CargoTransaction(kind: .load, cargo: diesel.cargoKind, units: 1_000, destinationCompartmentID: c1, occurredAt: now)
            try ledger.append(load)
            do { _ = try FuelMassProjector.project(FuelCommittedState(ledger: ledger)); return false }
            catch FuelMassProjectionError.missingLoadEvidence(let id) { return id == load.id }
            catch { return false }
        }

        return results
    }
}
