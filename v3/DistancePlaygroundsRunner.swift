//======================================
// MARK: - DistancePlaygroundsRunner (V3 Chunk 2)
//======================================
//
// © 2026 Cory Russell Olsen. All rights reserved.
//
// Single entry point for the structural + regression layer of Chunk 2.
// Does not claim the final road-comparison gate.
//
// Phase: Chunk 2 — Distance truth engine
//======================================

import Foundation

public enum DistancePlaygroundsRunner {

    public static func runStructuralGate() -> String {
        var lines: [String] = []
        lines.append("=== V3 Chunk 2 Distance Truth — Structural Gate ===")

        let failures = DistanceGateTests.runAll()
        if failures.isEmpty {
            lines.append("All regression fixtures: PASS")
            lines.append("---")
            lines.append("STRUCTURAL PASS")
            lines.append("(Road-comparison gate still requires real drive data)")
        } else {
            lines.append("FAILURES:")
            failures.forEach { lines.append("  • \($0)") }
            lines.append("---")
            lines.append("STRUCTURAL FAIL")
        }
        return lines.joined(separator: "\n")
    }
}
