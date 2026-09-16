//======================================
// MARK: - AppModel
//======================================
//
// © 2026 Cory Russell Olsen. All rights reserved.
//
// Path: AppModels/AppModel.swift
//
// Purpose:
// - Transitional application shell while V2-proven behaviour is migrated into V3 domain owners.
// - Owns SwiftUI-facing @Published compatibility state and app-level wiring during migration.
//
// Responsibilities:
// - Preserve the existing UI/API while canonical ownership moves behind V3 boundaries.
// - Coordinate lifecycle, autosave and domain adapters that still require AppModel.
// - Avoid creating new cross-domain truth in this shell.
//
// Notes:
// - @Published compatibility properties remain here until callers can migrate safely.
// - V3 domain owners progressively replace this shell as the storage root.
// - AutoSaveController remains an AppModel adapter until persistence is migrated.
//
// Phase: V3 migration
//======================================

import SwiftUI
import Combine
import CoreLocation

@MainActor
final class AppModel: ObservableObject {
    
    //======================================
    // MARK: - Core Services / Runtime
    //======================================
    
    let runtimeServices = RuntimeServices()
    var time: TimeService { runtimeServices.time }
    var saveStore: SaveStore { runtimeServices.saveStore }
    
    var autosave: AutoSaveController?
    private var initComplete = false
    private var timer: Timer?
    var isGpsConnected: Bool {
        get { runtimeServices.isGpsConnected }
        set { runtimeServices.isGpsConnected = newValue }
    }
    
    private static let otherActivitiesKey = "OtherActivities_v1"
    
    //======================================
    // MARK: - App-Wide UI Routing / Shell
    //======================================
    
    @Published var didFinishSplash = false
    @Published var splashSetupStarted = false
    @Published var isShowingSettingsSheet: Bool = false
    
    enum CommandSheet: String, Identifiable {
        case journal, truck, numbers
        var id: String { rawValue }
    }
    
    @Published var activeCommandSheet: CommandSheet? = nil
    
    enum BannerContext {
        case motion
        case heading
        case odo
        case cost
    }
    
    func openCommand(_ sheet: CommandSheet) {
        activeCommandSheet = sheet
    }
    
    func bannerContext(for tab: MainTab) -> BannerContext {
        switch tab {
        case .today:   return .motion
        case .map:     return .heading
        case .load:    return .odo
        case .sim:     return .motion
        case .command: return .cost
        }
    }
    
    var integrityIssueCount: Int {
        backgroundGapRecords.filter { !$0.isResolved }.count
    }
    func presentIntegritySheet() {
        activeCommandSheet = .journal
    }
    
    var currentSuburbForBanner: String {
        odoLocationRecords.last?.suburb.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        ? (odoLocationRecords.last?.suburb ?? "—")
        : "—"
    }
    
    var futureProjectionLine1: String { "—" }
    var futureProjectionLine2: String { "" }
    @Published var liveCostPerKmText: String = "Cost/km —"
    
    //======================================
    // MARK: - Driver / Profiles / Config
    //======================================
    
    @Published var settings: DriverSettings = DriverSettings()
    @Published var driverProfile = DriverProfilePayloadV1()
    @Published var settingsProfile = SettingsPayloadV1()
    @Published var appConfig: AppConfigV1 = AppConfigV1()
    @Published var lastConfigLoadedAt: Date? = nil
    
    var gpsT: AppConfigV1.GpsTunables { appConfig.gps }
    
    // Temporary Phase 1 selection
    @Published var selectedTruckLabel: String = "Truck 92"
    // later: @Published var selectedTruckID: UUID?
    
    //======================================
    // MARK: - Shift / Session Truth
    //======================================
    
    @Published var isOnDuty: Bool = false
    @Published var isDriving: Bool = false
    @Published var isOnBreak: Bool = false
    
    @Published var shiftStartTime: Date? = nil
    @Published var lastShiftSummary: ShiftSummary? = nil
    @Published var events: [ShiftEvent] = []
    
    @Published var currentActivity: ActivityType = .offDuty
    @Published var currentSegmentStart: Date? = nil
    @Published var segmentsToday: [ActivitySegment] = []
    
    @Published var driveSecondsToday: TimeInterval = 0
    @Published var lastTick: Date? = nil
    
    @Published var sessionBaseTimeZoneID: String = TimeZone.current.identifier
    
    var complianceTimeZone: TimeZone {
        TimeZone(identifier: sessionBaseTimeZoneID) ?? TimeZone.current
    }
    
    var complianceCalendar: Calendar {
        var cal = Calendar.current
        cal.timeZone = complianceTimeZone
        return cal
    }
    
    //======================================
    // MARK: - Odo / Prompt / Guard / Incident State
    //======================================
    
    @Published var odoText: String = ""
    @Published var prestartDone: Bool = false
    @Published var odoLocationRecords: [OdoLocationRecord] = []
    
    @Published var odoPromptTimestampOverride: Date? = nil
    @Published var odoPromptContext: OdoPromptContext? = nil
    @Published var odoPromptOdoText: String = ""
    @Published var odoPromptSuburbText: String = ""
    
    @Published var pendingStartShiftCapture: Bool = false
    @Published var pendingEndShiftCapture: Bool = false
    @Published var pendingActionAfterOdo: (() -> Void)? = nil
    
    @Published var activeGuardPrompt: GuardPrompt? = nil
    
    @Published var isShowingIncidentSheet: Bool = false
    @Published var incidentDraft: IncidentReport? = nil
    @Published var lastIncidentAdvicePlan: IncidentAdvicePlan? = nil
    
    // Load-view stopped nudge state
    @Published var showStoppedNudgeInLoad: Bool = false
    @Published var stoppedStartAt: Date? = nil
    @Published var pendingStoppedNudge: DispatchWorkItem? = nil
    var lastStoppedNudgeAt: Date? = nil
    
    // Movement nudge state
    var movementStartAt: Date? = nil
    var lastNudgeAt: Date? = nil
    
    //======================================
    // MARK: - Load Plan / Resolution / Templates
    //======================================
    
    @Published var compartments: [CompartmentModel] = []
    @Published var lazyAxleIsUp: Bool = false
    @Published var fuelStepIndex: Int = 6
