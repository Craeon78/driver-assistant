//======================================
// MARK: - RollingFatigue (V3 Driver)
//======================================
//
// © 2026 Cory Russell Olsen. All rights reserved.
//
// Rolling 24h / 7d / 14d evaluation from the Work/Rest ledger.
// Standard HV only. BFM deferred until pre-ship.
// Pure function over entries — no session state.
//
// Phase: Chunk 3c — Rolling windows
//======================================

import Foundation

public enum StandardHVLimits {
    public static let work24: TimeInterval = 12 * 3600
    public static let minStationaryRest24: TimeInterval = 7 * 3600
    public static let work7d: TimeInterval = 72 * 3600
    public static let work14d: TimeInterval = 144 * 3600
    public static let continuousRest7d: TimeInterval = 24 * 3600
    public static let nightRestMin: TimeInterval = 7 * 3600
    public static let nightRestRequired14d: Int = 4
}

public struct RollingFatigueSnapshot: Sendable, Equatable {
    public var asOf: Date
    public var work24: TimeInterval
    public var maxContinuousStationaryRest24: TimeInterval
    public var work7d: TimeInterval
    public var work14d: TimeInterval
    public var has24hContinuousRestIn7d: Bool
    public var nightRestCount14d: Int
    public var hasConsecutiveNightRestPair14d: Bool

    public var remainingWork24: TimeInterval { StandardHVLimits.work24 - work24 }
    public var remainingWork7d: TimeInterval { StandardHVLimits.work7d - work7d }
    public var remainingWork14d: TimeInterval { StandardHVLimits.work14d - work14d }
}

public enum RollingFatigueEvaluator {

    public static func evaluate(
        entries: [WorkRestEntry],
        asOf now: Date,
        timeZone: TimeZone = TimeZone(identifier: "Australia/Brisbane") ?? .current
    ) -> RollingFatigueSnapshot {
        let win24 = DateInterval(start: now.addingTimeInterval(-24 * 3600), end: now)
        let win7 = DateInterval(start: now.addingTimeInterval(-7 * 24 * 3600), end: now)
        let win14 = DateInterval(start: now.addingTimeInterval(-14 * 24 * 3600), end: now)

        let work24 = sumWork(entries, in: win24, now: now)
        let work7 = sumWork(entries, in: win7, now: now)
        let work14 = sumWork(entries, in: win14, now: now)
        let maxRest24 = maxContinuousStationaryRest(entries, in: win24, now: now)
        let has24Rest7 = hasContinuousStationaryRest(entries, minSeconds: StandardHVLimits.continuousRest7d, in: win7, now: now)
        let nightLabels = nightRestLabels(entries, in: win14, now: now, timeZone: timeZone)
        let streak = maxConsecutiveNightStreak(nightLabels, timeZone: timeZone)

        return RollingFatigueSnapshot(
            asOf: now,
            work24: work24,
            maxContinuousStationaryRest24: maxRest24,
            work7d: work7,
            work14d: work14,
            has24hContinuousRestIn7d: has24Rest7,
            nightRestCount14d: nightLabels.count,
            hasConsecutiveNightRestPair14d: streak >= 2
        )
    }

    // MARK: - Aggregation

    private static func clippedDuration(start: Date, end: Date?, window: DateInterval, now: Date) -> TimeInterval {
        let effectiveEnd = end ?? now
        let seg = DateInterval(start: start, end: effectiveEnd)
        guard let inter = seg.intersection(with: window) else { return 0 }
        return inter.duration
    }

    private static func sumWork(_ entries: [WorkRestEntry], in window: DateInterval, now: Date) -> TimeInterval {
        entries.filter { $0.kind == .work }.reduce(0) {
            $0 + clippedDuration(start: $1.start, end: $1.end, window: window, now: now)
        }
    }

    private static func maxContinuousStationaryRest(_ entries: [WorkRestEntry], in window: DateInterval, now: Date) -> TimeInterval {
        var best: TimeInterval = 0
        for e in entries where e.kind == .rest && e.stationaryRest {
            best = max(best, clippedDuration(start: e.start, end: e.end, window: window, now: now))
        }
        return best
    }

    private static func hasContinuousStationaryRest(
        _ entries: [WorkRestEntry],
        minSeconds: TimeInterval,
        in window: DateInterval,
        now: Date
    ) -> Bool {
        for e in entries where e.kind == .rest && e.stationaryRest {
            if clippedDuration(start: e.start, end: e.end, window: window, now: now) >= minSeconds {
                return true
            }
        }
        return false
    }

    /// Qualifying night rest: stationary rest ≥7h that overlaps 22:00–08:00, or ≥24h continuous.
    private static func nightRestLabels(
        _ entries: [WorkRestEntry],
        in window: DateInterval,
        now: Date,
        timeZone: TimeZone
    ) -> [Date] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        var labels: Set<Date> = []

        for e in entries where e.kind == .rest && e.stationaryRest {
            let effectiveEnd = e.end ?? now
            let full = DateInterval(start: e.start, end: effectiveEnd)
            guard let clipped = full.intersection(with: window) else { continue }
            if clipped.duration < StandardHVLimits.nightRestMin && clipped.duration < 24 * 3600 {
                continue
            }
            if clipped.duration >= 24 * 3600 {
                labels.insert(cal.startOfDay(for: clipped.start))
                continue
            }
            // Overlap ≥7h inside a 22:00–08:00 window
            for offset in -1...1 {
                guard let day = cal.date(byAdding: .day, value: offset, to: clipped.start) else { continue }
                let dayStart = cal.startOfDay(for: day)
                guard let winStart = cal.date(bySettingHour: 22, minute: 0, second: 0, of: dayStart),
                      let winEnd = cal.date(byAdding: .hour, value: 10, to: winStart) else { continue }
                let nightWin = DateInterval(start: winStart, end: winEnd)
                if let inter = clipped.intersection(with: nightWin), inter.duration >= StandardHVLimits.nightRestMin {
                    labels.insert(cal.startOfDay(for: winStart))
                }
            }
        }
        return labels.sorted()
    }

    private static func maxConsecutiveNightStreak(_ labels: [Date], timeZone: TimeZone) -> Int {
        guard !labels.isEmpty else { return 0 }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let sorted = labels.sorted()
        var best = 1
        var cur = 1
        for i in 1..<sorted.count {
            let prev = sorted[i - 1]
            if let expected = cal.date(byAdding: .day, value: 1, to: prev),
               cal.isDate(sorted[i], inSameDayAs: expected) {
                cur += 1
                best = max(best, cur)
            } else {
                cur = 1
            }
        }
        return best
    }
}
