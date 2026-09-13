//======================================
// MARK: - CanonicalID (V3 Core)
//======================================
//
// © 2026 Cory Russell Olsen. All rights reserved.
//
// Owns stable, opaque identifiers used across the event spine and persistence.
// Never use raw UUID or string IDs in domain logic; always wrap.
//
// Phase: Chunk 1 — Silent spine
//======================================

import Foundation

/// Opaque, stable identifier for any V3 entity or event.
/// Equality and hashing are value-based on the underlying UUID.
public struct CanonicalID: Hashable, Codable, Sendable, CustomStringConvertible {
    public let raw: UUID

    public init(_ raw: UUID = UUID()) {
        self.raw = raw
    }

    public var description: String { raw.uuidString }
}

// MARK: - Convenience factories

public extension CanonicalID {
    static func fresh() -> CanonicalID { CanonicalID() }
}
