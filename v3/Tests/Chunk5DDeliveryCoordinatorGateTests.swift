import Foundation

public enum Chunk5DDeliveryCoordinatorGateTests {
    public static func run() -> [String] {
        var results = ["=== V3 Chunk 5D.4 Delivery Coordinator Gate ==="]
        func check(_ label: String, _ value: @autoclosure () -> Bool) { results.append("\(label): \(value() ? "PASS" : "FAIL")") }
        func succeeds(_ block: () throws -> Bool) -> Bool { (try? block()) == true }

        let t0 = Date(timeIntervalSince1970: 1_758_200_000)
        let c1 = CanonicalID.fresh(), c3 = CanonicalID.fresh()
        let product = FuelProduct(name: "Ultimate Diesel", code: "xls", family: .diesel)

        check("Completed delivery atomically changes Cargo and Service state", succeeds {
            var ledger = try CargoLedger(limits: [
                CargoCompartmentLimit(compartmentID: c1, capacityUnits: 8000),
                CargoCompartmentLimit(compartmentID: c3, capacityUnits: 8000)
            ])
            try ledger.append(CargoTransaction(kind: .load, cargo: product.cargoKind, units: 5000, destinationCompartmentID: c1, occurredAt: t0))
            try ledger.append(CargoTransaction(kind: .load, cargo: product.cargoKind, units: 3001, destinationCompartmentID: c3, occurredAt: t0))

            var job = ServiceJob(identity: ServiceJobIdentity(siteID: CanonicalID.fresh(), customerID: CanonicalID.fresh()))
            guard job.confirmArrival(at: t0.addingTimeInterval(60)), job.begin(at: t0.addingTimeInterval(120)) else { return false }

            var card = FuelDeliveryCard(serviceJobID: job.id, productID: product.id, expectedDeliveryLitres: 8001)
            guard card.startPump(at: t0.addingTimeInterval(180)), card.finishPump(at: t0.addingTimeInterval(1020)) else { return false }
            card.recordDeliveredLitres(OperationalQuantityEvidence(value: 8001, unitName: "L", status: .confirmed, occurredAt: t0.addingTimeInterval(1020)))

            let commit = try FuelDeliveryCoordinator.prepare(job: job, card: card, product: product, compartmentAllocations: [(c1, 5000), (c3, 3001)], occurredAt: t0.addingTimeInterval(1020))
            let outcome = try FuelDeliveryCoordinator.committing(commit, job: job, card: card, cargoLedger: ledger)
            return outcome.job.state == .completed
                && (try outcome.cargoLedger.state(compartmentID: c1).quantity) == nil
                && (try outcome.cargoLedger.state(compartmentID: c3).quantity) == nil
        })

        check("Bad allocation cannot fabricate a Cargo movement", succeeds {
            var job = ServiceJob(identity: ServiceJobIdentity())
            guard job.confirmArrival(at: t0), job.begin(at: t0) else { return false }
            var card = FuelDeliveryCard(serviceJobID: job.id, productID: product.id, expectedDeliveryLitres: 8001)
            _ = card.startPump(at: t0); _ = card.finishPump(at: t0.addingTimeInterval(60))
            card.recordDeliveredLitres(OperationalQuantityEvidence(value: 8001, unitName: "L", status: .confirmed, occurredAt: t0.addingTimeInterval(60)))
            do {
                _ = try FuelDeliveryCoordinator.prepare(job: job, card: card, product: product, compartmentAllocations: [(c1, 5000)], occurredAt: t0.addingTimeInterval(60))
                return false
            } catch FuelDeliveryCommitError.allocationTotalMismatch {
                return true
            }
        })

        check("Insufficient Cargo cannot falsely complete ServiceJob", succeeds {
            var ledger = try CargoLedger(limits: [CargoCompartmentLimit(compartmentID: c1, capacityUnits: 8000)])
            try ledger.append(CargoTransaction(kind: .load, cargo: product.cargoKind, units: 5000, destinationCompartmentID: c1, occurredAt: t0))
            var job = ServiceJob(identity: ServiceJobIdentity())
            guard job.confirmArrival(at: t0), job.begin(at: t0) else { return false }
            var card = FuelDeliveryCard(serviceJobID: job.id, productID: product.id)
            _ = card.startPump(at: t0); _ = card.finishPump(at: t0.addingTimeInterval(60))
            card.recordDeliveredLitres(OperationalQuantityEvidence(value: 5580, unitName: "L", status: .confirmed, occurredAt: t0.addingTimeInterval(60)))
            let commit = try FuelDeliveryCoordinator.prepare(job: job, card: card, product: product, compartmentAllocations: [(c1, 5580)], occurredAt: t0.addingTimeInterval(60))
            do {
                _ = try FuelDeliveryCoordinator.committing(commit, job: job, card: card, cargoLedger: ledger)
                return false
            } catch FuelDeliveryCommitError.cargoCommitFailed {
                return job.state == .active && (try ledger.state(compartmentID: c1).quantity?.units) == 5000
            }
        })

        check("Forged commit cannot substitute product identity", succeeds {
            var ledger = try CargoLedger(limits: [CargoCompartmentLimit(compartmentID: c1, capacityUnits: 8000)])
            try ledger.append(CargoTransaction(kind: .load, cargo: product.cargoKind, units: 1000, destinationCompartmentID: c1, occurredAt: t0))
            var job = ServiceJob(identity: ServiceJobIdentity())
            guard job.confirmArrival(at: t0), job.begin(at: t0) else { return false }
            var card = FuelDeliveryCard(serviceJobID: job.id, productID: product.id)
            _ = card.startPump(at: t0); _ = card.finishPump(at: t0.addingTimeInterval(60))
            card.recordDeliveredLitres(OperationalQuantityEvidence(value: 1000, unitName: "L", status: .confirmed, occurredAt: t0.addingTimeInterval(60)))
            let other = FuelProduct(name: "Other Fuel", code: "other", family: .petrol)
            let forgedTx = FuelCargoAdapter.delivery(product: other, litres: 1000, from: c1, occurredAt: t0.addingTimeInterval(60), destinationDescription: "serviceJob:\(job.id.raw.uuidString)")
            let forged = FuelDeliveryCommit(serviceJobID: job.id, deliveryCardID: card.id, productID: other.id, cargoTransactions: [forgedTx], deliveredLitres: 1000, occurredAt: t0.addingTimeInterval(60))
            do {
                _ = try FuelDeliveryCoordinator.committing(forged, job: job, card: card, cargoLedger: ledger)
                return false
            } catch FuelDeliveryCommitError.productMismatch {
                return job.state == .active
            }
        })

        results.append("---")
        results.append(results.contains(where: { $0.hasSuffix("FAIL") }) ? "GATE FAIL" : "GATE PASS")
        return results
    }
}
