
import SwiftUI

  

//======================================

// MARK: - Shift summary card (Today tab)

//======================================

//

// Purpose (Phase 1 / v0.2):

// - Display a compact “last shift” snapshot when the driver is OFF DUTY.

// - Provide a simple “earliest next legal start” hint using Phase 1

//   back-calc logic (a conservative proxy until persistence + full rule engine).

//

// Data source:

// - `summary` is a precomputed ShiftSummary from AppModel.

// - `earliestSimpleStart` uses `phase1_earliestNextStart(from:)`

//

// Notes / limitations (pre-persistence):

// - This is *not* a full NHVR compliance engine across rolling windows.

// - “Earliest next legal start” is a simplified coaching aid, not a legal verdict.

// - Once persistence lands, this card can be powered by real multi-day history.

//

// Future (post-persistence):

// - Show shift duration, break compliance, and breaches with timestamps.

// - Allow tapping into History (day/week/fortnight/month) views.

// - Replace Phase 1 proxies with real rolling-window calculations.

//======================================

  

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

            Text("End:   \(formatTimeShort(summary.end))")

            Divider()

            Text("Work: \(formatTimeHM(summary.workSeconds))")

            Text("Rest: \(formatTimeHM(summary.restSeconds))")

            Text("Driving: \(formatTimeHM(summary.driveSeconds))")

            Divider()

            Text("Loads: \(summary.loadCount)")

            Text("Unloads: \(summary.unloadCount)")

            Divider()

            // This reads from the live model (today proxy), not from the shift summary.

            // That’s OK pre-persistence; post-persistence we’ll likely compute/restamp

            // rest figures per shift/day from stored segments.

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
