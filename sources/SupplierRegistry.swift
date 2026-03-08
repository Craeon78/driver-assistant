
// File: Models/Assets/SupplierRegistry.swift

import Foundation

  

// © 2026 Cory Russell Olsen. All rights reserved.

  

enum SupplierRegistry {

    static let bp = Supplier(

        id: UUID(uuidString: "2C9F7D27-3F80-4A0D-9E1D-2B7B4EAFB0A1")!,

        name: "BP"

    )

    static let mobil = Supplier(

        id: UUID(uuidString: "A6D8D8A0-2A7B-4F9E-9C64-65D83B5A8A11")!,

        name: "Mobil"

    )

    static let united = Supplier(

        id: UUID(uuidString: "4B9F4C6D-8F63-4F2E-8A0C-8B6C44D2A2D0")!,

        name: "United"

    )

    static let chevron = Supplier(

        id: UUID(uuidString: "F1A28C3B-6A3E-4A1C-9E0A-39B1F5B7A2E7")!,

        name: "Chevron"

    )

    static let ior = Supplier(

        id: UUID(uuidString: "7A3E8D31-8B2B-4C7A-9B2E-9A0D3B2C1F88")!,

        name: "iOR"

    )

    static var all: [Supplier] { [bp, mobil, united, chevron, ior] }

}
