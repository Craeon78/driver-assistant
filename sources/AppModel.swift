//======================================
// MARK: - AppModel
//======================================
//
// © 2026 Cory Russell Olsen. All rights reserved.
//
// Path: AppModels/AppModel.swift
//
// Purpose:
// - Central state container and orchestration hub for the Driver Assistant app.
// - Owns all @Published stored properties, cross-domain runtime state, and app-level wiring.
//
// Responsibilities:
// - Hold canonical in-memory app/session state across all domains.
// - Coordinate lifecycle, autosave, ticker, and GPS connection wiring.
// - Expose shared runtime state to AppModel extension files.
// - Keep stored state centralised while domain logic lives in AppModel+*.swift files.
//
// Notes:
// - This file owns state; behavioural/domain logic should live in the extension files wherever practical.
// - Swift extensions cannot store @Published properties, so AppModel remains the single storage root.
// - Pre-persistence, this file is the main in-memory state spine; post-persistence it remains the orchestration shell.
//
// Phase: Pre-persistence
//======================================

import SwiftUI
import Combine
import CoreLocation

@MainActor
final class AppModel: ObservableObject {
    
    //======================================
    // MARK: - Core Services / Runtime
    //======================================
    
    let time = TimeService()
    let saveStore = SaveStore()
    
    var autosave: AutoSaveController?
    private var initComplete = false
    private var timer: Timer?
    private var tickerTask: Task<Void, Never>?
    private var gpsCancellables = Set<AnyCancellable>()
    var isGpsConnected = false
    
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
    
    @Published var confirmedLoads: [ConfirmedLoad] = []
    @Published var isUnloadMode: Bool = false
    @Published var unloadFinalised: Bool = false
    @Published var suppressPlacardUntilNextConfirm: Bool = false
    @Published var sgOverrides: [UUID: Double] = [:]
    
    @Published var terminalName: String = "BP"
    @Published var loadCode: String = "6750"
    @Published var vehicleId: String = "277 WQH"
    
    @Published var selectedSupplierID: UUID? = nil
    @Published var resolvedSupplierName: String = ""
    @Published var resolvedTerminalName: String = ""
    
    @Published var loadAccountCandidates: [LoadAccount] = []
    @Published var loadAccountResolveHint: String? = nil
    @Published var resolvedTerminalID: UUID? = nil
    @Published var resolvedLoadAccountID: UUID? = nil
    @Published var typedLoadNumber: String = ""
    @Published var loadAccountResolveError: String? = nil
    @Published var loadAccountAmbiguousMatches: [LoadAccount] = []
    
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
                "C2": ("DSL", 0),
                "C3": ("DSL", 4500),
                "C4": ("DSL", 3000),
                "C5": ("DSL", 7000)
            ]
        )
    ]
    
    var loadCodeCanonical: String {
        loadCode.replacingOccurrences(of: " ", with: "")
    }
    
    var fuelStepFractions: [Double] {
        [0.0, 0.25, 1.0 / 3.0, 0.5, 2.0 / 3.0, 0.75, 1.0]
    }
    
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
    
    //======================================
    // MARK: - Truck Config / Reference
    //======================================
    
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
            "C1": AxleSplit(steerFraction: 0.70, driveFraction: 0.30),
            "C2": AxleSplit(steerFraction: 0.45, driveFraction: 0.55),
            "C3": AxleSplit(steerFraction: 0.15, driveFraction: 0.85),
            "C4": AxleSplit(steerFraction: 0.05, driveFraction: 0.95),
            "C5": AxleSplit(steerFraction: -0.23, driveFraction: 1.23)
        ]
    )
    
    //======================================
    // MARK: - GPS / Motion / Distance State
    //======================================
    
    @Published var gpsKmSinceLastOdoBySegment: [UUID: Double] = [:]
    @Published var finalisedKmBySegment: [UUID: Double] = [:]
    @Published var runningSegmentID: UUID? = nil
    
    @Published var lastOdoAnchorRecordID: UUID? = nil
    @Published var lastOdoAnchorKm: Int? = nil
    @Published var kmCorrectionFactor: Double = 1.0
    @Published var lastOdoCaptureTime: Date? = nil
    
    @Published var gpsKmPendingUntilFirstSegment: Double = 0
    @Published var gpsIngestSeq: Int = 0
    @Published var gpsShiftMetersLive: Double = 0
    
    @Published var lastGpsUpdateAt: Date? = nil
    @Published var lastGpsAccuracyMeters: Double? = nil
    @Published var lastGpsWasStalled: Bool = false
    @Published var lastLmDeltaMeters: Double = 0
    @Published var lastLmValidSpeedMps: Double? = nil
    
    @Published var lastKnownCourseDegrees: Double? = nil
    @Published var lastKnownSpeedMps: Double? = nil
    @Published var lastSpeedSampleAt: Date? = nil
    
    @Published var motionState: MotionState = .unsure
    @Published var showMotionDebug: Bool = true
    @Published var motionUncertaintyReasons: [String] = []
    @Published var motionCertaintyReasons: [String] = []
    
    var motionTunables = MotionTunables()
    var speedSamples: [SpeedSample] = []
    let maxSpeedSamples: Int = 8
    
    var courseSamples: [Double] = []
    let maxCourseHistory: Int = 5
    
    var stateChangeHistory: [Date] = []
    var stoppedAccumulatorStart: Date? = nil
    var pendingStoppedAt: Date? = nil
    var pendingMovingAt: Date? = nil
    
    // Distance guard / motion quality
    var lastDistanceIngestAt: Date? = nil
    var distanceSpikeCount: Int = 0
    var motionQualityStrikes: Int = 0
    var motionLastQualityStrikeAt: Date? = nil
    var decelUnsureGraceStartedAt: Date?
    var lastAutoRecoverAt: Date? = nil
    var lowMotionSince: Date? = nil
    
    @Published var lastAutoRecoverFiredAt: Date? = nil
    @Published var lastAutoRecoverReason: String? = nil
    
    //======================================
    // MARK: - Background Gap Advisory / Recovery
    //======================================
    
    let backgroundGapCoordinator = BackgroundGapCoordinator()
    
    @Published var lastBackgroundGapEstimate: BackgroundGapEstimate?
    @Published var backgroundGapHistory: [BackgroundGapEstimate] = []
    
    @Published var backgroundGapStartAt: Date? = nil
    @Published var backgroundGapStartCoord: CLLocationCoordinate2D? = nil
    @Published var backgroundGapEndAt: Date? = nil
    @Published var backgroundGapEndCoord: CLLocationCoordinate2D? = nil
    
    @Published var pendingGapEstimateMeters: Double? = nil
    @Published var pendingGapEstimateSegmentID: UUID? = nil
    @Published var pendingGapReason: String? = nil
    @Published var pendingGapSegmentID: UUID? = nil
    @Published var backgroundGapResumePending: Bool = false
    
    var hasLoggedResumeNotPending = false
    @Published var distanceEvents: [DistanceEvent] = []
    
    @Published var backgroundGapRecords: [BackgroundGapRecord] = []
    @Published var activeBackgroundGapID: UUID? = nil
    
    //======================================
    // MARK: - Shadow Telemetry (Alternate GPS Engine)
    //======================================
    
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
    
    // UI hooks for GPS/runtime control
    var requestGpsKickFromUI: ((String) -> Void)? = nil
    var requestLmResetShiftMetersFromUI: ((String) -> Void)? = nil
    
    //======================================
    // MARK: - Other Activities (UserDefaults Exception)
    //======================================
    
    @Published var otherActivities: [OtherActivity] = [
        OtherActivity(id: UUID(), name: "Training", isWork: true),
        OtherActivity(id: UUID(), name: "Induction", isWork: true),
        OtherActivity(id: UUID(), name: "Truck wash", isWork: true)
    ] {
        didSet {
            guard initComplete else {
                DebugLog.lifecycle("⚠️ otherActivities didSet blocked during init")
                return
            }
            saveOtherActivities()
        }
    }
    
    //======================================
    // MARK: - Init
    //======================================
    
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
    
    //======================================
    // MARK: - Runtime Wiring
    //======================================
    
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
    
    func connect(locationManager lm: LocationManager) {
        if isGpsConnected && !gpsCancellables.isEmpty { return }
        
        isGpsConnected = true
        startTickerIfNeeded()
        gpsCancellables.removeAll()
        
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
                
                self.lastGpsUpdateAt = loc?.timestamp
                self.lastGpsAccuracyMeters = loc?.horizontalAccuracy
                
                guard self.backgroundGapResumePending else {
                    if !self.hasLoggedResumeNotPending {
                        DebugLog.lifecycle("⛔ BG completion skipped: resume not pending")
                        self.hasLoggedResumeNotPending = true
                    }
                    return
                }
                
                guard self.isOnDuty else {
                    DebugLog.lifecycle("⛔ BG completion skipped: not on duty")
                    return
                }
                
                guard let loc else {
                    DebugLog.lifecycle("⛔ BG completion skipped: no lastGoodLocation")
                    return
                }
                
                let now = Date()
                let age = now.timeIntervalSince(loc.timestamp)
                let lat = String(format: "%.6f", loc.coordinate.latitude)
                let lon = String(format: "%.6f", loc.coordinate.longitude)
                let acc = String(format: "%.1f", loc.horizontalAccuracy)
                let ageText = String(format: "%.2f", age)
                
                guard age < 3 else {
                    DebugLog.lifecycle("⛔ BG completion blocked: stale good fix at=\(now) fix=\(loc.timestamp) age=\(ageText)s acc=\(acc)m lat=\(lat) lon=\(lon)")
                    return
                }
                
                DebugLog.lifecycle("✅ BG completion accepted at=\(now) fix=\(loc.timestamp) age=\(ageText)s acc=\(acc)m lat=\(lat) lon=\(lon)")
                
                self.backgroundGapResumePending = false
                
                if let startAt = self.backgroundGapStartAt,
                   let startCoord = self.backgroundGapStartCoord {
                    
                    let startLoc = CLLocation(latitude: startCoord.latitude, longitude: startCoord.longitude)
                    let endLoc = CLLocation(latitude: loc.coordinate.latitude, longitude: loc.coordinate.longitude)
                    
                    let straightLineKm = startLoc.distance(from: endLoc) / 1000.0
                    let elapsed = now.timeIntervalSince(startAt)
                    
                    // Embryonic-stage rough road estimate only.
                    let estimatedRoadKm = straightLineKm * 1.2
                    
                    let gap = BackgroundGapRecord(
                        startTime: startAt,
                        endTime: now,
                        startLat: startCoord.latitude,
                        startLon: startCoord.longitude,
                        endLat: loc.coordinate.latitude,
                        endLon: loc.coordinate.longitude,
                        elapsedSeconds: elapsed,
                        straightLineKm: straightLineKm,
                        estimatedRoadKm: estimatedRoadKm,
                        isResolved: false,
                        resolutionNote: nil
                    )
                    
                    self.backgroundGapRecords.append(gap)
                    self.activeBackgroundGapID = gap.id
                    
                    DebugLog.lifecycle(
                        "🟡 BG record created " +
                        "elapsed=\(Int(elapsed))s " +
                        "straight=\(String(format: "%.2f", straightLineKm))km " +
                        "roadEst=\(String(format: "%.2f", estimatedRoadKm))km"
                    )
                }
                
                self.backgroundGapCoordinator.estimateOnForegroundReturn(
                    at: now,
                    coord: loc.coordinate
                ) { [weak self] estimate in
                    guard let self else { return }
                    guard let estimate else { return }
                    
                    let minGapSeconds = 10.0
                    let minGapDistanceKm = 0.05
                    
                    let elapsedSeconds = estimate.endAt.timeIntervalSince(estimate.startAt)
                    let roadEstimateKm = Double(estimate.suggestedOdoDeltaKm)
                    
                    if elapsedSeconds < minGapSeconds {
                        DebugLog.gps("🟨 BG skipped: too short elapsed=\(Int(elapsedSeconds))s")
                        return
                    }
                    
                    if roadEstimateKm < minGapDistanceKm {
                        DebugLog.gps("🟨 BG skipped: too small roadEst=\(String(format: "%.2f", roadEstimateKm))km")
                        return
                    }
                    
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
    
    //======================================
    // MARK: - Config / Profile IO
    //======================================
    
    func applyHotConfig(reason: String) {
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
    
    func loadProfilesFromJSONIfAvailable() {
        if let s = saveStore.loadSettings() {
            settings.nhvrBaseName = s.nhvrBaseName
            settings.nhvrBaseAddress = s.nhvrBaseAddress
            settings.nhvrRadiusKm = s.nhvrRadiusKm
        }
        
        if let cfg = saveStore.loadAppConfig() {
            appConfig = cfg
            applyHotConfig(reason: "Init load")
        }
        
        if let d = saveStore.loadDriverProfile() {
            settings.driverName = d.driverName
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
    
    //======================================
    // MARK: - Workflow Reset / Telemetry Reset
    //======================================
    
    func resetTransientWorkflows() {
        odoPromptContext = nil
        odoPromptOdoText = ""
        odoPromptSuburbText = ""
        pendingActionAfterOdo = nil
        pendingStartShiftCapture = false
        pendingEndShiftCapture = false
        odoPromptTimestampOverride = nil
        
        activeGuardPrompt = nil
        movementStartAt = nil
        lastNudgeAt = nil
        stoppedStartAt = nil
        pendingStoppedNudge?.cancel()
        pendingStoppedNudge = nil
        
        gpsKmPendingUntilFirstSegment = 0
        gpsKmSinceLastOdoBySegment.removeAll()
        finalisedKmBySegment.removeAll()
        kmCorrectionFactor = 1.0
        lastOdoAnchorKm = nil
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
        lastShadowErrorPercent = (lastShadowErrorVsOdoKm ?? 0) / max(log.odoDeltaKm, 0.001) * 100
        shadowTelemetryAvailable = true
    }
    
    //======================================
    // MARK: - Local Persistence Exceptions
    //======================================
    
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
