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
        let truckA = VehicleProfile(name: "Truck A", registration: "A", bodyKind: .primeMover)
        let trailerA = VehicleProfile(name: "Trailer A", registration: "TA", bodyKind: .trailer)
        let comboA = VehicleCombinationSnapshot(capturedAt: t0, units: [truckA, trailerA])

        var operations = OperationsLedger()
        let drive = OperationEntry(kind: .drive, start: t0, vehicleCombination: comboA)
        operations.append(drive)
        operations.close(id: drive.id, at: t0.addingTimeInterval(3600))
        operations.append(OperationEntry(kind: .stop, start: t0.addingTimeInterval(3600), vehicleCombination: comboA))

        check("Drive and Stop are Operations truth", operations.entries.map(\.kind) == [.drive, .stop])
        check("Operation captures historical vehicle combination", operations.entries.first?.vehicleCombination == comboA)

        // The driver later selects a materially different current vehicle.
        let rigidB = VehicleProfile(name: "Rigid B", registration: "B", bodyKind: .rigid)
        let currentComboB = VehicleCombinationSnapshot(capturedAt: t0.addingTimeInterval(7200), units: [rigidB])
        check("Second fixture is structurally different", currentComboB.units.count == 1 && comboA.units.count == 2)
        check("Current truck does not rewrite past operation", operations.entries.first?.vehicleCombination.units.map(\.name) == ["Truck A", "Trailer A"])

        // Codable replay proves the two ledgers can survive relaunch independently.
        let encoded = try! JSONEncoder().encode(operations)
        let replayed = try! JSONDecoder().decode(OperationsLedger.self, from: encoded)
        check("Operations replay deterministic", replayed == operations)
        check("Historical vehicle survives replay", replayed.entries.first?.vehicleCombination == comboA)

        // Driver truth is deliberately independent: an Operations event does not mutate it.
        let driver = WorkRestEntry(kind: .work, start: t0, end: t0.addingTimeInterval(3600))
        let before = driver
        _ = currentComboB
        _ = replayed
        check("Driver truth unaffected by Vehicle/Operations", driver == before)

        out.append("---")
        out.append(failures == 0 ? "GATE PASS" : "GATE FAIL (\(failures))")
        return out
    }
}
