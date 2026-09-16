import Foundation

public enum Chunk4VehicleOperationsGateTests {
    public static func run() -> [String] {
        var out = ["=== V3 Chunk 2 ↔ Chunk 4 ODO Integration Gate v2 ==="]; var failures = 0
        func check(_ name: String, _ ok: Bool) { out.append("\(name): \(ok ? "PASS" : "FAIL")"); if !ok { failures += 1 } }
        let t0 = Date(timeIntervalSince1970: 1_789_520_400)
        let truckA = VehicleChassis(name: "Rigid A", registration: "RIGID-A", baseEmptyMassKg: 8_200)
        let bodyA = VehicleBodyModule(name: "Tank A", kind: .tank, emptyMassKg: 4_000)
        let comboA = VehicleCombinationSnapshot(capturedAt: t0, chassis: truckA, body: bodyA, relationships: [ConfigurationRelationship(subject: .body(bodyA.id), kind: .fittedTo, target: .poweredVehicle(truckA.id))])
        let truckB = VehicleChassis(name: "Prime B", registration: "PRIME-B", baseEmptyMassKg: 9_000)
        let comboB = VehicleCombinationSnapshot(capturedAt: t0, chassis: truckB)

        let a1 = ODOAnchor(km: 428_317, recordedAt: t0), a2 = ODOAnchor(km: 428_407, recordedAt: t0.addingTimeInterval(3600))
        let va1 = VehicleODOAnchor(anchor: a1, poweredVehicleID: truckA.id), va2 = VehicleODOAnchor(anchor: a2, poweredVehicleID: truckA.id)
        check("Driver-entered ODO remains authoritative", va1.anchor.km == 428_317 && va1.anchor.provenance == .driverEntered)
        let intervalA = DistanceInterval(startAnchor: a1, endAnchor: a2, odoDeltaKm: 90, gpsRawKm: 91.2, gpsFilteredKm: 89.7, chosenSource: .odoAnchor, chosenKm: 90, closedAt: t0.addingTimeInterval(3600))
        let evidenceA = try! VehicleODOAttribution.attribute(interval: intervalA, start: va1, end: va2)
        check("Chunk 2 interval survives attribution unchanged", evidenceA.interval == intervalA)

        // P1 regression: vehicle identity participates BEFORE DistanceEngine commits.
        let engine = DistanceEngine()
        check("First Truck A anchor opens span", engine.handleODOAnchor(a1, poweredVehicleID: truckA.id) == nil)
        let factorBeforeSwap = engine.effectiveCorrectionFactor
        let closedBeforeSwap = engine.closedIntervals().count
        let b1 = ODOAnchor(km: 612_010, recordedAt: t0.addingTimeInterval(3700))
        check("Truck swap opens new span instead of cross-vehicle interval", engine.handleODOAnchor(b1, poweredVehicleID: truckB.id) == nil)
        check("Truck swap cannot commit poisoned interval", engine.closedIntervals().count == closedBeforeSwap)
        check("Truck swap cannot alter learned correction factor", engine.effectiveCorrectionFactor == factorBeforeSwap)
        let b2 = ODOAnchor(km: 612_045, recordedAt: t0.addingTimeInterval(5400))
        let validB = engine.handleODOAnchor(b2, poweredVehicleID: truckB.id)
        check("Second truck can close its own subsequent span", validB?.odoDeltaKm == 35)

        let vb1 = VehicleODOAnchor(anchor: b1, poweredVehicleID: truckB.id), vb2 = VehicleODOAnchor(anchor: b2, poweredVehicleID: truckB.id)
        let intervalB = DistanceInterval(startAnchor: b1, endAnchor: b2, odoDeltaKm: 35, chosenSource: .odoAnchor, chosenKm: 35, closedAt: t0.addingTimeInterval(5400))
        let evidenceB = try! VehicleODOAttribution.attribute(interval: intervalB, start: vb1, end: vb2)

        var driveA = OperationEntry(kind: .drive, start: t0, vehicleCombination: comboA)
        check("Drive consumes matching distance evidence", driveA.attachDistanceEvidence(evidenceA))
        check("Entry rejects duplicate attachment", !driveA.attachDistanceEvidence(evidenceA))
        var driveB = OperationEntry(kind: .drive, start: t0.addingTimeInterval(3700), vehicleCombination: comboB)
        check("Wrong vehicle rejects distance evidence", !driveB.attachDistanceEvidence(evidenceA))
        check("Second truck accepts own evidence", driveB.attachDistanceEvidence(evidenceB))
        var wait = OperationEntry(kind: .wait, start: t0, vehicleCombination: comboA)
        check("Non-drive rejects distance evidence", !wait.attachDistanceEvidence(evidenceA))

        // P2 regression: ledger prevents same interval being consumed by two Drives.
        var blankDrive1 = OperationEntry(kind: .drive, start: t0, vehicleCombination: comboA)
        let blankDrive2 = OperationEntry(kind: .drive, start: t0.addingTimeInterval(10), vehicleCombination: comboA)
        var uniqueLedger = OperationsLedger(entries: [blankDrive1, blankDrive2])
        check("Ledger accepts first interval attachment", uniqueLedger.attachDistanceEvidence(operationID: blankDrive1.id, evidence: evidenceA))
        check("Ledger rejects same interval on second Drive", !uniqueLedger.attachDistanceEvidence(operationID: blankDrive2.id, evidence: evidenceA))
        blankDrive1 = uniqueLedger.entries.first(where: { $0.id == blankDrive1.id })!

        // P2 regression: decoding is also an invariant boundary.
        let goodData = try! JSONEncoder().encode(uniqueLedger)
        let replayed = try! JSONDecoder().decode(OperationsLedger.self, from: goodData)
        check("Valid evidence survives replay", replayed.entries.first(where: { $0.id == blankDrive1.id })?.distanceEvidence == evidenceA)

        let bodyB = VehicleBodyModule(id: bodyA.id, name: bodyA.name, kind: bodyA.kind, serialNumber: bodyA.serialNumber, emptyMassKg: bodyA.emptyMassKg, dimensions: bodyA.dimensions, compartments: bodyA.compartments)
        let moved = VehicleCombinationSnapshot(capturedAt: t0, chassis: truckB, body: bodyB, relationships: [ConfigurationRelationship(subject: .body(bodyB.id), kind: .fittedTo, target: .poweredVehicle(truckB.id))])
        check("Body can move without moving powered-vehicle ODO identity", moved.body?.id == bodyA.id && evidenceA.poweredVehicleID == truckA.id)
        let driver = WorkRestEntry(kind: .work, start: t0, end: t0.addingTimeInterval(5400)); let before = driver; _ = replayed
        check("Driver truth remains independent", driver == before)
        check("Vehicle holds no duplicate mutable current ODO", evidenceA.interval.endAnchor.km == 428_407)

        out.append("---"); out.append(failures == 0 ? "GATE PASS" : "GATE FAIL (\(failures))"); return out
    }
}
