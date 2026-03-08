
import Foundation

  

//======================================

// MARK: - Mass Simulation (draft / what-if)

//======================================

//

// Intent (Phase 1 / pre-persistence):

// - Run a deterministic "what-if" mass + axle load estimate for a LoadTemplate.

// - Uses SG override per template item if provided, otherwise product.defaultSg.

// - Starts from truck tare weights, then adds each compartment's mass via axle split.

// - Ignores template lines with unknown products (fails safe).

//

// Notes for reviewers:

// - This is a PURE calculation (no AppModel state, no side effects).

// - Axle split fractions may be negative or > 1.0 (rear-heavy comps can unload steer).

// - Litres are clamped at >= 0 (negative inputs are treated as 0).

  

enum MassSimulationLogic {

    static func simulate(

        template: LoadTemplate,

        products: [Product],

        truck: TruckConfig

    ) -> MassSimulationResult {

        // Local lookup helper (case-insensitive short name).

        func product(for short: String) -> Product? {

            products.first { $0.shortName.uppercased() == short.uppercased() }

        }

        var totalLitres = 0

        var totalMass: Double = 0

        // Start with tare (empty truck).

        var steer = truck.tareSteerKg

        var drive = truck.tareDriveKg

        // Apply each template item as a draft load.

        for item in template.items {

            guard let prod = product(for: item.productShortName) else { continue }

            let litres = max(item.litres, 0)

            let sg = item.sgOverride ?? prod.defaultSg

            let mass = Double(litres) * sg

            totalLitres += litres

            totalMass += mass

            // If we have a known axle split for this compartment, apply it.

            if let split = truck.axleSplitByCompartment[item.compartmentName] {

                steer += mass * split.steerFraction

                drive += mass * split.driveFraction

            }

        }

        let gvm = steer + drive

        // Human-readable over-limit message (nil if within limits).

        let warning: String? = {

            var msgs: [String] = []

            if steer > truck.maxSteerKg {

                msgs.append("Steer axle is OVER by \(Int(steer - truck.maxSteerKg)) kg")

            }

            if drive > truck.maxDriveKg {

                msgs.append("Drive axle is OVER by \(Int(drive - truck.maxDriveKg)) kg")

            }

            if gvm > truck.maxGvmKg {

                msgs.append("GVM is OVER by \(Int(gvm - truck.maxGvmKg)) kg")

            }

            return msgs.isEmpty ? nil : msgs.joined(separator: " • ")

        }()

        return MassSimulationResult(

            totalLitres: totalLitres,

            totalMassKg: totalMass,

            steerKg: steer,

            driveKg: drive,

            gvmKg: gvm,

            maxSteerKg: truck.maxSteerKg,

            maxDriveKg: truck.maxDriveKg,

            maxGvmKg: truck.maxGvmKg,

            steerHeadroom: truck.maxSteerKg - steer,

            driveHeadroom: truck.maxDriveKg - drive,

            gvmHeadroom: truck.maxGvmKg - gvm,

            warning: warning

        )

    }

}
