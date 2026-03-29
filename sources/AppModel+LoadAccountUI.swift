//======================================
// MARK: - AppModel+LoadAccount (Display)
//======================================
//
// © 2026 Cory Russell Olsen. All rights reserved.
//
// Path: AppModels/AppModel+LoadAccountUI.swift
//
// Purpose:
// - Provides registry-backed lookup helpers and display values for resolved load account state.
//
// Responsibilities:
// - Expose in-memory terminal, supplier, and load account registries.
// - Derive resolved load account lookup from resolvedLoadAccountID.
// - Provide display-ready terminal, supplier, and billing role strings.
//
// Notes:
// - This file is UI-facing helper logic, not resolution workflow.
// - It depends on resolution state already being set elsewhere.
// - Current implementation is pre-persistence and uses static registries.
//
// Phase: Pre-persistence
//======================================

import Foundation

extension AppModel {
    
    // Registries (Phase 1: in-memory)
    var terminals: [Terminal] { TerminalRegistry.all }
    var loadAccounts: [LoadAccount] { LoadAccountRegistry.all }
    var suppliers: [Supplier] { SupplierRegistry.all }
    
    // Your selected/resolved account (rename these two vars if your model uses different names)
    var resolvedLoadAccount: LoadAccount? {
        guard let id = resolvedLoadAccountID else { return nil }
        return loadAccounts.first(where: { $0.id == id })
    }
    
    var terminalNameDisplay: String {
        guard let tid = resolvedLoadAccount?.terminalID,
              let t = terminals.first(where: { $0.id == tid }) else { return "—" }
        return t.name
    }
    
    var supplierNameDisplay: String {
        guard let sid = resolvedLoadAccount?.supplierID,
              let s = suppliers.first(where: { $0.id == sid }) else { return "—" }
        return s.name
    }
    
    var billingRoleDisplay: String {
        resolvedLoadAccount?.billingRole.rawValue.capitalized ?? "—"
    }
}
