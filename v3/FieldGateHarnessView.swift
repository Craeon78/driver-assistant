//======================================
// MARK: - FieldGateHarnessView (V3 Chunk 3d)
//======================================
//
// © 2026 Cory Russell Olsen. All rights reserved.
//
// Truck-facing shell over ledger + daily + rolling fatigue.
// Not production Today UI — diagnostic field gate only.
//
// Phase: Chunk 3d — Field gate
//======================================

import SwiftUI

@MainActor
final class FieldGateModel: ObservableObject {
    @Published private(set) var entries: [WorkRestEntry] = []
    @Published private(set) var statusLine: String = "Ready — start Work or Rest when stationary if needed."
    @Published var lastError: String?

    private var ledger: WorkRestLedger?
    private let tz = TimeZone(identifier: "Australia/Brisbane") ?? .current

    var daily: DailyFatigueSnapshot {
        DailyFatigueEvaluator.evaluate(entries: entries, asOf: Date())
    }

    var rolling: RollingFatigueSnapshot {
        RollingFatigueEvaluator.evaluate(entries: entries, asOf: Date(), timeZone: tz)
    }

    var open: WorkRestEntry? {
        entries.first { $0.isOpen }
    }

    init() {
        bootstrap()
    }

    private func bootstrap() {
        do {
            let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            let store = try FileWorkRestLedgerStore(directory: dir, filename: "v3-field-gate-ledger.json")
            let led = try WorkRestLedger(store: store)
            self.ledger = led
            self.entries = led.allEntries()
            statusLine = entries.isEmpty
                ? "Ledger empty — fresh field run."
                : "Reloaded \(entries.count) entr\(entries.count == 1 ? "y" : "ies") from disk (relaunch-safe)."
        } catch {
            lastError = "\(error)"
            statusLine = "Ledger bootstrap failed."
        }
    }

    func refresh() {
        guard let ledger else { return }
        entries = ledger.allEntries()
    }

    func start(kind: WorkRestKind) {
        guard let ledger else { return }
        if let open {
            lastError = "Already open \(open.kind.rawValue) — end it first."
            return
        }
        do {
            let entry = WorkRestEntry(kind: kind, start: Date(), end: nil, stationaryRest: kind == .rest)
            try ledger.append(entry)
            refresh()
            statusLine = "Started \(kind.rawValue)."
            lastError = nil
        } catch {
            lastError = "\(error)"
        }
    }

    func endOpenSegment() {
        guard let ledger, let open else {
            lastError = "Nothing open to end."
            return
        }
        do {
            try ledger.close(id: open.id, at: Date())
            refresh()
            statusLine = "Closed \(open.kind.rawValue)."
            lastError = nil
        } catch {
            lastError = "\(error)"
        }
    }

    /// End shift must NOT wipe ledger (3a invariant).
    func markShiftEndedNote() {
        statusLine = "Shift end noted — ledger retained (\(entries.count) entries). No wipe."
        lastError = nil
    }

    func simulateRelaunch() {
        guard let ledger else { return }
        do {
            _ = try ledger.simulateRelaunch()
            refresh()
            statusLine = "Simulated relaunch — \(entries.count) entries restored."
            lastError = nil
        } catch {
            lastError = "\(error)"
        }
    }
}

struct FieldGateHarnessView: View {
    @StateObject private var model = FieldGateModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(model.statusLine)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if let err = model.lastError {
                        Text(err)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    controls
                    openBanner
                    dailyCard
                    rollingCard
                    ledgerList
                    fieldChecklist
                }
                .padding()
            }
            .navigationTitle("Chunk 3d Field Gate")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var controls: some View {
        VStack(spacing: 8) {
            HStack {
                Button("Start Work") { model.start(kind: .work) }
                    .buttonStyle(.borderedProminent)
                Button("Start Rest") { model.start(kind: .rest) }
                    .buttonStyle(.borderedProminent)
                Button("End segment") { model.endOpenSegment() }
                    .buttonStyle(.bordered)
            }
            HStack {
                Button("Shift end (no wipe)") { model.markShiftEndedNote() }
                    .buttonStyle(.bordered)
                Button("Simulate relaunch") { model.simulateRelaunch() }
                    .buttonStyle(.bordered)
                Button("Refresh") { model.refresh() }
                    .buttonStyle(.bordered)
            }
            .font(.footnote)
        }
    }

    @ViewBuilder
    private var openBanner: some View {
        if let open = model.open {
            Text("OPEN \(open.kind.rawValue.uppercased()) since \(open.start.formatted(date: .omitted, time: .shortened))")
                .font(.headline)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(open.kind == .work ? Color.blue.opacity(0.15) : Color.green.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private var dailyCard: some View {
        let d = model.daily
        return GroupBox("Daily (from ledger)") {
            VStack(alignment: .leading, spacing: 4) {
                row("Work", fmt(d.workSeconds))
                row("Legal rest (≥15m)", fmt(d.legalRestSeconds))
                row("Short rest", fmt(d.shortRestSeconds))
                row("Work since legal rest", fmt(d.workSinceLastLegalRest))
                row("Until 7.5h", fmtSigned(d.remainingUntil7h30))
                row("Until 10h", fmtSigned(d.remainingUntil10h))
                row("Until 12h cap", fmtSigned(d.remainingUntil12hCap))
                if d.isInRestLimbo15 {
                    Text("Rest limbo — \(fmt(d.secondsUntilLegal15)) until legal 15m")
                        .foregroundStyle(.orange)
                }
            }
            .font(.system(.body, design: .monospaced))
        }
    }

    private var rollingCard: some View {
        let r = model.rolling
        return GroupBox("Rolling Standard HV") {
            VStack(alignment: .leading, spacing: 4) {
                row("Work 24h", "\(fmt(r.work24))  remain \(fmtSigned(r.remainingWork24))")
                row("Max stat. rest 24h", fmt(r.maxContinuousStationaryRest24))
                row("Work 7d", "\(fmt(r.work7d))  remain \(fmtSigned(r.remainingWork7d))")
                row("Work 14d", "\(fmt(r.work14d))  remain \(fmtSigned(r.remainingWork14d))")
                row("24h rest in 7d", r.has24hContinuousRestIn7d ? "yes" : "no")
                row("Night rests 14d", "\(r.nightRestCount14d)")
                row("Consecutive night pair", r.hasConsecutiveNightRestPair14d ? "yes" : "no")
            }
            .font(.system(.body, design: .monospaced))
        }
    }

    private var ledgerList: some View {
        GroupBox("Ledger (\(model.entries.count))") {
            if model.entries.isEmpty {
                Text("Empty")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(model.entries) { e in
                    HStack {
                        Text(e.kind.rawValue)
                            .frame(width: 44, alignment: .leading)
                        Text(e.start.formatted(date: .numeric, time: .shortened))
                        Text("→")
                        Text(e.end.map { $0.formatted(date: .omitted, time: .shortened) } ?? "open")
                        Spacer()
                        if e.kind == .rest && e.stationaryRest {
                            Text("stat")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.system(.caption, design: .monospaced))
                }
            }
        }
    }

    private var fieldChecklist: some View {
        GroupBox("Field checklist (3d gate)") {
            VStack(alignment: .leading, spacing: 6) {
                Text("1. Start Work, drive a leg, End segment.")
                Text("2. Start Rest (≥15m once), confirm legal rest & limbo behaviour.")
                Text("3. Kill app mid-open segment → relaunch → open still there (or use Simulate relaunch).")
                Text("4. Leave a segment open across a long break; confirm daily/rolling still coherent.")
                Text("5. Shift end — ledger must not wipe.")
                Text("6. Optional overnight-open if you can leave the iPad running / relaunch next morning.")
                Text("Pass = fatigue truth still matches what you actually did.")
                    .fontWeight(.semibold)
            }
            .font(.footnote)
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
        }
    }

    private func fmt(_ t: TimeInterval) -> String {
        let s = Int(t.rounded())
        let h = s / 3600
        let m = (s % 3600) / 60
        return String(format: "%d:%02d", h, m)
    }

    private func fmtSigned(_ t: TimeInterval) -> String {
        let neg = t < 0
        let absT = abs(t)
        return (neg ? "−" : "") + fmt(absT)
    }
}

// Active harness entry for Playgrounds
typealias ContentView = FieldGateHarnessView
