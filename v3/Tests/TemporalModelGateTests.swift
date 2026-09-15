//======================================
// MARK: - TemporalModelGateTests (V3 Chunk 3d)
//======================================
//
// Fabricated cross-midnight fixtures — no overnight wait required.
// Proves calendar vs episode vs rolling answer different questions.
//
//======================================

import Foundation

public enum TemporalModelGateTests {

    public static func runAll() -> String {
        var lines: [String] = ["=== V3 Temporal Model Gate (calendar ≠ episode ≠ rolling) ==="]
        var failures = 0

        func check(_ name: String, _ ok: Bool, _ detail: String = "") {
            if ok { lines.append("\(name): PASS") }
            else { failures += 1; lines.append("\(name): FAIL \(detail)") }
        }

        let tz = TimeZone(identifier: "Australia/Brisbane") ?? .current
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz

        // Fixed “now” = 16 Sep 2026 03:24 AEST
        var sep16 = DateComponents()
        sep16.year = 2026; sep16.month = 9; sep16.day = 16
        sep16.hour = 3; sep16.minute = 24
        let now = cal.date(from: sep16)!

        // Rest 15 Sep 20:45 → still open at 03:24 (continuous 6h39)
        var sep15 = DateComponents()
        sep15.year = 2026; sep15.month = 9; sep15.day = 15
        sep15.hour = 20; sep15.minute = 45
        let restStart = cal.date(from: sep15)!

        // Small work earlier on 15th so previous day has work
        sep15.hour = 8; sep15.minute = 0
        let workStart = cal.date(from: sep15)!
        sep15.hour = 8; sep15.minute = 30
        let workEnd = cal.date(from: sep15)!

        let entries: [WorkRestEntry] = [
            WorkRestEntry(kind: .work, start: workStart, end: workEnd),
            WorkRestEntry(kind: .rest, start: restStart, end: nil, stationaryRest: true)
        ]

        // --- Episode: continuous rest ~6:39 ---
        let episode = EpisodeFatigueEvaluator.current(entries: entries, asOf: now)
        let expectedEpisode: TimeInterval = now.timeIntervalSince(restStart)
        check("Episode is open rest", episode.kind == .rest && episode.isOpen)
        check("Episode duration ~6h39", abs(episode.duration - expectedEpisode) < 2, "got \(episode.duration)")
        check("Episode is legal rest", episode.isLegalRest)
        check("Episode not limbo", !episode.isLimbo)

        // --- Calendar current day (16th): rest from midnight→03:24 only ---
        let current = CalendarFatigueEvaluator.currentDay(entries: entries, asOf: now, calendar: cal)
        let dayStart16 = cal.startOfDay(for: now)
        let expectedCurrentRest = now.timeIntervalSince(dayStart16) // 3h24
        check("Current day work 0", current.work < 1, "got \(current.work)")
        check("Current day legal rest ~3h24", abs(current.legalRest - expectedCurrentRest) < 2, "got \(current.legalRest)")

        // --- Calendar previous day (15th): rest 20:45→midnight + work 0:30 ---
        let prev = CalendarFatigueEvaluator.previousDay(entries: entries, asOf: now, calendar: cal)
        let midnight = dayStart16
        let expectedPrevRest = midnight.timeIntervalSince(restStart) // ~3h15
        check("Previous day work 0:30", abs(prev.work - 30 * 60) < 2, "got \(prev.work)")
        check("Previous day legal rest ~3h15", abs(prev.legalRest - expectedPrevRest) < 2, "got \(prev.legalRest)")

        // --- Both figures differ (the bug report insight) ---
        check("Episode ≠ current calendar rest", abs(episode.duration - current.legalRest) > 60)

        // --- Rolling max stationary rest uses full continuous episode ---
        let rolling = RollingFatigueEvaluator.evaluate(entries: entries, asOf: now, timeZone: tz)
        check("Rolling max stat rest ~6h39", abs(rolling.maxContinuousStationaryRest24 - expectedEpisode) < 2, "got \(rolling.maxContinuousStationaryRest24)")

        // --- Shift spanning midnight ---
        let shift = ShiftBoundary(start: workStart, end: nil)
        let shiftSnap = ShiftFatigueEvaluator.evaluate(entries: entries, boundary: shift, asOf: now)
        check("Shift work 0:30", abs(shiftSnap.work - 30 * 60) < 2)
        check("Shift rest ~6h39", abs(shiftSnap.rest - expectedEpisode) < 2, "got \(shiftSnap.rest)")

        // --- Shift end does not wipe ability to read ledger ---
        let closedShift = ShiftBoundary(start: workStart, end: now)
        let closedSnap = ShiftFatigueEvaluator.evaluate(entries: entries, boundary: closedShift, asOf: now)
        check("Closed shift still has work", closedSnap.work > 0)
        check("Entries still 2", entries.count == 2)

        lines.append("---")
        lines.append(failures == 0 ? "GATE PASS" : "GATE FAIL (\(failures) failure(s))")
        return lines.joined(separator: "\n")
    }
}
