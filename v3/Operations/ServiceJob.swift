import Foundation

public enum ServiceJobState: String, Codable, Sendable, CaseIterable {
    case planned, arrived, active, completed, deferred
}

public struct ServiceJobIdentity: Codable, Sendable, Equatable {
    public let siteID: CanonicalID?
    public let customerID: CanonicalID?
    public let assetID: CanonicalID?
    public init(siteID: CanonicalID? = nil, customerID: CanonicalID? = nil, assetID: CanonicalID? = nil) {
        self.siteID = siteID; self.customerID = customerID; self.assetID = assetID
    }
}

/// A proposal never becomes truth merely because it was pre-filled.
/// confirmedValue remains nil until explicit driver confirmation/replacement.
public struct ConfirmedValue<Value: Codable & Sendable & Equatable>: Codable, Sendable, Equatable {
    public let suggestedValue: Value?
    public let confirmedValue: Value?
    public let confirmedAt: Date?
    public let provenance: EventProvenance?
    public init(suggestedValue: Value? = nil, confirmedValue: Value? = nil, confirmedAt: Date? = nil, provenance: EventProvenance? = nil) {
        self.suggestedValue = suggestedValue; self.confirmedValue = confirmedValue
        self.confirmedAt = confirmedAt; self.provenance = provenance
    }
    public func confirming(_ value: Value, at date: Date, provenance: EventProvenance = .driverEntered) -> Self {
        Self(suggestedValue: suggestedValue, confirmedValue: value, confirmedAt: date, provenance: provenance)
    }
}

public struct ServiceJob: Identifiable, Codable, Sendable, Equatable {
    public let id: CanonicalID
    public let identity: ServiceJobIdentity
    public let plannedArrival: Date?
    public let plannedCompletion: Date?
    public private(set) var actualArrival: Date?
    public private(set) var actualStart: Date?
    public private(set) var actualCompletion: Date?
    public private(set) var actualDeparture: Date?
    public private(set) var state: ServiceJobState

    public init(id: CanonicalID = .fresh(), identity: ServiceJobIdentity, plannedArrival: Date? = nil, plannedCompletion: Date? = nil) {
        self.id = id; self.identity = identity
        self.plannedArrival = plannedArrival; self.plannedCompletion = plannedCompletion
        self.state = .planned
    }

    /// Geofence/GPS may suggest arrival; only explicit confirmation establishes operational truth.
    public mutating func confirmArrival(at date: Date) -> Bool {
        guard state == .planned else { return false }
        actualArrival = date; state = .arrived; return true
    }

    public mutating func begin(at date: Date) -> Bool {
        guard state == .arrived, let arrival = actualArrival, date >= arrival else { return false }
        actualStart = date; state = .active; return true
    }

    public mutating func complete(at date: Date) -> Bool {
        guard state == .active, let start = actualStart, date >= start else { return false }
        actualCompletion = date; state = .completed; return true
    }

    public mutating func depart(at date: Date) -> Bool {
        guard state == .completed, actualDeparture == nil, let completion = actualCompletion, date >= completion else { return false }
        actualDeparture = date; return true
    }

    public mutating func deferJob() -> Bool {
        guard state == .planned || state == .arrived else { return false }
        state = .deferred; return true
    }
}
