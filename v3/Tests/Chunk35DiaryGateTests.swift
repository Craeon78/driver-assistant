import Foundation

public enum Chunk35DiaryGateTests {
    public static func run() -> [String] {
        var out=["=== V3 Chunk 3.5b Diary Projection Gate ==="];var fail=0
        func ck(_ n:String,_ ok:Bool){out.append("\(n): \(ok ? "PASS":"FAIL")");if !ok{fail+=1}}
        let tz=TimeZone(identifier:"Australia/Brisbane")!;var c=Calendar(identifier:.gregorian);c.timeZone=tz
        func d(_ day:Int,_ h:Int,_ m:Int)->Date{c.date(from:DateComponents(year:2026,month:9,day:day,hour:h,minute:m))!}
        let work=WorkRestEntry(kind:.work,start:d(16,3,7),end:d(16,4,2));let rest=WorkRestEntry(kind:.rest,start:d(16,4,2),end:d(16,4,29))
        let exact=DiaryProjector.project(entries:[work,rest],mode:.actualExact,baseTimeZone:tz)
        let wwd=DiaryProjector.project(entries:[work,rest],mode:.wwd,baseTimeZone:tz)
        let ewd=DiaryProjector.project(entries:[work,rest],mode:.ewdStyle,baseTimeZone:tz)
        let local=DiaryProjector.project(entries:[work,rest],mode:.localAreaRecord,baseTimeZone:tz)
        ck("Canonical timestamps preserved",wwd[0].actualStart==work.start && wwd[1].actualEnd==rest.end)
        ck("WWD work conservative",wwd[0].displayedStart<=work.start && wwd[0].displayedEnd!>=work.end!)
        ck("WWD rest conservative",wwd[1].displayedStart>=rest.start && wwd[1].displayedEnd!<=rest.end!)
        ck("EWD-style keeps exact occurrence time",ewd[0].displayedStart==exact[0].displayedStart && ewd[1].displayedEnd==exact[1].displayedEnd)
        ck("Local-area keeps exact occurrence time",local[0].displayedStart==work.start && local[1].displayedEnd==rest.end)
        let overnight=WorkRestEntry(kind:.work,start:d(15,23,53),end:d(16,0,17));let ow=DiaryProjector.project(entries:[overnight],mode:.wwd,baseTimeZone:tz)[0]
        ck("Cross-midnight WWD does not truncate",ow.displayedStart<=overnight.start && ow.displayedEnd!>=overnight.end!)
        out.append("---");out.append(fail==0 ? "GATE PASS":"GATE FAIL (\(fail))");return out
    }
}
