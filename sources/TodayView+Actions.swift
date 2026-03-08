
import SwiftUI

  

extension TodayView {

    //======================================

    // MARK: - Todayview+Actions block

    //

    // Primary on-duty driver actions shown on TodayView.

    // This view is intentionally "dumb UI":

    // - It reflects current AppModel state

    // - It delegates all business logic to AppModel

    // - It does NOT enforce fatigue or NHVR rules itself

    //

    // Updated (segment/state catches):

    // - All actions funnel through AppModel.request(...)

    //   so AppModel can coach/guard impossible combos.

    //

    // Pre-persistence scope:

    // - Coaching prompts only (no blocking)

    // - No persistent record of prompt responses

    // - Driver always has final say

    //

    // Post-persistence evolution:

    // - May create advisory events ("user overrode prompt")

    // - Still never blocks actions

    //

    //======================================

    var actionsBlock: some View {

  

        VStack(spacing: 8) {

            if model.isOnDuty {

                let columns = [GridItem(.flexible()), GridItem(.flexible())]

                LazyVGrid(columns: columns, spacing: 8) {

                    // DRIVE (press-style)

                    Button {

                        model.request(.drive)

                    } label: {

                        Text(model.isDriving ? "Driving" : "Drive")

                            .frame(maxWidth: .infinity)

                    }

                    .buttonStyle(.borderedProminent)

                    .disabled(!model.canPressDrive)   // IMPORTANT: no toggling in UI anymore

                    // BREAK (press-style)

                    Button {

                        model.request(.breakTime)

                    } label: {

                        Text(model.isOnBreak ? "On Break" : "Break")

                            .frame(maxWidth: .infinity)

                    }

                    .buttonStyle(.borderedProminent)

                    .disabled(!model.canPressBreak)   // IMPORTANT

                    // LOAD / UNLOAD (guarded; AppModel decides)

                    Button {

                        model.request(.load)

                        // optional: switch tabs / navigate to LoadView later

                    } label: {

                        Text("Load").frame(maxWidth: .infinity)

                    }

                    .buttonStyle(.bordered)

                    .disabled(!model.canPressLoad)

                    Button {

                        model.request(.unload)

                        // optional: switch tabs / navigate to LoadView later

                    } label: {

                        Text("Unload").frame(maxWidth: .infinity)

                    }

                    .buttonStyle(.bordered)

                    .disabled(!model.canPressUnload)

                    // INCIDENT (event only for now; still route via guard for consistency)

                    Button {

                        model.openIncidentSheet()

                    } label: {

                        Text("Incident").frame(maxWidth: .infinity)

                    }

                    .buttonStyle(.bordered)

                    // OTHER (sheet; selection should call model.request(.startOther(...)))

                    Button {

                        showingOtherSheet = true

                    } label: {

                        Text("Other").frame(maxWidth: .infinity)

                    }

                    .buttonStyle(.bordered)

                }

                .font(.footnote)

            }

        }

    }

}
