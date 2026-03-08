
import SwiftUI

import Foundation

  

//======================================

// MARK: - Phase 1 Start Planner Card (Pre-Persistence Proxy)

//======================================

//

// Purpose:

// - "Plan next start" helper for drivers

// - Uses Phase 1 back-calc logic (AppModel.phase1_backCalculateFinish)

//

// Scope (pre-persistence):

// - Today-only rest proxy (not true rolling 24h)

// - Conservative heuristic (7h continuous rest + 12h total rest target)

// - Advisory only (no enforcement)

//

// Post-persistence evolution:

// - Will use real multi-day fatigue windows

// - True rolling 24h rest requirements

// - May move to Simulation screen (out of TodayView)

//

// Usage:

// - Shown in simulationview  at any time.

// - Lets driver pick desired start time → shows latest finish time

//

//======================================

  

struct Phase1StartPlannerCard: View {

  

    @EnvironmentObject var model: AppModel

    @State private var targetStart: Date = {

        let now = Date()

        return Calendar.current.date(bySettingHour: 4, minute: 0, second: 0, of: now) ?? now

    }()

    private var planningResult: Phase1StartPlanning? {

        model.phase1_backCalculateFinish(desiredStart: targetStart)

    }

    var body: some View {

        VStack(alignment: .leading, spacing: 8) {

            Text("Plan next start (Phase 1 proxy)")

                .font(.headline)

            DatePicker(

                "Desired start time",

                selection: $targetStart,

                displayedComponents: [.hourAndMinute]

            )

            .datePickerStyle(.compact)

            if let planning = planningResult {

                VStack(alignment: .leading, spacing: 4) {

                    Text("To start at: \(formatTimeShort(targetStart))")

                        .font(.subheadline)

                    Text("Latest legal finish: \(formatTimeShort(planning.latestFinishToStartAtDesired))")

                        .font(.caption)

                    Text("Rest today (≥15m): \(formatTimeHM(planning.restToday))")

                        .font(.caption2)

                        .foregroundColor(.secondary)

                    if planning.requiredRestAfterShift > 0 {

                        Text("Rest needed after finish: \(formatTimeHM(planning.requiredRestAfterShift))")

                            .font(.caption2)

                            .foregroundColor(.secondary)

                    } else {

                        Text("No additional rest required after finish (based on rest banked today).")

                            .font(.caption2)

                            .foregroundColor(.secondary)

                    }

                }

                .padding(.top, 6)

            }

        }

        .padding()

        .background(Color.gray.opacity(0.06))

        .cornerRadius(12)

    }

    private func formatTimeHM(_ seconds: TimeInterval) -> String {

        let s = max(0, Int(seconds))

        let h = s / 3600

        let m = (s % 3600) / 60

        return String(format: "%dh %02dm", h, m)

    }

    private func formatTimeShort(_ date: Date) -> String {

        let f = DateFormatter()

        f.timeStyle = .short

        f.dateStyle = .none

        return f.string(from: date)

    }

}
