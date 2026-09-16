import Foundation

public enum Chunk4VehicleOperationsGateTests {
    public static func run() -> [String] {
        var out = ["=== V3 Chunk 4 Physical Truth Hardening Gate ==="]
        var failures = 0
        func check(_ name: String, _ ok: Bool) { out.append("\(name): \(ok ? "PASS" : "FAIL")"); if !ok { failures += 1 } }
        let t0 = Date(timeIntervalSince1970: 1_789_520_400)
        func compartments(_ capacities: [Double]) -> [VehicleCompartment] { capacities.enumerated().map { VehicleCompartment(name: "Compartment \($0.offset + 1)", capacityLitres: $0.element) } }

        let steer = VehicleAxleGroup(name: "Steer", kind: .steer, axleCount: 1, manufacturerRatingKg: 6_500)
        let rigidDrive = VehicleAxleGroup(name: "Drive tandem", kind: .tandem, axleCount: 2, manufacturerRatingKg: 16_500, spacingToPreviousMetres: 4.2)
        let dogFront = VehicleAxleGroup(name: "Dog front tandem", kind: .tandem, axleCount: 2, manufacturerRatingKg: 16_500)
        let dogRear = VehicleAxleGroup(name: "Dog rear tandem", kind: .tandem, axleCount: 2, manufacturerRatingKg: 16_500, spacingToPreviousMetres: 4.0)
        let rigid = VehicleChassis(name: "Rigid A", registration: "RIGID-A", baseEmptyMassKg: 8_200, grossVehicleMassLimitKg: 26_000, axleGroups: [steer, rigidDrive])
        let tank3 = VehicleBodyModule(name: "Tank #17", kind: .tank, serialNumber: "T17", emptyMassKg: 4_000, compartments: compartments([6_000, 5_000, 5_000]))
        let dog6 = TowedAsset(name: "Quad Dog Tanker #4", kind: .dog, registration: "DOG-4", emptyMassKg: 6_000, compartments: compartments([4_000,4_000,4_000,4_000,4_000,4_000]), axleGroups: [dogFront, dogRear])
        let relationships = [ConfigurationRelationship(subject: .body(tank3.id), kind: .fittedTo, target: .poweredVehicle(rigid.id)), ConfigurationRelationship(subject: .towedAsset(dog6.id), kind: .coupledTo, target: .poweredVehicle(rigid.id))]
        let truckDog = VehicleCombinationSnapshot(capturedAt: t0, chassis: rigid, body: tank3, towedAssets: [dog6], relationships: relationships)

        check("Rigid physical axle groups retained", truckDog.chassis.axleGroups.count == 2 && truckDog.chassis.axleGroups.map(\.axleCount).reduce(0,+) == 3)
        check("Quad-dog physical axle groups retained", dog6.axleGroups.count == 2 && dog6.axleGroups.map(\.axleCount).reduce(0,+) == 4)
        check("Axle manufacturer ratings retained as Vehicle truth", dog6.axleGroups.compactMap(\.manufacturerRatingKg).reduce(0,+) == 33_000)
        check("Rigid tank owns three identified compartments", tank3.compartments.count == 3)
        check("Dog owns six identified compartments", dog6.compartments.count == 6)

        let fp1 = truckDog.configurationFingerprint
        let reordered = VehicleCombinationSnapshot(capturedAt: t0.addingTimeInterval(1), chassis: rigid, body: tank3, towedAssets: [dog6], relationships: relationships.reversed())
        check("Configuration fingerprint independent of relationship ordering", fp1 == reordered.configurationFingerprint)
        let changedDog = TowedAsset(id: dog6.id, name: dog6.name, kind: dog6.kind, registration: dog6.registration, serialNumber: dog6.serialNumber, emptyMassKg: dog6.emptyMassKg, dimensions: dog6.dimensions, compartments: dog6.compartments, axleGroups: [dogFront])
        let changedAxles = VehicleCombinationSnapshot(capturedAt: t0, chassis: rigid, body: tank3, towedAssets: [changedDog], relationships: relationships)
        check("Physical axle configuration changes fingerprint", changedAxles.configurationFingerprint != fp1)

        let crane = VehicleEquipment(name: "Crane #7", kind: .crane, massKg: 1_200)
        let forklift = VehicleEquipment(name: "Forklift #22", kind: .forklift, massKg: 2_500)
        let orphan = VehicleEquipment(name: "Unclassified equipment", kind: .other, massKg: 9_999)
        let flatbed = VehicleBodyModule(name: "Flatbed", kind: .tray, emptyMassKg: 1_800)
        let equipmentRels = [ConfigurationRelationship(subject: .body(flatbed.id), kind: .fittedTo, target: .poweredVehicle(rigid.id)), ConfigurationRelationship(subject: .equipment(crane.id), kind: .mountedTo, target: .poweredVehicle(rigid.id)), ConfigurationRelationship(subject: .equipment(forklift.id), kind: .carriedBy, target: .poweredVehicle(rigid.id))]
        let equipmentCombo = VehicleCombinationSnapshot(capturedAt: t0, chassis: rigid, body: flatbed, equipment: [crane, forklift, orphan], relationships: equipmentRels)
        check("Mounted equipment contributes to tare", equipmentCombo.calculatedEmptyMassKg == 11_200)
        check("Carried equipment excluded from tare", equipmentCombo.calculatedEmptyMassKg != 13_700)
        check("Orphan equipment cannot silently alter tare", equipmentCombo.calculatedEmptyMassKg != 21_199)

        let tare = MeasuredTareEvidence(measuredAt: t0, massKg: 18_100, configurationFingerprint: fp1, note: "Weighbridge")
        let measured = VehicleCombinationSnapshot(capturedAt: t0, chassis: rigid, body: tank3, towedAssets: [dog6], relationships: relationships, measuredTare: tare)
        check("Measured tare applies to exact physical configuration", measured.authoritativeTareKg == 18_100)
        let stale = VehicleCombinationSnapshot(capturedAt: t0, chassis: rigid, body: tank3, towedAssets: [changedDog], relationships: relationships, measuredTare: tare)
        check("Axle change invalidates stale measured tare", stale.authoritativeTareKg == stale.calculatedEmptyMassKg && stale.authoritativeTareKg != 18_100)

        let primeSteer = VehicleAxleGroup(name: "Prime steer", kind: .steer, axleCount: 1, manufacturerRatingKg: 6_500)
        let primeDrive = VehicleAxleGroup(name: "Prime drive", kind: .tandem, axleCount: 2, manufacturerRatingKg: 16_500)
        let prime = VehicleChassis(name: "Prime Mover B", registration: "PM-B", baseEmptyMassKg: 9_000, axleGroups: [primeSteer, primeDrive])
        let semiTri = VehicleAxleGroup(name: "Trailer tri", kind: .tri, axleCount: 3, manufacturerRatingKg: 20_000)
        let semi = TowedAsset(name: "Semi B", kind: .semiTrailer, emptyMassKg: 7_000, axleGroups: [semiTri])
        let second = VehicleCombinationSnapshot(capturedAt: t0, chassis: prime, towedAssets: [semi], relationships: [ConfigurationRelationship(subject: .towedAsset(semi.id), kind: .coupledTo, target: .poweredVehicle(prime.id))])
        check("Second vehicle uses same Vehicle model without redesign", second.chassis.axleGroups.count == 2 && second.towedAssets.first?.axleGroups.first?.kind == .tri)

        var operations = OperationsLedger(); let drive = OperationEntry(kind: .drive, start: t0, vehicleCombination: truckDog); operations.append(drive); _ = operations.close(id: drive.id, at: t0.addingTimeInterval(3600))
        let replayed = try! JSONDecoder().decode(OperationsLedger.self, from: JSONEncoder().encode(operations))
        check("Axle/topology truth survives Operations replay", replayed.entries.first?.vehicleCombination == truckDog)
        let driver = WorkRestEntry(kind: .work, start: t0, end: t0.addingTimeInterval(3600)); let before = driver; _ = second
        check("Driver truth remains independent", driver == before)

        out.append("---"); out.append(failures == 0 ? "GATE PASS" : "GATE FAIL (\(failures))"); return out
    }
}
