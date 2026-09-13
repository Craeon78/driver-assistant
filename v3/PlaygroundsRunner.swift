//======================================
// MARK: - PlaygroundsRunner (V3 Chunk 1)
//======================================
//
// © 2026 Cory Russell Olsen. All rights reserved.
//
// Paste this into a Swift Playgrounds page (or run from any entry point)
// after the v3/Core and v3/Tests files are present.
//
// It exercises both the in-memory and file-backed stores and prints
// a clear GATE PASS / FAIL result. No XCTest required.
//
// Phase: Chunk 1 — Silent spine
//======================================

import Foundation

public enum PlaygroundsRunner {

    /// Run the full Chunk 1 gate against both store implementations.
    /// Returns a human-readable summary string.
    public static func runGate() -> String {
        var lines: [String] = []
        lines.append("=== V3 Chunk 1 Silent Spine Gate ===")

        // 1. In-memory (pure logic)
        let memory = InMemoryEventStore()
        let memFailures = SilentSpineGateTests.runAll(store: memory)
        if memFailures.isEmpty {
            lines.append("InMemoryEventStore: PASS")
        } else {
            lines.append("InMemoryEventStore: FAIL")
            memFailures.forEach { lines.append("  • \($0)") }
        }

        // 2. File-backed (crash/relaunch proof)
        do {
            let dir = FileManager.default.temporaryDirectory
                .appendingPathComponent("v3-gate-\(UUID().uuidString)", isDirectory: true)
            let fileStore = try FileEventStore(directory: dir)
            let fileFailures = SilentSpineGateTests.runAll(store: fileStore)
            if fileFailures.isEmpty {
                lines.append("FileEventStore: PASS")
            } else {
                lines.append("FileEventStore: FAIL")
                fileFailures.forEach { lines.append("  • \($0)") }
            }
            // Clean up temp directory
            try? FileManager.default.removeItem(at: dir)
        } catch {
            lines.append("FileEventStore: FAIL (setup error: \(error))")
        }

        let overall = lines.contains(where: { $0.contains("FAIL") }) ? "GATE FAIL" : "GATE PASS"
        lines.append("---")
        lines.append(overall)
        return lines.joined(separator: "\n")
    }
}
