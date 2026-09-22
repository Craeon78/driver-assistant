import Foundation

@MainActor
public enum Chunk5HPreflightPlaygroundsRunner {
    public static func runGate() -> String {
        let lines = Chunk5HIntegrationPreflightTests.run()
        let failed = lines.contains { $0.contains(": FAIL") }
        return (lines + [failed ? "PREFLIGHT FAIL" : "PREFLIGHT PASS — FIELD GATE STILL REQUIRED"]).joined(separator: "\n")
    }
}
