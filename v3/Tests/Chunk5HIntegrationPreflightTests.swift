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
        check("Canonical Driver ledger remains Work through cargo", shift.driverEntries.last?.kind == .work && shift.driverEntries.last?.isOpen == true && shift.currentDailyFatigue?.openKind == .work)

        // Leave unexecuted work ahead of the two committed Driver contexts.
        shift.moveRunItem(from: IndexSet(integer: 4), to: 2)
        shift.openRunItem(at: 3)
        check("Rest reaches canonical fatigue feed", shift.driverEntries.last?.kind == .rest && shift.currentDailyFatigue?.openKind == .rest)
        shift.endRest()
        shift.openRunItem(at: 4)
        shift.endOtherWork()
        check("Actual Rest and Work have independent anchors", shift.eventLog.filter { $0.kind == .restStart }.count == 1 && shift.eventLog.filter { $0.kind == .restEnd }.count == 1 && shift.eventLog.filter { $0.kind == .workRest }.count == 2)
        check("Other Work stays in the open Work interval", shift.driverEntries.map(\.kind) == [.work, .rest, .work] && shift.currentDailyFatigue?.openKind == .work)
        let policy = shift.standardHours(asOf: Date().addingTimeInterval(60))
        check("Chunk 3.5 policy consumes post-Rest Driver work", policy?.activeWindows(for: .twentyFourHours).contains(where: { $0.work > 0 }) == true && policy?.historyUncertain == true)
        let committedIDs = shift.runItems.filter(\.hasCommittedExecution).map(\.id)
        let committedPositions = shift.runItems.enumerated().filter { $0.element.hasCommittedExecution }.map { ($0.element.id, $0.offset) }
        let futureID = shift.runItems[2].id
        shift.addTerminalLoad()
        shift.moveRunItem(from: IndexSet(integer: 2), to: shift.runItems.count)
        check("Future intent crosses committed slots", shift.runItems.last?.id == futureID)
        check("Committed Run history stays at exact positions", shift.runItems.filter(\.hasCommittedExecution).map(\.id) == committedIDs && committedPositions.allSatisfy { shift.runItems[$0.1].id == $0.0 })
        shift.commitTransfer(from: 0, to: 2, litres: 50)
        let beforeCheck = shift.confirmedLitres[2]
        shift.commitPhysicalCheck(compartment: 2, observedLitres: beforeCheck + 10, note: "Observed dip")
        check("Exception preserves separate event species", shift.eventLog.contains { $0.kind == .transfer } && shift.eventLog.contains { $0.kind == .physicalCheck && $0.physicalCheck?.differenceLitres == 10 })

        let committed = shift.eventLog.filter { $0.kind != .relaunch }
        let cargo = shift.confirmedLitres
        let order = shift.runItems.map(\.id)
        let ledgerBytes = defaults.data(forKey: "chunk5h.driver.ledger")
        if let emptyBytes = try? JSONEncoder().encode([WorkRestEntry]()) {
            defaults.set(emptyBytes, forKey: "chunk5h.driver.ledger")
        }
        let conflicting = Chunk5FPrototypeStore(recoveringFrom: defaults)
        check("Conflicting Driver file locks recovery", conflicting.shiftLifecycle == .recoveryLocked && conflicting.persistenceStatus == .fail)
        if let ledgerBytes { defaults.set(ledgerBytes, forKey: "chunk5h.driver.ledger") }
        let recovered = Chunk5FPrototypeStore(recoveringFrom: defaults)
        check("Mid-shift relaunch restores one event history", recovered.persistenceStatus == .pass && recovered.eventLog == committed)
        check("Relaunch rebuilds cargo and Run", recovered.confirmedLitres == cargo && recovered.runItems.map(\.id) == order)
        check("Relaunch preserves canonical Driver and fatigue", recovered.driverEntries == shift.driverEntries && recovered.currentDailyFatigue?.openKind == .work)
        recovered.draftClosingODO = 800_064
        recovered.endShift()
        let report = recovered.lastGateReport
        check("End Shift archives coherent anchors", recovered.shiftLifecycle == .fresh && report?.openingODO == 800_000 && report?.closingODO == 800_064 && report?.persistenceStatus == .pass)
        check("Gate separates integrity from completeness", report?.representationIntegrityStatus == .pass && report?.operationalCompletenessStatus == .notTested)
        check("Gate confirms canonical Driver feed", report?.driverLedgerStatus == .pass && recovered.driverEntries.last?.end != nil)
        check("Archived history retains cross-system events", report?.events.filter { $0.kind == .delivery }.count == 2 && report?.events.contains { $0.kind == .physicalCheck } == true)
        let previousDriverEntries = recovered.driverEntries
        recovered.draftOpeningODO = 800_064
        recovered.acceptOpeningBaseline()
        recovered.startShift()
        check("Next shift retains prior Driver intervals", recovered.driverEntries.count == previousDriverEntries.count + 1 && Array(recovered.driverEntries.dropLast()) == previousDriverEntries && recovered.driverEntries.last?.kind == .work)

        let legacySuite = "chunk5h.active.legacy.\(UUID().uuidString)"
        if let legacyDefaults = UserDefaults(suiteName: legacySuite) {
            defer { legacyDefaults.removePersistentDomain(forName: legacySuite) }
            recovered.addSiteVisit(customer: "LEGACY", site: "UNFINISHED", fillName: "Pending", product: "XLS", plannedLitres: 100)
            let old = Chunk5GLegacyV2Snapshot(
                evidenceSource: .live, compartments: recovered.compartments, visits: recovered.visits,
                eventLog: recovered.eventLog, cargoLedger: recovered.cargoLedger,
                reconciliationLog: recovered.reconciliationLog,
                openingBaselineAccepted: recovered.openingBaselineAccepted,
                shiftStartedAt: recovered.shiftStartedAt, shiftEndedAt: nil,
                openingODO: recovered.openingODO, closingODO: nil,
                cargoOpeningSnapshot: recovered.cargoOpeningSnapshot, unresolvedDiscrepancies: 0,
                dieselCargo: CargoKind(name: "Diesel", kind: "fuel.diesel", unitName: "L"),
                ulpCargo: CargoKind(name: "ULP", kind: "fuel.ulp", unitName: "L"),
                selectedVisit: 0, selectedFill: 0, restMinutes: 18, loadVisitIndex: nil
            )
            if let original = try? JSONEncoder().encode(old) {
                legacyDefaults.set(original, forKey: "chunk5g.live.snapshot.v2")
                check("Active legacy fixture has no canonical Driver ledger", old.shiftStartedAt != nil && old.shiftEndedAt == nil && legacyDefaults.data(forKey: "chunk5h.driver.ledger") == nil)
                let locked = Chunk5FPrototypeStore(recoveringFrom: legacyDefaults)
                check("Active legacy relaunch locks recovery", locked.shiftLifecycle == .recoveryLocked && locked.persistenceStatus == .fail)
                check("Original active legacy evidence survives", legacyDefaults.data(forKey: "chunk5g.live.snapshot.v2") == original)
                check("No active v3 shift is installed", legacyDefaults.data(forKey: "chunk5g.live.snapshot.v3") == nil && locked.shiftStartedAt == nil && locked.eventLog.isEmpty)
                let beforeCargo = locked.confirmedLitres
                locked.addSiteVisit(customer: "FALSE", site: "CONTINUATION", fillName: "False", product: "XLS", plannedLitres: 1)
                locked.openLoad(); locked.setDraft(compartment: 0, litres: 1); locked.commitLoad()
                check("Recovery lock blocks Cargo and Run continuation", locked.workspace == .preShift && locked.runItems.isEmpty && locked.visits.isEmpty && locked.confirmedLitres == beforeCargo && locked.eventLog.isEmpty)
            } else { lines.append("Active legacy fixture encoding: FAIL") }
        } else { lines.append("Active legacy isolated defaults: FAIL") }

        let priorV3Suite = "chunk5h.active.prior-v3.\(UUID().uuidString)"
        if let priorV3Defaults = UserDefaults(suiteName: priorV3Suite) {
            defer { priorV3Defaults.removePersistentDomain(forName: priorV3Suite) }
            let prior = Chunk5FPrototypeStore(evidenceSource: .live, persistenceDefaults: priorV3Defaults)
            prior.draftOpeningODO = 801_000
            prior.setOpeningDraft(compartment: 0, litres: 500)
            prior.acceptOpeningBaseline()
            prior.addSiteVisit(customer: "PRIOR", site: "ACTIVE", fillName: "Pending", product: "XLS", plannedLitres: 100)
            prior.startShift()
            if let currentBytes = priorV3Defaults.data(forKey: "chunk5g.live.snapshot.v3"),
               var object = (try? JSONSerialization.jsonObject(with: currentBytes)) as? [String: Any] {
                object.removeValue(forKey: "driverLedgerEntries")
                do {
                    priorV3Defaults.set(try JSONSerialization.data(withJSONObject: object), forKey: "chunk5g.live.snapshot.v3")
                    try prior.refingerprintPersistedSnapshotForTesting()
                    priorV3Defaults.removeObject(forKey: "chunk5h.driver.ledger")
                    let original = priorV3Defaults.data(forKey: "chunk5g.live.snapshot.v3")
                    check("Active prior-v3 fixture lacks Driver history", original != nil && priorV3Defaults.data(forKey: "chunk5h.driver.ledger") == nil)
                    let locked = Chunk5FPrototypeStore(recoveringFrom: priorV3Defaults)
                    check("Active prior-v3 relaunch locks recovery", locked.shiftLifecycle == .recoveryLocked && locked.persistenceStatus == .fail)
                    check("Original prior-v3 evidence survives", priorV3Defaults.data(forKey: "chunk5g.live.snapshot.v3") == original)
                    check("No active prior-v3 shift installs", locked.shiftStartedAt == nil && locked.eventLog.isEmpty && locked.runItems.isEmpty)
                    let beforeCargo = locked.confirmedLitres
                    locked.addSiteVisit(customer: "FALSE", site: "CONTINUATION", fillName: "False", product: "XLS", plannedLitres: 1)
                    locked.openLoad(); locked.setDraft(compartment: 0, litres: 1); locked.commitLoad()
                    check("Prior-v3 recovery lock blocks Cargo and Run", locked.runItems.isEmpty && locked.visits.isEmpty && locked.confirmedLitres == beforeCargo && locked.eventLog.isEmpty)
                } catch { lines.append("Active prior-v3 fixture sealing: FAIL") }
            } else { lines.append("Active prior-v3 fixture encoding: FAIL") }
        } else { lines.append("Active prior-v3 isolated defaults: FAIL") }

        let endFailureSuite = "chunk5h.end-save-failure.\(UUID().uuidString)"
        if let endDefaults = UserDefaults(suiteName: endFailureSuite) {
            defer { endDefaults.removePersistentDomain(forName: endFailureSuite) }
            let ending = Chunk5FPrototypeStore(evidenceSource: .live, persistenceDefaults: endDefaults)
            ending.draftOpeningODO = 802_000
            ending.acceptOpeningBaseline()
            ending.startShift()
            let activeBytes = endDefaults.data(forKey: "chunk5g.live.snapshot.v3")
            ending.draftClosingODO = 802_012
            ending.snapshotWriteFailureForTesting = true
            ending.endShift()
            check("Failed final save locks completed truth", ending.shiftLifecycle == .recoveryLocked && ending.persistenceStatus == .fail && ending.shiftEndedAt != nil)
            check("Failed final save retains active evidence", activeBytes != nil && endDefaults.data(forKey: "chunk5g.live.snapshot.v3") == activeBytes)
            check("Failed final save does not archive stale snapshot", endDefaults.data(forKey: "chunk5g.completed.previous.snapshot.v3") == nil && ending.lastGateReport == nil)
            let resumed = Chunk5FPrototypeStore(recoveringFrom: endDefaults)
            check("Closed Driver interval prevents stale shift resumption", resumed.shiftLifecycle == .recoveryLocked && resumed.persistenceStatus == .fail)
        } else { lines.append("End-save-failure isolated defaults: FAIL") }

        let completedSuite = "chunk5h.completed-driver-loss.\(UUID().uuidString)"
        if let completedDefaults = UserDefaults(suiteName: completedSuite) {
            defer { completedDefaults.removePersistentDomain(forName: completedSuite) }
            let completedShift = Chunk5FPrototypeStore(evidenceSource: .live, persistenceDefaults: completedDefaults)
            completedShift.draftOpeningODO = 803_000
            completedShift.acceptOpeningBaseline()
            completedShift.startShift()
            completedShift.draftClosingODO = 803_010
            completedShift.endShift()
            if let completedBytes = completedDefaults.data(forKey: "chunk5g.completed.previous.snapshot.v3") {
                completedDefaults.set(completedBytes, forKey: "chunk5g.live.snapshot.v3")
                completedDefaults.removeObject(forKey: "chunk5g.completed.previous.snapshot.v3")
                completedDefaults.removeObject(forKey: "chunk5h.driver.ledger")
                let locked = Chunk5FPrototypeStore(recoveringFrom: completedDefaults)
                check("Completed relaunch without Driver file locks recovery", locked.shiftLifecycle == .recoveryLocked && locked.persistenceStatus == .fail)
                check("Completed evidence survives Driver mismatch", completedDefaults.data(forKey: "chunk5g.live.snapshot.v3") == completedBytes && completedDefaults.data(forKey: "chunk5g.completed.previous.snapshot.v3") == nil)
                check("Completed mismatch cannot reset as ready", locked.lastGateReport == nil && locked.shiftStartedAt == nil && locked.completedShiftLocked)
            } else { lines.append("Completed Driver mismatch fixture archive: FAIL") }
        } else { lines.append("Completed Driver mismatch isolated defaults: FAIL") }
        lines.append("5H FIELD GATE: AWAITING REAL WORKING SHIFT")
        return lines
    }
}
