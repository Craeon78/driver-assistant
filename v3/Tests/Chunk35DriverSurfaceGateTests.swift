import Foundation

public struct RegulatoryPeriodHeadline: Sendable, Equatable {
    public let kind: StandardHoursPeriodKind
    public let state: RegulatoryComplianceState
    public let activeWindowCount: Int
    public let mostConstrainingWindow: StandardHoursCountingWindow?
}

public enum RegulatoryDriverSurface {
    public static func headlines(from snapshot: StandardHoursPolicySnapshot) -> [RegulatoryPeriodHeadline] {
        StandardHoursPeriodKind.allCases.map { kind in
            let active=snapshot.activeWindows(for:kind)
            let constraining=active.min { lhs,rhs in
                if lhs.state != rhs.state { return severity(lhs.state)>severity(rhs.state) }
                return lhs.remainingWork < rhs.remainingWork
            }
            return RegulatoryPeriodHeadline(kind:kind,state:constraining?.state ?? (snapshot.historyUncertain ? .uncertainHistory:.compliantAsOfNow),activeWindowCount:active.count,mostConstrainingWindow:constraining)
        }
    }
    private static func severity(_ s:RegulatoryComplianceState)->Int{switch s{case .breach:return 3;case .uncertainHistory:return 2;case .actionDue:return 1;case .compliantAsOfNow:return 0}}
}

public enum Chunk35DriverSurfaceGateTests {
    public static func run()->[String]{
        var out=["=== V3 Chunk 3.5d Driver Surface Gate ==="];var fail=0
        func ck(_ n:String,_ ok:Bool){out.append("\(n): \(ok ? "PASS":"FAIL")");if !ok{fail+=1}}
        let tz=TimeZone(identifier:"Australia/Brisbane")!;var c=Calendar(identifier:.gregorian);c.timeZone=tz
        func d(_ h:Int,_ m:Int=0)->Date{c.date(from:DateComponents(year:2026,month:9,day:16,hour:h,minute:m))!}
        let e=[WorkRestEntry(kind:.rest,start:d(2,30),end:d(3)),WorkRestEntry(kind:.work,start:d(3),end:d(5)),WorkRestEntry(kind:.rest,start:d(5),end:d(5,20)),WorkRestEntry(kind:.work,start:d(5,20),end:d(7))]
        let s=StandardHoursPolicy.evaluate(entries:e,asOf:d(7),baseTimeZone:tz);let h=RegulatoryDriverSurface.headlines(from:s)
        ck("One headline per Standard Hours period",h.count==StandardHoursPeriodKind.allCases.count)
        ck("Headline retains underlying active-window count",h.first{$0.kind == .eightHours}?.activeWindowCount==2)
        ck("Most-constraining window remains inspectable",h.first{$0.kind == .eightHours}?.mostConstrainingWindow != nil)
        let u=StandardHoursPolicy.evaluate(entries:e,asOf:d(7),historyUncertain:true,baseTimeZone:tz);let uh=RegulatoryDriverSurface.headlines(from:u)
        ck("Driver surface exposes uncertainty",uh.filter{$0.activeWindowCount>0}.allSatisfy{$0.state == .uncertainHistory})
        out.append("---");out.append(fail==0 ? "GATE PASS":"GATE FAIL (\(fail))");return out
    }
}
