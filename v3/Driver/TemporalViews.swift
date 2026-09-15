//======================================
// MARK: - TemporalViews (V3 Driver)
//======================================
//
// © 2026 Cory Russell Olsen. All rights reserved.
//
// Multiple temporal views over one Work/Rest ledger.
// Calendar ≠ shift ≠ episode ≠ rolling/statutory.
//
// Field finding 2026-09-16: rest 20:45→03:24 is 6:39 continuous but
// calendar-day slices are 3:15 (15 Sep) + 3:24 (16 Sep). Both correct.
//
// Phase: Chunk 3d temporal model
//======================================

import Foundation

// MARK: - Shift boundary (driver-declared)

/// Explicit operational period. Does not wipe the work/rest ledger.
/// ShiftEnd does not auto-close an open work/rest segment (driver authority).
public struct ShiftBoundary: Identifiable, Codable, Sendable, Equatable {
    public let id: CanonicalID
    public var start: Date
    public var end: Date? // nil = shift still open
    public var recordedAt: Date
    public var provenance: EventProvenance

    public init(
        id: CanonicalID = .fresh(),
        start: Date,
        end: Date? = nil,
        recordedAt: Date = Date(),
        provenance: EventProvenance = .driverEntered
    ) {
        self.id = id
        self.start = start
        self.end = end
        self.recordedAt = recordedAt
        self.provenance = provenance
    }

    public var isOpen: Bool { end == nil }
}

// MARK: - Interval helpers

public enum LedgerIntervalMath {
    /// Duration of entry overlapping [windowStart, windowEnd], open ends at `now`.
    public static func overlap(
        entry: WorkRestEntry,
        windowStart: Date,
        windowEnd: Date,
        now: Date
    ) -> TimeInterval {
        let segEnd = entry.end ?? now
        let start = max(entry.start, windowStart)
        let end = min(segEnd, windowEnd)
        return max(end.timeIntervalSince(start), 0)
    }

    public static func sumKind(
        _ kind: WorkRestKind,
        entries: [WorkRestEntry],
        windowStart: Date,
        windowEnd: Date,
        now: Date
    ) -> TimeInterval {
        entries.filter { $0.kind == kind }.reduce(0) {
            $0 + overlap(entry: $1, windowStart: windowStart, windowEnd: windowEnd, now: now)
        }
    }

    public static func sumLegalRest(
        entries: [WorkRestEntry],
        windowStart: Date,
        windowEnd: Date,
        now: Date,
        minLegal: TimeInterval = DailyFatigueConstants.legalBreak15
    ) -> TimeInterval {
        var total: TimeInterval = 0
        for e in entries where e.kind == .rest {
            let fullEnd = e.end ?? now
            let fullDur = max(fullEnd.timeIntervalSince(e.start), 0)
            // Legal qualification uses the full continuous rest; credit only the overlap in-window.
            if fullDur >= minLegal {
                total += overlap(entry: e, windowStart: windowStart, windowEnd: windowEnd, now: now)
            }
        }
        return total
    }
}

// MARK: - Calendar view (logbook / day sheet)

public struct CalendarDaySnapshot: Sendable, Equatable {
    public var dayStart: Date
    public var work: TimeInterval
    public var legalRest: TimeInterval
    public var shortRest: TimeInterval
}

public enum CalendarFatigueEvaluator {

    public static func daySnapshot(
        entries: [WorkRestEntry],
        dayStart: Date,
        asOf now: Date,
        calendar: Calendar
    ) -> CalendarDaySnapshot {
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(24 * 3600)
        let windowEnd = min(dayEnd, max(now, dayStart))
        let work = LedgerIntervalMath.sumKind(.work, entries: entries, windowStart: dayStart, windowEnd: windowEnd, now: now)
        let legal = LedgerIntervalMath.sumLegalRest(entries: entries, windowStart: dayStart, windowEnd: windowEnd, now: now)
        // short rest in window: rest overlap where full continuous rest < 15m
        var short: TimeInterval = 0
        for e in entries where e.kind == .rest {
            let fullEnd = e.end ?? now
            let fullDur = max(fullEnd.timeIntervalSince(e.start), 0)
            if fullDur < DailyFatigueConstants.legalBreak15 {
                short += LedgerIntervalMath.overlap(entry: e, windowStart: dayStart, windowEnd: windowEnd, now: now)
            }
        }
        return CalendarDaySnapshot(dayStart: dayStart, work: work, legalRest: legal, shortRest: short)
    }

    public static func currentDay(
        entries: [WorkRestEntry],
        asOf now: Date,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> CalendarDaySnapshot {
        var cal = calendar
        if cal.timeZone.secondsFromGMT() == 0 { cal.timeZone = .current }
        let start = cal.startOfDay(for: now)
        return daySnapshot(entries: entries, dayStart: start, asOf: now, calendar: cal)
    }

    public static func previousDay(
        entries: [WorkRestEntry],
        asOf now: Date,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> CalendarDaySnapshot {
        var cal = calendar
        if cal.timeZone.secondsFromGMT() == 0 { cal.timeZone = .current }
        let today = cal.startOfDay(for: now)
        let prev = cal.date(byAdding: .day, value: -1, to: today) ?? today.addingTimeInterval(-24 * 3600)
        // Previous day is a closed 24h window (not clipped to now)
        let dayEnd = today
        let work = LedgerIntervalMath.sumKind(.work, entries: entries, windowStart: prev, windowEnd: dayEnd, now: now)
        let legal = LedgerIntervalMath.sumLegalRest(entries: entries, windowStart: prev, windowEnd: dayEnd, now: now)
        var short: TimeInterval = 0
        for e in entries where e.kind == .rest {
            let fullEnd = e.end ?? now
            let fullDur = max(fullEnd.timeIntervalSince(e.start), 0)
            if fullDur < DailyFatigueConstants.legalBreak15 {
                short += LedgerIntervalMath.overlap(entry: e, windowStart: prev, windowEnd: dayEnd, now: now)
            }
        }
        return CalendarDaySnapshot(dayStart: prev, work: work, legalRest: legal, shortRest: short)
    }
}

// MARK: - Episode view (continuous uninterrupted)

public struct EpisodeSnapshot: Sendable, Equatable {
    public var kind: WorkRestKind?
    public var start: Date?
    public var end: Date?
    public var duration: TimeInterval
    public var isOpen: Bool
    public var isLegalRest: Bool // rest ≥15m continuous (full episode)
    public var isLimbo: Bool     // open rest <15m
}

public enum EpisodeFatigueEvaluator {

    /// Current open entry, or nil if nothing open.
    public static func current(entries: [WorkRestEntry], asOf now: Date) -> EpisodeSnapshot {
        guard let open = entries.first(where: { $0.isOpen }) else {
            return EpisodeSnapshot(kind: nil, start: nil, end: nil, duration: 0, isOpen: false, isLegalRest: false, isLimbo: false)
        }
        let dur = open.duration(asOf: now)
        let legal = open.kind == .rest && dur >= DailyFatigueConstants.legalBreak15
        let limbo = open.kind == .rest && dur > 0 && dur < DailyFatigueConstants.legalBreak15
        return EpisodeSnapshot(
            kind: open.kind,
            start: open.start,
            end: nil,
            duration: dur,
            isOpen: true,
            isLegalRest: legal,
            isLimbo: limbo
        )
    }

    /// Longest continuous stationary rest overlapping a window (episode sense — full entry duration if stationary).
    public static func maxContinuousStationaryRest(
        entries: [WorkRestEntry],
        asOf now: Date
    ) -> TimeInterval {
        var best: TimeInterval = 0
        for e in entries where e.kind == .rest && e.stationaryRest {
            best = max(best, e.duration(asOf: now))
        }
        return best
    }
}

// MARK: - Shift view

public struct ShiftSnapshot: Sendable, Equatable {
    public var boundary: ShiftBoundary?
    public var work: TimeInterval
    public var rest: TimeInterval
    public var legalRest: TimeInterval
    public var duration: TimeInterval

    public static let none = ShiftSnapshot(boundary: nil, work: 0, rest: 0, legalRest: 0, duration: 0)
}

public enum ShiftFatigueEvaluator {

    public static func evaluate(
        entries: [WorkRestEntry],
        boundary: ShiftBoundary?,
        asOf now: Date
    ) -> ShiftSnapshot {
        guard let b = boundary else { return .none }
        let end = b.end ?? now
        let work = LedgerIntervalMath.sumKind(.work, entries: entries, windowStart: b.start, windowEnd: end, now: now)
        let rest = LedgerIntervalMath.sumKind(.rest, entries: entries, windowStart: b.start, windowEnd: end, now: now)
        let legal = LedgerIntervalMath.sumLegalRest(entries: entries, windowStart: b.start, windowEnd: end, now: now)
        let dur = max(end.timeIntervalSince(b.start), 0)
        return ShiftSnapshot(boundary: b, work: work, rest: rest, legalRest: legal, duration: dur)
    }
}
