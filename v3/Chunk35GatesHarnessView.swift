import SwiftUI

public struct Chunk35GatesHarnessView: View {
    private let gates:[(String,[String])] = [
        ("3.5a — Long-period Standard Hours",Chunk35LongPeriodGateTests.run()),
        ("3.5b — Diary interpretation",Chunk35DiaryGateTests.run()),
        ("3.5c — Recovery / replay",Chunk35RecoveryGateTests.run()),
        ("3.5d — Driver surface",Chunk35DriverSurfaceGateTests.run())
    ]
    public init(){}
    public var body: some View {
        NavigationStack { ScrollView { VStack(alignment:.leading,spacing:22) {
            Text("Chunk 3.5 — Final Gates").font(.title2.bold())
            Text("Separate a–d harnesses • one canonical Driver ledger").font(.caption).foregroundStyle(.secondary)
            ForEach(Array(gates.enumerated()),id:\.offset){_,gate in
                VStack(alignment:.leading,spacing:6){
                    Text(gate.0).font(.headline)
                    ForEach(Array(gate.1.enumerated()),id:\.offset){_,line in
                        HStack(alignment:.firstTextBaseline,spacing:8){
                            if line.hasSuffix("PASS"){Image(systemName:"checkmark.circle.fill").foregroundStyle(.green)}
                            else if line.contains("FAIL"){Image(systemName:"xmark.octagon.fill").foregroundStyle(.red)}
                            Text(line).font(.system(.body,design:.monospaced)).textSelection(.enabled)
                        }
                    }
                }
                Divider()
            }
        }.frame(maxWidth:.infinity,alignment:.leading).padding() }.navigationTitle("Driver Assistant V3") }
    }
}
