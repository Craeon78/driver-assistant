
import Foundation

  

// © 2026 Cory Russell Olsen. All rights reserved.

//======================================

// MARK: - Product (Unified)

//======================================

//

// Goal:

// - One Product model across disciplines.

// - Fuel fields supported (UN / Hazchem / SG range).

// - Other disciplines can ignore fuel fields safely.

// - Persist `code` as the stable foreign key.

// - `id` is runtime-only (do NOT persist across runs later).

//

// Back-compat:

// - Provides `shortName`, `defaultSg`, `sgMin`, `sgMax`, `un`, `hazchem`

//   so existing code keeps compiling.

//

//======================================

  

struct Product: Codable, Identifiable, Hashable {

    let id: UUID

    // Stable foreign key (persist this)

    var code: String          // e.g. "P91", "DSL"

    var name: String          // e.g. "ULP 91", "Diesel"

    // Optional general fields (multi-discipline friendly)

    var description: String? = nil

    var densityKgPerLitre: Double? = nil

    var dgClass: String? = nil

    // ==============================

    // Fuel / DG fields (optional)

    // ==============================

    /// UN number (fuel: e.g. 1203 for petrol). nil if unknown / not relevant.

    var unNumber: Int? = nil

    /// Hazchem (fuel: e.g. "3YE"). nil if unknown / not relevant.

    var hazchemCode: String? = nil

    /// Specific gravity range + default. nil if unknown / not relevant.

    var sgMinValue: Double? = nil

    var sgMaxValue: Double? = nil

    var defaultSgValue: Double? = nil

    init(

        id: UUID = UUID(),

        code: String,

        name: String,

        description: String? = nil,

        densityKgPerLitre: Double? = nil,

        dgClass: String? = nil,

        unNumber: Int? = nil,

        hazchemCode: String? = nil,

        sgMinValue: Double? = nil,

        sgMaxValue: Double? = nil,

        defaultSgValue: Double? = nil

    ) {

        self.id = id

        self.code = code

        self.name = name

        self.description = description

        self.densityKgPerLitre = densityKgPerLitre

        self.dgClass = dgClass

        self.unNumber = unNumber

        self.hazchemCode = hazchemCode

        self.sgMinValue = sgMinValue

        self.sgMaxValue = sgMaxValue

        self.defaultSgValue = defaultSgValue

    }

}

  

//======================================

// MARK: - Back-compat shims

//======================================

//

// These keep your existing app compiling while you migrate views/logic.

// Eventually you can delete these and update call sites to use the new names.

//======================================

  

extension Product {

    /// Old name used by LoadPlan UI etc.

    var shortName: String { code }

    /// Old names used by SG sliders / mass sim

    var sgMin: Double { sgMinValue ?? 0.0 }

    var sgMax: Double { sgMaxValue ?? 1.0 }

    var defaultSg: Double { defaultSgValue ?? (densityKgPerLitre ?? 0.0) } // fallback if you ever set density

    /// Old names used by DG logic

    var un: Int { unNumber ?? 0 }

    var hazchem: String { hazchemCode ?? "— —" }

    /// Convenience: do we have a real SG range?

    var hasSgRange: Bool {

        guard let a = sgMinValue, let b = sgMaxValue else { return false }

        return a > 0 && b > 0 && a <= b

    }

}
