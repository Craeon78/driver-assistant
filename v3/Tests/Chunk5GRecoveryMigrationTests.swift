import Foundation

@MainActor
public enum Chunk5GRecoveryMigrationTests {
    public static func run() -> [String] {
        var results = ["=== V3 Chunk 5G Recovery Migration ==="]
        func check(_ label: String, _ value: @autoclosure () -> Bool) {
            results.append("\(label): \(value() ? "PASS" : "FAIL")")
        }

        let suite = "chunk5g.recovery.tests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            return results + ["Isolated defaults suite: FAIL", "---", "GATE FAIL"]
        }
        defer { defaults.removePersistentDomain(forName: suite) }

        do {
            let c1 = CanonicalID.fresh()
            let c2 = CanonicalID.fresh()
            let compartments = [
                Chunk5FCompartment(id: 1, cargoCompartmentID: c1, product: "XLS", capacityLitres: 5360),
                Chunk5FCompartment(id: 2, cargoCompartmentID: c2, product: "ULP", capacityLitres: 3240)
            ]
            let diesel = CargoKind(name: "Diesel", kind: "fuel.diesel", unitName: "L")
            let ulp = CargoKind(name: "ULP", kind: "fuel.ulp", unitName: "L")
            let limits = compartments.map {
                CargoCompartmentLimit(compartmentID: $0.cargoCompartmentID, capacityUnits: Double($0.capacityLitres))
            }
            let ledger = try CargoLedger(limits: limits)
            var reconciliation = try CargoReconciliationLog()
            let started = Date(timeIntervalSince1970: 1_700_000_000)
            try reconciliation.append(CargoReconciliationEvent(
                compartmentID: c1,
                cargo: diesel,
                calculatedUnitsBefore: 0,
                confirmedPhysicalUnitsAfter: 3917,
                occurredAt: started,
                recordedAt: started,
                provenance: .driverEntered,
                note: "chunk5g.opening.baseline"
            ))
            let events = [
                Chunk5GEvent(id: UUID(), timestamp: started, kind: .cargoBaseline, summary: "Opening cargo baseline"),
                Chunk5GEvent(id: UUID(), timestamp: started, kind: .shiftStart, summary: "Shift started")
            ]
            let visits = [
                Chunk5FSiteVisit(
                    customer: "TERMINAL",
                    site: "LOAD",
                    projectedTime: "04:30",
                    fills: [Chunk5FFillItem(name: "Legacy Load", product: "XLS", plannedLitres: 0)],
                    isTerminalLoad: true
                ),
                Chunk5FSiteVisit(customer: "PARTIAL", site: "FIRST FILL DONE", projectedTime: "05:00", fills: [
                    Chunk5FFillItem(name: "Done", product: "XLS", plannedLitres: 100, completed: true),
                    Chunk5FFillItem(name: "Remaining", product: "XLS", plannedLitres: 200)
                ]),
                Chunk5FSiteVisit(customer: "COMPLETE", site: "DONE", projectedTime: "05:10", fills: [
                    Chunk5FFillItem(name: "Done", product: "XLS", plannedLitres: 300, completed: true)
                ]),
                Chunk5FSiteVisit(
                    customer: "MIGRATION TEST",
                    site: "ODD VALUES",
                    projectedTime: "05:17",
                    fills: [Chunk5FFillItem(name: "Fill A", product: "XLS", plannedLitres: 4123)]
                )
            ]
            let legacy = Chunk5GLegacyV2Snapshot(
                evidenceSource: .live,
                compartments: compartments,
                visits: visits,
                eventLog: events,
                cargoLedger: ledger,
                reconciliationLog: reconciliation,
                openingBaselineAccepted: true,
                shiftStartedAt: started,
                shiftEndedAt: nil,
                openingODO: 19604,
                closingODO: nil,
                cargoOpeningSnapshot: [3917, 0],
                unresolvedDiscrepancies: 0,
                dieselCargo: diesel,
                ulpCargo: ulp,
                selectedVisit: 3,
                selectedFill: 0,
                restMinutes: 18,
                loadVisitIndex: nil
            )
            defaults.set(try JSONEncoder().encode(legacy), forKey: "chunk5g.live.snapshot.v2")

            let restored = Chunk5FPrototypeStore(recoveringFrom: defaults)
            check("v2 removed only after verified v3 write", defaults.data(forKey: "chunk5g.live.snapshot.v2") == nil && defaults.data(forKey: "chunk5g.live.snapshot.v3") != nil)
            check("Distinctive reconciled cargo restored", restored.confirmedLitres == [3917, 0])
            check("Run restored without becoming history", restored.visits.count == 3 && restored.visits[2].fills[0].plannedLitres == 4123 && !restored.visits[2].fills[0].completed)
            check("Legacy terminal normalizes as Terminal/Load", restored.runItems.first?.kind == .terminalLoad && restored.visits.allSatisfy { !$0.isTerminalLoad })
            check("Legacy partial Site is locked but unsatisfied", restored.runItems.first(where: { $0.title.contains("PARTIAL") })?.hasCommittedExecution == true && restored.runItems.first(where: { $0.title.contains("PARTIAL") })?.isSatisfied == false)
            check("Legacy completed Site is locked and satisfied", restored.runItems.first(where: { $0.title.contains("COMPLETE") })?.isSatisfied == true)
            check("Legacy terminal cannot become next Site", restored.nextIncompleteVisit?.site == "FIRST FILL DONE")
            restored.openRunItem(at: 0)
            check("Legacy terminal opens Load safely", restored.workspace == .load)
            restored.returnToActive()

            if let v3Data = defaults.data(forKey: "chunk5g.live.snapshot.v3"), var siteRoot = try? JSONSerialization.jsonObject(with: v3Data) as? [String: Any] {
                siteRoot["selectedVisit"] = 3; siteRoot["workspace"] = "Site"
                if let siteData = try? JSONSerialization.data(withJSONObject: siteRoot) {
                    defaults.set(siteData, forKey: "chunk5g.live.snapshot.v3")
                    let selectedSite = Chunk5FPrototypeStore(recoveringFrom: defaults)
                    check("Legacy selected Site remaps past terminal", selectedSite.workspace == .site && selectedSite.currentVisit?.site == "ODD VALUES")
                }
                var loadRoot = siteRoot; loadRoot["workspace"] = "Load"; loadRoot["loadVisitIndex"] = 0
                if let loadData = try? JSONSerialization.data(withJSONObject: loadRoot) {
                    defaults.set(loadData, forKey: "chunk5g.live.snapshot.v3")
                    let selectedLoad = Chunk5FPrototypeStore(recoveringFrom: defaults)
                    check("Legacy Load workspace requires explicit Terminal reopen", selectedLoad.workspace == .active && selectedLoad.loadVisitIndexForTesting == nil && selectedLoad.visits.allSatisfy { !$0.isTerminalLoad })
                    if let terminalIndex = selectedLoad.runItems.firstIndex(where: { $0.kind == .terminalLoad }) {
                        selectedLoad.openRunItem(at: terminalIndex)
                        selectedLoad.setDraft(compartment: 0, litres: selectedLoad.confirmedLitres[0] + 1)
                        selectedLoad.commitLoad()
                        let relaunchedLoad = Chunk5FPrototypeStore(recoveringFrom: defaults)
                        let terminal = relaunchedLoad.runItems.first(where: { $0.kind == .terminalLoad })
                        check("Explicitly reopened legacy Terminal commits and relaunches linked", relaunchedLoad.persistenceStatus == .pass && terminal?.isSatisfied == true && terminal?.executionEventID == terminal?.satisfactionEventID && relaunchedLoad.eventLog.contains { $0.id == terminal?.executionEventID && $0.relatedRunItemID == terminal?.id })
                    } else { results.append("Explicitly reopened legacy Terminal commits and relaunches linked: FAIL") }
                }
                let hybridSuite = "chunk5g.recovery.hybrid.\(UUID().uuidString)"
                if let hybridDefaults = UserDefaults(suiteName: hybridSuite) {
                    defer { hybridDefaults.removePersistentDomain(forName: hybridSuite) }
                    hybridDefaults.set(v3Data, forKey: "chunk5g.live.snapshot.v3")
                    let hybrid = Chunk5FPrototypeStore(recoveringFrom: hybridDefaults)
                    if let partialRunIndex = hybrid.runItems.firstIndex(where: { $0.title.contains("PARTIAL") }),
                       let partialVisit = hybrid.visits.first(where: { $0.site == "FIRST FILL DONE" }),
                       let legacyFillID = partialVisit.fills.first(where: \.completed)?.id {
                        hybrid.openRunItem(at: partialRunIndex)
                        hybrid.setDraft(compartment: 0, litres: hybrid.confirmedLitres[0] - 200)
                        hybrid.commitDelivery()
                        let hybridRelaunch = Chunk5FPrototypeStore(recoveringFrom: hybridDefaults)
                        let relaunchedItem = hybridRelaunch.runItems.first(where: { $0.title.contains("PARTIAL") })
                        check("Legacy partial Site completes through Run row and relaunches", hybridRelaunch.persistenceStatus == .pass && relaunchedItem?.isSatisfied == true && relaunchedItem?.legacyCompletedFillIDs == [legacyFillID] && relaunchedItem?.satisfactionEventID != nil && hybridRelaunch.eventLog.contains { $0.id == relaunchedItem?.satisfactionEventID && $0.deliveryOutcome?.fillID != legacyFillID })

                        if let hybridData = hybridDefaults.data(forKey: "chunk5g.live.snapshot.v3"),
                           let hybridRoot = try? JSONSerialization.jsonObject(with: hybridData) as? [String: Any] {
                            var priorSchemaRoot = hybridRoot
                            var priorSchemaItems = priorSchemaRoot["runItems"] as! [[String: Any]]
                            let priorSchemaIndex = priorSchemaItems.firstIndex(where: { ($0["title"] as? String)?.contains("PARTIAL") == true })!
                            priorSchemaItems[priorSchemaIndex].removeValue(forKey: "legacyCompletedFillIDs")
                            priorSchemaRoot["runItems"] = priorSchemaItems
                            if let priorSchemaData = try? JSONSerialization.data(withJSONObject: priorSchemaRoot) {
                                hybridDefaults.set(priorSchemaData, forKey: "chunk5g.live.snapshot.v3")
                                do {
                                    try hybridRelaunch.refingerprintPersistedSnapshotForTesting()
                                    let repairedPriorSchema = Chunk5FPrototypeStore(recoveringFrom: hybridDefaults)
                                    repairedPriorSchema.persistLiveSnapshot()
                                    let normalizedPriorSchema = Chunk5FPrototypeStore(recoveringFrom: hybridDefaults)
                                    check("Pre-ID hybrid snapshot derives and persists exact legacy fill set", normalizedPriorSchema.persistenceStatus == .pass && normalizedPriorSchema.runItems.first(where: { $0.title.contains("PARTIAL") })?.legacyCompletedFillIDs == [legacyFillID])
                                } catch { results.append("Pre-ID hybrid snapshot derives and persists exact legacy fill set: FAIL — \(error)") }
                            } else { results.append("Pre-ID hybrid snapshot derives and persists exact legacy fill set: FAIL") }

                            func rejectsHybridTamper(_ label: String, mutate: (inout [String: Any]) -> Void) {
                                var root = hybridRoot; mutate(&root)
                                guard let changed = try? JSONSerialization.data(withJSONObject: root) else { results.append("\(label): FAIL"); return }
                                hybridDefaults.set(changed, forKey: "chunk5g.live.snapshot.v3")
                                do { try hybridRelaunch.refingerprintPersistedSnapshotForTesting() }
                                catch { results.append("\(label): FAIL — re-fingerprint \(error)"); return }
                                let candidate = Chunk5FPrototypeStore(recoveringFrom: hybridDefaults)
                                check(label, candidate.persistenceStatus == .fail && candidate.shiftLifecycle == .recoveryLocked)
                            }
                            rejectsHybridTamper("Hybrid Site cannot erase legacy completed-fill identity") { root in
                                var items = root["runItems"] as! [[String: Any]]
                                let index = items.firstIndex(where: { ($0["title"] as? String)?.contains("PARTIAL") == true })!
                                items[index]["legacyCompletedFillIDs"] = [String](); root["runItems"] = items
                            }
                            rejectsHybridTamper("Hybrid Site cannot overlap legacy and new Delivery fills") { root in
                                var items = root["runItems"] as! [[String: Any]]
                                let index = items.firstIndex(where: { ($0["title"] as? String)?.contains("PARTIAL") == true })!
                                let visitID = items[index]["siteVisitID"] as! String
                                let visit = (root["visits"] as! [[String: Any]]).first(where: { $0["id"] as? String == visitID })!
                                items[index]["legacyCompletedFillIDs"] = (visit["fills"] as! [[String: Any]]).map { $0["id"] as! String }
                                root["runItems"] = items
                            }
                        } else { results.append("Legacy/new hybrid semantic tamper fixtures: FAIL") }
                    } else { results.append("Legacy partial Site completes through Run row and relaunches: FAIL") }
                } else { results.append("Legacy/new hybrid defaults suite: FAIL") }
                defaults.set(v3Data, forKey: "chunk5g.live.snapshot.v3")
            } else { results.append("Legacy v3 selection remap fixtures: FAIL") }
            check("Chronology unchanged", restored.eventLog == events)
            check("ODO and active lifecycle restored", restored.openingODO == 19604 && restored.workspace == .active && restored.shiftLifecycle == .active)
            check("Migration reports persistence PASS", restored.persistenceStatus == .pass)

            restored.persistLiveSnapshot()
            let replayed = Chunk5FPrototypeStore(recoveringFrom: defaults)
            check("Normalized legacy state persists and relaunches", replayed.persistenceStatus == .pass && replayed.eventLog == events && replayed.confirmedLitres == [3917, 0] && replayed.runItems.first?.kind == .terminalLoad && replayed.runItems.first(where: { $0.title.contains("PARTIAL") })?.hasCommittedExecution == true && defaults.data(forKey: "chunk5g.live.snapshot.v2") == nil)

            if let normalizedData = defaults.data(forKey: "chunk5g.live.snapshot.v3"),
               let normalizedRoot = try? JSONSerialization.jsonObject(with: normalizedData) as? [String: Any] {
                func rejectsSemanticTamper(_ label: String, mutate: (inout [String: Any]) -> Void) {
                    var root = normalizedRoot; mutate(&root)
                    guard let changed = try? JSONSerialization.data(withJSONObject: root) else { results.append("\(label): FAIL"); return }
                    defaults.set(changed, forKey: "chunk5g.live.snapshot.v3")
                    do { try replayed.refingerprintPersistedSnapshotForTesting() }
                    catch { results.append("\(label): FAIL — re-fingerprint \(error)"); return }
                    let candidate = Chunk5FPrototypeStore(recoveringFrom: defaults)
                    check(label, candidate.persistenceStatus == .fail && candidate.shiftLifecycle == .recoveryLocked)
                }
                rejectsSemanticTamper("Legacy partial Site cannot claim satisfaction") { root in
                    var items = root["runItems"] as! [[String: Any]]
                    let index = items.firstIndex(where: { ($0["title"] as? String)?.contains("PARTIAL") == true })!
                    items[index]["legacySatisfied"] = true; root["runItems"] = items
                }
                rejectsSemanticTamper("Legacy Terminal cannot claim execution without event") { root in
                    var items = root["runItems"] as! [[String: Any]]
                    let index = items.firstIndex(where: { $0["kind"] as? String == "terminalLoad" })!
                    items[index]["legacyExecutionLock"] = true; root["runItems"] = items
                }
                defaults.set(normalizedData, forKey: "chunk5g.live.snapshot.v3")
            } else { results.append("Legacy semantic tamper fixtures: FAIL") }

            defaults.set(try JSONEncoder().encode(legacy), forKey: "chunk5g.live.snapshot.v2")
            let preferredV3 = Chunk5FPrototypeStore(recoveringFrom: defaults)
            check("Validated v3 retires stale v2", defaults.data(forKey: "chunk5g.live.snapshot.v2") == nil && preferredV3.eventLog == events && preferredV3.confirmedLitres == [3917, 0])

            defaults.removeObject(forKey: "chunk5g.live.snapshot.v3")
            defaults.set(Data("not-json".utf8), forKey: "chunk5g.live.snapshot.v2")
            let rejected = Chunk5FPrototypeStore(recoveringFrom: defaults)
            check("Rejected v2 bytes remain preserved", defaults.data(forKey: "chunk5g.live.snapshot.v2") == Data("not-json".utf8))
            check("Rejected migration locks mutation", rejected.shiftLifecycle == .recoveryLocked && rejected.persistenceStatus == .fail)
            check("Rejected migration does not create v3", defaults.data(forKey: "chunk5g.live.snapshot.v3") == nil)

            let validV2 = try JSONEncoder().encode(legacy)
            let rejectedV3 = Data("not-v3-json".utf8)
            defaults.set(validV2, forKey: "chunk5g.live.snapshot.v2")
            defaults.set(rejectedV3, forKey: "chunk5g.live.snapshot.v3")
            let precedence = Chunk5FPrototypeStore(recoveringFrom: defaults)
            check("Existing v3 takes precedence over v2", defaults.data(forKey: "chunk5g.live.snapshot.v3") == rejectedV3 && defaults.data(forKey: "chunk5g.live.snapshot.v2") == validV2)
            check("Rejected current state remains locked", precedence.shiftLifecycle == .recoveryLocked && precedence.persistenceStatus == .fail)
        } catch {
            results.append("Unexpected error: FAIL — \(error)")
        }

        results.append("---")
        results.append(results.contains(where: { $0.contains(": FAIL") }) ? "GATE FAIL" : "GATE PASS")
        return results
    }
}
