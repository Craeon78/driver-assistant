  

import SwiftUI

import Combine

import CoreLocation

  

// © 2026 Cory Russell Olsen. All rights reserved.

//======================================

// MARK: - AppModel

//======================================

  

// Purpose:

// - Central state container and coordinator for the driver assistant app.

// - Owns all @Published stored properties (Swift extensions cannot store them).

// - Delegates GPS inference to AppModel+GPS, guard coaching to AppModel+Guard,

//   and odo/load nudges to AppModel+OdoCapture.

  

// Owns:

// - All @Published stored properties across every domain.

// - App lifecycle: init, ticker, autosave setup, GPS connection.

// - Other-activity persistence (UserDefaults; pre-persistence exception).

// - Shift/session workflow reset.

  

// Notes:

// - Keep this file free of domain logic. Domain logic lives in the + files.

// - Computed properties and methods that span domains may live here if they

//   don't cleanly belong to a single extension.

//======================================

  

@MainActor

final class AppModel: ObservableObject {

    @Published var selectedTruckLabel: String = "Truck 92" // temporary Phase 1

    // later: @Published var selectedTruckID: UUID?

    // MARK: - Service Objects

    let time = TimeService()

    let saveStore = SaveStore()

    var autosave: AutoSaveController?

    private var initComplete  = false

    private var timer: Timer?

    private var tickerTask: Task<Void, Never>?

    private var gpsCancellables = Set<AnyCancellable>()

    var isGpsConnected = false

    private static let otherActivitiesKey = "OtherActivities_v1"

    // MARK: - Driver Settings (Identity / Config)

    @Published var settings: DriverSettings = DriverSettings()

    // MARK: - Banner / Global UI (stubs)

    @Published var isShowingSettingsSheet: Bool = false

    var integrityIssueCount: Int { 0 }  // later: computed from validations

    func presentIntegritySheet() { }     // later: open “Adjust / Review” sheet

    var currentSuburbForBanner: String {

        // Best available right now: last odo suburb if any

        odoLocationRecords.last?.suburb.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false

        ? (odoLocationRecords.last?.suburb ?? "—")

        : "—"

    }

    var futureProjectionLine1: String { "—" }

    var futureProjectionLine2: String { "" }

    // MARK: - Command (global sheet routing)

    enum CommandSheet: String, Identifiable {

        case journal, truck, numbers

        var id: String { rawValue }

    }

    @Published var activeCommandSheet: CommandSheet? = nil

    func openCommand(_ sheet: CommandSheet) {

        activeCommandSheet = sheet

    }

    // MARK: - Splash

    @Published var didFinishSplash    = false

    @Published var splashSetupStarted = false

    // MARK: - Shift State

    @Published var isOnDuty:   Bool = false

    @Published var isDriving:  Bool = false

    @Published var isOnBreak:  Bool = false

    @Published var shiftStartTime:   Date?          = nil

    @Published var lastShiftSummary: ShiftSummary?  = nil

    @Published var driveSecondsToday: TimeInterval = 0

    @Published var lastTick: Date?                  = nil

    @Published var events: [ShiftEvent] = []

    @Published var sessionBaseTimeZoneID: String = TimeZone.current.identifier

    var complianceTimeZone: TimeZone {

        TimeZone(identifier: sessionBaseTimeZoneID) ?? TimeZone.current

    }

    var complianceCalendar: Calendar {

        var cal = Calendar.current

        cal.timeZone = complianceTimeZone

        return cal

    }

    // MARK: - GPS / Motion Stored State

    @Published var gpsKmSinceLastOdoBySegment: [UUID: Double] = [:]

    @Published var finalisedKmBySegment:        [UUID: Double] = [:]

    @Published var runningSegmentID:            UUID?          = nil

    @Published var lastOdoAnchorRecordID: UUID? = nil

    @Published var lastOdoAnchorKm:       Int?  = nil

    @Published var kmCorrectionFactor:    Double = 1.0

    @Published var lastOdoCaptureTime:    Date? = nil

    @Published var lastKnownCourseDegrees: Double? = nil

    @Published var lastKnownSpeedMps:      Double? = nil

    @Published var lastSpeedSampleAt:      Date?   = nil

    @Published var motionState:    MotionState    = .unsure

    @Published var showMotionDebug: Bool          = true

    var motionTunables = MotionTunables()

    var speedSamples:       [SpeedSample] = []

    let maxSpeedSamples:    Int           = 8

    var courseSamples:      [Double]      = []

    let maxCourseHistory:   Int           = 5

    var stateChangeHistory: [Date]        = []

    var stoppedAccumulatorStart: Date? = nil

    var pendingStoppedAt:        Date? = nil

    var pendingMovingAt:         Date? = nil

    var lastNudgeAt:             Date? = nil

    @Published var gpsKmPendingUntilFirstSegment: Double = 0

    @Published var gpsIngestSeq: Int = 0

    @Published var lastGpsUpdateAt:      Date?   = nil

    @Published var lastGpsAccuracyMeters: Double? = nil

    @Published var lastGpsWasStalled:    Bool     = false

    @Published var lastLmDeltaMeters:   Double  = 0

    @Published var lastLmValidSpeedMps: Double? = nil

    @Published var gpsShiftMetersLive: Double = 0

    // MARK: - Shadow Telemetry (alternate GPS engine)

    private let shadowGpsEngine = GPSDistanceEngine()

    private var shadowLastMirroredLocationTimestamp: Date? = nil

    private var shadowHasStartedSpan: Bool = false

    private var shadowProcessedTotalKmBacking: Double = 0

    private var shadowRawTotalKmBacking: Double = 0

    @Published var productionRawGpsDistanceKm: Double = 0

    @Published var alternateProcessedGpsDistanceKm: Double = 0

    @Published var alternateRawGpsDistanceKm: Double = 0

    @Published var alternateEffectiveCorrectionFactor: Double = 1.0

    @Published var lastShadowOdoDeltaKm: Double? = nil

    @Published var lastShadowRawGpsDeltaKm: Double? = nil

    @Published var lastShadowProcessedGpsDeltaKm: Double? = nil

    @Published var lastShadowChosenSource: DistanceSource? = nil

    @Published var lastShadowErrorVsOdoKm: Double? = nil
    @Published var lastShadowErrorPercent: Double? = nil

    @Published var shadowTelemetryAvailable: Bool = false

    var requestGpsKickFromUI: ((String) -> Void)? = nil

    var requestLmResetShiftMetersFromUI: ((String) -> Void)? = nil

    // GPS advisory (does NOT affect factor learning)

    let backgroundGapCoordinator = BackgroundGapCoordinator()

    @Published var lastBackgroundGapEstimate: BackgroundGapEstimate?

    @Published var backgroundGapHistory: [BackgroundGapEstimate] = []

    // MARK: - Distance Guard (internal)

    var lastDistanceIngestAt: Date? = nil

    var distanceSpikeCount: Int = 0

    @Published var liveCostPerKmText: String = "Cost/km —"

    enum BannerContext {

        case motion

        case heading

        case odo

        case cost

    }

    func bannerContext(for tab: MainTab) -> BannerContext {

        switch tab {

        case .today:

            return .motion

        case .map:

            return .heading

        case .load:

            return .odo

        case .sim:

            return .motion   // or leave as motion for now

        case .command:

            return .cost

        }

    }

    // MARK: - Motion Auto-Recovery

    @Published var lastAutoRecoverFiredAt: Date?   = nil

    @Published var lastAutoRecoverReason:  String? = nil

    @Published var motionCertaintyReasons: [String] = []

    @Published var driverProfile = DriverProfilePayloadV1()

    @Published var settingsProfile = SettingsPayloadV1()

    @Published var appConfig: AppConfigV1 = AppConfigV1()

    @Published var lastConfigLoadedAt: Date? = nil

    // MARK: - Motion Quality (internal)

    var motionQualityStrikes: Int = 0

    var motionLastQualityStrikeAt: Date? = nil

    // Backing state for the motion watchdog (not @Published — internal only).

    var lastAutoRecoverAt: Date? = nil

    var lowMotionSince:    Date? = nil

    // MARK: - Background Gap Recovery

    @Published var backgroundGapStartAt:     Date?                    = nil

    @Published var backgroundGapStartCoord:  CLLocationCoordinate2D? = nil

    @Published var backgroundGapEndAt:       Date?                    = nil

    @Published var backgroundGapEndCoord:    CLLocationCoordinate2D? = nil

    @Published var pendingGapEstimateMeters: Double?                  = nil

    @Published var pendingGapEstimateSegmentID: UUID?                 = nil

    @Published var pendingGapReason:         String?                  = nil

    @Published var pendingGapSegmentID:      UUID?                    = nil

    @Published var backgroundGapResumePending: Bool                   = false

    @Published var distanceEvents: [DistanceEvent] = []

    // MARK: - Fatigue Activity Tracking

    @Published var currentActivity:     ActivityType    = .offDuty

    @Published var currentSegmentStart: Date?           = nil

    @Published var segmentsToday:       [ActivitySegment] = []

    // MARK: - Odometer & Load Nudge State

    @Published var odoText:     String = ""

    @Published var prestartDone: Bool  = false

    @Published var odoLocationRecords:        [OdoLocationRecord] = []

    @Published var odoPromptTimestampOverride: Date?              = nil

    @Published var odoPromptContext:          OdoPromptContext?   = nil

    @Published var odoPromptOdoText:          String             = ""

    @Published var odoPromptSuburbText:       String             = ""

    @Published var pendingStartShiftCapture: Bool                = false

    @Published var pendingEndShiftCapture:   Bool                = false

    @Published var pendingActionAfterOdo:    (() -> Void)?       = nil

    @Published var showStoppedNudgeInLoad: Bool = false

    @Published var stoppedStartAt:         Date? = nil

    @Published var pendingStoppedNudge:    DispatchWorkItem? = nil

    var lastStoppedNudgeAt: Date? = nil

    var movementStartAt:    Date? = nil

    // MARK: - Guard Prompt State

    @Published var activeGuardPrompt: GuardPrompt? = nil

    @Published var isShowingIncidentSheet: Bool    = false

    @Published var incidentDraft:          IncidentReport?    = nil

    @Published var lastIncidentAdvicePlan: IncidentAdvicePlan? = nil

    // MARK: - Load Plan

    @Published var compartments:  [CompartmentModel] = []

    @Published var lazyAxleIsUp: Bool                = false

    @Published var fuelStepIndex: Int                = 6  // default = FULL

    @Published var confirmedLoads: [ConfirmedLoad]   = []

    @Published var isUnloadMode:   Bool              = false

    @Published var unloadFinalised: Bool             = false

    @Published var suppressPlacardUntilNextConfirm: Bool = false

    @Published var sgOverrides: [UUID: Double]       = [:]

    @Published var terminalName: String = "BP"

    @Published var loadCode:    String  = "6750"

    @Published var vehicleId:   String  = "277 WQH"

    @Published var selectedSupplierID: UUID? = nil

    @Published var resolvedSupplierName: String = "" 

    @Published var resolvedTerminalName: String = ""

    @Published var loadAccountCandidates: [LoadAccount] = []

  

    @Published var loadAccountResolveHint: String? = nil

    var loadCodeCanonical: String {

        loadCode.replacingOccurrences(of: " ", with: "")

    }

    // Phase 1 selection state (wire these to your Terminals screen)

    @Published var resolvedTerminalID: UUID? = nil

    @Published var resolvedLoadAccountID: UUID? = nil

    @Published var typedLoadNumber: String = ""

    @Published var loadAccountResolveError: String? = nil

    @Published var loadAccountAmbiguousMatches: [LoadAccount] = []

    var fuelStepFractions: [Double] { [0.0, 0.25, 1.0/3.0, 0.5, 2.0/3.0, 0.75, 1.0] }

    var fuelFraction: Double {

        let idx = min(max(fuelStepIndex, 0), fuelStepFractions.count - 1)

        return fuelStepFractions[idx]

    }

    var fuelStepLabel: String {

        switch fuelStepIndex {

        case 0: return "0"

        case 1: return "1/4"

        case 2: return "1/3"

        case 3: return "1/2"

        case 4: return "2/3"

        case 5: return "3/4"

        default: return "FULL"

        }

    }

    // MARK: - Templates & Simulation

    @Published var savedTemplates: [LoadTemplate] = []

    @Published var draftTemplate: LoadTemplate = LoadTemplate(

        name: "New template",

        items: [

            .init(compartmentName: "C1", productShortName: "DSL", litres: 0),

            .init(compartmentName: "C2", productShortName: "P91", litres: 0),

            .init(compartmentName: "C3", productShortName: "DSL", litres: 0),

            .init(compartmentName: "C4", productShortName: "DSL", litres: 0),

            .init(compartmentName: "C5", productShortName: "DSL", litres: 0)

        ]

    )

    let typicalLoadTemplates: [TypicalLoadTemplate] = [

        TypicalLoadTemplate(

            name: "Metro mix – ULP + Diesel",

            perCompartment: [

                "C1": ("DSL", 4500),

                "C2": ("P91", 2000),

                "C3": ("DSL", 3500),

                "C4": ("DSL", 3000),

                "C5": ("DSL", 7000)

            ]

        ),

        TypicalLoadTemplate(

            name: "All Diesel (high volume)",

            perCompartment: [

                "C1": ("DSL", 5000),

                "C2": ("DSL",    0),

                "C3": ("DSL", 4500),

                "C4": ("DSL", 3000),

                "C5": ("DSL", 7000)

            ]

        )

    ]

  

    // MARK: - Truck Config

    // Phase 1: hard-coded for Truck 92.

    // Axle split fractions are rough tuning values, not certified calculations.

    let truckConfig = TruckConfig(

        name: "Truck 92",

        tareSteerKg: 8400,

        tareDriveKg: 6200,

        runTankFullKg: 340,

        lazyLiftTransferKg: 660,

        maxSteerKg: 11000,

        maxDriveKg: 20000,

        maxGvmKg: 31000,

        axleSplitByCompartment: [

            "C1": AxleSplit(steerFraction:  0.70, driveFraction: 0.30),

            "C2": AxleSplit(steerFraction:  0.45, driveFraction: 0.55),

            "C3": AxleSplit(steerFraction:  0.15, driveFraction: 0.85),

            "C4": AxleSplit(steerFraction:  0.05, driveFraction: 0.95),

            "C5": AxleSplit(steerFraction: -0.23, driveFraction: 1.23)

        ]

    )

    // MARK: - Other Activities (UserDefaults persistence)

    // Pre-persistence exception: saved so drivers don't lose custom buttons between runs.

    @Published var otherActivities: [OtherActivity] = [

        OtherActivity(id: UUID(), name: "Training",   isWork: true),

        OtherActivity(id: UUID(), name: "Induction",  isWork: true),

        OtherActivity(id: UUID(), name: "Truck wash",  isWork: true)

    ] {

        didSet {

            guard initComplete else {

                DebugLog.lifecycle("⚠️ otherActivities didSet blocked during init")

                return

            }

            saveOtherActivities()

        }

    }

    // MARK: - AppConfig

    var gpsT: AppConfigV1.GpsTunables { appConfig.gps }

    func applyHotConfig(reason: String) {

        // MotionTunables is already used everywhere; just replace the bag.

        motionTunables = appConfig.motion

        DebugLog.autosave("🧩 Applied AppConfig (hot) reason=\(reason) savedAt=\(appConfig.savedAt)")

    }

    func reloadAppConfig(reason: String = "Manual reload") {

        if let cfg = saveStore.loadAppConfig() {

            appConfig = cfg

            applyHotConfig(reason: reason)

            DebugLog.autosave("✅ AppConfig reloaded")

        } else {

            DebugLog.autosave("⚠️ AppConfig not found at JSON/AppConfig/appconfig.json")

        }

    }

    func saveAppConfig(reason: String = "Manual save") {

        do {

            appConfig.savedAt = Date()

            try saveStore.writeAppConfig(appConfig)

            DebugLog.autosave("✅ AppConfig saved reason=\(reason)")

        } catch {

            DebugLog.autosave("❌ AppConfig save failed: \(error)")

        }

    }

    // MARK: - Init

    init() {

        guard !initComplete else {

            DebugLog.lifecycle("⚠️ AppModel init called multiple times – ignoring duplicate")

            return

        }

        DebugLog.lifecycle("🔧 AppModel init START \(Date())")

        compartments = [

            CompartmentModel(name: "C1", capacityLitres: 5360),

            CompartmentModel(name: "C2", capacityLitres: 3240),

            CompartmentModel(name: "C3", capacityLitres: 4900),

            CompartmentModel(name: "C4", capacityLitres: 3250),

            CompartmentModel(name: "C5", capacityLitres: 7240)

        ]

        loadOtherActivitiesIfAvailable()

        loadProfilesFromJSONIfAvailable()

        initComplete = true

        sessionBaseTimeZoneID = TimeZone.current.identifier

        DebugLog.lifecycle("🕒 TimeService base TZ seeded: \(sessionBaseTimeZoneID)")

        DebugLog.lifecycle("🔧 AppModel init COMPLETE \(Date())")

    }

    // MARK: - Ticker

    func startTickerIfNeeded() {

        guard tickerTask == nil else { return }

        tickerTask = Task { [weak self] in

            while !Task.isCancelled {

                try? await Task.sleep(nanoseconds: 1_000_000_000)

                await MainActor.run { self?.tick() }

            }

        }

    }

    func stopTicker() {

        tickerTask?.cancel()

        tickerTask = nil

    }

    // MARK: - Autosave

    func ensureAutosaveSetup() {

        guard autosave == nil else { return }

        autosave = AutoSaveController(model: self)

        saveStore.debugPrintSaveFolder()

        autosave?.restoreIfAvailable()

    }

    func clearAutosaveFiles() {

        autosave?.clearAutosaves()

        DebugLog.autosave("🧹 Cleared autosave files")

    }

    // MARK: - JSON Profiles (Driver + Settings)

    func loadProfilesFromJSONIfAvailable() {

        if let s = saveStore.loadSettings() {

            // map SettingsV1 -> DriverSettings

            settings.nhvrBaseName    = s.nhvrBaseName

            settings.nhvrBaseAddress = s.nhvrBaseAddress

            settings.nhvrRadiusKm    = s.nhvrRadiusKm

        }

        if let cfg = saveStore.loadAppConfig() {

            appConfig = cfg

            applyHotConfig(reason: "Init load")

        } else {

            // Optional: write defaults once so the file exists for editing

            // (comment out if you don't want the app to create files automatically)

            // try? saveStore.writeAppConfig(appConfig)

        }

        if let d = saveStore.loadDriverProfile() {

            // map DriverProfileV1 -> DriverSettings (and/or future driverProfile)

            settings.driverName = d.driverName

            // Only if these exist on DriverSettings:

            // settings.licenceType = d.licenceType.rawValue

            // settings.licenceHoursMode = d.licenceHoursMode.rawValue

            // settings.crewMode = d.crewMode.rawValue

            // settings.isOwnerDriver = d.isOwnerDriver

        }

        DebugLog.autosave("✅ Profiles loaded from JSON (if present)")

    }

    func saveProfilesToJSON() {

        do {

            try saveStore.writeSettings(settingsProfile)

            try saveStore.writeDriverProfile(driverProfile)

            DebugLog.autosave("✅ Profiles saved to JSON")

        } catch {

            DebugLog.autosave("❌ saveProfilesToJSON failed: \(error)")

        }

    }

    // MARK: - GPS Connection

    func connect(locationManager lm: LocationManager) {

        if isGpsConnected && !gpsCancellables.isEmpty { return }

        isGpsConnected = true

        startTickerIfNeeded()

        gpsCancellables.removeAll()

        // ✅ Seed LM with restored shift meters so LIVE GPS survives autosave restore

        Task { @MainActor in

            lm.setShiftMeters(self.gpsShiftMetersLive)

        }

        lm.$lastDeltaMeters

            .receive(on: DispatchQueue.main)

            .sink { [weak self] delta in

                guard let self else { return }

                self.lastLmDeltaMeters = delta

                guard delta > 0 else { return }

                self.ingestGpsDeltaMeters(delta)

            }

            .store(in: &gpsCancellables)

        Publishers.CombineLatest(lm.$rawSpeedMps, lm.$courseDegrees)

            .receive(on: DispatchQueue.main)

            .sink { [weak self] mps, course in

                guard let self else { return }

                self.lastLmValidSpeedMps = mps

                self.ingestSpeedSample(mps, course: course)

                self.considerMovementPrompt(speedMps: mps)

                self.considerStoppedNudgeInLoad(speedMps: mps)

            }

            .store(in: &gpsCancellables)

        lm.$gpsShiftMeters

            .receive(on: DispatchQueue.main)

            .sink { [weak self] meters in

                self?.gpsShiftMetersLive = meters

                self?.productionRawGpsDistanceKm = meters / 1000.0

            }

            .store(in: &gpsCancellables)

        lm.$lastLocation

            .receive(on: DispatchQueue.main)

            .sink { [weak self] loc in

                guard let self, let loc else { return }

                // Mirror each unique sample once into the alternate stack.

                if let last = self.shadowLastMirroredLocationTimestamp,

                   abs(last.timeIntervalSince(loc.timestamp)) < 0.0001 {

                    return

                }

                self.shadowLastMirroredLocationTimestamp = loc.timestamp

                self.shadowGpsEngine.handleLocationUpdate(loc)

            }

            .store(in: &gpsCancellables)

        lm.$lastGoodLocation

            .receive(on: DispatchQueue.main)

            .sink { [weak self] loc in

                guard let self else { return }

                self.lastGpsUpdateAt       = loc?.timestamp

                self.lastGpsAccuracyMeters = loc?.horizontalAccuracy

                guard self.backgroundGapResumePending,

                      self.isOnDuty,

                      let loc else { return }

                let now = Date()

                guard now.timeIntervalSince(loc.timestamp) < 3 else { return }

                self.backgroundGapResumePending = false

                self.backgroundGapCoordinator.estimateOnForegroundReturn(

                    at: now,

                    coord: loc.coordinate

                ) { [weak self] estimate in

                    guard let self else { return }

                    guard let estimate else { return }

                    self.lastBackgroundGapEstimate = estimate

                    self.backgroundGapHistory.append(estimate)

                    DebugLog.gps("🟧 BG estimate: \(estimate.note)")

                }

            }

            .store(in: &gpsCancellables)

    }

    func disconnectLocationManager() {

        gpsCancellables.removeAll()

        isGpsConnected = false

        stopTicker()

    }

    // MARK: - Workflow Reset

    func resetTransientWorkflows() {

        odoPromptContext           = nil

        odoPromptOdoText           = ""

        odoPromptSuburbText        = ""

        pendingActionAfterOdo      = nil

        pendingStartShiftCapture   = false

        pendingEndShiftCapture     = false

        odoPromptTimestampOverride = nil

        activeGuardPrompt = nil

        movementStartAt = nil

        lastNudgeAt     = nil

        stoppedStartAt  = nil

        pendingStoppedNudge?.cancel()

        pendingStoppedNudge = nil

        gpsKmPendingUntilFirstSegment = 0

        gpsKmSinceLastOdoBySegment.removeAll()

        finalisedKmBySegment.removeAll()

        kmCorrectionFactor = 1.0

        lastOdoAnchorKm    = nil

        lastOdoCaptureTime = nil

        shadowLastMirroredLocationTimestamp = nil

        shadowHasStartedSpan = false

        shadowProcessedTotalKmBacking = 0

        shadowRawTotalKmBacking = 0

        productionRawGpsDistanceKm = 0

        alternateProcessedGpsDistanceKm = 0

        alternateRawGpsDistanceKm = 0

        alternateEffectiveCorrectionFactor = 1.0

        lastShadowOdoDeltaKm = nil

        lastShadowRawGpsDeltaKm = nil

        lastShadowProcessedGpsDeltaKm = nil

        lastShadowChosenSource = nil

        lastShadowErrorVsOdoKm = nil

        shadowTelemetryAvailable = false

    }

    // MARK: - Shadow Telemetry Bridge

    func mirrorOdoCaptureToShadow(odoKm: Int, at timestamp: Date) {

        if !shadowHasStartedSpan {

            shadowGpsEngine.startSpan(startOdoKm: odoKm, at: timestamp)

            shadowHasStartedSpan = true

            alternateEffectiveCorrectionFactor = shadowGpsEngine.effectiveCorrectionFactor

            return

        }

        shadowGpsEngine.handleOdoCapture(newOdoKm: odoKm, timestamp: timestamp)

        alternateEffectiveCorrectionFactor = shadowGpsEngine.effectiveCorrectionFactor

        guard let log = shadowGpsEngine.spanLogs.last else { return }

        let processedDeltaKm: Double = {
    switch log.chosenSource {

    case .raw:
        return log.gpsRawKm

    case .filtered:
        return log.gpsFilteredKm ?? log.gpsRawKm
    }
}()

        shadowRawTotalKmBacking += log.gpsRawKm

        shadowProcessedTotalKmBacking += processedDeltaKm

        alternateRawGpsDistanceKm = shadowRawTotalKmBacking

        alternateProcessedGpsDistanceKm = shadowProcessedTotalKmBacking

        lastShadowOdoDeltaKm = log.odoDeltaKm

        lastShadowRawGpsDeltaKm = log.gpsRawKm

        lastShadowProcessedGpsDeltaKm = processedDeltaKm

        lastShadowChosenSource = log.chosenSource

        lastShadowErrorVsOdoKm = log.odoDeltaKm - processedDeltaKm
        
        let errorPercent =
    (lastShadowErrorVsOdoKm ?? 0) /
    max(log.odoDeltaKm, 0.001) * 100

        shadowTelemetryAvailable = true

    }

    // MARK: - Other Activity Persistence

    private func saveOtherActivities() {

        do {

            let data = try JSONEncoder().encode(otherActivities)

            UserDefaults.standard.set(data, forKey: Self.otherActivitiesKey)

        } catch {

            DebugLog.autosave("Failed to save otherActivities: \(error)")

        }

    }

    private func loadOtherActivitiesIfAvailable() {

        guard let data = UserDefaults.standard.data(forKey: Self.otherActivitiesKey) else { return }

        do {

            let decoded = try JSONDecoder().decode([OtherActivity].self, from: data)

            if !decoded.isEmpty { otherActivities = decoded }

        } catch {

            DebugLog.autosave("Failed to load otherActivities: \(error)")

        }

    }

}
