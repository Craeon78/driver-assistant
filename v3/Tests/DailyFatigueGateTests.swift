//======================================
// MARK: - DailyFatigueGateTests (V3 Chunk 3b)
//======================================
//
// © 2026 Cory Russell Olsen. All rights reserved.
//
// Phase: Chunk 3b — Daily fatigue from ledger
//======================================

import Foundation

public enum DailyFatigueGateTests {

    public static func runAll() -> String {
        var lines: [String] = ["=== V3 Chunk 3b Daily Fatigue Gate ==="]
        var failures = 0

        func check(_ name: String, _ ok: Bool, _ detail: String = "") {
            if ok {
                lines.append("\(name): PASS")
            } else {
                failures += 1
                lines.append("\(name): FAIL \(detail)")
            }
        }

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Australia/Brisbane") ?? .current
        let day = cal.startOfDay(for: Date())
        let t: (Int, Int) -> Date = { h, m in
            cal.date(bySettingHour: h, minute: m, second: 0, of: day)!
        }

        // Script: 06:00–11:00 work (5h), 11:00–11:20 rest (20m legal), 11:20–13:20 work (2h)
        let entries: [WorkRestEntry] = [
            WorkRestEntry(kind: .work, start: t(6, 0), end: t(11, 0)),
            WorkRestEntry(kind: .rest, start: t(11, 0), end: t(11, 20), stationaryRest: true),
            WorkRestEntry(kind: .work, start: t(11, 20), end: t(13, 20))
        ]
        let now = t(13, 20)
        let snap = DailyFatigueEvaluator.evaluate(entries: entries, asOf: now, calendar: cal)

        check("Work 7h", abs(snap.workSeconds - 7 * 3600) < 1, "got \(snap.workSeconds)")
        check("Legal rest 20m", abs(snap.legalRestSeconds - 20 * 60) < 1, "got \(snap.legalRestSeconds)")
        check("Work since legal ~2h", abs(snap.workSinceLastLegalRest - 2 * 3600) < 1, "got \(snap.workSinceLastLegalRest)")
        check("Not limbo", snap.isInRestLimbo15 == false)
        check("Remaining 12h cap ~5h", abs(snap.remainingUntil12hCap - 5 * 3600) < 1)

        // Limbo: open rest 10 minutes
        let limboEntries: [WorkRestEntry] = [
            WorkRestEntry(kind: .work, start: t(6, 0), end: t(10, 0)),
            WorkRestEntry(kind: .rest, start: t(10, 0), end: nil, stationaryRest: true)
        ]
        let limboNow = t(10, 10)
        let limbo = DailyFatigueEvaluator.evaluate(entries: limboEntries, asOf: limboNow, calendar: cal)
        check("Limbo active", limbo.isInRestLimbo15)
        check("Until legal ~5m", abs(limbo.secondsUntilLegal15 - 5 * 60) < 2, "got \(limbo.secondsUntilLegal15)")
        check("Open kind rest", limbo.openKind == .rest)

        // Short closed rest <15m does not count as legal
        // Work 06:00–09:00 (3h) + 09:10–10:10 (1h) = 4h; rest 10m not legal
        let shortEntries: [WorkRestEntry] = [
            WorkRestEntry(kind: .work, start: t(6, 0), end: t(9, 0)),
            WorkRestEntry(kind: .rest, start: t(9, 0), end: t(9, 10), stationaryRest: true),
            WorkRestEntry(kind: .work, start: t(9, 10), end: t(10, 10))
        ]
        let shortSnap = DailyFatigueEvaluator.evaluate(entries: shortEntries, asOf: t(10, 10), calendar: cal)
        check("Short rest not legal", shortSnap.legalRestSeconds < 1, "got \(shortSnap.legalRestSeconds)")
        check("Work includes full day work", abs(shortSnap.workSeconds - 4 * 3600) < 1, "got \(shortSnap.workSeconds)")

        // Over cap → negative remaining
        let overEntries: [WorkRestEntry] = [
            WorkRestEntry(kind: .work, start: t(4, 0), end: t(17, 0))
        ]
        let over = DailyFatigueEvaluator.evaluate(entries: overEntries, asOf: t(17, 0), calendar: cal)
        check("Over 12h negative remaining", over.remainingUntil12hCap < 0)

        // Ledger-only: evaluate uses provided entries array only (no hidden session)
        let empty = DailyFatigueEvaluator.evaluate(entries: [], asOf: now, calendar: cal)
        check("Empty ledger zero work", empty.workSeconds == 0)

        lines.append("---")
        lines.append(failures == 0 ? "GATE PASS" : "GATE FAIL (\(failures) failure(s))")
        return lines.joined(separator: "\n")
    }
}
