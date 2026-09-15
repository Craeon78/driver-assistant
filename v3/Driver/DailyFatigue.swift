//======================================
// MARK: - DailyFatigue (V3 Driver)
//======================================
//
// © 2026 Cory Russell Olsen. All rights reserved.
//
// Same-day fatigue metrics computed ONLY from the Work/Rest ledger.
// No parallel session array. Timers/UI later derive remaining from these figures.
//
// Phase: Chunk 3b — Daily fatigue
//======================================

import Foundation

public enum DailyFatigueConstants {
    public static let legalBreak15: TimeInterval = 15 * 60
    public static let threshold7h30: TimeInterval = 7.5 * 3600
    public static let threshold10h: TimeInterval = 10 * 3600
    public static let dailyCap12h: TimeInterval = 12 * 3600
    public static let requiredRestAt7h30: TimeInterval = 30 * 60
    public static let requiredRestAt10h: TimeInterval = 60 * 60
}

public struct DailyFatigueSnapshot: Sendable, Equatable {
    public var asOf: Date
    public var workSeconds: TimeInterval
    public var legalRestSeconds: TimeInterval
    public var shortRestSeconds: TimeInterval
    public var workSinceLastLegalRest: TimeInterval
    public var isInRestLimbo15: Bool
    public var secondsUntilLegal15: TimeInterval
    public var openKind: WorkRestKind?

    /// Remaining until 12h cap; negative if over (timer-style).
    public var remainingUntil12hCap: TimeInterval {
        DailyFatigueConstants.dailyCap12h - workSeconds
    }

    public var remainingUntil7h30: TimeInterval {
        DailyFatigueConstants.threshold7h30 - workSeconds
    }

    public var remainingUntil10h: TimeInterval {
        DailyFatigueConstants.threshold10h - workSeconds
    }
}

public enum DailyFatigueEvaluator {

    /// Evaluate same-calendar-day metrics from ledger entries only.
    public static func evaluate(
        entries: [WorkRestEntry],
        asOf now: Date,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> DailyFatigueSnapshot {
        var cal = calendar
        if cal.timeZone.identifier.isEmpty {
            cal.timeZone = .current
        }
        let dayStart = cal.startOfDay(for: now)
        let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) ?? now

        let sorted = entries.sorted { $0.start < $1.start }

        var work: TimeInterval = 0
        var legalRest: TimeInterval = 0
        var shortRest: TimeInterval = 0
        var lastLegalRestEnd: Date?
        var openKind: WorkRestKind?
        var isLimbo = false
        var untilLegal: TimeInterval = 0

        for e in sorted {
            let segStart = max(e.start, dayStart)
            let segEnd = min(e.end ?? now, dayEnd)
            guard segEnd > segStart else { continue }
            let dur = segEnd.timeIntervalSince(segStart)

            if e.kind == .work {
                work += dur
            } else {
                // Rest: full segment duration against legal threshold uses actual rest length
                let fullStart = e.start
                let fullEnd = e.end ?? now
                let fullDur = max(fullEnd.timeIntervalSince(fullStart), 0)
                if fullDur >= DailyFatigueConstants.legalBreak15 {
                    legalRest += dur
                    lastLegalRestEnd = fullEnd
                } else if e.isOpen {
                    shortRest += dur
                    isLimbo = true
                    untilLegal = max(DailyFatigueConstants.legalBreak15 - fullDur, 0)
                } else {
                    shortRest += dur
                }
            }
            if e.isOpen { openKind = e.kind }
        }

        // Work since last legal rest (within day timeline, using full entry list order)
        let workSince: TimeInterval = {
            var acc: TimeInterval = 0
            let anchor = lastLegalRestEnd ?? dayStart
            for e in sorted where e.kind == .work {
                let segEnd = e.end ?? now
                if segEnd <= anchor { continue }
                let effectiveStart = max(e.start, anchor, dayStart)
                let effectiveEnd = min(segEnd, dayEnd)
                if effectiveEnd > effectiveStart {
                    acc += effectiveEnd.timeIntervalSince(effectiveStart)
                }
            }
            return acc
        }()

        return DailyFatigueSnapshot(
            asOf: now,
            workSeconds: work,
            legalRestSeconds: legalRest,
            shortRestSeconds: shortRest,
            workSinceLastLegalRest: workSince,
            isInRestLimbo15: isLimbo && openKind == .rest,
            secondsUntilLegal15: untilLegal,
            openKind: openKind
        )
    }
}
