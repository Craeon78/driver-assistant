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
    case fiveAndHalfHours
    case eightHours
    case elevenHours
    case twentyFourHours
    case sevenDays
    case fourteenDays

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
    case compliantAsOfNow
    case actionDue
    case breach
    case uncertainHistory
}

public struct StandardHoursCountingWindow: Identifiable, Sendable, Equatable {
    public let id: String
    public let kind: StandardHoursPeriodKind
    public let anchor: Date
    public let end: Date
    public let evaluatedThrough: Date
    public let work: TimeInterval
    public let qualifyingRest: TimeInterval
    public let state: RegulatoryComplianceState

    public var remainingWork: TimeInterval { kind.maximumWork - work }
    public var isComplete: Bool { evaluatedThrough >= end }
}

public struct StandardHoursPolicySnapshot: Sendable, Equatable {
    public var asOf: Date
    public var windows: [StandardHoursCountingWindow]
    public var historyUncertain: Bool

    public func windows(for kind: StandardHoursPeriodKind) -> [StandardHoursCountingWindow] {
        windows.filter { $0.kind == kind }
    }
}

public enum StandardHoursPolicy {

    /// First Chunk 3.5 slice: statutory anchor/window generation plus work/rest
    /// evaluation. Driver truth is input only.
    public static func evaluate(
        entries: [WorkRestEntry],
        asOf now: Date,
        historyUncertain: Bool = false,
        baseTimeZone: TimeZone = TimeZone(identifier: "Australia/Brisbane") ?? .current
    ) -> StandardHoursPolicySnapshot {
        let sorted = entries.sorted { $0.start < $1.start }
        var windows: [StandardHoursCountingWindow] = []

        // NHVR: periods <24h count forward from the end of any rest break.
        let restEnds = sorted.compactMap { entry -> Date? in
            guard entry.kind == .rest, let end = entry.end, end <= now else { return nil }
            return end
        }
        for anchor in restEnds {
            for kind in [StandardHoursPeriodKind.fiveAndHalfHours, .eightHours, .elevenHours] {
                windows.append(makeWindow(kind: kind, anchor: anchor, entries: sorted, now: now, historyUncertain: historyUncertain, baseTimeZone: baseTimeZone))
            }
        }

        // Standard Hours >=24h anchors. Generate all qualifying anchors so
        // overlapping periods survive. If none qualifies for a kind, fall back
        // to rest-end anchors as required by the counting rule.
        for kind in [StandardHoursPeriodKind.twentyFourHours, .sevenDays, .fourteenDays] {
            let qualified = qualifyingMajorRestEnds(for: kind, entries: sorted, now: now, baseTimeZone: baseTimeZone)
            let anchors = qualified.isEmpty ? restEnds : qualified
            for anchor in anchors {
                windows.append(makeWindow(kind: kind, anchor: anchor, entries: sorted, now: now, historyUncertain: historyUncertain, baseTimeZone: baseTimeZone))
            }
        }

        return StandardHoursPolicySnapshot(
            asOf: now,
            windows: windows.sorted { lhs, rhs in
                if lhs.anchor == rhs.anchor { return lhs.kind.duration < rhs.kind.duration }
                return lhs.anchor < rhs.anchor
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
        let work = LedgerIntervalMath.sumKind(.work, entries: entries, windowStart: anchor, windowEnd: through, now: now)
        let rest = qualifyingRest(in: DateInterval(start: anchor, end: through), kind: kind, entries: entries, now: now, baseTimeZone: baseTimeZone)
        let state: RegulatoryComplianceState
        if historyUncertain {
            state = .uncertainHistory
        } else if work > kind.maximumWork {
            state = .breach
        } else if work == kind.maximumWork && through < end {
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
            state: state
        )
    }

    private static func qualifyingRest(
        in window: DateInterval,
        kind: StandardHoursPeriodKind,
        entries: [WorkRestEntry],
        now: Date,
        baseTimeZone: TimeZone
    ) -> TimeInterval {
        switch kind {
        case .fiveAndHalfHours, .eightHours, .elevenHours:
            // Only blocks >=15 continuous minutes receive short-period credit.
            return entries.filter { $0.kind == .rest }.reduce(0) { total, e in
                let fullEnd = e.end ?? now
                guard fullEnd.timeIntervalSince(e.start) >= 15 * 60 else { return total }
                return total + overlap(e, window: window, now: now)
            }
        case .twentyFourHours:
            return longestStationaryRest(entries, in: window, now: now)
        case .sevenDays:
            return longestStationaryRest(entries, in: window, now: now)
        case .fourteenDays:
            // Night-rest counts are exposed in a later policy slice; keep the
            // raw rest duration out of the canonical ledger and policy-owned.
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
                return isNightRest(e, end: end, baseTimeZone: baseTimeZone) ? end : nil
            }
        default:
            return []
        }
    }

    private static func overlap(_ entry: WorkRestEntry, window: DateInterval, now: Date) -> TimeInterval {
        let end = entry.end ?? now
        guard end > entry.start else { return 0 }
        let interval = DateInterval(start: entry.start, end: end)
        return interval.intersection(with: window)?.duration ?? 0
    }

    private static func longestStationaryRest(_ entries: [WorkRestEntry], in window: DateInterval, now: Date) -> TimeInterval {
        entries.filter { $0.kind == .rest && $0.stationaryRest }.reduce(0) {
            max($0, overlap($1, window: window, now: now))
        }
    }

    private static func isNightRest(_ entry: WorkRestEntry, end: Date, baseTimeZone: TimeZone) -> Bool {
        let duration = end.timeIntervalSince(entry.start)
        if duration >= 24 * 3600 { return true }
        guard duration >= 7 * 3600 else { return false }

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = baseTimeZone
        let startDay = cal.startOfDay(for: entry.start)
        for offset in -1...1 {
            guard let day = cal.date(byAdding: .day, value: offset, to: startDay),
                  let tenPM = cal.date(bySettingHour: 22, minute: 0, second: 0, of: day),
                  let eightAM = cal.date(byAdding: .hour, value: 10, to: tenPM) else { continue }
            let night = DateInterval(start: tenPM, end: eightAM)
            let rest = DateInterval(start: entry.start, end: end)
            if rest.intersection(with: night)?.duration ?? 0 >= 7 * 3600 { return true }
        }
        return false
    }
}
