// File: AppModel+LoadAccount.swift

import Foundation

  

extension AppModel {

    func resolveLoadAccount() {

        loadAccountResolveError = nil

        loadAccountAmbiguousMatches = []

        resolvedLoadAccountID = nil

        do {

            let acct = try LoadAccountResolver.resolve(

                terminalID: resolvedTerminalID,

                typed: typedLoadNumber,

                accounts: LoadAccountRegistry.all

            )

            resolvedLoadAccountID = acct.id

        } catch let err as LoadAccountResolver.ResolveError {

            switch err {

            case .ambiguous(let matches):

                loadAccountAmbiguousMatches = matches

                loadAccountResolveError = err.description

            default:

                loadAccountResolveError = err.description

            }

        } catch {

            loadAccountResolveError = error.localizedDescription

        }

    }

}
