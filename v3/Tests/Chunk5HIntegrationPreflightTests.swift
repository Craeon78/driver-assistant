import Foundation

/// Supplementary regression evidence. A passing fixture cannot adjudicate 5H.
@MainActor
public enum Chunk5HIntegrationPreflightTests {
    public static func run() -> [String] {
        var lines = ["=== 5H CROSS-SYSTEM PREFLIGHT (NOT FIELD PASS) ==="]
        func check(_ name: String, _ condition: @autoclosure () -> Bool) {
            lines.append("\(name): \(condition() ? "PASS" : "FAIL")")
        }

        let suite = "chunk5h.preflight.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            return lines + ["Isolated persistence suite: FAIL"]
        }
        defer { defaults.removePersistentDomain(forName: suite) }

        let shift = Chunk5FPrototypeStore(evidenceSource: .live, persistenceDefaults: defaults)
        shift.draftOpeningODO = 800_000
        shift.setOpeningDraft(compartment: 0, litres: 1_000)
        shift.acceptOpeningBaseline()
        shift.addTerminalLoad()
        shift.addSiteVisit(customer: "FIELD", site: "A", fillName: "First", product: "XLS", plannedLitres: 100)
        shift.addFill(toVisitIndex: 0, name: "Second", product: "XLS", plannedLitres: 200)
        shift.addPlannedRest()
        shift.addPlannedOtherWork()
        shift.addSiteVisit(customer: "FIELD", site: "B", fillName: "Future", product: "XLS", plannedLitres: 50)
        let planEvents = shift.eventLog
        check("Planning emits only plan changes", planEvents.dropFirst().allSatisfy { $0.kind == .planChange })
        check("Planned Rest and Work have no execution", shift.runItems.filter { $0.kind == .plannedRest || $0.kind == .plannedOtherWork }.allSatisfy { !$0.hasCommittedExecution })
        check("Opening baseline is not a Load", !planEvents.contains { $0.kind == .load })

        shift.startShift()
        shift.openRunItem(at: 0)
        shift.setDraft(compartment: 0, litres: 1_200)
        shift.commitLoad()
        check("Load retains Work context", shift.workspace == .active && shift.eventLog.filter { $0.kind == .restStart }.isEmpty)
        shift.openRunItem(at: 1)
        shift.setDraft(compartment: 0, litres: 1_100)
        shift.commitDelivery()
        shift.commitZeroDelivery(reason: "Customer declined remaining fill")
        let deliveries = shift.eventLog.filter { $0.kind == .delivery }
        check("Positive and 0 L outcomes remain distinct", deliveries.count == 2 && deliveries[0].deliveryOutcome?.actualLitres == 100 && deliveries[1].deliveryOutcome?.actualLitres == 0)
        check("0 L makes no cargo movement", shift.confirmedLitres[0] == 1_100 && shift.cargoLedger.transactions.filter { $0.kind == .unload }.count == 1)
        check("Cargo work has not become Rest", shift.eventLog.filter { $0.kind == .restStart || $0.kind == .restEnd }.isEmpty)

        shift.openRunItem(at: 2)
        shift.endRest()
        shift.openRunItem(at: 3)
        shift.endOtherWork()
        check("Actual Rest and Work have independent anchors", shift.eventLog.filter { $0.kind == .restStart }.count == 1 && shift.eventLog.filter { $0.kind == .restEnd }.count == 1 && shift.eventLog.filter { $0.kind == .workRest }.count == 2)
        let committedIDs = shift.runItems.filter(\.hasCommittedExecution).map(\.id)
        shift.addTerminalLoad()
        shift.moveRunItem(from: IndexSet(integer: shift.runItems.count - 1), to: 4)
        check("Committed Run history stays anchored", shift.runItems.filter(\.hasCommittedExecution).map(\.id) == committedIDs)
        shift.commitTransfer(from: 0, to: 2, litres: 50)
        let beforeCheck = shift.confirmedLitres[2]
        shift.commitPhysicalCheck(compartment: 2, observedLitres: beforeCheck + 10, note: "Observed dip")
        check("Exception preserves separate event species", shift.eventLog.contains { $0.kind == .transfer } && shift.eventLog.contains { $0.kind == .physicalCheck && $0.physicalCheck?.differenceLitres == 10 })

        let committed = shift.eventLog.filter { $0.kind != .relaunch }
        let cargo = shift.confirmedLitres
        let order = shift.runItems.map(\.id)
        let recovered = Chunk5FPrototypeStore(recoveringFrom: defaults)
        check("Mid-shift relaunch restores one event history", recovered.persistenceStatus == .pass && recovered.eventLog == committed)
        check("Relaunch rebuilds cargo and Run", recovered.confirmedLitres == cargo && recovered.runItems.map(\.id) == order)
        recovered.draftClosingODO = 800_064
        recovered.endShift()
        let report = recovered.lastGateReport
        check("End Shift archives coherent anchors", recovered.shiftLifecycle == .fresh && report?.openingODO == 800_000 && report?.closingODO == 800_064 && report?.persistenceStatus == .pass)
        check("Gate separates integrity from completeness", report?.representationIntegrityStatus == .pass && report?.operationalCompletenessStatus == .notTested)
        check("Archived history retains cross-system events", report?.events.filter { $0.kind == .delivery }.count == 2 && report?.events.contains { $0.kind == .physicalCheck } == true)
        lines.append("5H FIELD GATE: AWAITING REAL WORKING SHIFT")
        return lines
    }
}
