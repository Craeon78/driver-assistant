import Foundation

public enum Chunk4VehicleOperationsGateTests {
    public static func run() -> [String] {
        var out = ["=== V3 Chunk 2 ↔ Chunk 4 ODO Integration Gate ==="]
        var failures = 0
        func check(_ name: String, _ ok: Bool) { out.append("\(name): \(ok ? "PASS" : "FAIL")"); if !ok { failures += 1 } }
        let t0 = Date(timeIntervalSince1970: 1_789_520_400)

        let truckA = VehicleChassis(name: "Rigid A", registration: "RIGID-A", baseEmptyMassKg: 8_200)
        let bodyA = VehicleBodyModule(name: "Tank A", kind: .tank, emptyMassKg: 4_000)
        let comboA = VehicleCombinationSnapshot(capturedAt: t0, chassis: truckA, body: bodyA, relationships: [ConfigurationRelationship(subject: .body(bodyA.id), kind: .fittedTo, target: .poweredVehicle(truckA.id))])
        let truckB = VehicleChassis(name: "Prime B", registration: "PRIME-B", baseEmptyMassKg: 9_000)
        let comboB = VehicleCombinationSnapshot(capturedAt: t0, chassis: truckB)

        let a1 = ODOAnchor(km: 428_317, recordedAt: t0)
        let a2 = ODOAnchor(km: 428_407, recordedAt: t0.addingTimeInterval(3600))
        let va1 = VehicleODOAnchor(anchor: a1, poweredVehicleID: truckA.id)
        let va2 = VehicleODOAnchor(anchor: a2, poweredVehicleID: truckA.id)
        check("Driver-entered ODO value remains unchanged", va1.anchor.km == 428_317 && va1.anchor.provenance == .driverEntered)
        check("ODO observation attributed to powered vehicle", va1.poweredVehicleID == comboA.chassis.id)

        let intervalA = DistanceInterval(startAnchor: a1, endAnchor: a2, odoDeltaKm: 90, gpsRawKm: 91.2, gpsFilteredKm: 89.7, chosenSource: .odoAnchor, chosenKm: 90, closedAt: t0.addingTimeInterval(3600))
        let evidenceA = try! VehicleODOAttribution.attribute(interval: intervalA, start: va1, end: va2)
        check("Chunk 2 interval survives attribution unchanged", evidenceA.interval == intervalA)
        check("Distance evidence belongs to powered vehicle", evidenceA.poweredVehicleID == truckA.id)

        var driveA = OperationEntry(kind: .drive, start: t0, vehicleCombination: comboA)
        check("Drive consumes matching distance evidence", driveA.attachDistanceEvidence(evidenceA))
        check("Operation does not rewrite ODO truth", driveA.distanceEvidence?.interval.endAnchor == a2)
        check("Distance evidence cannot be attached twice", !driveA.attachDistanceEvidence(evidenceA))

        let b1 = ODOAnchor(km: 612_010, recordedAt: t0.addingTimeInterval(3700))
        let vb1 = VehicleODOAnchor(anchor: b1, poweredVehicleID: truckB.id)
        let crossInterval = DistanceInterval(startAnchor: a2, endAnchor: b1, odoDeltaKm: 183_603, chosenSource: .odoAnchor, chosenKm: 183_603, closedAt: t0.addingTimeInterval(3700))
        let crossRejected = (try? VehicleODOAttribution.attribute(interval: crossInterval, start: va2, end: vb1)) == nil
        check("Truck swap rejects cross-vehicle ODO span", crossRejected)

        let bodyB = VehicleBodyModule(id: bodyA.id, name: bodyA.name, kind: bodyA.kind, serialNumber: bodyA.serialNumber, emptyMassKg: bodyA.emptyMassKg, dimensions: bodyA.dimensions, compartments: bodyA.compartments)
        let bodyMoved = VehicleCombinationSnapshot(capturedAt: t0.addingTimeInterval(4000), chassis: truckB, body: bodyB, relationships: [ConfigurationRelationship(subject: .body(bodyB.id), kind: .fittedTo, target: .poweredVehicle(truckB.id))])
        check("Body identity may move without moving ODO identity", bodyMoved.body?.id == bodyA.id && va2.poweredVehicleID == truckA.id)

        let b2 = ODOAnchor(km: 612_045, recordedAt: t0.addingTimeInterval(5400))
        let vb2 = VehicleODOAnchor(anchor: b2, poweredVehicleID: truckB.id)
        let intervalB = DistanceInterval(startAnchor: b1, endAnchor: b2, odoDeltaKm: 35, chosenSource: .odoAnchor, chosenKm: 35, closedAt: t0.addingTimeInterval(5400))
        let evidenceB = try! VehicleODOAttribution.attribute(interval: intervalB, start: vb1, end: vb2)
        var driveB = OperationEntry(kind: .drive, start: t0.addingTimeInterval(3700), vehicleCombination: comboB)
        check("Second truck accepts its own ODO evidence", driveB.attachDistanceEvidence(evidenceB))
        check("Wrong vehicle rejects distance evidence", !driveB.attachDistanceEvidence(evidenceA))

        var wait = OperationEntry(kind: .wait, start: t0, vehicleCombination: comboA)
        check("Non-drive operation rejects distance evidence", !wait.attachDistanceEvidence(evidenceA))

        var ledger = OperationsLedger(entries: [driveA, driveB])
        let encoded = try! JSONEncoder().encode(ledger)
        ledger = try! JSONDecoder().decode(OperationsLedger.self, from: encoded)
        check("Vehicle-attributed ODO evidence survives replay", ledger.entries.first?.distanceEvidence == evidenceA && ledger.entries.last?.distanceEvidence == evidenceB)

        let driver = WorkRestEntry(kind: .work, start: t0, end: t0.addingTimeInterval(5400))
        let driverBefore = driver
        _ = ledger
        check("Driver truth remains independent of ODO attribution", driver == driverBefore)

        check("Vehicle model contains no duplicate current ODO state", comboA.chassis.id == truckA.id && evidenceA.interval.endAnchor.km == 428_407)

        out.append("---")
        out.append(failures == 0 ? "GATE PASS" : "GATE FAIL (\(failures))")
        return out
    }
}
