
import SwiftUI

  

//======================================

// MARK: - Stopped While Driving Nudge Sheet

//======================================

//

// Purpose:

// - Alert driver when GPS shows sustained stop while marked "Driving"

// - Offer quick actions: Switch to Load / Unload / Keep Driving

//

// Trigger:

// - model.considerStoppedNudgeInLoad() detects:

//   - Speed ≤ 1 m/s for ≥ 90 seconds

//   - Driver is marked "Driving"

//   - Not on break

//

// Cooldown:

// - 5 minutes between nudges (prevents spam at traffic lights)

//

// Actions:

// - Switch to Load: sets isUnloadMode = false, calls model.pressLoad()

// - Switch to Unload: sets isUnloadMode = true, calls model.pressUnload()

// - Keep Driving (snooze): resets cooldown timer

// - Cancel: dismisses sheet only

//

// Design:

// - Compact layout (no scrolling needed)

// - Clear visual hierarchy

// - Non-alarmist language

//

// Pre-persistence:

// - No record of nudge shown/dismissed

//

// Post-persistence:

// - May create advisory event ("stopped nudge shown")

//

//======================================

  

struct StoppedNudgeSheet: View {

  

    let onLoad: () -> Void

    let onUnload: () -> Void

    let onKeepDriving: () -> Void

    let onCancel: () -> Void

    var body: some View {

        VStack(alignment: .leading, spacing: 14) {

            HStack {

                Image(systemName: "exclamationmark.triangle")

                Text("You appear to be stopped")

                    .font(.headline)

                Spacer()

            }

            Text("You're marked as Driving, but speed has been near zero for ~90 seconds. What would you like to do?")

                .font(.subheadline)

                .foregroundStyle(.secondary)

                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {

                Button(action: onLoad) {

                    Label("Switch to Load", systemImage: "shippingbox")

                        .frame(maxWidth: .infinity)

                }

                .buttonStyle(.borderedProminent)

                Button(action: onUnload) {

                    Label("Switch to Unload", systemImage: "tray.and.arrow.down")

                        .frame(maxWidth: .infinity)

                }

                .buttonStyle(.bordered)

                Button(action: onKeepDriving) {

                    Label("Keep driving (snooze)", systemImage: "car")

                        .frame(maxWidth: .infinity)

                }

                .buttonStyle(.bordered)

                Button(role: .cancel, action: onCancel) {

                    Text("Cancel")

                        .frame(maxWidth: .infinity)

                }

            }

            Spacer(minLength: 0)

        }

        .padding()

    }

}
