//======================================
// MARK: - MyApp
//======================================
//
// © 2026 Cory Russell Olsen. All rights reserved.
//
// Path: MyApp.swift
//
// Entry point for the application.
//
// Responsibilities:
// - Create and own root state objects:
//   - AppModel (application state / domain logic)
//   - LocationManager (GPS + motion pipeline)
// - Inject shared dependencies into the SwiftUI environment.
// - Host the root ContentView within the main WindowGroup.
//
// Notes:
// - Objects are created once at app launch via @StateObject.
// - Debug logging here is lifecycle-focused (creation + attachment),
//   not business logic.
//======================================

import SwiftUI

@main
struct MyApp: App {

    @StateObject private var model: AppModel = {
        let m = AppModel()
        DebugLog.myapp("Model created")
        return m
    }()
    
    @StateObject private var locationManager: LocationManager = {
        DebugLog.myapp("Creating LocationManager at \(Date())")
        let lm = LocationManager()  // calls the fixed init we corrected earlier
        DebugLog.myapp("LocationManager created and configured")
        return lm
    }()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .environmentObject(locationManager)
                .onAppear {
                    DebugLog.myapp("🟣 MyApp WindowGroup onAppear  t=\(Date()) modelID=\(ObjectIdentifier(model)) locID=\(ObjectIdentifier(locationManager))")
                    
                }
            
        }
    }
}
