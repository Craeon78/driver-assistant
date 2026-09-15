//======================================
// MARK: - StandardHoursPolicy (V3 Policy)
//======================================
//
// © 2026 Cory Russell Olsen. All rights reserved.
//
// Regulatory interpretation over Driver-owned Work/Rest truth.
// Does not own or mutate the ledger.
// Rolling analytics != statutory counting periods.
//
// Phase: Chunk 3.5 — NHVR regulatory interpretation
//======================================

import Foundation

public enum StandardHoursPeriodKind: String, Codable, Sendable, CaseIterable {
    case fiveAndHalfHours, eightHours, elevenHours, twentyFourHours, sevenDays, fourteenDays

    public var duration: TimeInterval {
        switch self {
        case .fiveAndHalfHours: return 5.5 * 3600
        case .eightHours: return 8 * 3600
        case .elevenHours: return 11 * 3600
        case .twentyFourHours: return 24 * 3600
        case .sevenDays: return 7 * 24 * 3600
        case .fourteenDays: return 14 * 24 * 3600
        }
    }

    public var maximumWork: TimeInterval {
        switch self {
        case .fiveAndHalfHours: return 5.25 * 3600
        case .eightHours: return 7.5 * 3600
        case .elevenHours: return 10 * 3600
        case .twentyFourHours: return 12 * 3600
        case .sevenDays: return 72 * 3600
        case .fourteenDays: return 144 * 3600
        }
    }
}

public enum RegulatoryComplianceState: String, Codable, Sendable {
    case compliantAsOfNow, actionDue, breach, uncertainHistory
}

public struct StandardHoursCountingWindow: Identifiable, Sendable, Equatable {
    public let id: String
    public let kind: StandardHoursPeriodKind
    public let anchor: Date
    public let end: Date
    public let evaluatedThrough: Date
    public let work: TimeInterval
    public let qualifyingRest: TimeInterval
    public let nightRestCount: Int
    public let hasConsecutiveNightRestPair: Bool
    public let restRequirementSatisfied: Bool
    public let state: RegulatoryComplianceState

    public var remainingWork: TimeInterval { kind.maximumWork - work }
    public var isComplete: Bool { evaluatedThrough >= end }
    public var isActive: Bool { evaluatedThrough < end }
}

public struct StandardHoursPolicySnapshot: Sendable, Equatable {
    public var asOf: Date
    public var windows: [StandardHoursCountingWindow]
    public var historyUncertain: Bool

    public func windows(for kind: StandardHoursPeriodKind) -> [StandardHoursCountingWindow] {
        windows.filter { $0.kind == kind }
    }

    /// Driver UX normally uses this collection. Completed windows remain in the
    /// snapshot for audit/reconciliation but do not clutter the live surface.
    public func activeWindows(for kind: StandardHoursPeriodKind) -> [StandardHoursCountingWindow] {
        windows.filter { $0.kind == kind && $0.anchor <= asOf && $0.end > asOf }
    }
}

public enum StandardHoursPolicy {
    public static func evaluate(
        entries: [WorkRestEntry],
        asOf now: Date,
        historyUncertain: Bool = false,
        baseTimeZone: TimeZone = TimeZone(identifier: "Australia/Brisbane") ?? .current
    ) -> StandardHoursPolicySnapshot {
        let sorted = entries.sorted { $0.start < $1.start }
        var windows: [StandardHoursCountingWindow] = []

        let restEnds = sorted.compactMap { entry -> Date? in
            guard entry.kind == .rest, let end = entry.end, end <= now else { return nil }
            return end
        }

        // Periods under 24h count forward from the end of every rest break.
        for anchor in restEnds {
            for kind in [StandardHoursPeriodKind.fiveAndHalfHours, .eightHours, .elevenHours] {
                windows.append(makeWindow(kind: kind, anchor: anchor, entries: sorted, now: now, historyUncertain: historyUncertain, baseTimeZone: baseTimeZone))
            }
        }

        // Standard Hours periods >=24h use the longest major rest required for
        // that period. Keep all qualifying anchors so an overlapping period is
        // never erased. Before a qualifying major rest exists, any rest end is a
        // candidate anchor under the NHVR fallback rule.
        for kind in [StandardHoursPeriodKind.twentyFourHours, .sevenDays, .fourteenDays] {
            let qualified = qualifyingMajorRestEnds(for: kind, entries: sorted, now: now, baseTimeZone: baseTimeZone)
            let anchors = qualified.isEmpty ? restEnds : qualified
            for anchor in anchors {
                windows.append(makeWindow(kind: kind, anchor: anchor, entries: sorted, now: now, historyUncertain: historyUncertain, baseTimeZone: baseTimeZone))
            }
        }

        return StandardHoursPolicySnapshot(
            asOf: now,
            windows: windows.sorted {
                if $0.anchor == $1.anchor { return $0.kind.duration < $1.kind.duration }
                return $0.anchor < $1.anchor
            },
            historyUncertain: historyUncertain
        )
    }

    private static func makeWindow(
        kind: StandardHoursPeriodKind,
        anchor: Date,
        entries: [WorkRestEntry],
        now: Date,
        historyUncertain: Bool,
        baseTimeZone: TimeZone
    ) -> StandardHoursCountingWindow {
        let end = anchor.addingTimeInterval(kind.duration)
        let through = min(now, end)
        let interval = DateInterval(start: anchor, end: through)
        let work = LedgerIntervalMath.sumKind(.work, entries: entries, windowStart: anchor, windowEnd: through, now: now)
        let rest = qualifyingRest(in: interval, kind: kind, entries: entries, now: now)
        let nightDates = qualifyingNightRestDates(entries: entries, in: interval, now: now, baseTimeZone: baseTimeZone)
        let pair = hasConsecutiveDates(nightDates, baseTimeZone: baseTimeZone)
        let restSatisfied = restRequirementSatisfied(kind: kind, qualifyingRest: rest, nightRestCount: nightDates.count, hasConsecutiveNightRestPair: pair)
        let complete = through >= end

        let state: RegulatoryComplianceState
        if historyUncertain {
            state = .uncertainHistory
        } else if work > kind.maximumWork || (complete && !restSatisfied) {
            state = .breach
        } else if work >= kind.maximumWork && !complete {
            state = .actionDue
        } else {
            state = .compliantAsOfNow
        }

        return StandardHoursCountingWindow(
            id: "\(kind.rawValue)|\(anchor.timeIntervalSince1970)",
            kind: kind,
            anchor: anchor,
            end: end,
            evaluatedThrough: through,
            work: work,
            qualifyingRest: rest,
            nightRestCount: nightDates.count,
            hasConsecutiveNightRestPair: pair,
            restRequirementSatisfied: restSatisfied,
            state: state
        )
    }

    private static func restRequirementSatisfied(
        kind: StandardHoursPeriodKind,
        qualifyingRest: TimeInterval,
        nightRestCount: Int,
        hasConsecutiveNightRestPair: Bool
    ) -> Bool {
        switch kind {
        case .fiveAndHalfHours: return qualifyingRest >= 15 * 60
        case .eightHours: return qualifyingRest >= 30 * 60
        case .elevenHours: return qualifyingRest >= 60 * 60
        case .twentyFourHours: return qualifyingRest >= 7 * 3600
        case .sevenDays: return qualifyingRest >= 24 * 3600
        case .fourteenDays: return nightRestCount >= 2 && hasConsecutiveNightRestPair
        }
    }

    private static func qualifyingRest(
        in window: DateInterval,
        kind: StandardHoursPeriodKind,
        entries: [WorkRestEntry],
        now: Date
    ) -> TimeInterval {
        switch kind {
        case .fiveAndHalfHours, .eightHours, .elevenHours:
            return entries.filter { $0.kind == .rest }.reduce(0) { total, e in
                let fullEnd = e.end ?? now
                guard fullEnd.timeIntervalSince(e.start) >= 15 * 60 else { return total }
                return total + overlap(e, window: window, now: now)
            }
        case .twentyFourHours, .sevenDays:
            return longestStationaryRest(entries, in: window, now: now)
        case .fourteenDays:
            return 0
        }
    }

    private static func qualifyingMajorRestEnds(
        for kind: StandardHoursPeriodKind,
        entries: [WorkRestEntry],
        now: Date,
        baseTimeZone: TimeZone
    ) -> [Date] {
        switch kind {
        case .twentyFourHours:
            return entries.compactMap { e in
                guard e.kind == .rest, e.stationaryRest, let end = e.end,
                      end <= now, end.timeIntervalSince(e.start) >= 7 * 3600 else { return nil }
                return end
            }
        case .sevenDays:
            return entries.compactMap { e in
                guard e.kind == .rest, e.stationaryRest, let end = e.end,
                      end <= now, end.timeIntervalSince(e.start) >= 24 * 3600 else { return nil }
                return end
            }
        case .fourteenDays:
            return entries.compactMap { e in
                guard e.kind == .rest, e.stationaryRest, let end = e.end, end <= now else { return nil }
                return nightRestDate(e, end: end, baseTimeZone: baseTimeZone) == nil ? nil : end
            }
        default:
            return []
        }
    }

    private static func qualifyingNightRestDates(
        entries: [WorkRestEntry],
        in window: DateInterval,
        now: Date,
        baseTimeZone: TimeZone
    ) -> [Date] {
        let dates = entries.compactMap { e -> Date? in
            guard e.kind == .rest, e.stationaryRest else { return nil }
            let end = e.end ?? now
            guard end > e.start else { return nil }
            let rest = DateInterval(start: e.start, end: end)
            guard rest.intersects(window) else { return nil }
            return nightRestDate(e, end: end, baseTimeZone: baseTimeZone)
        }
        return Array(Set(dates)).sorted()
    }

    /// Returns the base-time-zone calendar day on which a qualifying night rest
    /// begins. A 24h stationary rest also qualifies as a night rest.
    private static func nightRestDate(_ entry: WorkRestEntry, end: Date, baseTimeZone: TimeZone) -> Date? {
        guard entry.stationaryRest else { return nil }
        let duration = end.timeIntervalSince(entry.start)
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = baseTimeZone
        if duration >= 24 * 3600 { return cal.startOfDay(for: entry.start) }
        guard duration >= 7 * 3600 else { return nil }

        let startDay = cal.startOfDay(for: entry.start)
        for offset in -1...1 {
            guard let day = cal.date(byAdding: .day, value: offset, to: startDay),
                  let tenPM = cal.date(bySettingHour: 22, minute: 0, second: 0, of: day),
                  let eightAM = cal.date(byAdding: .hour, value: 10, to: tenPM) else { continue }
            let night = DateInterval(start: tenPM, end: eightAM)
            let rest = DateInterval(start: entry.start, end: end)
            if rest.intersection(with: night)?.duration ?? 0 >= 7 * 3600 { return day }
        }
        return nil
    }

    private static func hasConsecutiveDates(_ dates: [Date], baseTimeZone: TimeZone) -> Bool {
        guard dates.count >= 2 else { return false }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = baseTimeZone
        let sorted = dates.sorted()
        for i in 1..<sorted.count {
            if let next = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: sorted[i - 1])),
               cal.isDate(next, inSameDayAs: sorted[i]) { return true }
        }
        return false
    }

    private static func overlap(_ entry: WorkRestEntry, window: DateInterval, now: Date) -> TimeInterval {
        let end = entry.end ?? now
        guard end > entry.start else { return 0 }
        return DateInterval(start: entry.start, end: end).intersection(with: window)?.duration ?? 0
    }

    private static func longestStationaryRest(_ entries: [WorkRestEntry], in window: DateInterval, now: Date) -> TimeInterval {
        entries.filter { $0.kind == .rest && $0.stationaryRest }.reduce(0) {
            max($0, overlap($1, window: window, now: now))
        }
    }
}
