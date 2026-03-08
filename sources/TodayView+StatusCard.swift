
import SwiftUI

  

extension TodayView {

    //======================================

    // MARK: - Todayview+StatusCard (Top-Left Panel)

    //======================================

    //

    // Purpose:

    // - Quick-glance shift status

    // - Driver name, truck ID, odometer, location

    // - Work/rest/drive totals (both human and NHVR views)

    // - Start Shift / End Shift primary actions

    //

    // Displays:

    // - OFF DUTY state: "Start Shift" button

    // - ON DUTY state: current status, totals, "End Shift" button

    //

    // NHVR totals (Phase 1 scope):

    // - NHVR work = work + short rest (<15m)

    // - Legal rest = sum of >=15m rest blocks

    // - Short rest shown separately with explainer

    //

    // Post-persistence:

    // - May add shift ID, multi-day context

    // - May link to History screen

    //

    //======================================

    private func kmDisplay(_ km: Double) -> String {

        if km >= 10 {

            return "\(Int(km.rounded()))"

        } else {

            return String(format: "%.1f", km)

        }

    }

    var statusCard: some View {

  

        VStack(alignment: .leading, spacing: 8) {

            if !model.isOnDuty {

                Text("STATUS: OFF DUTY")

                    .font(.headline)

                Text("Tap Start Shift to begin.")

                    .font(.subheadline)

                Button(action: { showingStartShift = true }) {

                    Text("▶ Start Shift")

                        .font(.headline)

                        .padding(.vertical, 8)

                        .frame(maxWidth: .infinity)

                        .background(Color.blue.opacity(0.15))

                        .cornerRadius(8)

                }

            } else {

                Text("STATUS: \(currentStatusText)")

                    .font(.headline)

                Text(model.settings.driverName)

                    .font(.subheadline)

                let truckLabel = model.settings.truckIdentifier.isEmpty

                ? "Truck"

                : model.settings.truckIdentifier

                // Truck + odo line

                if !model.odoText.isEmpty {

                    Text("\(truckLabel) · Odo: \(model.odoText)")

                        .font(.subheadline)

                } else {

                    Text(truckLabel)

                        .font(.subheadline)

                }

                if let last = model.odoLocationRecords.last {

                    Text("Last odo: \(last.timestamp, style: .time)")

                        .font(.caption)

                        .foregroundColor(.secondary)

                }

                let segKm   = model.currentSegmentKmApprox          // segment (by segments model)

                let shiftKm = model.shiftKmBySegmentsApprox         // shift (by segments model)

                // Optional: show live GPS too (separately), because it will drift by design.

                let liveKm  = model.shiftKmLiveGps                  // raw LM accumulator

                Text("Km this segment: \(kmDisplay(segKm))")

                Text("Km this shift: \(kmDisplay(shiftKm))")

                // optional debug line:

                Text("Km live GPS: \(kmDisplay(liveKm))")

                    .font(.caption2)

                    .foregroundStyle(.secondary)

                // Manual odo update (always available while on duty)

                Button("Add odo reading") {

                    model.requestOdoCapture(.odoUpdate)

                }

                .font(.caption)

                .buttonStyle(.borderless)

                HStack {

                    Text("Drive today:")

                    Text(formatTimeHM(model.driveSecondsToday))

                        .bold()

                }

                .font(.subheadline)

                VStack(alignment: .leading, spacing: 2) {

                    // Human totals

                    HStack {

                        Text("Work today: \(formatTimeHM(model.workSecondsToday))")

                        Spacer()

                        Text("Rest today: \(formatTimeHM(model.restSecondsToday))")

                    }

                    // NHVR lens totals

                    HStack {

                        Text("NHVR work: \(formatTimeHM(model.nhvrWorkSecondsToday))")

                        Spacer()

                        Text("Legal rest:  \(formatTimeHM(model.legalRestSecondsToday))")

                            .bold()

                    }

                    if model.shortRestSecondsToday > 0 {

                        Text("Short rest (<15m): \(formatTimeHM(model.shortRestSecondsToday))")

                            .font(.caption)

                        Text("Counts as work for NHVR")

                            .font(.caption2)

                            .foregroundColor(.secondary)

                    }

                }

                .font(.caption)

                .foregroundColor(.secondary)

                Button(action: {

                    model.endShift()

                }) {

                    Text("End Shift")

                        .font(.subheadline)

                        .padding(.horizontal, 12)

                        .padding(.vertical, 6)

                        .background(Color.red.opacity(0.15))

                        .cornerRadius(8)

                }

                .disabled(!model.canPressEndShift)

                .padding(.top, 4)

            }

            if let reason = model.activityDisabledReason {

                Text(reason)

                    .font(.caption)

                    .foregroundColor(.secondary)

            }

        }

        // ✅ These now style the WHOLE CARD (both duty states)

        .padding()

        .background(Color.gray.opacity(0.1))

        .cornerRadius(12)

    }

  

}
