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
                selectedVisit: 0,
                selectedFill: 0,
                restMinutes: 18,
                loadVisitIndex: nil
            )
            defaults.set(try JSONEncoder().encode(legacy), forKey: "chunk5g.live.snapshot.v2")

            let restored = Chunk5FPrototypeStore(recoveringFrom: defaults)
            check("v2 removed only after verified v3 write", defaults.data(forKey: "chunk5g.live.snapshot.v2") == nil && defaults.data(forKey: "chunk5g.live.snapshot.v3") != nil)
            check("Distinctive reconciled cargo restored", restored.confirmedLitres == [3917, 0])
            check("Run restored without becoming history", restored.visits.count == 1 && restored.visits[0].fills[0].plannedLitres == 4123 && !restored.visits[0].fills[0].completed)
            check("Chronology unchanged", restored.eventLog == events)
            check("ODO and active lifecycle restored", restored.openingODO == 19604 && restored.workspace == .active && restored.shiftLifecycle == .active)
            check("Migration reports persistence PASS", restored.persistenceStatus == .pass)

            let replayed = Chunk5FPrototypeStore(recoveringFrom: defaults)
            check("Second launch is idempotent", replayed.eventLog == events && replayed.confirmedLitres == [3917, 0] && defaults.data(forKey: "chunk5g.live.snapshot.v2") == nil)

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
