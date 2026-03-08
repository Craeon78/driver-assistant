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
