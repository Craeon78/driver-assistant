
import Foundation

  

//==================================================

// MARK: - Fatigue Scheme (Phase 1: Standard + BFM)

//==================================================

  

enum FatigueScheme: String, CaseIterable, Identifiable {

    case standardHV = "Standard (HV)"

    case bfmHV = "BFM (HV)"

    case busCoachStandard = "Bus/Coach Standard (coming)"

    case busCoachBFM = "Bus/Coach BFM (coming)"

    case afmCustom = "AFM (coming)"

    var id: String { rawValue }

    var isAvailableNow: Bool {

        switch self {

        case .standardHV, .bfmHV: return true

        default: return false

        }

    }

}

  

//==================================================

// MARK: - Timeline primitives (Journal truth shape)

//==================================================

  

enum SegmentKind: String, Codable {

    case work

    case rest

}

  

struct WorkRestSegment: Identifiable, Codable, Hashable {

    let id: UUID

    var kind: SegmentKind

    var start: Date

    var end: Date?               // nil = in-progress segment

    var stationaryRest: Bool     // required for “stationary rest” rules

    init(

        id: UUID = UUID(),

        kind: SegmentKind,

        start: Date,

        end: Date? = nil,

        stationaryRest: Bool = true

    ) {

        self.id = id

        self.kind = kind

        self.start = start

        self.end = end

        self.stationaryRest = stationaryRest

    }

    func clipped(to window: DateInterval, now: Date) -> DateInterval? {

        let effectiveEnd = end ?? now

        let seg = DateInterval(start: start, end: effectiveEnd)

        let intersection = seg.intersection(with: window)

        return intersection

    }

}

  

//==================================================

// MARK: - Fatigue Output model (What Today/Sim renders)

//==================================================

  

enum FatigueSeverity: String {

    case ok

    case warn

    case over

    case unavailable

}

  

struct FatigueMetric {

    var title: String

    var value: String

    var severity: FatigueSeverity

    var detail: String? = nil

}

  

struct FatigueStatus {

    var scheme: FatigueScheme

    var asOf: Date

    // Core rolling windows

    var work24: TimeInterval

    var rest24StationaryContinuousMax: TimeInterval

    var work7d: TimeInterval

    var work14d: TimeInterval

    // Standard/BFM structural requirements

    var has24hContinuousRestIn7d: Bool

    var nightRestCount14d: Int

    var hasConsecutiveNightRestPair14d: Bool

    // BFM extras (Phase 1: placeholders you can wire later)

    var longNightWork7d: TimeInterval?          // BFM: “long/night work” rolling 7d (cap often 36h)

    var has24hRestAfter84hWork14d: Bool?        // BFM: reset condition

    // Render-ready cards (keep UI dumb)

    var cards: [FatigueMetric]

}

  

//==================================================

// MARK: - Engine

//==================================================

  

enum FatigueEngine {

    // Public entry point

    static func evaluate(

        scheme: FatigueScheme,

        segments: [WorkRestSegment],

        now: Date,

        tz: TimeZone = .current

    ) -> FatigueStatus {

        guard scheme.isAvailableNow else {

            return FatigueStatus(

                scheme: scheme,

                asOf: now,

                work24: 0,

                rest24StationaryContinuousMax: 0,

                work7d: 0,

                work14d: 0,

                has24hContinuousRestIn7d: false,

                nightRestCount14d: 0,

                hasConsecutiveNightRestPair14d: false,

                longNightWork7d: nil,

                has24hRestAfter84hWork14d: nil,

                cards: [

                    FatigueMetric(title: scheme.rawValue, value: "Coming", severity: .unavailable, detail: "Not enabled yet.")

                ]

            )

        }

        let win24  = DateInterval(start: now.addingTimeInterval(-24*3600), end: now)

        let win7d  = DateInterval(start: now.addingTimeInterval(-7*24*3600), end: now)

        let win14d = DateInterval(start: now.addingTimeInterval(-14*24*3600), end: now)

        let work24 = sum(kind: .work, segments: segments, in: win24, now: now)

        let work7d = sum(kind: .work, segments: segments, in: win7d, now: now)

        let work14 = sum(kind: .work, segments: segments, in: win14d, now: now)

        let maxContinuousStationaryRest24 = maxContinuousStationaryRest(segments: segments, in: win24, now: now)

        let has24hContRest7d = hasContinuousStationaryRest(segments: segments, minSeconds: 24*3600, in: win7d, now: now)

        // Night rest break detection: >=7h stationary rest with overlap inside 22:00–08:00 window

        let nightLabels14 = nightRestLabels(in: win14d, segments: segments, now: now, tz: tz)

        let nightCount = nightLabels14.count

        let streak = maxConsecutiveNightStreak(nightLabels14, tz: tz)

        let hasConsecPair = streak >= 2

        // Scheme-specific limits

        let (work24Limit, minRest24, work7Limit, work14Limit) = limits(for: scheme)

        // Create render cards (dense, decision-grade)

        var cards: [FatigueMetric] = []

        // Card 1 — Rolling 24h

        cards.append(

            metricRolling24h(

                work24: work24,

                work24Limit: work24Limit,

                maxStationaryRest24: maxContinuousStationaryRest24,

                minStationaryRest24: minRest24

            )

        )

        // Card 2 — 7d totals + 24h continuous rest requirement

        cards.append(

            metricRolling7d(

                work7d: work7d,

                work7Limit: work7Limit,

                has24hContinuousRest: has24hContRest7d

            )

        )

        // Card 3 — 14d totals + night rests structure

        cards.append(

            metricRolling14d(

                work14d: work14,

                work14Limit: work14Limit,

                nightRestCount: nightCount,

                nightRestRequiredTotal: 4,

                consecutiveStreak: streak

            )

        )

        // BFM placeholders

        var longNightWork7d: TimeInterval? = nil

        var has24After84: Bool? = nil

        if scheme == .bfmHV {

            // Wire these properly later once we encode “long/night work” classification.

            // For now leave as nil so UI can show “not yet”.

            longNightWork7d = nil

            has24After84 = nil

        }

        return FatigueStatus(

            scheme: scheme,

            asOf: now,

            work24: work24,

            rest24StationaryContinuousMax: maxContinuousStationaryRest24,

            work7d: work7d,

            work14d: work14,

            has24hContinuousRestIn7d: has24hContRest7d,

            nightRestCount14d: nightCount,

            hasConsecutiveNightRestPair14d: hasConsecPair,

            longNightWork7d: longNightWork7d,

            has24hRestAfter84hWork14d: has24After84,

            cards: cards

        )

    }

    private static func maxConsecutiveNightStreak(_ labels: [Date], tz: TimeZone) -> Int {

        guard !labels.isEmpty else { return 0 }

        var calendar = Calendar(identifier: .gregorian)

        calendar.timeZone = tz

        let sorted = labels.sorted()

        var best = 1

        var cur = 1

        for i in 1..<sorted.count {

            let prev = sorted[i-1]

            let expected = calendar.date(byAdding: .day, value: 1, to: prev)!

            if calendar.isDate(sorted[i], inSameDayAs: expected) {

                cur += 1

                best = max(best, cur)

            } else {

                cur = 1

            }

        }

        return best

    }

    // MARK: - Limits

    private static func limits(for scheme: FatigueScheme) -> (work24: TimeInterval, minRest24: TimeInterval, work7: TimeInterval, work14: TimeInterval) {

        switch scheme {

        case .standardHV:

            return (12*3600, 7*3600, 72*3600, 144*3600)

        case .bfmHV:

            // Core caps (from your screenshots): 14h/24h and 144h/14d.

            // 7d work cap differs by scheme/table; keep 72h as “base” and rely on BFM extras later.

            return (14*3600, 7*3600, 72*3600, 144*3600)

        default:

            return (0, 0, 0, 0)

        }

    }

    // MARK: - Aggregation helpers

    private static func sum(kind: SegmentKind, segments: [WorkRestSegment], in window: DateInterval, now: Date) -> TimeInterval {

        var total: TimeInterval = 0

        for s in segments where s.kind == kind {

            if let clipped = s.clipped(to: window, now: now) {

                total += clipped.duration

            }

        }

        return total

    }

    private static func maxContinuousStationaryRest(segments: [WorkRestSegment], in window: DateInterval, now: Date) -> TimeInterval {

        // Find max continuous REST where stationaryRest == true inside window.

        // Note: assumes segments are non-overlapping and in order; if not, you can sort by start.

        let sorted = segments.sorted { $0.start < $1.start }

        var best: TimeInterval = 0

        for s in sorted where s.kind == .rest && s.stationaryRest {

            guard let clipped = s.clipped(to: window, now: now) else { continue }

            best = max(best, clipped.duration)

        }

        return best

    }

    private static func hasContinuousStationaryRest(segments: [WorkRestSegment], minSeconds: TimeInterval, in window: DateInterval, now: Date) -> Bool {

        let sorted = segments.sorted { $0.start < $1.start }

        for s in sorted where s.kind == .rest && s.stationaryRest {

            guard let clipped = s.clipped(to: window, now: now) else { continue }

            if clipped.duration >= minSeconds { return true }

        }

        return false

    }

    // MARK: - Night rest breaks (Standard/BFM 14d structure)

    /// Returns qualifying night rest breaks in a rolling window:

    /// - stationary REST

    /// - continuous >= 7h

    /// - AND overlaps a “night rest window” (22:00–08:00)

    /// NOTE: This is a conservative approximation that works well for SimView tests.

    /// Later, you can refine with exact regulatory definitions and “night label” bucketing.

    // Returns unique "night labels" (22:00 start dates) that qualify in the window.

    private static func nightRestLabels(

        in window: DateInterval,

        segments: [WorkRestSegment],

        now: Date,

        tz: TimeZone

    ) -> [Date] {

        let sorted = segments.sorted { $0.start < $1.start }

        var calendar = Calendar(identifier: .gregorian)

        calendar.timeZone = tz

        var labels: [Date] = []

        for s in sorted where s.kind == .rest && s.stationaryRest {

            guard let clipped = s.clipped(to: window, now: now) else { continue }

            // This keeps your "rest must be at least 7h overall" guard

            // (doesn't block long rests; just ignores short ones).

            if clipped.duration < 7 * 3600 { continue }

            labels.append(contentsOf: qualifyingNightLabels(for: clipped, tz: tz))

        }

        // De-dupe by the day of the night label.

        let unique = Set(labels.map { calendar.startOfDay(for: $0) })

        return unique.sorted()

    }

    private static func nightRestBreaks(in window: DateInterval, segments: [WorkRestSegment], now: Date, tz: TimeZone) -> [DateInterval] {

        let sorted = segments.sorted { $0.start < $1.start }

        var results: [DateInterval] = []

        for s in sorted where s.kind == .rest && s.stationaryRest {

            guard let clipped = s.clipped(to: window, now: now) else { continue }

            if clipped.duration < 7*3600 { continue }

            // Must overlap some 22:00–08:00 window.

            if qualifiesAsNightRestStrict(rest: clipped, tz: tz) {

                results.append(clipped)

            }

        }

        return results

    }

    /// Detect if there exists at least one pair of night rests on consecutive “night labels”.

    /// “Night label” here = the date of the 22:00 start that the rest overlaps.

    private static func firstNightWindowStartOverlapped(by rest: DateInterval, calendar: Calendar) -> Date? {

        let anchorDays = [

            rest.start.addingTimeInterval(-24*3600),

            rest.start,

            rest.start.addingTimeInterval(24*3600)

        ]

        var candidates: [Date] = []

        for d in anchorDays {

            let dayStart = calendar.startOfDay(for: d)

            let winStart = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: dayStart)!

            let winEnd = calendar.date(byAdding: .hour, value: 10, to: winStart)! // 08:00 next day

            let nightWin = DateInterval(start: winStart, end: winEnd)

            if rest.intersection(with: nightWin) != nil {

                candidates.append(winStart)

            }

        }

        return candidates.sorted().first

    }

    private static func qualifiesAsNightRestStrict(rest: DateInterval, tz: TimeZone) -> Bool {

        // Rule: a night rest break is either:

        // 1) 24h continuous stationary rest, OR

        // 2) at least 7h continuous stationary rest that occurs within a single 22:00–08:00 window.

        if rest.duration >= 24 * 3600 { return true }

        var calendar = Calendar(identifier: .gregorian)

        calendar.timeZone = tz

        // Check nearby night windows so we don’t miss the correct one.

        let anchorDays = [

            rest.start.addingTimeInterval(-24*3600),

            rest.start,

            rest.start.addingTimeInterval(24*3600)

        ]

        for d in anchorDays {

            let dayStart = calendar.startOfDay(for: d)

            let winStart = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: dayStart)!

            let winEnd   = calendar.date(byAdding: .hour, value: 10, to: winStart)! // 08:00 next day

            let nightWin = DateInterval(start: winStart, end: winEnd)

            // Strict: rest must contain >=7h that lies inside the night window

            if let intersection = rest.intersection(with: nightWin),

               intersection.duration >= 7 * 3600 {

                return true

            }

        }

        return false

    }

    private static func maxConsecutiveNightRestStreak(_ rests: [DateInterval], tz: TimeZone) -> Int {

        var calendar = Calendar(identifier: .gregorian)

        calendar.timeZone = tz

        // Convert each qualifying rest to a “night label” (the day of the 22:00 start it belongs to)

        var labels: Set<Date> = []

        for r in rests {

            if let label = firstNightWindowStartOverlapped(by: r, calendar: calendar) {

                labels.insert(calendar.startOfDay(for: label))

            }

        }

        let sorted = labels.sorted()

        guard !sorted.isEmpty else { return 0 }

        var best = 1

        var current = 1

        for i in 1..<sorted.count {

            let prev = sorted[i - 1]

            let cur  = sorted[i]

            if let nextDay = calendar.date(byAdding: .day, value: 1, to: prev),

               calendar.isDate(cur, inSameDayAs: nextDay) {

                current += 1

                best = max(best, current)

            } else {

                current = 1

            }

        }

        return best

    }

    // MARK: - Render Metrics

    private static func metricRolling24h(

        work24: TimeInterval,

        work24Limit: TimeInterval,

        maxStationaryRest24: TimeInterval,

        minStationaryRest24: TimeInterval

    ) -> FatigueMetric {

        let workStr = "\(fmt(work24)) / \(fmt(work24Limit))"

        let remaining = max(work24Limit - work24, 0)

        let restOk = maxStationaryRest24 >= minStationaryRest24

        let sev: FatigueSeverity

        if work24 >= work24Limit { sev = .over }

        else if work24 >= work24Limit * 0.8 { sev = .warn }

        else { sev = restOk ? .ok : .warn }

        let detail = "Remain \(fmt(remaining)) • Max stationary rest \(fmt(maxStationaryRest24))"

        return FatigueMetric(

            title: "Rolling 24h",

            value: "Work \(workStr)",

            severity: sev,

            detail: detail

        )

    }

    private static func metricRolling7d(work7d: TimeInterval, work7Limit: TimeInterval, has24hContinuousRest: Bool) -> FatigueMetric {

        let sev: FatigueSeverity

        if work7d >= work7Limit { sev = .over }

        else if work7d >= work7Limit * 0.8 { sev = .warn }

        else { sev = has24hContinuousRest ? .ok : .warn }

        let detail = has24hContinuousRest ? "24h continuous rest ✅" : "Needs 24h continuous rest ⚠️"

        return FatigueMetric(

            title: "Rolling 7d",

            value: "Work \(fmt(work7d)) / \(fmt(work7Limit))",

            severity: sev,

            detail: detail

        )

    }

    // Returns all night-window starts (labels) that this REST qualifies for.

    // Qualification: overlap with the 22:00–08:00 window is >= 7h.

    private static func qualifyingNightLabels(for rest: DateInterval, tz: TimeZone) -> [Date] {

        var calendar = Calendar(identifier: .gregorian)

        calendar.timeZone = tz

        // We scan a range of days that cover the rest.

        // Start 1 day before to catch windows that begin before rest.start.

        let scanStart = calendar.startOfDay(for: rest.start.addingTimeInterval(-24*3600))

        let scanEnd   = calendar.startOfDay(for: rest.end.addingTimeInterval(24*3600))

        var labels: [Date] = []

        var day = scanStart

        while day <= scanEnd {

            let winStart = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: day)!

            let winEnd   = calendar.date(byAdding: .hour, value: 10, to: winStart)! // → 08:00 next day

            let nightWin = DateInterval(start: winStart, end: winEnd)

            if let overlap = rest.intersection(with: nightWin) {

                if overlap.duration >= 7*3600 {

                    labels.append(winStart) // label is the 22:00 start for that night

                }

            }

            day = calendar.date(byAdding: .day, value: 1, to: day)!

        }

        return labels

    }

    private static func metricRolling14d(

        work14d: TimeInterval,

        work14Limit: TimeInterval,

        nightRestCount: Int,

        nightRestRequiredTotal: Int,

        consecutiveStreak: Int

    ) -> FatigueMetric {

        // Severity considers both work cap and night-rest structure.

        var sev: FatigueSeverity = .ok

        if work14d >= work14Limit { sev = .over }

        else if work14d >= work14Limit * 0.8 { sev = .warn }

        // Night rest structure is “must have 4 total, including a consecutive pair”

        let hasConsecutivePair = consecutiveStreak >= 2

        if nightRestCount < nightRestRequiredTotal || !hasConsecutivePair {

            if sev == .ok { sev = .warn }

        }

        // Night rest UI: show as "X (min 4)" once compliant, so large numbers don’t look wrong.

        let nightText: String

        if nightRestCount >= nightRestRequiredTotal {

            let surplus = nightRestCount - nightRestRequiredTotal

            nightText = "Night rests \(nightRestCount) (min \(nightRestRequiredTotal), +\(surplus))"

        } else {

            nightText = "Night rests \(nightRestCount)/\(nightRestRequiredTotal)"

        }

        // Consecutive UI: show streak number (not just a tick)

        let streakText = hasConsecutivePair ? "Streak \(consecutiveStreak) ✅" : "Streak \(consecutiveStreak) ⚠️"

        let detail = "\(nightText) • \(streakText)"

        return FatigueMetric(

            title: "Rolling 14d",

            value: "Work \(fmt(work14d)) / \(fmt(work14Limit))",

            severity: sev,

            detail: detail

        )

    }

    static func build14DaySummary(

        segments: [WorkRestSegment],

        now: Date,

        tz: TimeZone = .current

    ) -> [DailyDriverSummary] {

        var calendar = Calendar(identifier: .gregorian)

        calendar.timeZone = tz

        let startOfToday = calendar.startOfDay(for: now)

        let windowStart = calendar.date(byAdding: .day, value: -13, to: startOfToday)!

        // Reuse existing night label logic

        let win14 = DateInterval(start: windowStart, end: now)

        let nightLabels = nightRestLabels(in: win14, segments: segments, now: now, tz: tz)

        var days: [DailyDriverSummary] = []

        for offset in 0..<14 {

            let dayStart = calendar.date(byAdding: .day, value: offset, to: windowStart)!

            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!

            let dayWindow = DateInterval(start: dayStart, end: dayEnd)

            var totalWork: TimeInterval = 0

            var firstStart: Date?

            var lastEnd: Date?

            for s in segments where s.kind == .work {

                guard let clipped = s.clipped(to: dayWindow, now: now) else { continue }

                totalWork += clipped.duration

                if firstStart == nil || clipped.start < firstStart! {

                    firstStart = clipped.start

                }

                if lastEnd == nil || clipped.end > lastEnd! {

                    lastEnd = clipped.end

                }

            }

            // Night rest label matches this calendar day?

            let hasNight = nightLabels.contains {

                calendar.isDate($0, inSameDayAs: dayStart)

            }

            days.append(

                DailyDriverSummary(

                    dayStart: calendar.startOfDay(for: dayStart),

                    firstWorkStart: firstStart,

                    lastWorkEnd: lastEnd,

                    totalWork: totalWork,

                    hasNightRest: hasNight

                )

            )

        }

        return days

    }

    private static func fmt(_ seconds: TimeInterval) -> String {

        let s = max(Int(seconds.rounded()), 0)

        let h = s / 3600

        let m = (s % 3600) / 60

        return "\(h)h \(m)m"

    }

}

  

struct DailyDriverSummary: Identifiable {

    let dayStart: Date   // startOfDay for that row

    var id: Date { dayStart }

    let firstWorkStart: Date?

    let lastWorkEnd: Date?

    let totalWork: TimeInterval

    let hasNightRest: Bool

    }
