
// File: Models/Assets/LoadAccountResolver.swift

import Foundation

  

// © 2026 Cory Russell Olsen. All rights reserved.

//======================================

// MARK: - LoadAccountResolver

//======================================

//

// Purpose:

// - Given (terminalID + typed loadNumber), resolve the best matching LoadAccount.

// - Normalizes user input (keeps digits only).

// - Prefers terminal-specific matches over “any terminal” matches.

// - Pure logic: no JSON required yet.

//======================================

  

struct LoadAccountResolver {

    enum ResolveError: Error, CustomStringConvertible {

        case emptyInput

        case noMatch

        case ambiguous([LoadAccount])

        var description: String {

            switch self {

            case .emptyInput: return "Empty load number"

            case .noMatch: return "No matching load account"

            case .ambiguous(let matches): return "Ambiguous: \(matches.count) matches"

            }

        }

    }

    /// Main entrypoint.

    /// - Parameters:

    ///   - terminalID: The terminal you’re at (or the one selected in UI).

    ///   - typed: What the driver typed (can include spaces, commas, etc).

    ///   - accounts: Your known LoadAccounts (Phase 1: in-memory).

    /// - Returns: A single best match, or throws if none/ambiguous.

    static func resolve(

        terminalID: UUID?,

        typed: String,

        accounts: [LoadAccount]

    ) throws -> LoadAccount {

        let normalized = normalize(typed)

        guard !normalized.isEmpty else { throw ResolveError.emptyInput }

        // 1) Exact matches on number (normalized)

        let numberMatches = accounts.filter { $0.normalizedLoadNumber == normalized }

        guard !numberMatches.isEmpty else { throw ResolveError.noMatch }

        // 2) If terminal is known, prefer exact terminal match.

        if let tid = terminalID {

            let terminalExact = numberMatches.filter { $0.terminalID == tid }

            if terminalExact.count == 1 { return terminalExact[0] }

            if terminalExact.count > 1 {

                // still ambiguous: eg same number used for nominal+cartage

                throw ResolveError.ambiguous(terminalExact)

            }

            // 3) Otherwise allow “terminal-agnostic” accounts (terminalID == nil)

            let terminalAgnostic = numberMatches.filter { $0.terminalID == nil }

            if terminalAgnostic.count == 1 { return terminalAgnostic[0] }

            if terminalAgnostic.count > 1 { throw ResolveError.ambiguous(terminalAgnostic) }

            // 4) Fallback: if all matches are for *other* terminals, treat as no match

            throw ResolveError.noMatch

        }

        // No terminal known → only safe if single match

        if numberMatches.count == 1, let only = numberMatches.first { return only }

        throw ResolveError.ambiguous(numberMatches)

    }

    /// Digits only. (“12 34-56” -> “123456”)

    static func normalize(_ s: String) -> String {

        s.filter { $0.isNumber }

    }

}
