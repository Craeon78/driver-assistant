
import SwiftUI

  

// File: Models/Assets/Terminal.swift

import Foundation

import CoreLocation

  

// © 2026 Cory Russell Olsen. All rights reserved.

//======================================

// MARK: - Terminal (Core asset)

//======================================

//

// Purpose:

// - Represents a physical loading location (fuel terminal, depot, etc).

// - Used for:

//     • Load planning (SimView)

//     • Map pins

//     • LoadAccount resolution

//

// Philosophy:

// - Driver-oriented model.

// - We do NOT model bays, gantries, or internal terminal layout.

// - Only what a driver actually needs.

//

// Future:

// - Works for other industries (e.g. reefer depots).

//======================================

  

struct Terminal: Codable, Identifiable, Hashable {

    let id: UUID

    /// Display name shown in UI

    var name: String

    /// Optional nickname drivers often use

    /// e.g. "Whinstanes", "Lytton", "Pinkenba"

    var shortName: String?

    /// Physical location (for map + proximity detection)

    var coordinate: CodableCoordinate?

    /// Known suppliers operating at this terminal

    /// (BP, Mobil, Chevron etc)

    var supplierIDs: [UUID]

    /// Notes the driver may want

    /// e.g. gate quirks, queue patterns, bay preferences

    var notes: String?

    init(

        id: UUID = UUID(),

        name: String,

        shortName: String? = nil,

        coordinate: CodableCoordinate? = nil,

        supplierIDs: [UUID] = [],

        notes: String? = nil

    ) {

        self.id = id

        self.name = name

        self.shortName = shortName

        self.coordinate = coordinate

        self.supplierIDs = supplierIDs

        self.notes = notes

    }

}
