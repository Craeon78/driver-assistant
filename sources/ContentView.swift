//======================================
// MARK: - ContentView
//======================================
//
// © 2026 Cory Russell Olsen. All rights reserved.
//
// Path: Views/Screens/ContentView.swift
//
// Purpose:
// - Root shell for the app.
// - Hosts the main TabView, splash overlay, global banner, and app-wide sheets.
// - Wires top-level lifecycle / activation signals into AppModel.
//
// Responsibilities:
// - Present the five primary workflows:
//   • Today   (shift + fatigue)
//   • Load    (load plan, placards, mass)
//   • Map     (pins, telemetry, routing)
//   • Sim     (fatigue simulation / planning)
//   • Command (journal/history, numbers, truck/profile setup)
// - Layer SplashView above the tab shell during startup.
// - Inject BannerShellView across the app via safe-area inset.
// - Present global guard prompts and settings sheets.
// - Connect root lifecycle signals:
//   • scenePhase changes
//   • UIApplication active/inactive notifications
//   • LocationManager update nudges for background-gap resume
//   • app-wide motion tick
// - Perform one-time startup wiring:
//   • connect AppModel ↔ LocationManager
//   • expose GPS kick / reset closures
//   • run splash sequence
//   • start app ticker
//
// Notes:
// - This file is app-shell orchestration, not domain logic.
// - Background-gap resume is intentionally nudged from the root because
//   focus changes and location updates are app-level concerns.
// - SplashView is deliberately layered above the TabView so underlying
//   screens can initialise before the splash fades out.
// - Persistence is not owned here; ContentView only triggers high-level startup flow.
// - Future debug/admin entry points should be attached here, not buried inside feature views.
//
// Phase: Pre-persistence / Root orchestration
//======================================

import SwiftUI
import Combine
import UIKit

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
        
        .onChange(of: scenePhase) { _, newPhase in
            print("🔥🔥🔥 SCENEPHASE -> \(newPhase)")
        
            guard model.didFinishSplash else { return }
            
            switch newPhase {
            case .inactive:
                DebugLog.lifecycle("📴 scenePhase .inactive")
                model.onAppBackgrounded(locationManager: locationManager)
            case .background:
                DebugLog.lifecycle("🌙 scenePhase .background")
                model.onAppBackgrounded(locationManager: locationManager)
            case .active:
                DebugLog.lifecycle("🌞 scenePhase .active")
                model.onAppBecameActive(locationManager: locationManager)
            default:
                break
            }
        }
        
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            print("📴 willResignActive")
            model.onAppBackgrounded(locationManager: locationManager)
        }
        
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            print("🌞 didBecomeActive")
            model.onAppBecameActive(locationManager: locationManager)
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
