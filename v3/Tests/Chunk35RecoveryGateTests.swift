import Foundation

public enum Chunk35RecoveryGateTests {
    public static func run() -> [String] {
        var out=["=== V3 Chunk 3.5c Recovery / Replay Gate ==="];var fail=0
        func ck(_ n:String,_ ok:Bool){out.append("\(n): \(ok ? "PASS":"FAIL")");if !ok{fail+=1}}
        let tz=TimeZone(identifier:"Australia/Brisbane")!;var c=Calendar(identifier:.gregorian);c.timeZone=tz
        func d(_ h:Int,_ m:Int=0)->Date{c.date(from:DateComponents(year:2026,month:9,day:16,hour:h,minute:m))!}
        let rest=WorkRestEntry(kind:.rest,start:d(2,30),end:d(3));let work=WorkRestEntry(kind:.work,start:d(3),end:d(6))
        let uncertain=RegulatoryHistory(entries:[rest,work],confidence:.uncertain,reason:"Missing work/rest history")
        let u=uncertain.evaluateStandardHours(asOf:d(6),baseTimeZone:tz)
        ck("Missing history never silently green",u.windows.allSatisfy{$0.state == .uncertainHistory})
        let late=WorkRestEntry(kind:.work,start:d(3),end:d(8),occurredAt:d(3),recordedAt:d(9))
        let corrected=uncertain.replacing(entryID:work.id,with:WorkRestEntry(id:work.id,kind:.work,start:late.start,end:late.end,occurredAt:late.occurredAt,recordedAt:late.recordedAt,provenance:.driverEntered))
        let r=corrected.evaluateStandardHours(asOf:d(8),baseTimeZone:tz)
        ck("Correction clears explicit uncertainty",r.historyUncertain==false)
        ck("Correction deterministically recalculates work",r.windows(for:.fiveAndHalfHours).contains{abs($0.work-5*3600)<1})
        let replay=corrected.evaluateStandardHours(asOf:d(8),baseTimeZone:tz)
        ck("Replay deterministic",r==replay)
        ck("Occurrence and recording time remain distinct",corrected.entries.contains{$0.id==work.id && $0.occurredAt==d(3) && $0.recordedAt==d(9)})
        out.append("---");out.append(fail==0 ? "GATE PASS":"GATE FAIL (\(fail))");return out
    }
}
