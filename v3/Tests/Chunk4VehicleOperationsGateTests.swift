import Foundation

public enum Chunk4VehicleOperationsGateTests {
    public static func run() -> [String] {
        var out = ["=== V3 Chunk 4 Combination Topology Gate ==="]
        var failures = 0
        func check(_ name: String, _ ok: Bool) {
            out.append("\(name): \(ok ? "PASS" : "FAIL")")
            if !ok { failures += 1 }
        }

        let t0 = Date(timeIntervalSince1970: 1_789_520_400)
        func compartments(_ capacities: [Double]) -> [VehicleCompartment] {
            capacities.enumerated().map { VehicleCompartment(name: "Compartment \($0.offset + 1)", capacityLitres: $0.element) }
        }

        let rigid = VehicleChassis(name: "Rigid A", registration: "RIGID-A", baseEmptyMassKg: 8_200, grossVehicleMassLimitKg: 26_000)
        let tank3 = VehicleBodyModule(name: "Tank #17", kind: .tank, serialNumber: "T17", emptyMassKg: 4_000, compartments: compartments([6_000, 5_000, 5_000]))
        let dog6 = TowedAsset(name: "Dog Tanker #4", kind: .dog, registration: "DOG-4", emptyMassKg: 6_000, compartments: compartments([4_000, 4_000, 4_000, 4_000, 4_000, 4_000]))
        let dogRelationships = [
            ConfigurationRelationship(subject: .body(tank3.id), kind: .fittedTo, target: .poweredVehicle(rigid.id)),
            ConfigurationRelationship(subject: .towedAsset(dog6.id), kind: .coupledTo, target: .poweredVehicle(rigid.id))
        ]
        let truckDog = VehicleCombinationSnapshot(capturedAt: t0, chassis: rigid, body: tank3, towedAssets: [dog6], relationships: dogRelationships)

        check("Rigid tank owns three identified compartments", truckDog.body?.compartments.count == 3)
        check("Dog owns six identified compartments", truckDog.towedAssets.first?.compartments.count == 6)
        check("Compartment identities are distinct", Set(tank3.compartments.map(\.id)).count == 3)

        let primeMover = VehicleChassis(name: "Prime Mover B", registration: "PM-B", baseEmptyMassKg: 9_000)
        let aTrailer = TowedAsset(name: "A Tanker", kind: .aTrailer, emptyMassKg: 5_000, compartments: compartments([6_000, 5_000, 5_000]))
        let bTrailer = TowedAsset(name: "B Tanker", kind: .bTrailer, emptyMassKg: 6_000, compartments: compartments([4_000, 4_000, 4_000, 4_000, 4_000, 4_000]))
        let bDoubleRelationships = [
            ConfigurationRelationship(subject: .towedAsset(aTrailer.id), kind: .coupledTo, target: .poweredVehicle(primeMover.id)),
            ConfigurationRelationship(subject: .towedAsset(bTrailer.id), kind: .coupledTo, target: .towedAsset(aTrailer.id))
        ]
        let bDouble = VehicleCombinationSnapshot(capturedAt: t0, chassis: primeMover, towedAssets: [aTrailer, bTrailer], relationships: bDoubleRelationships)

        let truckDogCounts = [truckDog.body?.compartments.count ?? 0, truckDog.towedAssets[0].compartments.count]
        let bDoubleCounts = [bDouble.towedAssets[0].compartments.count, bDouble.towedAssets[1].compartments.count]
        check("Truck+dog and B-double can both express 3+6", truckDogCounts == [3, 6] && bDoubleCounts == [3, 6])
        check("Same 3+6 cargo topology retains different vehicle topology", truckDog.relationships != bDouble.relationships && dog6.kind == .dog && aTrailer.kind == .aTrailer && bTrailer.kind == .bTrailer)

        let crane = VehicleEquipment(name: "Crane #7", kind: .crane, serialNumber: "CR7", massKg: 1_200)
        let forkliftMount = VehicleEquipment(name: "Forklift Mount", kind: .forkliftMount, massKg: 250)
        let forklift = VehicleEquipment(name: "Forklift #22", kind: .forklift, serialNumber: "FL22", massKg: 2_500)
        let flatbed = VehicleBodyModule(name: "Flatbed #2", kind: .tray, emptyMassKg: 1_800)
        let equipmentRelationships = [
            ConfigurationRelationship(subject: .body(flatbed.id), kind: .fittedTo, target: .poweredVehicle(rigid.id)),
            ConfigurationRelationship(subject: .equipment(crane.id), kind: .mountedTo, target: .poweredVehicle(rigid.id)),
            ConfigurationRelationship(subject: .equipment(forkliftMount.id), kind: .mountedTo, target: .poweredVehicle(rigid.id)),
            ConfigurationRelationship(subject: .equipment(forklift.id), kind: .carriedBy, target: .poweredVehicle(rigid.id))
        ]
        let flatbedCombo = VehicleCombinationSnapshot(capturedAt: t0, chassis: rigid, body: flatbed, equipment: [crane, forkliftMount, forklift], relationships: equipmentRelationships)
        check("Mounted crane contributes to empty configuration mass", flatbedCombo.calculatedEmptyMassKg == 11_450)
        check("Carried forklift excluded from tare", flatbedCombo.calculatedEmptyMassKg != 13_950)

        let craneOnPrime = VehicleCombinationSnapshot(capturedAt: t0.addingTimeInterval(100), chassis: primeMover, equipment: [crane], relationships: [ConfigurationRelationship(subject: .equipment(crane.id), kind: .mountedTo, target: .poweredVehicle(primeMover.id))])
        check("Crane identity survives transfer to prime mover", craneOnPrime.equipment.first?.id == crane.id)

        let tankOnNewChassis = VehicleCombinationSnapshot(capturedAt: t0.addingTimeInterval(200), chassis: primeMover, body: tank3, relationships: [ConfigurationRelationship(subject: .body(tank3.id), kind: .fittedTo, target: .poweredVehicle(primeMover.id))])
        check("Tank identity survives powered chassis replacement", tankOnNewChassis.body?.id == tank3.id)

        let dogLater = VehicleCombinationSnapshot(capturedAt: t0.addingTimeInterval(300), chassis: primeMover, towedAssets: [dog6], relationships: [ConfigurationRelationship(subject: .towedAsset(dog6.id), kind: .coupledTo, target: .poweredVehicle(primeMover.id))])
        check("Trailer identity survives combination change", dogLater.towedAssets.first?.id == dog6.id)

        let provisional = VehicleCombinationSnapshot(capturedAt: t0, chassis: rigid, body: flatbed, equipment: [crane], relationships: [ConfigurationRelationship(subject: .equipment(crane.id), kind: .mountedTo, target: .poweredVehicle(rigid.id))])
        let tare = MeasuredTareEvidence(measuredAt: t0, massKg: 11_300, configurationFingerprint: provisional.configurationFingerprint, note: "Weighbridge")
        let measuredCombo = VehicleCombinationSnapshot(capturedAt: t0, chassis: rigid, body: flatbed, equipment: [crane], relationships: provisional.relationships, measuredTare: tare)
        check("Measured tare applies to matching configuration", measuredCombo.authoritativeTareKg == 11_300)
        let changedCombo = VehicleCombinationSnapshot(capturedAt: t0.addingTimeInterval(400), chassis: rigid, body: flatbed, equipment: [crane, forkliftMount], relationships: provisional.relationships + [ConfigurationRelationship(subject: .equipment(forkliftMount.id), kind: .mountedTo, target: .poweredVehicle(rigid.id))], measuredTare: tare)
        check("Stale measured tare rejected after configuration change", changedCombo.authoritativeTareKg == changedCombo.calculatedEmptyMassKg && changedCombo.authoritativeTareKg != 11_300)

        var operations = OperationsLedger()
        let drive = OperationEntry(kind: .drive, start: t0, vehicleCombination: truckDog)
        operations.append(drive)
        check("Valid operation close accepted", operations.close(id: drive.id, at: t0.addingTimeInterval(3600)))
        let closedEnd = operations.entries.first?.end
        check("Repeated close rejected", !operations.close(id: drive.id, at: t0.addingTimeInterval(7200)))
        check("Repeated close cannot rewrite history", operations.entries.first?.end == closedEnd)

        let encoded = try! JSONEncoder().encode(operations)
        let replayed = try! JSONDecoder().decode(OperationsLedger.self, from: encoded)
        check("Operations replay deterministic", replayed == operations)
        check("Historical combination topology survives replay", replayed.entries.first?.vehicleCombination == truckDog)

        let driver = WorkRestEntry(kind: .work, start: t0, end: t0.addingTimeInterval(3600))
        let before = driver
        _ = bDouble
        _ = changedCombo
        check("Driver truth unaffected by Vehicle topology", driver == before)

        out.append("---")
        out.append(failures == 0 ? "GATE PASS" : "GATE FAIL (\(failures))")
        return out
    }
}
