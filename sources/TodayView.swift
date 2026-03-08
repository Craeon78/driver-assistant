
import SwiftUI

  

//======================================

// MARK: - TODAY VIEW (Main Tab)

//======================================

//

// Role:

// - The main operational screen during a shift.

// - Owns UI state that is shared across TodayView partials

//   (actions, fatigue, planner, timeline).

//

// Layout:

// - Split view:

//   • Left: status, last shift summary, action buttons, timeline.

//   • Right: fatigue dashboard + planner.

//

// State management:

// - Timer tick drives live durations (drive/work/rest) via model.tick().

// - Odo capture is driven by model.odoPromptContext and shown as a sheet.

// - Sheet toggles owned here: showingOtherSheet, showingStartShift, showingSettings

// - Countdown flash animation state: countdownFlashOn (used by TodayView+Fatigue)

//

// Extension files:

// - TodayView+Actions.swift: action button grid

// - TodayView+StatusCard.swift: top status card

// - TodayView+Fatigue.swift: right panel fatigue dashboard

// - TodayView+Timeline.swift: bottom timeline section

//

// Notes:

// - Some @State vars appear "unused" in this file because they are used

//   by TodayView extensions (partials).

// - Extensions are in Partials/ folder but logically part of this screen.

//

//======================================

  

struct TodayView: View {

    @EnvironmentObject var model: AppModel

    @EnvironmentObject var locationManager: LocationManager

    // Sheet toggles (owned here, used by partials)

    @State var showingOtherSheet = false

    @State var showingStartShift = false

    @State var showingSettings   = false

    // Used by TodayView+fatigue (countdown flashing)

    @State var countdownFlashOn  = false

        var currentStatusText: String {

            guard model.isOnDuty else { return "OFF DUTY" }

            switch model.currentActivity {

            case .driving:        return "DRIVING"

            case .workLoad:       return "LOADING"

            case .workUnload:     return "UNLOADING"

            case .workGeneral:    return "ON DUTY"

            case .restBreak:      return "ON BREAK"

            case .restBreakdown:  return "BREAKDOWN"

            case .offDuty:        return "OFF DUTY"

            }

        }

    private var odoSheetIsCritical: Bool {

        guard let ctx = model.odoPromptContext else { return false }

        return ctx == .shiftEnd || ctx == .shiftStart || ctx == .legalBreakEnd

    }

        //======================================

        // MARK: - Body (split layout)

        //======================================

        var body: some View {

            HStack(spacing: 0) {

                // LEFT COLUMN – controls, summary & timeline

                VStack(spacing: 16) {

                    statusCard

                    if !model.isOnDuty, let summary = model.lastShiftSummary {

                        ShiftSummaryView(summary: summary)

                    }

                    actionsBlock

                    Spacer()

                }

                .padding()

                .frame(maxWidth: 340, alignment: .top)

                .background(Color(.systemBackground))

                Divider()

                // RIGHT COLUMN – fatigue dashboard + planner

                ScrollView {

                    VStack(alignment: .leading, spacing: 16) {

                        workWindowSection

                        Divider()

                        timelineSection

                    }

                    .padding()

                }

                .background(Color(.systemGroupedBackground))

            }

            .sheet(isPresented: $showingStartShift) {

                StartShiftView(isPresented: $showingStartShift)

                    .environmentObject(model)

            }

            .sheet(isPresented: $showingOtherSheet) {

                OtherActivitySheet()

                    .environmentObject(model)

                    .presentationDetents([.large])

                    .presentationDragIndicator(.visible)

            }

            .sheet(isPresented: $model.isShowingIncidentSheet) {

                IncidentSheet()

                    .environmentObject(model)

            }

            // Odo capture sheet is driven by model.odoPromptContext (single source of truth).

            .sheet(

                isPresented: Binding(

                    get: { model.odoPromptContext != nil },

                    set: { newValue in

                        // If this sheet is "critical" (shift start/end / legal break end),

                        // ignore interactive dismiss attempts.

                        if !newValue {

                            if odoSheetIsCritical { return }

                            model.odoPromptContext = nil

                        }

                    }

                )

            ) {

                OdoLocationSheet()

                    .presentationDetents([.medium])

                    .presentationDragIndicator(odoSheetIsCritical ? .hidden : .visible)

                    .interactiveDismissDisabled(odoSheetIsCritical)

            }

            .onAppear {

                if model.isMissingShiftStartOdo {

                    model.requestOdoCapture(.shiftStart)

                }

            }

            .onChange(of: model.odoPromptContext) { _, newCtx in

                // If prompt got cleared but a mandatory gate is still pending, bring it back.

                if newCtx == nil {

                    if model.isMissingShiftStartOdo {

                        model.requestOdoCapture(.shiftStart)

                    } else if model.pendingEndShiftCapture {

                        model.requestOdoCapture(.shiftEnd)

                    }

                }

            }

        }

    }
