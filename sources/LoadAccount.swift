
// File: Models/Assets/LoadAccount.swift

import Foundation

  

// © 2026 Cory Russell Olsen. All rights reserved.

//======================================

// MARK: - LoadAccount (Commercial reference)

//======================================

//

// Purpose:

// - Represents a terminal/supplier “load number” you can select at load time.

// - This is NOT a security credential (not a PIN).

// - It’s an account/authorisation reference used for billing / allocation.

//

// Key UX goal:

// - Driver types/selects: (Terminal + LoadNumber)

// - App resolves: Supplier + BillingRole + Products allowed + notes.

//======================================

  

struct LoadAccount: Codable, Identifiable, Hashable {

    let id: UUID

    /// The number you type at the gantry / kiosk.

    /// Stored as String to preserve leading zeros and formatting.

    var loadNumber: String

    /// Human label (eg "United - Nominal", "United - Cartage", "BP - Backup").

    var label: String

    /// Nominal vs Cartage (your real-world split).

    var billingRole: BillingRole

    /// The supplier “brand bucket” this number belongs to.

    var supplierID: UUID

    /// Where it works (some numbers only exist at certain terminals).

    var terminalID: UUID?

    /// Optional: which products this load account can access at that terminal.

    /// If empty, treat as “unknown / assume terminal decides”.

    var allowedProductCodes: [String]   // e.g. ["P91","P95","P98","DSL","B100"]

    /// Some numbers stay stable, some rotate/change.

    var stability: AccountStability

    var orderKind: LoadOrderKind = .openOrder

    var notes: String?

    init(

        id: UUID = UUID(),

        loadNumber: String,

        label: String,

        billingRole: BillingRole,

        supplierID: UUID,

        terminalID: UUID? = nil,

        allowedProductCodes: [String] = [],

        stability: AccountStability = .staticNumber,

        orderKind: LoadOrderKind = .openOrder,

        notes: String? = nil

    ) {

        self.id = id

        self.loadNumber = loadNumber

        self.label = label

        self.billingRole = billingRole

        self.supplierID = supplierID

        self.terminalID = terminalID

        self.allowedProductCodes = allowedProductCodes

        self.stability = stability

        self.orderKind = orderKind

        self.notes = notes

    }

}

  

enum BillingRole: String, Codable, CaseIterable {

    case nominal

    case cartage

    case other

}

  

enum AccountStability: String, Codable, CaseIterable {

    case staticNumber

    case rotates

}

  

enum LoadOrderKind: String, Codable, CaseIterable {

    case openOrder   // static, driver-typable

    case rackOrder   // created by schedulers, driver recalls a specific order

}

  

extension LoadAccount {

    var normalizedLoadNumber: String {

        loadNumber.filter { $0.isNumber }

    }

}
