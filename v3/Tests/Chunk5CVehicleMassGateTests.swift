import Foundation

public enum Chunk5CVehicleMassGateTests {
    public static func run() -> [String] {
        var results: [String] = []
        func check(_ name: String, _ body: () throws -> Bool) {
            do { results.append("\(try body() ? "PASS" : "FAIL") — \(name)") }
            catch { results.append("FAIL — \(name): \(error)") }
        }

        let c1 = CanonicalID.fresh()
        let c3 = CanonicalID.fresh()
        let c4 = CanonicalID.fresh()
        let c5 = CanonicalID.fresh()
        let chassis = VehicleChassis(name: "Fixture vehicle", baseEmptyMassKg: 14_520, grossVehicleMassLimitKg: 31_000)
        let body = VehicleBodyModule(name: "Tank", kind: .tank, compartments: [
            VehicleCompartment(id: c1, name: "C1", capacityLitres: 5_360),
            VehicleCompartment(id: c3, name: "C3", capacityLitres: 4_900),
            VehicleCompartment(id: c4, name: "C4", capacityLitres: 3_250),
            VehicleCompartment(id: c5, name: "C5", capacityLitres: 7_240)
        ])
        let vehicle = VehicleCombinationSnapshot(chassis: chassis, body: body)

        check("unloaded configured vehicle projects tare") {
            let p = VehicleMassProjector.project(vehicle: vehicle, transportedMass: [])
            return p.tareKg == 14_520 && p.transportedMassKg == 0 && p.grossMassKg == 14_520
        }

        check("generic transported mass increases gross without mutating tare") {
            let p = VehicleMassProjector.project(vehicle: vehicle, transportedMass: [TransportedCompartmentMass(compartmentID: c1, massKg: 4_188)])
            return p.tareKg == 14_520 && p.transportedMassKg == 4_188 && p.grossMassKg == 18_708 && vehicle.authoritativeTareKg == 14_520
        }

        check("unload is reflected by lower current transported projection") {
            let before = VehicleMassProjector.project(vehicle: vehicle, transportedMass: [TransportedCompartmentMass(compartmentID: c1, massKg: 4_188)])
            let after = VehicleMassProjector.project(vehicle: vehicle, transportedMass: [TransportedCompartmentMass(compartmentID: c1, massKg: 3_000)])
            return before.grossMassKg == 18_708 && after.grossMassKg == 17_520
        }

        check("missing distribution geometry is explicitly unavailable") {
            let p = VehicleMassProjector.project(vehicle: vehicle, transportedMass: [TransportedCompartmentMass(compartmentID: c1, massKg: 100)])
            return p.axleProjection == .unavailable(.missingGeometry)
        }

        check("configuration-mismatched axle tare is rejected") {
            let geometry = VehicleLongitudinalGeometry(frontGroupPositionMetres: 0, rearGroupPositionMetres: 6, compartmentPositionsMetres: [c1: 1])
            let wrongTare = VehicleAxleTareEvidence(configurationFingerprint: "other", frontGroupMassKg: 7_460, rearGroupMassKg: 7_060)
            let p = VehicleMassProjector.project(vehicle: vehicle, transportedMass: [TransportedCompartmentMass(compartmentID: c1, massKg: 100)], geometry: geometry, axleTare: wrongTare)
            return p.axleProjection == .unavailable(.tareConfigurationMismatch)
        }

        check("known geometry derives two-support reactions without fuel semantics") {
            let geometry = VehicleLongitudinalGeometry(frontGroupPositionMetres: 0, rearGroupPositionMetres: 10, compartmentPositionsMetres: [c1: 2])
            let tare = VehicleAxleTareEvidence(configurationFingerprint: vehicle.configurationFingerprint, frontGroupMassKg: 7_460, rearGroupMassKg: 7_060)
            let p = VehicleMassProjector.project(vehicle: vehicle, transportedMass: [TransportedCompartmentMass(compartmentID: c1, massKg: 1_000)], geometry: geometry, axleTare: tare)
            guard case .available(let axle) = p.axleProjection else { return false }
            return axle.frontGroupMassKg == 8_260 && axle.rearGroupMassKg == 7_260
        }

        // Truck 92 July 2026 mass reconciliation fixture. This deliberately tests mass only.
        // The tare weigh was lazy UP and gross weigh was lazy DOWN, so those axle deltas are
        // not accepted as pure cargo reactions and are not used to tune geometry.
        check("Truck 92 July supplier mass independently reconciles weighbridge net") {
            let supplierMassKg = 16_083.0
            let weighbridgeNetKg = 16_040.0
            let difference = abs(supplierMassKg - weighbridgeNetKg)
            return difference == 43 && difference / supplierMassKg < 0.003
        }

        check("Truck 92 July compartment evidence sums without correcting source rounding") {
            let roundedCompartmentMasses = [4_188.0, 3_516.0, 2_518.0, 5_862.0]
            return roundedCompartmentMasses.reduce(0, +) == 16_084
        }

        check("Truck 92 ambiguous axle datum stays unavailable rather than guessed") {
            let julyMass = [
                TransportedCompartmentMass(compartmentID: c1, massKg: 4_188),
                TransportedCompartmentMass(compartmentID: c3, massKg: 3_516),
                TransportedCompartmentMass(compartmentID: c4, massKg: 2_518),
                TransportedCompartmentMass(compartmentID: c5, massKg: 5_862)
            ]
            let p = VehicleMassProjector.project(vehicle: vehicle, transportedMass: julyMass)
            return p.transportedMassKg == 16_084 && p.axleProjection == .unavailable(.missingGeometry)
        }

        return results
    }
}