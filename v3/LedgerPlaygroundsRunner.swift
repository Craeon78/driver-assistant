//======================================
// MARK: - LedgerPlaygroundsRunner (V3 Chunk 3a)
//======================================
//
// © 2026 Cory Russell Olsen. All rights reserved.
//
// Playgrounds entry for Chunk 3a structural gate.
// Point ContentView at a view that prints runGate(), or call directly.
//
// Phase: Chunk 3a — Ledger spine
//======================================

import Foundation

public enum LedgerPlaygroundsRunner {
    public static func runGate() -> String {
        LedgerSpineGateTests.runAll()
    }
}
