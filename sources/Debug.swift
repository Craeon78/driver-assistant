
import Foundation

  

//======================================

// MARK: - Debug Infrastructure

//======================================

  

enum DebugFlags {

    // Master override (turns everything on)

    static let all = false

    // App lifecycle

    static let myapp     = true

    static let lifecycle = true

    // Motion / GPS

    static let gps    = false

    static let motion = false

    // Persistence (general)

    static let persistence = true

    // Persistence (autosave subcategory)

    // Keep this so you can toggle autosave noise separately if you want.

    static let autosave = true

    // Odometer

    static let odo = true

    // Guard / Incident engine

    static let guardEngine = true

    // Debug UI

    static let debugMenu = true

    static let ui = true

    static let trianglePlaceholder = true

    static let sim = true

}

  

  

//======================================

// MARK: - Debug Logging

//======================================

  

enum DebugLog {

    private static func enabled(_ flag: Bool) -> Bool {

        DebugFlags.all || flag

    }

    // MARK: - App / Lifecycle

    static func myapp(_ msg: @autoclosure () -> String) {

        guard enabled(DebugFlags.myapp) else { return }

        print("🟣 " + msg())

    }

    static func lifecycle(_ msg: @autoclosure () -> String) {

        guard enabled(DebugFlags.lifecycle) else { return }

        print("🧬 " + msg())

    }

    // MARK: - GPS / Motion

    static func gps(_ msg: @autoclosure () -> String) {

        guard enabled(DebugFlags.gps) else { return }

        print("🛰️ " + msg())

    }

    static func motion(_ msg: @autoclosure () -> String) {

        guard enabled(DebugFlags.motion) else { return }

        print("🏃 " + msg())

    }

    // MARK: - Persistence

    /// General persistence logging (file IO, encoding/decoding, migrations, export, etc.)

    static func persistence(_ msg: @autoclosure () -> String) {

        guard enabled(DebugFlags.persistence) else { return }

        print("🗄️ " + msg())

    }

    /// Autosave-specific logging (debounce, flushes, restore, clear).

    static func autosave(_ msg: @autoclosure () -> String) {

        guard enabled(DebugFlags.autosave) else { return }

        print("💾 " + msg())

    }

    // MARK: - Odo

    static func odo(_ msg: @autoclosure () -> String) {

        guard enabled(DebugFlags.odo) else { return }

        print("🧭 " + msg())

    }

    // MARK: - Guard

    static func guardEngine(_ msg: @autoclosure () -> String) {

        guard enabled(DebugFlags.guardEngine) else { return }

        print("🛡️ " + msg())

    }

    // MARK: - UI

    /// UI events that aren't "app lifecycle" (sheets, banners, prompts, debug panels).

    static func ui(_ msg: @autoclosure () -> String) {

        guard enabled(DebugFlags.ui) else { return }

        print("🪟 " + msg())

    }

    // Mark:- Sim

    static func sim(_ msg: @autoclosure () -> String) {

            guard enabled(DebugFlags.sim) else { return } // ✅ your existing dev-only gate

            print("🧪SIM: " + msg())

    }

  

}
