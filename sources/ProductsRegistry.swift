
// File: Models/Assets/ProductRegistry.swift

import Foundation

  

// © 2026 Cory Russell Olsen. All rights reserved.

//======================================

// MARK: - ProductRegistry

//======================================

//

// Purpose:

// - Aggregates products across multiple disciplines.

// - Provides:

//     • stable canonical list (for pickers)

//     • lookups by code/name

//

// Notes:

// - Phase 0/1: in-memory lists.

// - Phase 2+: swap in JSON-backed packs, but keep this API.

//======================================

  

enum ProductRegistry {

    /// All known products across all disciplines (merged).

    static var all: [Product] {

        FuelProducts.all

        // + RefrigeratedProducts.all

        // + LivestockProducts.all

        // + ContainersProducts.all

    }

    /// Convenience: by code (case-insensitive).

    static func byCode(_ code: String) -> Product? {

        let needle = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        return all.first { $0.code.uppercased() == needle }

    }

    /// Convenience: by name (loose match).

    static func byName(_ name: String) -> Product? {

        let needle = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return all.first { $0.name.lowercased() == needle }

    }

}
