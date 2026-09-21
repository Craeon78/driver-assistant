import SwiftUI

/// Slice F + G: minimal chronological reconstruction and End-Shift Gate Report.
public struct Chunk5GGateReportView: View {
    let report: Chunk5GGateReport
    let onDismiss: () -> Void

    public init(report: Chunk5GGateReport, onDismiss: @escaping () -> Void) {
        self.report = report; self.onDismiss = onDismiss
    }

    public var body: some View {
        NavigationStack {
            List {
                Section("SHIFT") {
                    row("Start", report.shiftStart.map { fmt($0) } ?? "—")
                    row("End", report.shiftEnd.map { fmt($0) } ?? "—")
                    row("Opening ODO", report.openingODO.map(String.init) ?? "—")
                    row("Closing ODO", report.closingODO.map(String.init) ?? "—")
                    row("Derived km", "\(report.derivedKm)")
                }
                Section("CARGO RECONSTRUCTION") {
                    row("Opening", report.cargoOpening.map(String.init).joined(separator: ", "))
                    row("Closing", report.cargoClosing.map(String.init).joined(separator: ", "))
                    row("Unresolved discrepancies", "\(report.unresolvedDiscrepancies)")
                }
                Section("INTERNAL CHECKS") {
                    check("Cargo arithmetic", report.cargoArithmeticOK)
                    check("ODO anchors", report.odoAnchorsOK)
                    check("Loads represented", report.loadsRepresented)
                    check("Deliveries represented", report.deliveriesRepresented)
                    check("Transfers represented", report.transfersRepresented)
                    check("Reconciliations represented", report.reconciliationsRepresented)
                    status("Persistence/replay", report.persistenceStatus)
                }
                Section("CHRONOLOGICAL EVENTS") {
                    ForEach(report.events) { ev in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(fmt(ev.timestamp))  \(ev.kind.rawValue.uppercased())")
                                .font(.caption.bold())
                            Text(ev.summary)
                            if !ev.detail.isEmpty {
                                Text(ev.detail).font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                Section {
                    Text(report.externalComparisonNote)
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                }
            }
            .navigationTitle("5G Gate Report")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDismiss)
                }
            }
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack { Text(label); Spacer(); Text(value).foregroundStyle(.secondary) }
    }
    private func check(_ label: String, _ ok: Bool) -> some View {
        HStack {
            Text(label); Spacer()
            Text(ok ? "PASS" : "FAIL")
                .foregroundStyle(ok ? .green : .red)
                .bold()
        }
    }
    private func status(_ label: String, _ value: Chunk5GCheckStatus) -> some View {
        HStack { Text(label); Spacer(); Text(value.rawValue).bold() }
    }
    private func fmt(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f.string(from: d)
    }
}
