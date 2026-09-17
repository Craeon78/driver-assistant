import SwiftUI

/// Temporary target-runtime harness for Chunk 5C.
/// The harness owns the overall gate verdict; ContentView only hosts this view.
public struct Chunk5CVehicleMassHarnessView: View {
    private let results: [String]
    private let gatePassed: Bool

    public init() {
        let checks = Chunk5CVehicleMassGateTests.run()
        self.results = checks
        self.gatePassed = checks.count == 9 && checks.allSatisfy { $0.hasPrefix("PASS") }
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("Chunk 5C — Vehicle Mass Integration")
                    .font(.title2)
                    .bold()

                ForEach(Array(results.enumerated()), id: \.offset) { _, result in
                    Text(result)
                        .font(.system(.body, design: .monospaced))
                }

                Divider()

                Text(gatePassed ? "GATE PASS" : "GATE FAIL")
                    .font(.headline)
                    .bold()
            }
            .padding()
        }
        .onAppear {
            print("=== CHUNK 5C — VEHICLE MASS INTEGRATION ===")
            results.forEach { print($0) }
            print(gatePassed ? "GATE PASS" : "GATE FAIL")
        }
    }
}