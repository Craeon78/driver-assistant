//======================================
// MARK: - StandardHoursPolicy Gate Tests
//======================================

import Foundation

public enum StandardHoursPolicyGateTests {

    public static func run() -> [String] {
        var out: [String] = ["=== V3 Chunk 3.5 Standard Hours Policy Gate ==="]
        var failures = 0
        func check(_ name: String, _ value: Bool) {
            out.append("\(name): \(value ? "PASS" : "FAIL")")
            if !value { failures += 1 }
        }

        let tz = TimeZone(identifier: "Australia/Brisbane")!
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        func d(_ y: Int, _ m: Int, _ day: Int, _ h: Int, _ min: Int) -> Date {
            cal.date(from: DateComponents(year: y, month: m, day: day, hour: h, minute: min))!
        }

        // Rest 02:30→03:00 creates the sub-24h anchors.
        let entries = [
            WorkRestEntry(kind: .rest, start: d(2026,9,16,2,30), end: d(2026,9,16,3,0), stationaryRest: true),
            WorkRestEntry(kind: .work, start: d(2026,9,16,3,0), end: d(2026,9,16,6,0)),
            WorkRestEntry(kind: .rest, start: d(2026,9,16,6,0), end: d(2026,9,16,6,20), stationaryRest: true),
            WorkRestEntry(kind: .work, start: d(2026,9,16,6,20), end: d(2026,9,16,8,0))
        ]
        let now = d(2026,9,16,8,0)
        let snap = StandardHoursPolicy.evaluate(entries: entries, asOf: now, baseTimeZone: tz)

        let five = snap.windows(for: .fiveAndHalfHours)
        let eight = snap.windows(for: .eightHours)
        let eleven = snap.windows(for: .elevenHours)
        check("Every rest end creates 5.5h anchors", five.count == 2)
        check("Every rest end creates 8h anchors", eight.count == 2)
        check("Every rest end creates 11h anchors", eleven.count == 2)
        check("Overlapping anchors retained", Set(five.map { $0.anchor }).count == 2)
        check("First 5.5h work ~4h40", abs((five.first?.work ?? 0) - (4 * 3600 + 40 * 60)) < 1)

        let uncertain = StandardHoursPolicy.evaluate(entries: entries, asOf: now, historyUncertain: true, baseTimeZone: tz)
        check("Uncertain history never green", uncertain.windows.allSatisfy { $0.state == .uncertainHistory })

        // 7h major rest creates a 24h anchor at its end.
        let major = [
            WorkRestEntry(kind: .rest, start: d(2026,9,15,20,45), end: d(2026,9,16,3,45), stationaryRest: true),
            WorkRestEntry(kind: .work, start: d(2026,9,16,3,45), end: d(2026,9,16,8,0))
        ]
        let majorSnap = StandardHoursPolicy.evaluate(entries: major, asOf: now, baseTimeZone: tz)
        let w24 = majorSnap.windows(for: .twentyFourHours)
        check("7h stationary rest anchors 24h", w24.contains { $0.anchor == d(2026,9,16,3,45) })

        // Projection must preserve actual timestamps while WWD display is conservative.
        let odd = WorkRestEntry(kind: .work, start: d(2026,9,16,3,7), end: d(2026,9,16,4,2))
        let exact = DiaryProjector.project(entries: [odd], mode: .actualExact, baseTimeZone: tz)[0]
        let wwd = DiaryProjector.project(entries: [odd], mode: .wwd, baseTimeZone: tz)[0]
        check("Projection preserves canonical start", exact.actualStart == odd.start && wwd.actualStart == odd.start)
        check("WWD work does not understate interval", wwd.displayedStart <= odd.start && (wwd.displayedEnd ?? odd.end!) >= odd.end!)

        out.append("---")
        out.append(failures == 0 ? "GATE PASS" : "GATE FAIL (\(failures) failure(s))")
        return out
    }
}
