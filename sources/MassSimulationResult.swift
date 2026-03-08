
import Foundation

  

//======================================

// MARK: - Mass Simulation Result

//======================================

//

// Intent:

// - Output payload from MassSimulationLogic.

// - View layer uses this to render totals, axle loads, headroom, and warnings.

// - All weights are kilograms (kg). Volumes are litres (L).

// - Headroom: positive = under limit, negative = over limit.

//

// Usage:

// - Simulation screen: shows what-if results for draft templates

// - Load screen (future): may show live axle estimates as driver edits

//

// Important:

// - This is a DERIVED result, never authoritative truth

// - Confirmed loads store their OWN mass snapshot (from confirmation time)

// - This struct is for planning/preview only

//

//======================================

  

struct MassSimulationResult: Hashable {

  

    // Totals

    var totalLitres: Int          // L

    var totalMassKg: Double       // kg (product mass only, excludes tare)

    // Loaded axle / vehicle weights (tare + product mass allocation)

    var steerKg: Double           // kg

    var driveKg: Double           // kg

    var gvmKg: Double             // kg (steer + drive)

    // Legal/target limits (so the view can show "current / max")

    var maxSteerKg: Double        // kg

    var maxDriveKg: Double        // kg

    var maxGvmKg: Double          // kg

    // Headroom (positive = under limit, negative = over)

    var steerHeadroom: Double     // kg

    var driveHeadroom: Double     // kg

    var gvmHeadroom: Double       // kg

    /// Human-readable summary when any limit is exceeded.

    /// Nil means "no issues detected".

    var warning: String?

}
