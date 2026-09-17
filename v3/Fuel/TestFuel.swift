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

        func emptyState(_ limits: [CargoCompartmentLimit]) throws -> FuelCommittedState {
            FuelCommittedState(ledger: try CargoLedger(limits: limits))
        }

        check("Fuel adapts stable identity to generic CargoKind") {
            diesel.cargoKind.kind == "fuel.xls" && diesel.cargoKind.unitName == "L" && diesel.cargoKind.kilogramsPerUnit == nil
        }

        check("atomic load handshake returns Cargo Fuel and evidence truth together") {
            let state = try emptyState([CargoCompartmentLimit(compartmentID: c1, capacityUnits: 5_000)])
            let commit = FuelCargoAdapter.prepareLoad(product: diesel, litres: 1_000, evidence: densityA, into: c1, occurredAt: now)
            let result = try FuelCargoAdapter.committing(commit, to: state)
            let projection = try FuelProjector.project(cargoLedger: result.ledger, fuelEvents: result.fuelEvents)[0]
            return result.ledger.transactions.count == 1 && result.fuelEvents.count == 1 && result.loadEvidence.count == 1 && result.loadEvidence[0].cargoTransactionID == commit.cargoTransaction.id && projection.residual == .diesel(productID: diesel.id)
        }

        check("malformed load handshake cannot split Cargo and Fuel compartments") {
            let state = try emptyState([CargoCompartmentLimit(compartmentID: c1, capacityUnits: 5_000), CargoCompartmentLimit(compartmentID: c2, capacityUnits: 5_000)])
            let valid = FuelCargoAdapter.prepareLoad(product: diesel, litres: 1_000, evidence: densityA, into: c1, occurredAt: now)
            let wrongFuel = FuelStateEvent(kind: .productEntered, compartmentID: c2, productID: diesel.id, family: .diesel, occurredAt: now)
            let malformed = FuelLoadCommit(cargoTransaction: valid.cargoTransaction, fuelStateEvent: wrongFuel, loadEvidence: densityA)
            do { _ = try FuelCargoAdapter.committing(malformed, to: state); return false }
            catch FuelCargoHandshakeError.compartmentMismatch { return state.ledger.transactions.isEmpty && state.fuelEvents.isEmpty && state.loadEvidence.isEmpty }
            catch { return false }
        }

        check("malformed load handshake cannot substitute non-load transaction") {
            let state = try emptyState([CargoCompartmentLimit(compartmentID: c1, capacityUnits: 5_000), CargoCompartmentLimit(compartmentID: c2, capacityUnits: 5_000)])
            let fuel = FuelStateEvent(kind: .productEntered, compartmentID: c2, productID: diesel.id, family: .diesel, occurredAt: now)
            let transfer = CargoTransaction(kind: .transfer, cargo: diesel.cargoKind, units: 100, sourceCompartmentID: c1, destinationCompartmentID: c2, occurredAt: now)
            let malformed = FuelLoadCommit(cargoTransaction: transfer, fuelStateEvent: fuel, loadEvidence: densityA)
            do { _ = try FuelCargoAdapter.committing(malformed, to: state); return false }
            catch FuelCargoHandshakeError.cargoTransactionMustBeLoad { return true }
            catch { return false }
        }

        check("failed load handshake leaks neither truth nor evidence") {
            let state = try emptyState([CargoCompartmentLimit(compartmentID: c1, capacityUnits: 500)])
            let commit = FuelCargoAdapter.prepareLoad(product: diesel, litres: 1_000, evidence: densityA, into: c1, occurredAt: now)
            do { _ = try FuelCargoAdapter.committing(commit, to: state); return false }
            catch { return state.ledger.transactions.isEmpty && state.fuelEvents.isEmpty && state.loadEvidence.isEmpty }
        }

        check("zero litres retains diesel residue until degas") {
            let empty = try emptyState([CargoCompartmentLimit(compartmentID: c1, capacityUnits: 5_000)])
            var committed = try FuelCargoAdapter.committing(FuelCargoAdapter.prepareLoad(product: diesel, litres: 500, evidence: densityA, into: c1, occurredAt: now), to: empty)
            try committed.ledger.append(FuelCargoAdapter.delivery(product: diesel, litres: 500, from: c1, occurredAt: now.addingTimeInterval(1)))
            let before = try FuelProjector.project(cargoLedger: committed.ledger, fuelEvents: committed.fuelEvents)[0]
            let degas = FuelStateEvent(kind: .degas, compartmentID: c1, occurredAt: now.addingTimeInterval(2))
            let after = try FuelProjector.project(cargoLedger: committed.ledger, fuelEvents: committed.fuelEvents + [degas])[0]
            return before.liquid == nil && before.residual == .diesel(productID: diesel.id) && after.residual == .clear
        }

        check("petrol zero litres retains vapour") {
            let empty = try emptyState([CargoCompartmentLimit(compartmentID: c1, capacityUnits: 5_000)])
            var committed = try FuelCargoAdapter.committing(FuelCargoAdapter.prepareLoad(product: petrol, litres: 500, evidence: FuelLoadEvidence(kilogramsPerLitre: 0.74), into: c1, occurredAt: now), to: empty)
            try committed.ledger.append(FuelCargoAdapter.delivery(product: petrol, litres: 500, from: c1, occurredAt: now.addingTimeInterval(1)))
            let state = try FuelProjector.project(cargoLedger: committed.ledger, fuelEvents: committed.fuelEvents)[0]
            return state.liquid == nil && state.residual == .petrolVapour(productID: petrol.id)
        }

        check("same product reload preserves both density evidence records") {
            let empty = try emptyState([CargoCompartmentLimit(compartmentID: c1, capacityUnits: 5_000)])
            let first = FuelCargoAdapter.prepareLoad(product: diesel, litres: 1_000, evidence: densityA, into: c1, occurredAt: now)
            var committed = try FuelCargoAdapter.committing(first, to: empty)
            let second = FuelCargoAdapter.prepareLoad(product: diesel, litres: 500, evidence: densityB, into: c1, occurredAt: now.addingTimeInterval(1))
            committed = try FuelCargoAdapter.committing(second, to: committed)
            let finalState = try committed.ledger.state(compartmentID: c1)

            return committed.ledger.transactions.count == 2 &&
                committed.loadEvidence.count == 2 &&
                committed.loadEvidence[0].evidence.massKg(forLitres: 1_000) == 840 &&
                committed.loadEvidence[1].evidence.massKg(forLitres: 500) == 415 &&
                finalState.quantity?.units == 1_500
        }

        check("transfer establishes destination Fuel residue history") {
            let empty = try emptyState([CargoCompartmentLimit(compartmentID: c1, capacityUnits: 5_000), CargoCompartmentLimit(compartmentID: c2, capacityUnits: 5_000)])
            var committed = try FuelCargoAdapter.committing(FuelCargoAdapter.prepareLoad(product: diesel, litres: 1_000, evidence: densityA, into: c1, occurredAt: now), to: empty)
            let transfer = FuelCargoAdapter.prepareTransfer(product: diesel, litres: 250, from: c1, to: c2, occurredAt: now.addingTimeInterval(1))
            committed = try FuelCargoAdapter.committing(transfer, to: committed)
            try committed.ledger.append(FuelCargoAdapter.delivery(product: diesel, litres: 250, from: c2, occurredAt: now.addingTimeInterval(2)))
            let destination = try FuelProjector.project(cargoLedger: committed.ledger, fuelEvents: committed.fuelEvents).first { $0.compartmentID == c2 }
            return destination?.liquid == nil && destination?.residual == .diesel(productID: diesel.id)
        }

        check("running tank customer delivery is generic unload") {
            let empty = try emptyState([CargoCompartmentLimit(compartmentID: c1, capacityUnits: 5_000)])
            var committed = try FuelCargoAdapter.committing(FuelCargoAdapter.prepareLoad(product: diesel, litres: 3_600, evidence: densityA, into: c1, occurredAt: now), to: empty)
            let runningTank = FuelCargoAdapter.delivery(product: diesel, litres: 300, from: c1, occurredAt: now.addingTimeInterval(1), destinationDescription: "Customer: Vehicle / Running Tank")
            try committed.ledger.append(runningTank)
            let finalState = try committed.ledger.state(compartmentID: c1)

            return runningTank.kind == .unload &&
                finalState.quantity?.units == 3_300
        }

        check("correction preserves original and provenance") {
            var ledger = try CargoLedger(limits: [CargoCompartmentLimit(compartmentID: c1, capacityUnits: 5_000)])
            let wrong = FuelCargoAdapter.prepareLoad(product: diesel, litres: 1_000, evidence: densityA, into: c1, occurredAt: now).cargoTransaction
            try ledger.append(wrong)
            let correction = FuelCargoAdapter.correction(of: wrong, occurredAt: now.addingTimeInterval(1), note: "Recorded quantity wrong")
            try ledger.append(correction)
            let finalState = try ledger.state(compartmentID: c1)

            return ledger.transactions.count == 2 &&
                correction.correctsTransactionID == wrong.id &&
                ledger.transactions[0].id == wrong.id &&
                finalState.quantity == nil
        }

        check("incident is preserved as incident not correction") {
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
