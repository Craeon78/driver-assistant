
import SwiftUI

// © 2026 Cory Russell Olsen. All rights reserved.

// This application and its contents are proprietary and confidential.

  

//======================================

// MARK: - MyApp.swift

//======================================

  

// Drivers Assistant Entry point  

//  - wires AppModel + LocationManager into the view hierarchy

  

@main

struct MyApp: App {

  

    @StateObject private var model: AppModel = {

        let m = AppModel()

        DebugLog.myapp("Model created")

        return m

    }()

    @StateObject private var locationManager: LocationManager = {

        DebugLog.myapp("Creating LocationManager at \(Date())")

        let lm = LocationManager()  // calls the fixed init we corrected earlier

        DebugLog.myapp("LocationManager created and configured")

        return lm

    }()

    var body: some Scene {

        WindowGroup {

            ContentView()

                .environmentObject(model)

                .environmentObject(locationManager)

                .onAppear {

                    DebugLog.myapp("🟣 MyApp WindowGroup onAppear  t=\(Date()) modelID=\(ObjectIdentifier(model)) locID=\(ObjectIdentifier(locationManager))")

                }

        }

    }

}
