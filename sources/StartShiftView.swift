
import SwiftUI

  

//======================================

// MARK: - Start shift sheet

//======================================

//

// Purpose (v0.2 / pre-persistence):

// - Starts an on-duty “shift” in AppModel.

// - Optionally lets the driver back-date the start time *for today*,

//   so the fatigue counters don’t pretend you started “right now” if you didn’t.

// - Triggers the mandatory start-of-shift odometer + suburb capture.

//

// What this is (and is not):

// - This is a driver assistant / logging convenience UI.

// - It does not attempt to “police” NHVR compliance; it helps the driver

//   keep their own records and avoid accidental undercounting.

//

// Notes / limitations (pre-persistence):

// - `firstWorkTime` only captures HH:MM today (DatePicker hour/min only).

//   If the driver started “yesterday” or across midnight, this won’t represent it.

//   Post-persistence: shift start should be an actual stored timestamp.

// - The “minutes” back-date is clamped to ≥ 0 (future times ignored).

// - Odo capture is queued after dismiss to avoid sheet-on-sheet weirdness.

//

// Future (post-persistence):

// - Replace “previousMinutes” with a stored shift start timestamp.

// - Allow selecting the actual start date/time (incl. yesterday) if needed.

// - Optionally capture location automatically (with manual override).

//======================================

  

enum BackfillKind: Hashable {

    case onDutyNotDriving

    case driving

    case rest

    case other(OtherActivity)

}

  

  

struct StartShiftView: View {

    @EnvironmentObject var model: AppModel

    @Binding var isPresented: Bool

    // Optional: “I actually started earlier today”

    @State private var firstWorkTime: Date = Date()

    @State private var backfillKind: BackfillKind = .onDutyNotDriving

  

    var body: some View {

        NavigationView {

            Form {

                Section(header: Text("Truck")) {

                    Text(model.settings.truckIdentifier.isEmpty

                         ? "Not set (see Settings)"

                         : model.settings.truckIdentifier)

                    .foregroundColor(.secondary)

                }

                Section(header: Text("First work time today (optional)")) {

                    Text("If you actually started earlier today, set the time you first went on duty. Leave as now if you're starting fresh.")

                        .font(.caption)

                        .foregroundColor(.secondary)

                        .fixedSize(horizontal: false, vertical: true)

                    DatePicker(

                        "First work today",

                        selection: $firstWorkTime,

                        displayedComponents: [.hourAndMinute]

                    )

                }

                if firstWorkTime < Date() {

                    Section(header: Text("Backfilled time counts as")) {

                        Picker("Type", selection: $backfillKind) {

                            Text("On duty (not driving)").tag(BackfillKind.onDutyNotDriving)

                            Text("Driving").tag(BackfillKind.driving)

                            Text("Rest / Break").tag(BackfillKind.rest)

                            if !model.otherActivities.isEmpty {

                                Divider()

                                ForEach(model.otherActivities) { act in

                                    Text("Other – \(act.name)").tag(BackfillKind.other(act))

                                }

                            }

                        }

                        .pickerStyle(.menu)

                        Text("This applies only to the minutes between your chosen First work time and now.")

                            .font(.caption)

                            .foregroundColor(.secondary)

                            .fixedSize(horizontal: false, vertical: true)

                    }

                }

                Section {

                    Toggle("Prestart done (optional)", isOn: $model.prestartDone)

                }

            }

            .navigationTitle("Start Shift")

            .toolbar {

                ToolbarItem(placement: .cancellationAction) {

                    Button("Cancel") { isPresented = false }

                }

                ToolbarItem(placement: .confirmationAction) {

                    Button("Start") {

                        let now = Date()

                        // Convert “firstWorkTime today” into a back-date delta (minutes).

                        // Future times are treated as 0 to avoid negative offsets.

                        let minutes: Int

                        if firstWorkTime < now {

                            minutes = Int(now.timeIntervalSince(firstWorkTime) / 60)

                        } else {

                            minutes = 0

                        }

                       model.startShift(previousMinutes: minutes, backfillKind: backfillKind)

                        // Close this sheet, then prompt mandatory odo/suburb.

                        // (Avoid presenting another sheet while this one is still up.)

                        isPresented = false

                    }

                }

            }

        }

    }

}
