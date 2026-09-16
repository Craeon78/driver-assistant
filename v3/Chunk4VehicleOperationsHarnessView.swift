import SwiftUI

public struct Chunk4VehicleOperationsHarnessView: View {
    private let lines = Chunk4VehicleOperationsGateTests.run()
    public init() {}
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Chunk 2 ↔ Chunk 4 Integration").font(.title2.bold())
                    Text("Pre-commit vehicle boundary • authoritative ODO • single-use distance evidence • replay").font(.caption).foregroundStyle(.secondary)
                    Divider()
                    ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            if line.hasSuffix("PASS") { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
                            else if line.contains("FAIL") { Image(systemName: "xmark.octagon.fill").foregroundStyle(.red) }
                            Text(line).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                        }
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).padding()
            }.navigationTitle("Driver Assistant V3")
        }
    }
}
