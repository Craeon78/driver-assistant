
//

//  AccessCredential.swift

//  DriverAssistant

//

//  Asset model (Phase 1):

//  - Represents “load numbers / PINs” a driver can use at a terminal.

//  - Supports multiple suppliers per terminal.

//  - Supports nominal vs cartage roles.

//  - No JSON persistence assumed yet (iPad-safe).

//

  

import Foundation

  

// MARK: - AccessRole

  

enum AccessRole: String, Codable, CaseIterable {

    case nominal      // carrier house fuel

    case cartage      // supplier/customer fuel

}

  

// MARK: - AccessCredential

  

struct AccessCredential: Codable, Identifiable, Hashable {

    let id: UUID

    /// Linkages (by ID) so we don’t need heavy objects here.

    var terminalID: UUID

    var supplierID: UUID

    /// Nominal vs cartage

    var role: AccessRole

    /// The PIN / load number the driver enters/uses.

    var code: String

    /// Some codes rotate/change.

    var isRotating: Bool

    /// Optional: when you last verified it still works.

    var lastVerifiedAt: Date?

    /// Cartage-only (optional). Keep it lightweight until Customers exist.

    var customerLabel: String?

    /// Free-text notes (e.g. “United jumps terminals”, quirks, etc.)

    var notes: String?

    init(

        id: UUID = UUID(),

        terminalID: UUID,

        supplierID: UUID,

        role: AccessRole,

        code: String,

        isRotating: Bool = false,

        lastVerifiedAt: Date? = nil,

        customerLabel: String? = nil,

        notes: String? = nil

    ) {

        self.id = id

        self.terminalID = terminalID

        self.supplierID = supplierID

        self.role = role

        self.code = code

        self.isRotating = isRotating

        self.lastVerifiedAt = lastVerifiedAt

        self.customerLabel = customerLabel

        self.notes = notes

    }

}
