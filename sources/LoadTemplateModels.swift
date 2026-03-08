
import Foundation

  

//======================================

// MARK: - Load Template Models

//======================================

//

// Intent:

// - A LoadTemplate is a reusable preset you can apply to the live Load Plan.

// - Pre-persistence: templates live in memory (and can be stored later).

// - Post-persistence: templates become user data and may need migration.

//

// Design note:

// - `items` is an Array (not a Dictionary) to allow future extensions like:

//   - multi-drop sequencing

//   - multiple products per compartment over time

//   - metadata per row (e.g. priority, delivery order, notes)

// - In Phase 1/2 UI we treat it as "one row per compartment" (C1...C5).

//

// Template vs Load Plan distinction:

// - Template = reusable pattern (saved, shareable, non-authoritative)

// - Load Plan (in AppModel) = current draft (volatile until confirmed)

// - Confirmed Load (in confirmedLoads) = authoritative snapshot

//

//======================================

  

/// A reusable preset you can apply to the live Load Plan.

struct LoadTemplate: Identifiable, Codable, Hashable {

    let id: UUID

    var name: String

    var createdAt: Date

    /// Template rows.

    /// Phase 1/2 expectation: one row per compartment name ("C1"..."C5").

    /// Future: may contain multiple rows per compartment for sequencing.

    var items: [LoadTemplateItem]

    /// Optional notes / tags for later (e.g. "Metro", "Heavy steer", etc.)

    var notes: String?

    init(

        id: UUID = UUID(),

        name: String,

        createdAt: Date = Date(),

        items: [LoadTemplateItem],

        notes: String? = nil

    ) {

        self.id = id

        self.name = name

        self.createdAt = createdAt

        self.items = items

        self.notes = notes

    }

}

  

/// One “row” in a template.

/// In Phase 1/2 this represents a single compartment fill.

/// Future: could represent a step in a sequence (partial unload/reload patterns).

struct LoadTemplateItem: Identifiable, Codable, Hashable {

    let id: UUID

    /// Compartment identifier, e.g. "C1".

    var compartmentName: String

    /// Product identifier using the fleet short code, e.g. "P91", "DSL".

    /// (Resolution into a full Product happens in model logic.)

    var productShortName: String

    /// Litres for this row. Phase 1/2: intended to be >= 0.

    var litres: Int

    /// Optional per-template SG override (overrides product.defaultSg for simulation).

    var sgOverride: Double?

    init(

        id: UUID = UUID(),

        compartmentName: String,

        productShortName: String,

        litres: Int,

        sgOverride: Double? = nil

    ) {

        self.id = id

        self.compartmentName = compartmentName

        self.productShortName = productShortName

        self.litres = litres

        self.sgOverride = sgOverride

    }

}
