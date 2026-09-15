import Foundation

public enum Chunk35LongPeriodGateTests {
    public static func run() -> [String] {
        var out=["=== V3 Chunk 3.5a Long-Period Gate ==="]; var fail=0
        func ck(_ n:String,_ ok:Bool){out.append("\(n): \(ok ? "PASS":"FAIL")");if !ok{fail+=1}}
        let tz=TimeZone(identifier:"Australia/Brisbane")!; var c=Calendar(identifier:.gregorian);c.timeZone=tz
        func d(_ day:Int,_ h:Int,_ m:Int=0)->Date{c.date(from:DateComponents(year:2026,month:9,day:day,hour:h,minute:m))!}

        let seven=[WorkRestEntry(kind:.rest,start:d(15,20,45),end:d(16,3,45),stationaryRest:true),WorkRestEntry(kind:.work,start:d(16,3,45),end:d(16,6,0))]
        let s=StandardHoursPolicy.evaluate(entries:seven,asOf:d(16,6),baseTimeZone:tz)
        ck("7h major rest anchors 24h",s.windows(for:.twentyFourHours).contains{$0.anchor==d(16,3,45)})

        let fullDay=[WorkRestEntry(kind:.rest,start:d(14,6),end:d(15,6),stationaryRest:true),WorkRestEntry(kind:.work,start:d(15,6),end:d(16,6))]
        let s7=StandardHoursPolicy.evaluate(entries:fullDay,asOf:d(16,6),baseTimeZone:tz)
        ck("24h stationary rest anchors 7d",s7.windows(for:.sevenDays).contains{$0.anchor==d(15,6)})

        let nights=[
            WorkRestEntry(kind:.rest,start:d(13,22),end:d(14,5),stationaryRest:true),
            WorkRestEntry(kind:.work,start:d(14,5),end:d(14,22)),
            WorkRestEntry(kind:.rest,start:d(14,22),end:d(15,5),stationaryRest:true),
            WorkRestEntry(kind:.work,start:d(15,5),end:d(16,6))]
        let sn=StandardHoursPolicy.evaluate(entries:nights,asOf:d(16,6),baseTimeZone:tz)
        ck("Night rest can anchor 14d",sn.windows(for:.fourteenDays).count>=2)
        ck("Consecutive night pair detected",sn.windows(for:.fourteenDays).contains{$0.hasConsecutiveNightRestPair})

        let overlapping=[
            WorkRestEntry(kind:.rest,start:d(14,23),end:d(15,6),stationaryRest:true),
            WorkRestEntry(kind:.work,start:d(15,6),end:d(15,16)),
            WorkRestEntry(kind:.rest,start:d(15,16),end:d(15,23),stationaryRest:true),
            WorkRestEntry(kind:.work,start:d(15,23),end:d(16,6))]
        let so=StandardHoursPolicy.evaluate(entries:overlapping,asOf:d(16,6),baseTimeZone:tz)
        ck("Overlapping 24h anchors retained",Set(so.windows(for:.twentyFourHours).map{$0.anchor}).count==2)
        out.append("---");out.append(fail==0 ? "GATE PASS":"GATE FAIL (\(fail))");return out
    }
}
