
import SwiftUI

import Combine

  

//======================================

// MARK: - Contentview (root tab container)

//======================================

//

// Purpose:

// - Owns the main TabView for the app.

// - Hosts the five primary workflows:

//   • Today (shift + fatigue)

//   • Load (load plan, placards, mass)

//   • Map (pins, telemetry, routing)

//   • Sim (fatigue simulation / planning)

//   • Command (where Journal (history) , numbers (owner costings etc) and truck (truck profile setup) live)

//

// Notes:

// - SplashView is deliberately layered *above* the TabView

//   so tabs initialise underneath while splash fades out.

// - No persistence assumptions here; this is purely navigation.

// - Any future debug / admin tabs should be injected here,

//   not inside individual screens.

//======================================

  

enum MainTab: Hashable {

    case today

    case load

    case map

    case sim

    case command

}

  

struct ContentView: View {

    @Environment(\.scenePhase) private var scenePhase

    @EnvironmentObject var model: AppModel

    @EnvironmentObject var locationManager: LocationManager

    @State private var selectedTab: MainTab = .today

    @State private var progress: Double = 0.0

    @State private var status: String = "Starting up..."

    var body: some View {

        ZStack {

            TabView(selection: $selectedTab) {

                NavigationStack { TodayView() }

                    .toolbar(.hidden, for: .navigationBar)

                    .tag(MainTab.today)

                NavigationStack { LoadPlanView() }

                    .toolbar(.hidden, for: .navigationBar)

                    .tag(MainTab.load)

                NavigationStack { MapScreen() }

                    .toolbar(.hidden, for: .navigationBar)

                    .tag(MainTab.map)

                NavigationStack { SimulationView() }

                    .toolbar(.hidden, for: .navigationBar)

                    .tag(MainTab.sim)

                NavigationStack { CommandView() }

                    .toolbar(.hidden, for: .navigationBar)

                    .tag(MainTab.command)

            }

            .toolbar(.hidden, for: .tabBar) // ✅ native tab bar gone

            if !model.didFinishSplash {

                SplashView(

                    progress: $progress,

                    status: $status,

                    didFinishSplash: $model.didFinishSplash

                )

                .transition(.opacity)

                .zIndex(10)

            }

        }

        .safeAreaInset(edge: .top) {

            BannerShellView(selectedTab: $selectedTab)

                .environmentObject(model)

                .environmentObject(locationManager)

        }

        .sheet(item: $model.activeGuardPrompt) { prompt in

            GuardPromptSheet(prompt: prompt)

                .environmentObject(model)

        }

        .sheet(isPresented: $model.isShowingSettingsSheet) {

            SettingsView()

                .environmentObject(model)

                .environmentObject(locationManager)

        }

        .onChange(of: scenePhase) {

            guard model.didFinishSplash else { return }

            switch scenePhase {

            case .inactive:

                model.onAppBackgrounded(locationManager: locationManager)

            case .background:

                model.onAppBackgrounded(locationManager: locationManager)

            case .active:

                model.onAppBecameActive(locationManager: locationManager)

            default:

                break

            }

        }

        .onAppear {

            model.requestGpsKickFromUI = { reason in

                locationManager.kickUpdates(reason: reason)

            }

            model.requestLmResetShiftMetersFromUI = { [weak locationManager] reason in

                Task { @MainActor in

                    locationManager?.resetShiftMeters(reason: reason)

                }

            }

            guard !model.splashSetupStarted else { return }

            model.splashSetupStarted = true

            model.connect(locationManager: locationManager)

            runSplashSequence()

            model.startTickerIfNeeded()

        }

        .onReceive(locationManager.$lastUpdateAt) { _ in

            if model.backgroundGapResumePending {

                model.onAppBecameActive(locationManager: locationManager)

            }

        }

        .onReceive(

            Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

        ) { _ in

            DebugLog.motion("🟡 motion tick")

            model.tickMotionState()

        }

    }

    private func runSplashSequence() {

        // keep your exact timing

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {

            status = "AppModel ready"; progress = 0.25

            DebugLog.ui("🟠 Batch 1: AppModel ready")

            model.ensureAutosaveSetup()

        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {

            status = "Preparing location services"; progress = 0.5

            DebugLog.ui("🟠 Batch 2: Location prep")

        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {

            status = "Starting location updates"; progress = 0.75

            DebugLog.ui("🟠 Batch 3: Calling locationManager.start()")

            locationManager.start()

        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {

            status = "Loading complete"; progress = 1.0

            DebugLog.ui("🟠 Batch 4: Done")

            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {

                model.didFinishSplash = true

            }

        }

    }

}
