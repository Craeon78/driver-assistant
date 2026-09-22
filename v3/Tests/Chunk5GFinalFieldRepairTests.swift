import Foundation

@MainActor
public enum Chunk5GFinalFieldRepairTests {
    public static func run() -> [String] {
        var results = ["=== V3 Chunk 5G Final Field Repairs ==="]
        func check(_ label: String, _ value: @autoclosure () -> Bool) { results.append("\(label): \(value() ? "PASS" : "FAIL")") }

        let plan = Chunk5FPrototypeStore(evidenceSource: .fixture)
        let historyBefore = plan.eventLog.count
        plan.addTerminalLoad(); plan.addPlannedRest(); plan.addPlannedOtherWork()
        check("Run has explicit four-kind model", Set(plan.runItems.map(\.kind)) == Set(Chunk5FRunItemKind.allCases))
        check("Terminal/Rest/Work are not fake visits", plan.visits.allSatisfy { !$0.isTerminalLoad } && plan.runItems.filter { $0.kind != .siteVisit }.allSatisfy { $0.siteVisitID == nil })
        check("Planning writes only plan-change history", plan.eventLog.dropFirst(historyBefore).allSatisfy { $0.kind == .planChange })
        check("Planning creates no Rest/Work truth", !plan.eventLog.contains { [.restStart, .restEnd, .workRest].contains($0.kind) })
        let restIndex = plan.runItems.firstIndex(where: { $0.kind == .plannedRest })!
        plan.moveRunItem(from: IndexSet(integer: restIndex), to: 0)
        check("Unexecuted mixed Run items reorder", plan.runItems.first?.kind == .plannedRest)
        plan.startShift(); plan.openRunItem(at: 0)
        check("Planned Rest becomes history only on Start", plan.workspace == .rest && plan.eventLog.last?.kind == .restStart && plan.runItems.first?.hasCommittedExecution == true && plan.runItems.first?.isSatisfied == true)
        plan.endRest()
        let countBeforeRemove = plan.runItems.count
        plan.removeRunItem(at: 0)
        check("Executed Run item cannot be removed", plan.runItems.count == countBeforeRemove)
        if let workIndex = plan.runItems.firstIndex(where: { $0.kind == .plannedOtherWork }) {
            plan.openRunItem(at: workIndex)
            check("Other Work is a generic WORK anchor", plan.workspace == .otherWork && plan.eventLog.last?.kind == .workRest && plan.eventLog.last?.summary == "Work started")
            plan.endOtherWork()
            check("Other Work ends through generic WORK anchor", plan.workspace == .active && plan.eventLog.last?.kind == .workRest)
        } else { results.append("Other Work is a narrow current context: FAIL") }

        let reorderSuite = "chunk5g.anchored.reorder.\(UUID().uuidString)"
        if let reorderDefaults = UserDefaults(suiteName: reorderSuite) {
            defer { reorderDefaults.removePersistentDomain(forName: reorderSuite) }
            let anchored = Chunk5FPrototypeStore(evidenceSource: .live, persistenceDefaults: reorderDefaults)
            anchored.draftOpeningODO = 800_000; anchored.acceptOpeningBaseline()
            anchored.addSiteVisit(customer: "A", site: "FUTURE", fillName: "A fill", product: "XLS", plannedLitres: 100)
            anchored.addPlannedRest()
            anchored.addTerminalLoad()
            anchored.startShift()
            let executedID = anchored.runItems[1].id
            anchored.openRunItem(at: 1); anchored.endRest()
            let originalOrder = anchored.runItems.map(\.id)
            let historyBeforeRejectedMoves = anchored.eventLog.count
            anchored.moveRunItem(from: IndexSet(integer: 1), to: anchored.runItems.count)
            check("Executed middle Run row cannot move", anchored.runItems.map(\.id) == originalOrder && anchored.eventLog.count == historyBeforeRejectedMoves)
            anchored.moveRunItem(from: IndexSet([0, 1]), to: anchored.runItems.count)
            check("Mixed mutable/committed Run selection is a no-op", anchored.runItems.map(\.id) == originalOrder && anchored.eventLog.count == historyBeforeRejectedMoves)
            anchored.moveRunItem(from: IndexSet(integer: 99), to: 0)
            anchored.moveRunItem(from: IndexSet(integer: 0), to: anchored.runItems.count + 1)
            check("Invalid Run moves are rejected without history", anchored.runItems.map(\.id) == originalOrder && anchored.eventLog.count == historyBeforeRejectedMoves)
            anchored.moveRunItem(from: IndexSet(integer: 0), to: 2)
            check("Drop across anchor without mutable-order change emits nothing", anchored.runItems.map(\.id) == originalOrder && anchored.eventLog.count == historyBeforeRejectedMoves)
            let historyBeforeAnchoredMove = anchored.eventLog.count
            anchored.moveRunItem(from: IndexSet(integer: 0), to: anchored.runItems.count)
            let reorderedIDs = anchored.runItems.map(\.id)
            check("Future rows reorder across an anchored executed row", reorderedIDs == [originalOrder[2], executedID, originalOrder[0]] && anchored.eventLog.count == historyBeforeAnchoredMove + 1 && anchored.eventLog.last?.kind == .planChange)
            let relaunchedOrder = Chunk5FPrototypeStore(recoveringFrom: reorderDefaults)
            check("Anchored mutable Run order survives relaunch", relaunchedOrder.persistenceStatus == .pass && relaunchedOrder.runItems.map(\.id) == reorderedIDs && relaunchedOrder.runItems[1].id == executedID)
        } else { results.append("Anchored Run reorder persistence suite: FAIL") }

        let partialAnchor = Chunk5FPrototypeStore(evidenceSource: .fixture)
        partialAnchor.addPlannedRest()
        partialAnchor.moveRunItem(from: IndexSet(integer: 2), to: 0)
        partialAnchor.startShift(); partialAnchor.openRunItem(at: 1)
        partialAnchor.setDraft(compartment: 3, litres: 0); partialAnchor.setDraft(compartment: 4, litres: 5_400)
        partialAnchor.commitDelivery(); partialAnchor.returnToActive()
        let partialID = partialAnchor.runItems[1].id
        let partialOriginal = partialAnchor.runItems.map(\.id)
        partialAnchor.moveRunItem(from: IndexSet(integer: 0), to: partialAnchor.runItems.count)
        check("Future rows reorder around anchored partial Site", partialAnchor.runItems.map(\.id) == [partialOriginal[2], partialID, partialOriginal[0]] && partialAnchor.runItems[1].hasCommittedExecution && !partialAnchor.runItems[1].isSatisfied)
        partialAnchor.setPrototypeMoving(true)
        let movingOrder = partialAnchor.runItems.map(\.id)
        let movingHistory = partialAnchor.eventLog.count
        partialAnchor.moveRunItem(from: IndexSet(integer: 0), to: partialAnchor.runItems.count)
        check("Moving restraint blocks anchored-subsequence reorder", partialAnchor.runItems.map(\.id) == movingOrder && partialAnchor.eventLog.count == movingHistory)

        let allFuture = Chunk5FPrototypeStore(evidenceSource: .fixture)
        let allFutureFirst = allFuture.runItems[0].id
        let allFutureHistory = allFuture.eventLog.count
        allFuture.moveRunItem(from: IndexSet(integer: 0), to: allFuture.runItems.count)
        check("All-future Run reorder remains supported", allFuture.runItems.last?.id == allFutureFirst && allFuture.eventLog.count == allFutureHistory + 1)

        let zero = Chunk5FPrototypeStore(evidenceSource: .fixture)
        zero.startShift(); zero.openRunItem(at: 0)
        let ledgerBefore = zero.cargoLedger.transactions.count
        zero.commitZeroDelivery(reason: "   ")
        check("Blank 0 L reason is rejected", zero.currentFill?.name == "Minjerrabah" && zero.eventLog.last?.kind != .delivery)
        zero.commitZeroDelivery(reason: "Customer tank unavailable")
        let outcome = zero.eventLog.last(where: { $0.deliveryOutcome?.actualLitres == 0 })?.deliveryOutcome
        check("0 L preserves planned quantity and identity", outcome?.plannedLitres == 5_000 && outcome?.fillID == zero.visits[0].fills[0].id && outcome?.siteVisitID == zero.visits[0].id)
        check("0 L creates no cargo or reconciliation", zero.cargoLedger.transactions.count == ledgerBefore && zero.reconciliationLog.events.filter { $0.note != "chunk5g.opening.baseline" }.isEmpty)
        check("0 L advances multi-fill Run", zero.workspace == .site && zero.currentFill?.name == "Seabreeze" && zero.visits[0].fills[0].completed)
        let zeroRunIndex = zero.runItems.firstIndex(where: { $0.siteVisitID == zero.visits[0].id })!
        zero.returnToActive()
        let zeroRunCount = zero.runItems.count
        zero.updateVisit(at: 0, customer: "MUTATED", site: "MUTATED")
        zero.removeRunItem(at: zeroRunIndex)
        zero.moveRunItem(from: IndexSet(integer: zeroRunIndex), to: zero.runItems.count)
        check("0 L first fill locks destructive plan mutation", zero.runItems.count == zeroRunCount && zero.visits[0].customer == "SEALINK")
        check("Partial 0 L Site remains next Run item", zero.nextUnexecutedRunItem?.id == zero.runItems[zeroRunIndex].id && !zero.runItems[zeroRunIndex].isSatisfied)
        zero.openRunItem(at: zeroRunIndex)
        check("0 L first fill leaves remaining fill progressable", zero.workspace == .site && zero.currentFill?.name == "Seabreeze")
        check("0 L is excluded from corrections", !zero.correctableCargoEvents.contains { $0.deliveryOutcome?.actualLitres == 0 })
        check("Gate represents deliberate 0 L", zero.buildLiveGateReport().deliveriesRepresented)
        do {
            var legacyLedger = zero.cargoLedger
            let legacyCargo = legacyLedger.transactions.first(where: { $0.destinationCompartmentID == zero.compartments[0].cargoCompartmentID })!.cargo
            try legacyLedger.append(CargoTransaction(kind: .unload, cargo: legacyCargo, units: 1, sourceCompartmentID: zero.compartments[0].cargoCompartmentID, occurredAt: Date().addingTimeInterval(1), provenance: .imported, note: nil))
            try zero.validateExceptionFacts(events: zero.eventLog, ledger: legacyLedger, reconciliationLog: zero.reconciliationLog, compartments: zero.compartments)
            check("Unrelated nil-note unload does not invalidate 0 L", true)
        } catch { results.append("Unrelated nil-note unload does not invalidate 0 L: FAIL — \(error)") }

        let changedDraft = Chunk5FPrototypeStore(evidenceSource: .fixture)
        changedDraft.startShift(); _ = changedDraft.openSite(0)
        changedDraft.setDraft(compartment: 0, litres: changedDraft.confirmedLitres[0] - 1)
        changedDraft.commitZeroDelivery(reason: "No product taken")
        check("0 L rejects a changed cargo draft", changedDraft.eventLog.last?.deliveryOutcome == nil && !changedDraft.visits[0].fills[0].completed)

        let positive = Chunk5FPrototypeStore(evidenceSource: .fixture)
        positive.startShift(); positive.openRunItem(at: 0)
        positive.setDraft(compartment: 3, litres: 0); positive.setDraft(compartment: 4, litres: 5_400)
        positive.commitDelivery()
        let positiveRunIndex = positive.runItems.firstIndex(where: { $0.siteVisitID == positive.visits[0].id })!
        positive.returnToActive()
        let positiveRunCount = positive.runItems.count
        positive.updateFill(visitIndex: 0, fillIndex: 1, name: "MUTATED", product: "XLS", plannedLitres: 1)
        positive.removeRunItem(at: positiveRunIndex)
        positive.moveRunItem(from: IndexSet(integer: positiveRunIndex), to: positive.runItems.count)
        check("Positive first fill locks destructive plan mutation", positive.runItems.count == positiveRunCount && positive.visits[0].fills[1].name == "Seabreeze")
        check("Partial positive Site remains next Run item", positive.nextUnexecutedRunItem?.id == positive.runItems[positiveRunIndex].id && !positive.runItems[positiveRunIndex].isSatisfied)
        positive.openRunItem(at: positiveRunIndex)
        check("Positive first fill leaves remaining fill progressable", positive.workspace == .site && positive.currentFill?.name == "Seabreeze")

        let terminalFailure = Chunk5FPrototypeStore(evidenceSource: .fixture)
        terminalFailure.addTerminalLoad(); terminalFailure.startShift()
        let terminalIndex = terminalFailure.runItems.firstIndex(where: { $0.kind == .terminalLoad })!
        terminalFailure.openRunItem(at: terminalIndex)
        terminalFailure.setDraft(compartment: 0, litres: terminalFailure.confirmedLitres[0] + 100)
        let ledgerBeforeFailure = terminalFailure.cargoLedger
        let reconciliationBeforeFailure = terminalFailure.reconciliationLog
        let eventsBeforeFailure = terminalFailure.eventLog
        let runBeforeFailure = terminalFailure.runItems
        let visitsBeforeFailure = terminalFailure.visits
        let discrepanciesBeforeFailure = terminalFailure.unresolvedDiscrepancies
        let workspaceBeforeFailure = terminalFailure.workspace
        let loadVisitBeforeFailure = terminalFailure.loadVisitIndexForTesting
        terminalFailure.varianceFailureForTesting = true
        terminalFailure.commitLoad(actualLitres: 101, postTransactionEmpty: false, varianceNote: "Forced failure")
        check("Terminal variance failure rolls back the whole commit", terminalFailure.cargoLedger == ledgerBeforeFailure && terminalFailure.reconciliationLog == reconciliationBeforeFailure && terminalFailure.eventLog == eventsBeforeFailure && terminalFailure.runItems == runBeforeFailure && terminalFailure.visits == visitsBeforeFailure && terminalFailure.unresolvedDiscrepancies == discrepanciesBeforeFailure && terminalFailure.workspace == workspaceBeforeFailure && terminalFailure.loadVisitIndexForTesting == loadVisitBeforeFailure && terminalFailure.message.contains("not committed"))
        terminalFailure.varianceFailureForTesting = false
        terminalFailure.commitLoad()
        let retriedTerminal = terminalFailure.runItems[terminalIndex]
        check("Rolled-back Terminal context can retry atomically", retriedTerminal.isSatisfied && retriedTerminal.executionEventID == retriedTerminal.satisfactionEventID && terminalFailure.eventLog.contains { $0.id == retriedTerminal.executionEventID && $0.relatedRunItemID == retriedTerminal.id })

        let suite = "chunk5g.final.repairs.\(UUID().uuidString)"
        if let defaults = UserDefaults(suiteName: suite) {
            defer { defaults.removePersistentDomain(forName: suite) }
            let live = Chunk5FPrototypeStore(evidenceSource: .live, persistenceDefaults: defaults)
            live.draftOpeningODO = 700_000; live.acceptOpeningBaseline()
            live.addSiteVisit(customer: "ZERO", site: "FIELD", fillName: "Fill", product: "XLS", plannedLitres: 1_234)
            live.addFill(visitIndex: 0, name: "Final fill", product: "XLS", plannedLitres: 321)
            live.addPlannedRest(); live.addPlannedOtherWork()
            live.startShift(); _ = live.openSite(0)
            live.commitZeroDelivery(reason: "Site declined delivery")
            live.commitZeroDelivery(reason: "Final fill unavailable")
            let restored = Chunk5FPrototypeStore(recoveringFrom: defaults)
            check("Run kinds persist and relaunch", restored.persistenceStatus == .pass && restored.runItems.map(\.kind) == live.runItems.map(\.kind))
            check("0 L structured outcome round-trips", restored.eventLog.contains { $0.deliveryOutcome?.actualLitres == 0 && $0.deliveryOutcome?.reason == "Site declined delivery" })
            if let data = defaults.data(forKey: "chunk5g.live.snapshot.v3"),
               let original = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                func rejected(_ label: String, mutate: (inout [String: Any]) -> Void) {
                    var root = original; mutate(&root)
                    guard let changed = try? JSONSerialization.data(withJSONObject: root) else { results.append("\(label): FAIL"); return }
                    defaults.set(changed, forKey: "chunk5g.live.snapshot.v3")
                    do { try live.refingerprintPersistedSnapshotForTesting() }
                    catch { results.append("\(label): FAIL — re-fingerprint \(error)"); return }
                    let candidate = Chunk5FPrototypeStore(recoveringFrom: defaults)
                    check(label, candidate.persistenceStatus == .fail && candidate.shiftLifecycle == .recoveryLocked)
                }
                rejected("Executed Run item without event is rejected") { root in
                    var items = root["runItems"] as! [[String: Any]]
                    let index = items.firstIndex(where: { $0["kind"] as? String == "siteVisit" })!
                    items[index]["executionEventID"] = UUID().uuidString; root["runItems"] = items
                }
                rejected("Event link with unsatisfied Run item is rejected") { root in
                    var items = root["runItems"] as! [[String: Any]]
                    let index = items.firstIndex(where: { $0["kind"] as? String == "siteVisit" })!
                    items[index].removeValue(forKey: "executionEventID"); root["runItems"] = items
                }
                rejected("Wrong kind/Run linkage is rejected") { root in
                    var items = root["runItems"] as! [[String: Any]]
                    var events = root["eventLog"] as! [[String: Any]]
                    let restIndex = items.firstIndex(where: { $0["kind"] as? String == "plannedRest" })!
                    let deliveryIndex = events.firstIndex(where: { ($0["deliveryOutcome"] as? [String: Any])?["actualLitres"] as? Int == 0 })!
                    let eventID = events[deliveryIndex]["id"] as! String
                    let restID = items[restIndex]["id"] as! String
                    items[restIndex]["executionEventID"] = eventID
                    events[deliveryIndex]["relatedRunItemID"] = restID
                    root["runItems"] = items; root["eventLog"] = events
                }
                rejected("Satisfied Site with incomplete visit is rejected semantically") { root in
                    var items = root["runItems"] as! [[String: Any]]
                    var visits = root["visits"] as! [[String: Any]]
                    let siteIndex = items.firstIndex(where: { $0["kind"] as? String == "siteVisit" })!
                    let visitID = items[siteIndex]["siteVisitID"] as! String
                    let visitIndex = visits.firstIndex(where: { $0["id"] as? String == visitID })!
                    var fills = visits[visitIndex]["fills"] as! [[String: Any]]
                    fills[0]["completed"] = false; visits[visitIndex]["fills"] = fills
                    root["visits"] = visits; root["runItems"] = items
                }
                rejected("Site satisfaction must link its final completing Delivery") { root in
                    var items = root["runItems"] as! [[String: Any]]
                    let siteIndex = items.firstIndex(where: { $0["kind"] as? String == "siteVisit" })!
                    let runID = items[siteIndex]["id"] as! String
                    let deliveries = (root["eventLog"] as! [[String: Any]]).filter { $0["relatedRunItemID"] as? String == runID && $0["deliveryOutcome"] != nil }
                    items[siteIndex]["satisfactionEventID"] = deliveries.first!["id"]
                    root["runItems"] = items
                }
                rejected("Legacy execution flags on Rest are rejected semantically") { root in
                    var items = root["runItems"] as! [[String: Any]]
                    let index = items.firstIndex(where: { $0["kind"] as? String == "plannedRest" })!
                    items[index]["legacyExecutionLock"] = true
                    root["runItems"] = items
                }
            } else { results.append("Run linkage tamper fixtures: FAIL") }
        } else { results.append("Persistence suite: FAIL") }

        results.append("---")
        results.append(results.contains(where: { $0.contains(": FAIL") }) ? "GATE FAIL" : "GATE PASS")
        return results
    }
}
