
// File: Models/Assets/Supplier.swift

import Foundation

  

// © 2026 Cory Russell Olsen. All rights reserved.

  

struct Supplier: Identifiable, Codable, Hashable {

    let id: UUID

    var name: String

    init(id: UUID = UUID(), name: String) {

        self.id = id

        self.name = name

    }

}
