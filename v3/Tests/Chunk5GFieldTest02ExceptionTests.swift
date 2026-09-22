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
            let reversal = CargoTransaction(kind: .correction, cargo: cargo, units: 19_604, destinationCompartmentID: compartment, occurredAt: t0.addingTimeInterval(2), provenance: .corrected, correctsTransactionID: original.id, note: "chunk5g.correction.op.fixture")
            let replacement = CargoTransaction(kind: .unload, cargo: cargo, units: 19_504, sourceCompartmentID: compartment, occurredAt: t0.addingTimeInterval(3), provenance: .corrected, note: "chunk5g.correction.op.fixture")
            try ledger.append(reversal)
            try ledger.append(replacement)
            let payload = Chunk5GInputCorrection(
                originalEventID: UUID(), originalLitres: 19_604, correctedLitres: 19_504,
                compartmentAdjustments: [Chunk5GCompartmentAdjustment(compartmentIndex: 0, deltaLitres: -100)],
                correctionTransactionIDs: [reversal.id, replacement.id], provenance: .corrected
            )
            check("Correction keeps original transaction", ledger.transactions.contains { $0.id == original.id })
            check("Correction is append-only", ledger.transactions.count == 4)
            check("Correction preserves 19,604 → 19,504", payload.originalLitres == 19_604 && payload.correctedLitres == 19_504 && payload.deltaLitres == -100)
            check("Correction knowledge uses corrected provenance", reversal.provenance == .corrected && replacement.provenance == .corrected && payload.provenance == .corrected)
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

        let correctionStore = Chunk5FPrototypeStore(evidenceSource: .fixture)
        correctionStore.visits[0].fills[0].plannedLitres = 19_604
        correctionStore.startShift()
        correctionStore.openLoad()
        correctionStore.setDraft(compartment: 0, litres: 4_704)
        correctionStore.commitLoad()
        _ = correctionStore.openSite(0)
        for index in correctionStore.compartments.indices where correctionStore.compartments[index].product == "XLS" {
            correctionStore.setDraft(compartment: index, litres: 0)
        }
        correctionStore.commitDelivery()
        correctionStore.returnToActive()
        let originalDelivery = correctionStore.correctableCargoEvents.first(where: { $0.kind == .delivery })
        if let originalDelivery {
            correctionStore.commitCorrection(eventID: originalDelivery.id, correctedLitres: 19_504, compartment: 0, note: "Field Test 02 input error")
        }
        let storedCorrection = correctionStore.eventLog.last(where: { $0.kind == .correction })?.inputCorrection
        check("Store correction remains available from Active history", correctionStore.workspace == .active && originalDelivery != nil)
        check("Store appends 19,604 → 19,504 correction", storedCorrection?.originalLitres == 19_604 && storedCorrection?.correctedLitres == 19_504 && storedCorrection?.deltaLitres == -100)
        check("Store retains original Delivery event", originalDelivery.map { original in correctionStore.eventLog.contains(where: { $0.id == original.id }) } == true)
        check("Store correction links the original Delivery event", storedCorrection?.originalEventID == originalDelivery?.id)
        check("Store correction rebuilds the +100 L projection", correctionStore.confirmedLitres[0] == 100)
        check("Store correction ledger facts use corrected provenance", storedCorrection?.correctionTransactionIDs.allSatisfy { id in correctionStore.cargoLedger.transactions.first(where: { $0.id == id })?.provenance == .corrected } == true)

        let transferStore = Chunk5FPrototypeStore(evidenceSource: .fixture)
        transferStore.startShift()
        let transferTotalBefore = transferStore.confirmedLitres.reduce(0, +)
        transferStore.commitTransfer(from: 0, to: 2, litres: 100)
        check("Transfer remains a distinct ledger movement", transferStore.cargoLedger.transactions.last?.kind == .transfer && transferStore.eventLog.last?.kind == .transfer)
        check("Transfer conserves physical cargo", transferStore.confirmedLitres.reduce(0, +) == transferTotalBefore)
        check("Transfer is not an exception substitute", transferStore.eventLog.last?.transactionVariance == nil && transferStore.eventLog.last?.physicalCheck == nil && transferStore.eventLog.last?.inputCorrection == nil)

        let suite = "Chunk5GFieldTest02ExceptionTests.\(UUID().uuidString)"
        if let defaults = UserDefaults(suiteName: suite) {
            defer { defaults.removePersistentDomain(forName: suite) }
            let live = Chunk5FPrototypeStore(evidenceSource: .live, persistenceDefaults: defaults)
            live.draftOpeningODO = 500_000
            let opening = [5_360, 0, 4_900, 2_104, 7_240]
            for index in opening.indices { live.setOpeningDraft(compartment: index, litres: opening[index]) }
            live.acceptOpeningBaseline()
            live.addSiteVisit(customer: "FIELD", site: "TEST 02", fillName: "Drop", product: "XLS", plannedLitres: 19_604)
            live.startShift()
            _ = live.openSite(0)
            for index in live.compartments.indices where live.compartments[index].product == "XLS" {
                live.setDraft(compartment: index, litres: 0)
            }
            live.commitDelivery(actualLitres: 19_799, postTransactionEmpty: true, varianceNote: "External total")
            live.returnToActive()
            if let delivery = live.correctableCargoEvents.first(where: { $0.kind == .delivery }) {
                live.commitCorrection(eventID: delivery.id, correctedLitres: 19_504, compartment: 0, note: "Corrected entry")
            }
            live.commitPhysicalCheck(compartment: 0, observedLitres: 125, note: "Dip")

            let restored = Chunk5FPrototypeStore(recoveringFrom: defaults)
            let restoredVariance = restored.eventLog.last(where: { $0.kind == .transactionVariance })?.transactionVariance
            let restoredCorrection = restored.eventLog.last(where: { $0.kind == .correction })?.inputCorrection
            let restoredPhysical = restored.eventLog.last(where: { $0.kind == .physicalCheck })?.physicalCheck
            check("Exception snapshot relaunch validates", restored.persistenceStatus == .pass && restored.shiftLifecycle == .active)
            check("Variance facts round-trip", restoredVariance?.calculatedLitres == 19_604 && restoredVariance?.actualLitres == 19_799 && restoredVariance?.varianceLitres == 195)
            check("Correction facts round-trip", restoredCorrection?.originalLitres == 19_604 && restoredCorrection?.correctedLitres == 19_504 && restoredCorrection?.provenance == .corrected)
            check("Physical Check facts round-trip", restoredPhysical?.calculatedLitres == 100 && restoredPhysical?.observedLitres == 125 && restoredPhysical?.differenceLitres == 25)

            if let snapshotData = defaults.data(forKey: "chunk5g.live.snapshot.v3"),
               var root = try? JSONSerialization.jsonObject(with: snapshotData) as? [String: Any],
               var events = root["eventLog"] as? [[String: Any]],
               let varianceIndex = events.firstIndex(where: { $0["transactionVariance"] != nil }),
               var varianceJSON = events[varianceIndex]["transactionVariance"] as? [String: Any] {
                // Notes are not derived arithmetic. Changing one proves the
                // authoritative fingerprint covers the complete payload too.
                varianceJSON["note"] = "tampered after persistence"
                events[varianceIndex]["transactionVariance"] = varianceJSON
                root["eventLog"] = events
                if let tampered = try? JSONSerialization.data(withJSONObject: root) {
                    defaults.set(tampered, forKey: "chunk5g.live.snapshot.v3")
                    let rejected = Chunk5FPrototypeStore(recoveringFrom: defaults)
                    check("Structured exception tamper is rejected", rejected.persistenceStatus == .fail && rejected.shiftLifecycle == .recoveryLocked)
                } else {
                    results.append("Structured exception tamper is rejected: FAIL — JSON rewrite failed")
                }
            } else {
                results.append("Structured exception tamper is rejected: FAIL — persisted payload unavailable")
            }
        } else {
            results.append("Exception persistence/relaunch fixture: FAIL — unavailable UserDefaults suite")
        }

        results.append("---")
        results.append(results.contains(where: { $0.contains(": FAIL") }) ? "GATE FAIL" : "GATE PASS")
        return results
    }
}
