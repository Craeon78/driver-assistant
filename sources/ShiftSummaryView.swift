//======================================
// MARK: - ShiftSummaryView
//======================================
//
// Path:
// - Views/Today/ShiftSummaryView.swift
//
// Purpose:
// - Display a compact off-duty snapshot of the most recently ended shift.
// - Give the driver a quick recap of:
//   - start / end times
//   - work / rest / driving totals
//   - load / unload counts
//   - shift-distance context
//   - a simple next-start coaching hint
//
// Responsibilities:
// - Present a short “last shift” summary card when no shift is currently active.
// - Combine summary-level shift totals with selected derived coaching fields
//   that help the driver interpret how the shift ended.
// - Surface distance context using:
//   - corrected / ODO-side km
//   - live GPS km
//   - difference and percentage variance
// - Show a conservative Phase 1 next-start hint while full persistence and
//   multi-day fatigue logic are still under construction.
//
// Data sources:
// - `summary` supplies the ended-shift snapshot currently available.
// - `model` is still consulted for certain derived / transitional values
//   (for example Phase 1 rest and current distance comparison fields).
//
// Current limitations (pre-persistence):
// - This is still a transitional summary surface, not a final review/finalise flow.
// - Some values shown here are derived from live model state rather than a fully
//   frozen, reviewed shift snapshot.
// - “Earliest next legal start” remains a simplified coaching aid, not a final
//   compliance-grade legal verdict.
// - This view currently sits in a pre-persistence workflow where End Shift,
//   review, finalisation, export, and clearing are not yet fully separated.
//
// Architectural note:
// - Long-term, ending a shift should not immediately imply finalisation.
// - This card is expected to evolve into part of a broader end-of-shift review
//   flow where the driver may:
//   - inspect timeline truth
//   - resolve missing-km suggestions
//   - confirm final ODO context
//   - generate/export a final summary
// - Once persistence lands, this view should read from a frozen/reviewed shift
//   snapshot rather than from mutable live state.
//
// Future direction:
// - Replace live-state dependencies with reviewed persisted shift data.
// - Support stronger distance reconciliation output at shift close.
// - Add end-of-shift review / finalisation hooks.
// - Allow export / print / PDF style output from reviewed shift truth.
// - Replace Phase 1 next-start proxy with true rolling-window fatigue logic.
//======================================

import SwiftUI

struct ShiftSummaryView: View {
    let summary: ShiftSummary
    @EnvironmentObject var model: AppModel
    
    // Conservative “next start” hint (Phase 1 proxy)
    private var earliestSimpleStart: Date {
        let proposed = model.phase1_earliestNextStart(from: summary.end)
        // Phase 1 safety: never show a start time earlier than the shift end.
        return max(summary.end, proposed)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Last shift summary")
                .font(.headline)
            
            if let start = summary.start {
                Text("Start: \(formatTimeShort(start))")
            }
            Text("End:   \(formatTimeShort(summary.end))")
            
            Divider()
            
            Text("Work: \(formatTimeHM(summary.workSeconds))")
            Text("Rest: \(formatTimeHM(summary.restSeconds))")
            Text("Driving: \(formatTimeHM(summary.driveSeconds))")
            
            Divider()
            
            Text("Loads: \(summary.loadCount)")
            Text("Unloads: \(summary.unloadCount)")
            
            Divider()
            
            Divider()
            
            let correctedKm = model.shiftKmBySegmentsApprox
            let liveGpsKm = model.shiftKmLiveGps
            let diffKm = liveGpsKm - correctedKm
            let diffPct = correctedKm > 0 ? (diffKm / correctedKm) * 100.0 : 0.0
            
            Text("Shift distance summary")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("Corrected / ODO-side km: \(String(format: "%.1f", correctedKm))")
                .font(.caption)
            
            Text("Live GPS km: \(String(format: "%.1f", liveGpsKm))")
                .font(.caption)
            
            Text("Difference: \(diffKm >= 0 ? "+" : "")\(String(format: "%.1f", diffKm)) km (\(diffPct >= 0 ? "+" : "")\(String(format: "%.1f", diffPct))%)")
                .font(.caption)
                .foregroundColor(abs(diffPct) > 5 ? .orange : .secondary)
            
            // Transitional pre-persistence note:
            // this field still reads from live model state rather than a frozen reviewed
            // shift snapshot. That is acceptable temporarily, but it is not the intended
            // post-persistence design.
            Text("Legal rest today (≥15m blocks): \(formatTimeHM(model.phase1_restToday))")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if earliestSimpleStart <= summary.end.addingTimeInterval(60) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Next start (Phase 1 proxy)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("OK to start again now.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
            } else {
                Text("Earliest next start (Phase 1 proxy): \(formatTimeShort(earliestSimpleStart))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}
