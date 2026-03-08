
import SwiftUI

  

//======================================

// MARK: - Load planning screen (container)

//======================================

//

// Purpose:

// - Hosts the entire Load workflow.

// - Splits the screen into:

//   • Left panel: data entry, templates, actions

//   • Right panel: printable-style load sheet + placard

//

// Design notes:

// - This is intentionally a *wide* split view.

// - On iPad, this behaves like a two-column workspace.

// - On smaller devices, future work may collapse panels

//   (but NOT in Phase 1 / pre-persistence).

//======================================

  

struct LoadPlanView: View {

    @EnvironmentObject var model: AppModel

    @EnvironmentObject var locationManager: LocationManager

    // Focus targets for fields inside LoadLeftPanel

    enum Field: Hashable {

        case loadCode

        case terminalName

        case vehicleId

        case driverName

        case litres(Int)

    }

    @FocusState private var focusedField: Field?

    var body: some View {

            HStack(spacing: 0) {

                LoadLeftPanel(focusedField: $focusedField)

                    .frame(maxWidth: 340)

                Divider()

                LoadSheetView()

            }

            .navigationTitle("Load")

            .onAppear {

                // Tier 1 Entry Guard: Soft prompt when entering LoadView in wrong segment

                guard model.isOnDuty else { return }

                let expectedSegment: ActivityType = model.isUnloadMode ? .workUnload : .workLoad

  

                if model.currentActivity != expectedSegment {

                    // Give the view a moment to settle before showing prompt

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {

                        if self.model.isUnloadMode {

                            self.model.promptToSwitchToUnload()

                        } else {

                            self.model.promptToSwitchToLoad()

                        }

                    }

                }

                // Also prime stopped nudge (existing code)

                model.primeStoppedNudgeInLoadEntry()

            }

            .onDisappear {

                model.stoppedStartAt = nil

                model.pendingStoppedNudge?.cancel()

                model.pendingStoppedNudge = nil

            }

            .sheet(isPresented: $model.showStoppedNudgeInLoad) {

                StoppedNudgeSheet(

                    onLoad: {

                        model.isUnloadMode = false

                        model.pressLoad()

                        model.showStoppedNudgeInLoad = false

                    },

                    onUnload: {

                        model.isUnloadMode = true

                        model.pressUnload()

                        model.showStoppedNudgeInLoad = false

                    },

                    onKeepDriving: {

                        model.snoozeStoppedNudgeInLoad()

                        model.showStoppedNudgeInLoad = false

                    },

                    onCancel: {

                        model.showStoppedNudgeInLoad = false

                    }

                )

                .presentationDetents([.height(320)])     // fits all buttons, no scrolling

                .presentationDragIndicator(.visible)

            }

            .onReceive(locationManager.$speedMps) { newSpeed in

                model.considerStoppedNudgeInLoad(speedMps: newSpeed)

            }

    }

}
