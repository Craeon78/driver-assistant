import Foundation

@MainActor
public enum Chunk5GFieldTest02ExceptionTests {
    public static func run() -> [String] {
        var results = ["=== V3 Chunk 5G Field Test 02 Exceptions ==="]
        func check(_ label: String, _ condition: @autoclosure () throws -> Bool) {
            do { results.append("\(label): \(try condition() ? "PASS" : "FAIL")") }
            catch { results.append("\(label): FAIL — \(error)") }
        }

        let variance = Chunk5GTransactionVariance(
            calculatedLitres: 15_997,
            actualLitres: 16_192,
            postTransactionEmpty: true,
            provenance: .driverEntered,
            note: "Field Test 02"
        )
        check("Variance preserves calculated total", variance.calculatedLitres == 15_997)
        check("Variance preserves actual total", variance.actualLitres == 16_192)
        check("Variance derives +195 L", variance.varianceLitres == 195)
        check("Variance preserves explicit empty post-state", variance.postTransactionEmpty == true)

        let zeroToHundred = Chunk5GPhysicalCheck(
            compartmentIndex: 0, calculatedLitres: 0, observedLitres: 100,
            reconciliationEventID: .fresh()
        )
        let hundredToZero = Chunk5GPhysicalCheck(
            compartmentIndex: 0, calculatedLitres: 100, observedLitres: 0,
            reconciliationEventID: .fresh()
        )
        check("Physical Check preserves 0 → 100 observation", zeroToHundred.differenceLitres == 100)
        check("Physical Check preserves 100 → 0 observation", hundredToZero.differenceLitres == -100)

        do {
            let compartment = CanonicalID.fresh()
            let cargo = CargoKind(name: "Diesel", kind: "fuel.diesel", unitName: "L")
            let t0 = Date(timeIntervalSince1970: 1_700_000_000)
            var ledger = try CargoLedger(limits: [CargoCompartmentLimit(compartmentID: compartment, capacityUnits: 25_000)])
            try ledger.append(CargoTransaction(kind: .load, cargo: cargo, units: 20_000, destinationCompartmentID: compartment, occurredAt: t0))
            let original = CargoTransaction(kind: .unload, cargo: cargo, units: 19_604, sourceCompartmentID: compartment, occurredAt: t0.addingTimeInterval(1), note: "chunk5g.delivery.op.fixture")
            try ledger.append(original)
            let reversal = CargoTransaction(kind: .correction, cargo: cargo, units: 19_604, destinationCompartmentID: compartment, occurredAt: t0.addingTimeInterval(2), correctsTransactionID: original.id, note: "chunk5g.correction.op.fixture")
            let replacement = CargoTransaction(kind: .unload, cargo: cargo, units: 19_504, sourceCompartmentID: compartment, occurredAt: t0.addingTimeInterval(3), note: "chunk5g.correction.op.fixture")
            try ledger.append(reversal)
            try ledger.append(replacement)
            let payload = Chunk5GInputCorrection(
                originalEventID: UUID(), originalLitres: 19_604, correctedLitres: 19_504,
                compartmentAdjustments: [Chunk5GCompartmentAdjustment(compartmentIndex: 0, deltaLitres: -100)],
                correctionTransactionIDs: [reversal.id, replacement.id]
            )
            check("Correction keeps original transaction", ledger.transactions.contains { $0.id == original.id })
            check("Correction is append-only", ledger.transactions.count == 4)
            check("Correction preserves 19,604 → 19,504", payload.originalLitres == 19_604 && payload.correctedLitres == 19_504 && payload.deltaLitres == -100)
            check("Corrected projection is 496 L", try ledger.state(compartmentID: compartment).quantity?.units == 496)
        } catch {
            results.append("Append-only correction fixture: FAIL — \(error)")
        }

        let store = Chunk5FPrototypeStore(evidenceSource: .fixture)
        store.startShift()
        store.beginRest(); store.endRest(); store.beginRest(); store.endRest()
        check("Two Rest cycles have two starts", store.eventLog.filter { $0.kind == .restStart }.count == 2)
        check("Two Rest cycles have two ends", store.eventLog.filter { $0.kind == .restEnd }.count == 2)
        store.startSimulatedDriving()
        check("Simulated driving explicitly runs", store.simulatedDrivingRunning && store.prototypeSpeedKmh > 0)
        store.stopSimulatedDriving()
        check("Simulated driving explicitly stops", !store.simulatedDrivingRunning && store.prototypeSpeedKmh == 0)

        let report = Chunk5GGateReport(
            persistenceStatus: .notTested,
            representationIntegrityStatus: .pass,
            operationalCompletenessStatus: .notTested
        )
        check("Gate keeps integrity distinct", report.representationIntegrityStatus == .pass)
        check("Gate does not claim operational completeness", report.operationalCompletenessStatus == .notTested)
        check("Persistence remains explicit", report.persistenceStatus == .notTested)

        let fieldStore = Chunk5FPrototypeStore(evidenceSource: .fixture)
        fieldStore.startShift()
        _ = fieldStore.openSite(0)
        fieldStore.setDraft(compartment: 0, litres: 0)
        fieldStore.setDraft(compartment: 2, litres: 0)
        fieldStore.setDraft(compartment: 3, litres: 0)
        fieldStore.setDraft(compartment: 4, litres: 2_903)
        check("Field fixture derives 15,997 L", fieldStore.deliveryMovement == 15_997)
        fieldStore.commitDelivery(actualLitres: 16_192, postTransactionEmpty: true, varianceNote: "Metered actual")
        let storedVariance = fieldStore.eventLog.last(where: { $0.kind == .transactionVariance })?.transactionVariance
        check("Store retains 15,997 and 16,192", storedVariance?.calculatedLitres == 15_997 && storedVariance?.actualLitres == 16_192)
        check("Empty post-state has no invented or negative XLS cargo", fieldStore.compartments.indices.filter { fieldStore.compartments[$0].product == "XLS" }.allSatisfy { fieldStore.confirmedLitres[$0] == 0 })
        fieldStore.commitPhysicalCheck(compartment: 2, observedLitres: 100, note: "Dip")
        check("Positive Physical Check reconciles current projection", fieldStore.confirmedLitres[2] == 100 && fieldStore.eventLog.last?.physicalCheck?.differenceLitres == 100)
        fieldStore.commitPhysicalCheck(compartment: 2, observedLitres: 0, note: "Empty observation")
        check("Negative Physical Check reconciles current projection", fieldStore.confirmedLitres[2] == 0 && fieldStore.eventLog.last?.physicalCheck?.differenceLitres == -100)

        results.append("---")
        results.append(results.contains(where: { $0.contains(": FAIL") }) ? "GATE FAIL" : "GATE PASS")
        return results
    }
}
