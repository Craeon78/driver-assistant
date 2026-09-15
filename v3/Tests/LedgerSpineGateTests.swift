//======================================
// MARK: - LedgerSpineGateTests (V3 Chunk 3a)
//======================================
//
// © 2026 Cory Russell Olsen. All rights reserved.
//
// Structural gate for Work/Rest ledger spine.
// Playgrounds-callable; no Xcode test target required.
//
// Phase: Chunk 3a — Ledger spine
//======================================

import Foundation

public enum LedgerSpineGateTests {

    public static func runAll() -> String {
        var lines: [String] = ["=== V3 Chunk 3a Work/Rest Ledger Spine Gate ==="]
        var failures = 0

        func check(_ name: String, _ ok: Bool, _ detail: String = "") {
            if ok {
                lines.append("\(name): PASS")
            } else {
                failures += 1
                lines.append("\(name): FAIL \(detail)")
            }
        }

        // 1. Closed shift round-trip (in-memory)
        do {
            let store = InMemoryWorkRestLedgerStore()
            let ledger = try WorkRestLedger(store: store)
            let fabricated = WorkRestFabricator.closedShift()
            for e in fabricated { try ledger.append(e) }
            let loaded = ledger.allEntries()
            check("Closed shift count", loaded.count == 3, "got \(loaded.count)")
            check("Closed shift all closed", loaded.allSatisfy { !$0.isOpen })
            check("Kinds work|rest only", loaded.allSatisfy { $0.kind == .work || $0.kind == .rest })
        } catch {
            check("Closed shift", false, "\(error)")
        }

        // 2. File persist + simulate relaunch
        do {
            let dir = FileManager.default.temporaryDirectory.appendingPathComponent("v3-ledger-gate-\(UUID().uuidString)")
            let store = try FileWorkRestLedgerStore(directory: dir)
            let ledger = try WorkRestLedger(store: store)
            let fabricated = WorkRestFabricator.openShift()
            for e in fabricated { try ledger.append(e) }
            let before = ledger.allEntries()
            let after = try ledger.simulateRelaunch()
            check("Relaunch count", before.count == after.count)
            check("Relaunch open preserved", after.contains { $0.isOpen })
            check(
                "Relaunch ids stable",
                before.map(\.id) == after.map(\.id),
                "ids diverged"
            )
            try? FileManager.default.removeItem(at: dir)
        } catch {
            check("File relaunch", false, "\(error)")
        }

        // 3. Overnight-open: one entry crosses midnight conceptually; still open; not split
        do {
            let store = InMemoryWorkRestLedgerStore()
            let ledger = try WorkRestLedger(store: store)
            let (entries, afterMidnight) = WorkRestFabricator.overnightOpen()
            for e in entries { try ledger.append(e) }
            let open = ledger.openEntry()
            check("Overnight open exists", open != nil)
            check("Overnight single entry", ledger.allEntries().count == 1)
            if let open {
                let dur = open.duration(asOf: afterMidnight)
                check("Overnight duration spans midnight", dur > 2 * 3600, "dur=\(dur)")
                check("Overnight still open", open.isOpen)
            }
        } catch {
            check("Overnight open", false, "\(error)")
        }

        // 4. Shift end does not wipe history
        do {
            let store = InMemoryWorkRestLedgerStore()
            let ledger = try WorkRestLedger(store: store)
            for e in WorkRestFabricator.closedShift() { try ledger.append(e) }
            let countBefore = ledger.allEntries().count
            _ = ledger.assertHistoryPreservedAfterShiftEnd()
            check("Shift end preserves history", ledger.allEntries().count == countBefore)
        } catch {
            check("Shift end preserve", false, "\(error)")
        }

        // 5. Close open entry
        do {
            let store = InMemoryWorkRestLedgerStore()
            let ledger = try WorkRestLedger(store: store)
            for e in WorkRestFabricator.openShift() { try ledger.append(e) }
            let open = ledger.openEntry()!
            let closeAt = open.start.addingTimeInterval(3600)
            try ledger.close(id: open.id, at: closeAt)
            check("Close removes open", ledger.openEntry() == nil)
            check("Closed duration", ledger.allEntries().first { $0.id == open.id }?.end == closeAt)
        } catch {
            check("Close entry", false, "\(error)")
        }

        lines.append("---")
        if failures == 0 {
            lines.append("GATE PASS")
        } else {
            lines.append("GATE FAIL (\(failures) failure(s))")
        }
        return lines.joined(separator: "\n")
    }
}
