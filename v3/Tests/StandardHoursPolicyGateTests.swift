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
        var cal = Calendar(identifier: .gregorian); cal.timeZone = tz
        func d(_ y:Int,_ m:Int,_ day:Int,_ h:Int,_ min:Int) -> Date {
            cal.date(from: DateComponents(year:y,month:m,day:day,hour:h,minute:min))!
        }

        let entries = [
            WorkRestEntry(kind:.rest,start:d(2026,9,16,2,30),end:d(2026,9,16,3,0),stationaryRest:true),
            WorkRestEntry(kind:.work,start:d(2026,9,16,3,0),end:d(2026,9,16,6,0)),
            WorkRestEntry(kind:.rest,start:d(2026,9,16,6,0),end:d(2026,9,16,6,20),stationaryRest:true),
            WorkRestEntry(kind:.work,start:d(2026,9,16,6,20),end:d(2026,9,16,8,0))
        ]
        let now=d(2026,9,16,8,0)
        let snap=StandardHoursPolicy.evaluate(entries:entries,asOf:now,baseTimeZone:tz)
        check("Every rest end creates 5.5h anchors",snap.windows(for:.fiveAndHalfHours).count==2)
        check("Every rest end creates 8h anchors",snap.windows(for:.eightHours).count==2)
        check("Every rest end creates 11h anchors",snap.windows(for:.elevenHours).count==2)
        check("Overlapping anchors retained",Set(snap.windows(for:.fiveAndHalfHours).map{$0.anchor}).count==2)

        let uncertain=StandardHoursPolicy.evaluate(entries:entries,asOf:now,historyUncertain:true,baseTimeZone:tz)
        check("Uncertain history never green",uncertain.windows.allSatisfy{$0.state == .uncertainHistory})

        let major=[
            WorkRestEntry(kind:.rest,start:d(2026,9,15,20,45),end:d(2026,9,16,3,45),stationaryRest:true),
            WorkRestEntry(kind:.work,start:d(2026,9,16,3,45),end:d(2026,9,16,8,0))
        ]
        let majorSnap=StandardHoursPolicy.evaluate(entries:major,asOf:now,baseTimeZone:tz)
        check("7h stationary rest anchors 24h",majorSnap.windows(for:.twentyFourHours).contains{$0.anchor==d(2026,9,16,3,45)})

        // Exact work boundary and one-minute over.
        let anchor=d(2026,9,16,3,0)
        let exact=[
            WorkRestEntry(kind:.rest,start:d(2026,9,16,2,30),end:anchor),
            WorkRestEntry(kind:.work,start:anchor,end:d(2026,9,16,8,15))
        ]
        let exactSnap=StandardHoursPolicy.evaluate(entries:exact,asOf:d(2026,9,16,8,15),baseTimeZone:tz)
        check("5.25h exact work is action due",exactSnap.activeWindows(for:.fiveAndHalfHours).contains{$0.state == .actionDue})
        let over=exact+[WorkRestEntry(kind:.work,start:d(2026,9,16,8,15),end:d(2026,9,16,8,16))]
        let overSnap=StandardHoursPolicy.evaluate(entries:over,asOf:d(2026,9,16,8,16),baseTimeZone:tz)
        check("One minute over work breaches",overSnap.activeWindows(for:.fiveAndHalfHours).contains{$0.state == .breach})

        // Completed 5.5h period with insufficient qualifying rest must breach.
        let noRest=[
            WorkRestEntry(kind:.rest,start:d(2026,9,16,2,45),end:anchor),
            WorkRestEntry(kind:.work,start:anchor,end:d(2026,9,16,8,0)),
            WorkRestEntry(kind:.rest,start:d(2026,9,16,8,0),end:d(2026,9,16,8,10))
        ]
        let noRestSnap=StandardHoursPolicy.evaluate(entries:noRest,asOf:d(2026,9,16,8,30),baseTimeZone:tz)
        check("Completed 5.5h needs 15m qualifying rest",noRestSnap.windows(for:.fiveAndHalfHours).contains{$0.anchor==anchor && $0.state == .breach})

        // Subsequent major rest must not erase the first 24h window.
        let overlapMajor=[
            WorkRestEntry(kind:.rest,start:d(2026,9,14,23,0),end:d(2026,9,15,6,0),stationaryRest:true),
            WorkRestEntry(kind:.work,start:d(2026,9,15,6,0),end:d(2026,9,15,16,0)),
            WorkRestEntry(kind:.rest,start:d(2026,9,15,16,0),end:d(2026,9,15,23,0),stationaryRest:true),
            WorkRestEntry(kind:.work,start:d(2026,9,15,23,0),end:d(2026,9,16,2,0))
        ]
        let overlapSnap=StandardHoursPolicy.evaluate(entries:overlapMajor,asOf:d(2026,9,16,2,0),baseTimeZone:tz)
        let anchors24=Set(overlapSnap.windows(for:.twentyFourHours).map{$0.anchor})
        check("Second major rest does not erase first 24h anchor",anchors24.contains(d(2026,9,15,6,0)) && anchors24.contains(d(2026,9,15,23,0)))

        // WWD projection is conservative and exact ledger survives.
        let odd=WorkRestEntry(kind:.work,start:d(2026,9,16,3,7),end:d(2026,9,16,4,2))
        let exactP=DiaryProjector.project(entries:[odd],mode:.actualExact,baseTimeZone:tz)[0]
        let wwd=DiaryProjector.project(entries:[odd],mode:.wwd,baseTimeZone:tz)[0]
        check("Projection preserves canonical start",exactP.actualStart==odd.start && wwd.actualStart==odd.start)
        check("WWD work does not understate interval",wwd.displayedStart<=odd.start && (wwd.displayedEnd ?? odd.end!)>=odd.end!)

        out.append("---")
        out.append(failures==0 ? "GATE PASS" : "GATE FAIL (\(failures) failure(s))")
        return out
    }
}
