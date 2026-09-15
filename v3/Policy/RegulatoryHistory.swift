import Foundation

public enum RegulatoryHistoryConfidence: String, Codable, Sendable {
    case complete, uncertain
}

public struct RegulatoryHistory: Sendable, Equatable {
    public var entries: [WorkRestEntry]
    public var confidence: RegulatoryHistoryConfidence
    public var reason: String?

    public init(entries: [WorkRestEntry], confidence: RegulatoryHistoryConfidence = .complete, reason: String? = nil) {
        self.entries = entries.sorted { $0.start < $1.start }
        self.confidence = confidence
        self.reason = reason
    }

    public func evaluateStandardHours(asOf now: Date, baseTimeZone: TimeZone) -> StandardHoursPolicySnapshot {
        StandardHoursPolicy.evaluate(entries: entries, asOf: now, historyUncertain: confidence == .uncertain, baseTimeZone: baseTimeZone)
    }

    /// Corrections create a new deterministic projection. The Driver ledger remains
    /// the authority/persistence owner; this type does not silently mutate it.
    public func replacing(entryID: CanonicalID, with corrected: WorkRestEntry) -> RegulatoryHistory {
        var copy = entries
        if let i = copy.firstIndex(where: { $0.id == entryID }) { copy[i] = corrected }
        return RegulatoryHistory(entries: copy, confidence: .complete, reason: nil)
    }
}
