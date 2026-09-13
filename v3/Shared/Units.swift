//======================================
// MARK: - Units (V3 Shared)
//======================================
//
// © 2026 Cory Russell Olsen. All rights reserved.
//
// Canonical quantity types and unit conversion stubs.
// Store canonical values; convert only at boundaries.
//
// Phase: Chunk 1 — Silent spine (stubs only)
//======================================

import Foundation

/// Distance in metres (canonical).
public struct Metres: Hashable, Codable, Sendable {
    public let value: Double
    public init(_ value: Double) { self.value = value }
    public var kilometres: Double { value / 1000.0 }
}

/// Mass in kilograms (canonical).
public struct Kilograms: Hashable, Codable, Sendable {
    public let value: Double
    public init(_ value: Double) { self.value = value }
}

/// Volume in litres (canonical for liquid cargo).
public struct Litres: Hashable, Codable, Sendable {
    public let value: Double
    public init(_ value: Double) { self.value = value }
}

/// Duration in seconds (canonical).
public struct Seconds: Hashable, Codable, Sendable {
    public let value: TimeInterval
    public init(_ value: TimeInterval) { self.value = value }
    public var hours: Double { value / 3600.0 }
}
