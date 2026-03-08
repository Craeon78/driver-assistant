
// File: Models/Assets/LoadAccountRegistry.swift

import Foundation

  

// © 2026 Cory Russell Olsen. All rights reserved.

//======================================

// MARK: - LoadAccountRegistry

//======================================

//

// Phase 0/1 seed list.

// Replace with JSON later (same shape).

//======================================

  

enum LoadAccountRegistry {

    static let bpNominal_whinstanes = LoadAccount(

        id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,

        loadNumber: "6750",

        label: "BP Nominal",

        billingRole: .nominal,

        supplierID: SupplierRegistry.bp.id,

        terminalID: TerminalRegistry.atomWhinstanes.id,

        orderKind: .openOrder

    )

    static let unitedNominal_whinstanes = LoadAccount(

        id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,

        loadNumber: "9014",

        label: "United Nominal",

        billingRole: .nominal,

        supplierID: SupplierRegistry.united.id,

        terminalID: TerminalRegistry.atomWhinstanes.id

    )

    static let unitedCartage_whinstanes = LoadAccount(

        id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,

        loadNumber: "9023",

        label: "United Cartage",

        billingRole: .cartage,

        supplierID: SupplierRegistry.united.id,

        terminalID: TerminalRegistry.atomWhinstanes.id

    )

    static let chevronNominal_chevron = LoadAccount(

        id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,

        loadNumber: "130647",

        label: "Chevron Nominal",

        billingRole: .nominal,

        supplierID: SupplierRegistry.chevron.id,

        terminalID: TerminalRegistry.chevron.id

    )

    static let unitedNominal_chevron = LoadAccount(

        id: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,

        loadNumber: "13105 1",

        label: "United Nominal (Chevron)",

        billingRole: .nominal,

        supplierID: SupplierRegistry.united.id,

        terminalID: TerminalRegistry.chevron.id

    )

    static let unitedCartage_chevron = LoadAccount(

        id: UUID(uuidString: "66666666-6666-6666-6666-666666666666")!,

        loadNumber: "13103 1",

        label: "United Cartage (Chevron)",

        billingRole: .cartage,

        supplierID: SupplierRegistry.united.id,

        terminalID: TerminalRegistry.chevron.id

    )

    static let ior_ior = LoadAccount(

        id: UUID(uuidString: "77777777-7777-7777-7777-777777777777")!,

        loadNumber: "530589",

        label: "iOR",

        billingRole: .nominal,

        supplierID: SupplierRegistry.ior.id,

        terminalID: TerminalRegistry.ior.id

    )

    static let all: [LoadAccount] = [

        bpNominal_whinstanes,

        unitedNominal_whinstanes,

        unitedCartage_whinstanes,

        chevronNominal_chevron,

        unitedNominal_chevron,

        unitedCartage_chevron,

        ior_ior

    ]

}
