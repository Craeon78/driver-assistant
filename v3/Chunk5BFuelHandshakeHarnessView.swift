import SwiftUI

public struct Chunk5BFuelHandshakeHarnessView: View {
    private let lines = Chunk5BFuelHandshakeGateTests.run()
    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Chunk 5B — Fuel ↔ Cargo").font(.title2.bold())
                    Text("Fuel specialisation • generic Cargo ledger • residue/vapour • modularity regression").font(.caption).foregroundStyle(.secondary)
                    Divider()
                    ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            if line.hasPrefix("PASS") || line == "GATE PASS" { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
                            else if line.hasPrefix("FAIL") || line == "GATE FAIL" { Image(systemName: "xmark.octagon.fill").foregroundStyle(.red) }
                            Text(line).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .navigationTitle("Driver Assistant V3")
        }
    }
}
