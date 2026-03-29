//======================================
// MARK: - AppModel+LoadAccount (Resolution)
//======================================
//
// © 2026 Cory Russell Olsen. All rights reserved.
//
// Path: AppModels/AppModel+LoadAccount.swift
//
// Purpose:
// - Resolves typed load account input into a single selected load account state.
//
// Responsibilities:
// - Run load account resolution against current terminal / typed input.
// - Update resolved account ID, ambiguity matches, and resolution errors.
// - Reset stale resolution state before each new resolve attempt.
//
// Notes:
// - This file owns load account resolution workflow, not display formatting.
// - Resolution state is written here and consumed by UI-facing helpers elsewhere.
// - Current implementation is pre-persistence and uses in-memory registries.
//
// Phase: Pre-persistence
//======================================

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
