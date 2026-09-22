import Foundation

@MainActor
public enum Chunk5GFinalFieldRepairsPlaygroundsRunner {
    /// Executable Playgrounds entry point for the bounded final-field repair gate.
    public static func runGate() -> String {
        let suites = [
            Chunk5GFinalFieldRepairTests.run(),
            Chunk5GFieldTest02ExceptionTests.run(),
            Chunk5GRecoveryMigrationTests.run()
        ]
        let lines = suites.flatMap { $0 }
        return (lines + ["=== FINAL ===", lines.contains(where: { $0.contains(": FAIL") || $0 == "GATE FAIL" }) ? "GATE FAIL" : "GATE PASS"]).joined(separator: "\n")
    }
}
