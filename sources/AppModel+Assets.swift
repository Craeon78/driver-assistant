import SwiftUI

  

extension AppModel {

    var products: [Product] { FuelProducts.all }

}

  

extension AppModel {

    func resolveLoadNumber(_ raw: String) {

        let canon = raw.replacingOccurrences(of: " ", with: "")

        let matches = loadAccounts.filter { $0.loadNumber.replacingOccurrences(of: " ", with: "") == canon }

        guard let first = matches.first else {

            // nothing found: don’t overwrite current selections

            return

        }

        // If multiple: pick a deterministic default (nominal first)

        let chosen = matches.first(where: { $0.billingRole == .nominal }) ?? first

        resolvedLoadAccountID = chosen.id

        resolvedTerminalID = chosen.terminalID

        loadCode = raw // if you still store/display this

    }

    var selectedLoadAccount: LoadAccount? {

        guard let id = resolvedLoadAccountID else { return nil }

        return loadAccounts.first(where: { $0.id == id })

    }

} 

extension AppModel {

    // New selection truth (Phase 2 UI wiring)

    // Registries (stubbed for now)

    /// Call this when loadCode changes.

    func resolveLoadCodeAutofill() {

        let canon = LoadAccountResolver.normalize(loadCode)

        guard canon.count >= 3 else { 

            resolvedLoadAccountID = nil

            loadAccountCandidates = []

            loadAccountResolveHint = nil

            return

        }

        let typed = loadCode 

        // Empty → clear *resolution UI* but don't nuke legacy fields

        guard !canon.isEmpty else {

            resolvedLoadAccountID = nil

            loadAccountCandidates = []

            loadAccountResolveHint = nil

            return

        }

        do {

            // If you don’t, pass nil and resolver will only succeed if unique.

            let resolved = try LoadAccountResolver.resolve(

                terminalID: nil,

                typed: typed,

                accounts: loadAccounts

            )

            resolvedLoadAccountID = resolved.id

            loadAccountCandidates = []

            loadAccountResolveHint = nil

            // Migration bridge (optional)

            resolvedTerminalID = resolved.terminalID

            terminalName = terminalNameDisplay

        } catch let err as LoadAccountResolver.ResolveError {

            switch err {

            case .emptyInput:

                resolvedLoadAccountID = nil

                loadAccountCandidates = []

                loadAccountResolveHint = nil

            case .noMatch:

                // Don’t overwrite existing selection, but show hint

                resolvedLoadAccountID = nil

                loadAccountCandidates = []

                loadAccountResolveHint = "No matching load account"

            case .ambiguous(let matches):

                resolvedLoadAccountID = nil

                loadAccountCandidates = matches

                loadAccountResolveHint = "Multiple matches — choose one"

            }

        } catch {

            resolvedLoadAccountID = nil

            loadAccountCandidates = []

            loadAccountResolveHint = "Resolve failed"

        }

    }

}
