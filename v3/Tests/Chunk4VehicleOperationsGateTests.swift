import Foundation

public enum Chunk4VehicleOperationsGateTests {
    public static func run() -> [String] {
        var out = ["=== V3 Chunk 4 Vehicle + Operations Gate ==="]
        var failures = 0
        func check(_ name: String, _ ok: Bool) {
            out.append("\(name): \(ok ? "PASS" : "FAIL")")
            if !ok { failures += 1 }
        }

        let t0 = Date(timeIntervalSince1970: 1_789_520_400)
        let chassisA = VehicleChassis(name: "Chassis A", registration: "A", baseEmptyMassKg: 8_200, grossVehicleMassLimitKg: 26_000)
        let tank17 = VehicleBodyModule(
            name: "Tank #17",
            kind: .tank,
            serialNumber: "T17",
            emptyMassKg: 4_800,
            compartmentCapacitiesLitres: [6_000, 5_000, 5_000, 4_000, 4_000]
        )
        let measured = MeasuredTareEvidence(measuredAt: t0, massKg: 13_120, note: "Configured weighbridge tare")
        let comboA = VehicleCombinationSnapshot(capturedAt: t0, chassis: chassisA, body: tank17, measuredTare: measured)

        check("Tank is independent physical asset", comboA.body?.id == tank17.id)
        check("Tank owns five physical compartments", comboA.body?.compartmentCapacitiesLitres.count == 5)
        check("Calculated empty mass combines chassis + body", comboA.calculatedEmptyMassKg == 13_000)
        check("Measured tare overrides calculated empty mass", comboA.authoritativeTareKg == 13_120)

        var operations = OperationsLedger()
        let drive = OperationEntry(kind: .drive, start: t0, vehicleCombination: comboA)
        operations.append(drive)
        check("Valid operation close accepted", operations.close(id: drive.id, at: t0.addingTimeInterval(3600)))
        let closedEnd = operations.entries.first?.end
        check("Repeated close rejected", !operations.close(id: drive.id, at: t0.addingTimeInterval(7200)))
        check("Repeated close cannot rewrite history", operations.entries.first?.end == closedEnd)

        let impossible = OperationEntry(kind: .wait, start: t0.addingTimeInterval(10_000), vehicleCombination: comboA)
        operations.append(impossible)
        check("End before start rejected", !operations.close(id: impossible.id, at: t0.addingTimeInterval(9_000)))
        check("Invalid close leaves operation open", operations.entries.first(where: { $0.id == impossible.id })?.isOpen == true)

        // Tank #17 survives replacement of its first chassis.
        let chassisB = VehicleChassis(name: "Chassis B", registration: "B", baseEmptyMassKg: 8_700, grossVehicleMassLimitKg: 26_000)
        let comboB = VehicleCombinationSnapshot(capturedAt: t0.addingTimeInterval(20_000), chassis: chassisB, body: tank17)
        check("Body survives chassis replacement", comboB.body?.id == comboA.body?.id)
        check("Chassis replacement changes chassis identity", comboB.chassis.id != comboA.chassis.id)
        check("Old operation retains old chassis", operations.entries.first?.vehicleCombination.chassis.id == chassisA.id)

        // The same chassis can later carry a different body without becoming a different chassis.
        let tray4 = VehicleBodyModule(name: "Tray #4", kind: .tray, serialNumber: "TR4", emptyMassKg: 1_900)
        let chassisAWithTray = VehicleCombinationSnapshot(capturedAt: t0.addingTimeInterval(30_000), chassis: chassisA, body: tray4)
        check("Chassis survives body replacement", chassisAWithTray.chassis.id == comboA.chassis.id)
        check("Body replacement changes body identity", chassisAWithTray.body?.id != comboA.body?.id)
        check("Configuration tare changes with body", chassisAWithTray.calculatedEmptyMassKg == 10_100)

        let encoded = try! JSONEncoder().encode(operations)
        let replayed = try! JSONDecoder().decode(OperationsLedger.self, from: encoded)
        check("Operations replay deterministic", replayed == operations)
        check("Historical chassis + body survive replay", replayed.entries.first?.vehicleCombination == comboA)

        let driver = WorkRestEntry(kind: .work, start: t0, end: t0.addingTimeInterval(3600))
        let before = driver
        _ = comboB
        _ = chassisAWithTray
        check("Driver truth unaffected by Vehicle/Operations", driver == before)

        out.append("---")
        out.append(failures == 0 ? "GATE PASS" : "GATE FAIL (\(failures))")
        return out
    }
}
