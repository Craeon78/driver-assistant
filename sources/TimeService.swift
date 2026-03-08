
import Foundation

  

//======================================

// MARK: - TimeService (single source of truth)

//======================================

//

// Goals:

// - Store absolute times as Date (always).

// - Present UI using the device's current timezone (autoupdating).

// - Compute compliance windows using a stable session timezone (Mode B).

//

// Phase 1:

// - Compliance timezone is "locked" when a shift starts (or at app init).

// - Later: optionally update complianceTZ from location/geocoder if you choose.

//

final class TimeService: ObservableObject {

    enum Context {

        case ui          // device-local, can change as you travel

        case compliance  // session-locked timezone for NHVR Mode B maths

    }

    /// Stable timezone used for compliance calculations this session/shift.

    @Published private(set) var complianceTimeZoneID: String

    init(baseTimeZoneID: String = TimeZone.current.identifier) {

        self.complianceTimeZoneID = baseTimeZoneID

    }

    // MARK: - Absolute time

    /// "Now" as an absolute timestamp.

    func now() -> Date { Date() }

    // MARK: - Time zones

    var uiTimeZone: TimeZone { .autoupdatingCurrent }

    var complianceTimeZone: TimeZone {

        TimeZone(identifier: complianceTimeZoneID) ?? .current

    }

    /// Lock compliance timezone (call at shift start).

    func lockComplianceTimeZoneToCurrentDevice(reason: String = "Shift start") {

        complianceTimeZoneID = TimeZone.current.identifier

        DebugLog.lifecycle("🕒 Compliance TZ locked to device: \(complianceTimeZoneID) (\(reason))")

    }

    /// Lock compliance timezone explicitly (future: derived from GPS/state rules).

    func lockComplianceTimeZone(id: String, reason: String = "Manual") {

        complianceTimeZoneID = id

        DebugLog.lifecycle("🕒 Compliance TZ locked: \(complianceTimeZoneID) (\(reason))")

    }

    // MARK: - Calendars (the big source of bugs if uncontrolled)

    func calendar(_ context: Context) -> Calendar {

        var cal = Calendar(identifier: .gregorian)

        cal.locale = Locale.current

        cal.timeZone = (context == .ui) ? uiTimeZone : complianceTimeZone

        return cal

    }

    // MARK: - Formatting helpers

    func formatTimeShort(_ date: Date, context: Context) -> String {

        let f = DateFormatter()

        f.locale = Locale.current

        f.timeZone = (context == .ui) ? uiTimeZone : complianceTimeZone

        f.dateStyle = .none

        f.timeStyle = .short

        return f.string(from: date)

    }

    func formatDateTimeShort(_ date: Date, context: Context) -> String {

        let f = DateFormatter()

        f.locale = Locale.current

        f.timeZone = (context == .ui) ? uiTimeZone : complianceTimeZone

        f.dateStyle = .medium

        f.timeStyle = .short

        return f.string(from: date)

    }

    // MARK: - "Day" boundaries (critical for 'today' proxy logic)

    func isSameDay(_ a: Date, _ b: Date, context: Context) -> Bool {

        let cal = calendar(context)

        return cal.isDate(a, inSameDayAs: b)

    }

    func startOfDay(_ date: Date, context: Context) -> Date {

        calendar(context).startOfDay(for: date)

    }

}
