
// File: Models/Assets/TerminalRegistry.swift

import Foundation

  

// © 2026 Cory Russell Olsen. All rights reserved.

  

enum TerminalRegistry {

    // Use stable UUIDs so your debug/test data doesn't reshuffle each run.

    // (Pick any UUIDs you like; just keep them constant once chosen.)

    static let atomWhinstanes = Terminal(

        id: UUID(uuidString: "8E2A4D3F-5C2D-4B8F-8C6D-0A5E1F9B6B01")!,

        name: "ATOM Whinstanes"

    )

    static let chevron = Terminal(

        id: UUID(uuidString: "0D9B08C9-1C5E-4F6A-8E9A-7F01B93E4B22")!,

        name: "Chevron Terminal"

    )

    static let ior = Terminal(

        id: UUID(uuidString: "B2D3A7C0-2B7C-4F0A-9D02-0E2E8A93C1F0")!,

        name: "iOR"

    )

    static var all: [Terminal] { [atomWhinstanes, chevron, ior] }

}
