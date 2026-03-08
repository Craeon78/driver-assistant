
import Foundation

// © 2026 Cory Russell Olsen. All rights reserved.

// This application and its contents are proprietary and confidential.

//======================================

// MARK: - DGPlacardLogic

//======================================

//

// MARK: - DG Placard Decision (v0.2 groundwork)

//

// Intent:

// - Decide what placard the truck should display based on compartment states.

// - "0 litres" may still count as product (vapour/residue) IF prior DG history exists.

// - Absence of history is represented as `.unknown` (do not invent residue).

// - Diesel-only => Combustible Liquid (no UN 1202 shown in AU road transport practice).

// - ULP-only (91/95/98) => UN 1203 PETROL

// - Any mix of ULP + Diesel anywhere in comps (including vapour/residue) => UN 1270 PETROLEUM FUEL

// - Degassed empty => top half blank (rare event)

  

enum DGProductFamily: String, Codable, CaseIterable {

    case ulp       // petrol family: 91/95/98 etc

    case diesel    // diesel family

    case other     // future: avgas, ethanol blends, etc

}

  

/// How a compartment should be treated for DG purposes.

/// This is intentionally not "litres only".

enum DGCompartmentState: Codable, Equatable {

    /// Comp has product in it (non-zero load).

    case loaded(family: DGProductFamily, litres: Int)

    /// Comp is "0 litres" but not degassed, and the last known product matters.

    /// This is where vapour/residue counts as product for placarding.

    case residueOrVapour(family: DGProductFamily)

    /// Comp has been degassed/cleared for maintenance/repairs (true blank).

    case degassedEmpty

    /// Nothing known (avoid inventing history). Treat as unknown, not as a product.

    case unknown

}

  

/// What the app will render.

enum DGPlacardDecision: Codable, Equatable {

    case petrol1203(hazchem: String)          // PETROL / UN 1203 / 3YE

    case petroleumFuel1270(hazchem: String)   // PETROLEUM FUEL / UN 1270 / 3YE

    case combustibleLiquid                    // COMBUSTIBLE LIQUID (no UN shown)

    case blankTopHalf                         // degassed truck (all compartments degassed)

    case blankUnknown                         // unknown or insufficient evidence (render as blank, no placard)

}

  

/// The classifier. Keep pure + deterministic.

struct DGPlacardLogic {

    struct Inputs {

        var compartments: [DGCompartmentState]

        /// Default hazchem for Class 3 petrol/petroleum fuel in your fleet.

        /// Keep it injectable for future products.

        var defaultHazchem: String = "3YE"

    }

    static func decide(_ input: Inputs) -> DGPlacardDecision {

        let comps = input.compartments

        // 1) Degassed check: ONLY if *every* compartment is degassedEmpty.

        // (If any comp is not degassed, we do not show blank top.)

        if !comps.isEmpty, comps.allSatisfy({ $0 == .degassedEmpty }) {

            return .blankTopHalf

        }

        // 2) Determine if ULP and/or Diesel exist anywhere (including residue/vapour).

        var hasULP = false

        var hasDiesel = false

        for c in comps {

            switch c {

            case .loaded(let family, _),

                    .residueOrVapour(let family):

                if family == .ulp { hasULP = true }

                if family == .diesel { hasDiesel = true }

            case .degassedEmpty, .unknown:

                continue

            }

        }

        // 3) Decision rules (your Brisbane tunnel reality):

        // - Mix => 1270

        // - ULP only => 1203

        // - Diesel only => Combustible Liquid (no UN 1202 on placard for AU road transport)

        // - Nothing known => blank / unknown.

        //   We deliberately avoid inventing a DG state when history is missing or corrupted.

        if hasULP && hasDiesel {

            return .petroleumFuel1270(hazchem: input.defaultHazchem)

        } else if hasULP {

            return .petrol1203(hazchem: input.defaultHazchem)

        } else if hasDiesel {

            return .combustibleLiquid

        } else {

            return .blankUnknown

        }

    }

}
