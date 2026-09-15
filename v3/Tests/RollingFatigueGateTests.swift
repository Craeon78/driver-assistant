//======================================
// MARK: - RollingFatigueGateTests (V3 Chunk 3c)
//======================================

import Foundation

public enum RollingFatigueGateTests {

    public static func runAll() -> String {
        var lines: [String] = ["=== V3 Chunk 3c Rolling Fatigue Gate (Standard HV) ==="]
        var failures = 0

        func check(_ name: String, _ ok: Bool, _ detail: String = "") {
            if ok {
                lines.append("\(name): PASS")
            } else {
                failures += 1
                lines.append("\(name): FAIL \(detail)")
            }
        }

        let tz = TimeZone(identifier: "Australia/Brisbane") ?? .current
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz

        let now = Date()
        // 10h work inside last 24h
        let workStart = now.addingTimeInterval(-10 * 3600)
        let entries24: [WorkRestEntry] = [
            WorkRestEntry(kind: .work, start: workStart, end: now)
        ]
        let s24 = RollingFatigueEvaluator.evaluate(entries: entries24, asOf: now, timeZone: tz)
        check("Work24 ~10h", abs(s24.work24 - 10 * 3600) < 2, "got \(s24.work24)")
        check("Remaining24 ~2h", abs(s24.remainingWork24 - 2 * 3600) < 2)

        // 8h stationary rest in last 24h
        let restEntries: [WorkRestEntry] = [
            WorkRestEntry(kind: .rest, start: now.addingTimeInterval(-8 * 3600), end: now, stationaryRest: true)
        ]
        let sRest = RollingFatigueEvaluator.evaluate(entries: restEntries, asOf: now, timeZone: tz)
        check("Max stationary rest24 ~8h", abs(sRest.maxContinuousStationaryRest24 - 8 * 3600) < 2)

        // 25h continuous rest → qualifies 24h-in-7d
        let longRest: [WorkRestEntry] = [
            WorkRestEntry(kind: .rest, start: now.addingTimeInterval(-25 * 3600), end: now, stationaryRest: true)
        ]
        let sLong = RollingFatigueEvaluator.evaluate(entries: longRest, asOf: now, timeZone: tz)
        check("Has 24h continuous rest in 7d", sLong.has24hContinuousRestIn7d)

        // Multi-day work: 6h per day for 3 days → work7d ~18h
        var multi: [WorkRestEntry] = []
        for dayOffset in 1...3 {
            let dayStart = now.addingTimeInterval(-TimeInterval(dayOffset) * 24 * 3600)
            multi.append(WorkRestEntry(
                kind: .work,
                start: dayStart,
                end: dayStart.addingTimeInterval(6 * 3600)
            ))
        }
        let sMulti = RollingFatigueEvaluator.evaluate(entries: multi, asOf: now, timeZone: tz)
        check("Work7d ~18h", abs(sMulti.work7d - 18 * 3600) < 5, "got \(sMulti.work7d)")
        check("Work14d includes same", abs(sMulti.work14d - 18 * 3600) < 5)

        // Midnight does not zero rolling work: entry crossing midnight still counts in 24h window
        let beforeMidnight = now.addingTimeInterval(-20 * 3600)
        let cross: [WorkRestEntry] = [
            WorkRestEntry(kind: .work, start: beforeMidnight, end: now)
        ]
        let sCross = RollingFatigueEvaluator.evaluate(entries: cross, asOf: now, timeZone: tz)
        check("Cross-midnight work counts in 24h", sCross.work24 > 19 * 3600, "got \(sCross.work24)")

        // Empty
        let empty = RollingFatigueEvaluator.evaluate(entries: [], asOf: now, timeZone: tz)
        check("Empty zeros", empty.work24 == 0 && empty.work7d == 0 && empty.work14d == 0)

        // Over 12h in 24h → negative remaining
        let over: [WorkRestEntry] = [
            WorkRestEntry(kind: .work, start: now.addingTimeInterval(-13 * 3600), end: now)
        ]
        let sOver = RollingFatigueEvaluator.evaluate(entries: over, asOf: now, timeZone: tz)
        check("Over 12h negative remaining24", sOver.remainingWork24 < 0)

        lines.append("---")
        lines.append(failures == 0 ? "GATE PASS" : "GATE FAIL (\(failures) failure(s))")
        return lines.joined(separator: "\n")
    }
}
