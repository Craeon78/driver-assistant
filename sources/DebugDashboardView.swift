//======================================
// MARK: - DebugDashboardView
//======================================
//
// Path:
// - Views/Debug/DebugDashboardView.swift
//
// Purpose:
// - Developer-facing diagnostic surface for inspecting live app state,
//   workflow gates, GPS / motion confidence, background-gap behaviour,
//   shadow telemetry, autosave state, and destructive recovery actions.
//
// Responsibilities:
// - Expose current runtime truth and convenience flags for inspection.
// - Surface workflow blockers such as pending ODO gates and missing
//   shift-start requirements.
// - Show GPS / motion evidence, certainty scoring, and related tuning
//   context without mixing that logic into production UI.
// - Show shadow telemetry and ODO-vs-GPS comparison data used to assess
//   reconciliation quality.
// - Display background-gap estimates and raw background-gap records for
//   development and recovery testing.
// - Provide access to timeline / event / confirmed-load inspection.
// - Provide autosave inspection and manual recovery / reset controls.
// - Host temporary debug-only actions while persistence and review flows
//   are still evolving.
//
// Current sections:
// 1. State Inspector
//    - live shift/activity flags and core runtime state
// 2. Workflow Gates
//    - ODO / guard / activity readiness blockers
// 3. GPS & Motion
//    - certainty scores, live evidence, background-gap advisory state
// 4. GPS vs ODO (Shadow)
//    - alternate engine / reconciliation telemetry
// 5. Timeline & Events
//    - event count, segment count, confirmed-load inspection
// 6. Background Gap Records
//    - raw unresolved / resolved gap captures for testing
// 7. Autosave Management
//    - save inspection, flush, file stats, debug save paths
// 8. Edge Case Triggers
//    - deliberate fault injection for workflow testing
// 9. Destructive Actions
//    - reset / clear / wipe operations requiring explicit confirmation
//
// Notes:
// - DebugDashboardView is intentionally separate from production-facing
//   Settings or driver UI.
// - This screen may expose transitional or temporary diagnostics that
//   exist only while systems are being proven pre-persistence.
// - Background-gap rows shown here are raw debug records, not yet the
//   final driver-facing review/finalisation UX.
// - Values shown here may combine canonical truth, evidence, heuristics,
//   and in-progress tuning data; the dashboard exists to help distinguish
//   those layers, not blur them.
//
// Safety:
// - Destructive actions must remain clearly labelled and confirmed.
// - Debug helpers should not silently alter canonical truth without the
//   action being explicit in the UI.
// - Keep this file focused on inspection, testing, and controlled debug
//   intervention — not on normal driver workflow.
//======================================

import SwiftUI
import CoreLocation


struct DebugDashboardView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var locationManager: LocationManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingClearConfirm = false
    @State private var showingResetConfirm = false
    @State private var showingAutosaveInspector = false
    
    var body: some View {
        NavigationStack {
            Form {
                
                // MARK: State Inspector
                Section(header: Text("🔍 State Inspector")) {
                    stateInspectorContent
                }
                
                // MARK: Workflow Gates
                Section(header: Text("🚪 Workflow Gates")) {
                    workflowGatesContent
                }
                
                // MARK: GPS & Motion
                Section(header: Text("📍 GPS & Motion")) {
                    gpsMotionContent
                }
                
                // MARK: Gps Info
                Section(header: Text("📏 GPS vs ODO (Shadow)")) {
                    LabeledContent("ODO Δ", value: shadowOdoDeltaText)
                    LabeledContent("GPS raw", value: shadowRawGpsText)
                    LabeledContent("GPS filt", value: shadowFilteredGpsText)
                    LabeledContent("Source", value: shadowSourceText)
                    LabeledContent("Error", value: shadowErrorKmText)
                    LabeledContent("Error %", value: shadowErrorPercentText)
                    LabeledContent("Corr", value: shadowCorrectionFactorText)
                    LabeledContent("GPS corr", value: shadowCorrectedGpsText)
                }
                
                // MARK: Timeline
                Section(header: Text("📋 Timeline & Events")) {
                    timelineForensicsContent
                }
                
                // MARK: Background Gap Records
                Section(header: Text("🟡 Background Gap Records")) {
                    backgroundGapRecordsContent
                }
                
                // MARK: Autosave
                Section(header: Text("💾 Autosave Management")) {
                    autosaveManagementContent
                }
                
                // MARK: Edge Case Triggers
                Section(header: Text("⚠️ Edge Case Triggers")) {
                    edgeCaseTriggersContent
                }
                
                // MARK: Destructive
                Section(header: Text("💣 Destructive Actions")) {
                    destructiveActionsContent
                }
            }
            .navigationTitle("Debug Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(isPresented: $showingAutosaveInspector) {
                AutosaveInspectorSheet()
                    .environmentObject(model)
            }
        }
    }
    
    //==================================
    // MARK: - Sections
    //==================================
    
    private var stateInspectorContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent("On Duty", value: model.isOnDuty ? "✅" : "❌")
            LabeledContent("Activity", value: model.currentActivity.rawValue)
            LabeledContent("Driving", value: model.isDriving ? "✅" : "❌")
            LabeledContent("On Break", value: model.isOnBreak ? "✅" : "❌")
            
            if let sid = model.runningSegmentID {
                LabeledContent("Running Segment", value: sid.uuidString)
            } else {
                LabeledContent("Running Segment", value: "nil")
            }
            
            LabeledContent("Drive Seconds Today", value: formatDuration(model.driveSecondsToday))
            LabeledContent("Work Seconds Today", value: formatDuration(model.workSecondsToday))
            LabeledContent("Rest Seconds Today", value: formatDuration(model.restSecondsToday))
            
            LabeledContent("Motion State", value: model.motionState.rawValue)
        }
    }
    
    private var workflowGatesContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent("Pending Start ODO", value: model.pendingStartShiftCapture ? "🔒" : "✅")
            LabeledContent("Missing Shift ODO", value: model.isMissingShiftStartOdo ? "⚠️" : "✅")
            LabeledContent("ODO Context", value: model.odoPromptContext?.rawValue ?? "nil")
            
            if model.pendingActionAfterOdo != nil {
                Label("Pending Action Queued", systemImage: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
            }
            
            LabeledContent("Load Mode", value: model.isUnloadMode ? "Unload" : "Load")
            LabeledContent("Prestart Done", value: model.prestartDone ? "✅" : "❌")
        }
    }
    
    private func overallCertaintyDetail(now: Date = Date()) -> CertaintyDetail {
        let gpsD = gpsCertaintyDetail(now: now)
        let motD = motionCertaintyDetail(now: now)
        
        let gps = gpsD.score
        let motion = motD.score
        let lower = min(gps, motion)
        let higher = max(gps, motion)
        
        let overallRaw: Double = {
            if lower < 20 { return Double(lower) }
            else if lower < 35 { return Double(lower) * 0.8 + Double(higher) * 0.2 }
            else { return Double(lower) * 0.65 + Double(higher) * 0.35 }
        }()
        
        let overall = max(0, min(100, Int(overallRaw.rounded())))
        
        let weaker = (gps <= motion) ? "GPS" : "Motion"
        let blendReason: String = {
            if lower < 20 { return "blend: HARD floor (weaker=\(weaker))" }
            if lower < 35 { return "blend: 80/20 toward weaker=\(weaker)" }
            return "blend: 65/35 toward weaker=\(weaker)"
        }()
        
        return CertaintyDetail(
            score: overall,
            ageSeconds: nil,
            reasons: [blendReason]
        )
    }
    
    private struct CertaintyDetail {
        var score: Int
        var ageSeconds: Double?          // nil = unknown
        var reasons: [String]            // already includes penalties
    }
    
    private var gpsMotionContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            
            // -----------------------------
            // Certainty scores (driver-useful)
            // -----------------------------
            
            let gpsD = gpsCertaintyDetail()
            let motD = motionCertaintyDetail()
            let ovD  = overallCertaintyDetail()
            
            LabeledContent("Overall certainty", value: "\(certaintyLabel(ovD.score)) (\(ovD.score)%)")
            Text(ovD.reasons.joined(separator: " • "))
                .font(.caption2)
                .foregroundStyle(.secondary)
            
            LabeledContent("GPS certainty", value: "\(certaintyLabel(gpsD.score)) (\(gpsD.score)%)")
            if let a = gpsD.ageSeconds {
                Text("age: \(Int(a))s • \(gpsD.reasons.joined(separator: " • "))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text(gpsD.reasons.joined(separator: " • "))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            LabeledContent("Motion certainty", value: "\(certaintyLabel(motD.score)) (\(motD.score)%)")
            if let a = motD.ageSeconds {
                Text("age: \(Int(a))s • \(motD.reasons.joined(separator: " • "))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text(motD.reasons.joined(separator: " • "))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Divider()
            
            // -----------------------------
            // Key evidence (keep it tight)
            // -----------------------------
            LabeledContent("Location Auth", value: locationManager.authDebug)
            LabeledContent("Service State", value: locationManager.stateDebug)
            
            if let acc = locationManager.lastLocation?.horizontalAccuracy {
                LabeledContent("Accuracy", value: "\(Int(acc.rounded())) m")
            } else {
                LabeledContent("Accuracy", value: "nil")
            }
            
            if let v = locationManager.lastValidSpeedMps {
                LabeledContent("Speed (valid)", value: String(format: "%.1f km/h", v * 3.6))
            } else if let raw = locationManager.rawSpeedMps {
                LabeledContent("Speed (raw)", value: String(format: "%.1f km/h", raw * 3.6))
            } else {
                LabeledContent("Speed", value: "nil")
            }
            
            if let ts = locationManager.lastLocation?.timestamp {
                LabeledContent("Last GPS update", value: formatTimeAgo(ts))
            } else if let t = locationManager.lastUpdateAt {
                LabeledContent("Last GPS update", value: formatTimeAgo(t))
            } else {
                LabeledContent("Last GPS update", value: "nil")
            }
            
            LabeledContent("Motion", value: model.motionState.shortLabel)
            
            Divider()
            
            // -----------------------------
            // Background Gap (advisory)
            // -----------------------------
            GroupBox("Background gap (advisory)") {
                VStack(alignment: .leading, spacing: 8) {
                    
                    LabeledContent("Resume pending", value: model.backgroundGapResumePending ? "✅" : "—")
                    
                    if let est = model.lastBackgroundGapEstimate {
                        LabeledContent("Suggested", value: "+\(est.suggestedOdoDeltaKm) km")
                        LabeledContent("Method", value: est.method.rawValue)
                        LabeledContent("Confidence", value: est.confidence.rawValue)
                        Text(est.note)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    } else {
                        LabeledContent("Last estimate", value: "nil")
                    }
                    
                    LabeledContent("History count", value: "\(model.backgroundGapHistory.count)")
                    
                    // ODO vs GPS window sanity check (spicy but useful)
                    let gpsWindow = model.gpsKmSinceLastOdoBySegment.values.reduce(0, +)
                    LabeledContent("GPS window since ODO", value: "\(fmtKm(gpsWindow)) km")
                    
                    if let anchor = model.lastOdoAnchorKm,
                       let current = Int(model.odoText.filter(\.isNumber)) {
                        
                        let odoDelta = max(0, current - anchor)
                        let err = Double(odoDelta) - gpsWindow
                        LabeledContent("ODOΔ vs GPSΔ", value: "\(odoDelta) km | err \(fmtKm(err)) km")
                    }
                    
                    // Quick controls
                    HStack {
                        Button {
                            model.clearBackgroundGapAdvisory(reason: "Debug Dashboard")
                        } label: {
                            Label("Clear BG advisory", systemImage: "xmark.circle")
                        }
                        
                        Spacer()
                        
                        Button {
                            locationManager.kickUpdates(reason: "Debug Dashboard (BG)")
                        } label: {
                            Label("Kick GPS", systemImage: "location.circle")
                        }
                    }
                    .font(.caption)
                }
            }
            
            // -----------------------------
            // Details (nerd view)
            // -----------------------------
            DisclosureGroup("Details") {
                VStack(alignment: .leading, spacing: 10) {
                    
                    // ==========================
                    // GPS evidence (score inputs)
                    // ==========================
                    GroupBox("GPS evidence (feeds GPS score)") {
                        VStack(alignment: .leading, spacing: 8) {
                            
                            if let t = locationManager.lastUpdateAt {
                                LabeledContent("LM lastUpdateAt", value: formatTimeAgo(t))
                            } else { LabeledContent("LM lastUpdateAt", value: "nil") }
                            
                            if let ts = locationManager.lastLocation?.timestamp {
                                LabeledContent("CLLocation.timestamp", value: formatTimeAgo(ts))
                            } else { LabeledContent("CLLocation.timestamp", value: "nil") }
                            
                            if let acc = locationManager.lastLocation?.horizontalAccuracy {
                                LabeledContent("Accuracy", value: "\(Int(acc.rounded())) m")
                            } else { LabeledContent("Accuracy", value: "nil") }
                            
                            LabeledContent("Auth", value: locationManager.authDebug)
                            LabeledContent("Service State", value: locationManager.stateDebug)
                            
                            LabeledContent("LM lastDeltaMeters", value: String(format: "%.1f", locationManager.lastDeltaMeters))
                            LabeledContent("LM gpsShiftMeters", value: String(format: "%.1f", locationManager.gpsShiftMeters))
                        }
                    }
                    
                    // ==========================
                    // Motion evidence (score inputs)
                    // ==========================
                    GroupBox("Motion evidence (feeds Motion score)") {
                        VStack(alignment: .leading, spacing: 8) {
                            
                            if let v = locationManager.lastValidSpeedMps {
                                LabeledContent("Speed (valid)", value: String(format: "%.1f km/h", v * 3.6))
                            } else if let raw = locationManager.rawSpeedMps {
                                LabeledContent("Speed (raw)", value: String(format: "%.1f km/h", raw * 3.6))
                            } else {
                                LabeledContent("Speed", value: "nil")
                            }
                            
                            if let smoothed = locationManager.speedMps {
                                LabeledContent("Speed (smoothed)", value: String(format: "%.1f km/h", smoothed * 3.6))
                            } else { LabeledContent("Speed (smoothed)", value: "nil") }
                            
                            if let c = locationManager.courseDegrees {
                                LabeledContent("Course (°)", value: String(format: "%.0f", c))
                            } else { LabeledContent("Course (°)", value: "nil") }
                            
                            Divider()
                            
                            // Read-only snapshot (keeps your current “why is this happening?” clarity)
                            GroupBox("AppConfig (loaded)") {
                                VStack(alignment: .leading, spacing: 8) {
                                    LabeledContent("SavedAt", value: formatTimeAgo(model.appConfig.savedAt))
                                    LabeledContent("StrikesToUnsure", value: "\(model.motionTunables.qualityStrikesToUnsure)")
                                    LabeledContent("MaxPlausibleSpeed", value: String(format: "%.1f m/s", model.gpsT.maxPlausibleSpeedMpsForDistance))
                                    
                                    Button {
                                        model.reloadAppConfig(reason: "Debug Dashboard")
                                    } label: {
                                        Label("Reload AppConfig", systemImage: "arrow.clockwise")
                                    }
                                }
                            }
                            
                            // AppModel motion pipeline
                            LabeledContent("MotionState", value: model.motionState.shortLabel)
                            
                            if let t = model.lastSpeedSampleAt {
                                LabeledContent("App lastSpeedSampleAt", value: formatTimeAgo(t))
                            } else { LabeledContent("App lastSpeedSampleAt", value: "nil") }
                            
                            if let s = model.lastKnownSpeedMps {
                                LabeledContent("App lastKnownSpeed", value: String(format: "%.1f km/h", s * 3.6))
                            } else { LabeledContent("App lastKnownSpeed", value: "nil") }
                            
                            LabeledContent("SpeedSamples", value: "\(model.speedSamples.count)")
                            LabeledContent("CourseSamples", value: "\(model.courseSamples.count)")
                            
                            if let start = model.stoppedAccumulatorStart {
                                LabeledContent("Stop accumulator", value: formatTimeAgo(start))
                            } else {
                                LabeledContent("Stop accumulator", value: "nil")
                            }
                        }
                    }
                    
                    // ==========================
                    // 🛠 AppConfig tweakables (MOVED UP)
                    // ==========================
                    GroupBox("🛠 AppConfig (live)") {
                        
                        if let t = model.lastConfigLoadedAt {
                            Text("Loaded: \(t.formatted())")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        
                        Stepper(
                            "Quality strikes → UNSURE: \(model.appConfig.motion.qualityStrikesToUnsure)",
                            value: Binding(
                                get: { model.appConfig.motion.qualityStrikesToUnsure },
                                set: { model.appConfig.motion.qualityStrikesToUnsure = $0 }
                            ),
                            in: 1...6
                        )
                        
                        Slider(
                            value: Binding(
                                get: { model.appConfig.motion.gpsStaleSeconds },
                                set: { model.appConfig.motion.gpsStaleSeconds = $0 }
                            ),
                            in: 1...6,
                            step: 0.5
                        ) {
                            Text("GPS stale seconds")
                        }
                        
                        Text("gpsStaleSeconds: \(model.appConfig.motion.gpsStaleSeconds, specifier: "%.1f")")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        
                        Button("Apply (no save)") {
                            model.applyHotConfig(reason: "Debug apply")
                        }
                        
                        Button("Save to JSON") {
                            model.saveAppConfig(reason: "Debug Dashboard")
                        }
                        
                        Button("Reload from JSON") {
                            model.reloadAppConfig(reason: "Reload from JSON (Debug)")
                        }
                    }
                    
                    // ==========================
                    // Distance / ODO (not score inputs)
                    // ==========================
                    GroupBox("Distance / ODO evidence (not used by certainty)") {
                        VStack(alignment: .leading, spacing: 8) {
                            LabeledContent("Pending GPS km", value: String(format: "%.3f", model.gpsKmPendingUntilFirstSegment))
                            LabeledContent("Km this segment", value: String(format: "%.3f", model.currentSegmentKmApprox))
                            LabeledContent("Km this shift (LIVE GPS)", value: String(format: "%.3f", model.shiftKmLiveGps))
                            LabeledContent("Km this shift", value: String(format: "%.3f", model.shiftKmBySegmentsApprox))
                            
                            let drift = model.shiftKmLiveGps - model.shiftKmBySegmentsApprox
                            LabeledContent("Δ live-seg", value: String(format: "%.2f km", drift))
                        }
                    }
                    
                    Divider()
                    
                    // Actions stay at bottom
                    Button {
                        model.resetMotionInference(reason: "Debug Dashboard")
                        locationManager.kickUpdates(reason: "Debug Dashboard")
                    } label: {
                        Label("Reset Motion + Kick GPS", systemImage: "arrow.clockwise.circle")
                    }
                    
                    Button {
                        locationManager.kickUpdates(reason: "Debug Dashboard")
                    } label: {
                        Label("Kick GPS Only", systemImage: "location.circle")
                    }
                }
                .padding(.top, 6)
            }
        }
        
    }
    
    // =====================================================
    // MARK: - Certainty helpers (pasted inside DebugDashboardView)
    // =====================================================
    
    private func certaintyLabel(_ score: Int) -> String {
        switch score {
        case 80...100: return "HIGH"
        case 55...79:  return "MED"
        case 30...54:  return "LOW"
        default:       return "UNTRUSTWORTHY"
        }
    }
    
    private func gpsCertaintyDetail(now: Date = Date()) -> CertaintyDetail {
        if locationManager.authDebug == "denied" || locationManager.authDebug == "restricted" {
            return CertaintyDetail(score: 0, ageSeconds: nil, reasons: ["auth \(locationManager.authDebug) (0)"])
        }
        
        var score = 100
        var reasons: [String] = []
        
        if locationManager.stateDebug == "reduced" {
            score -= 25
            reasons.append("reduced accuracy (-25)")
        }
        
        if let acc = locationManager.lastLocation?.horizontalAccuracy {
            if acc > 100 { score -= 40; reasons.append("accuracy \(Int(acc))m (-40)") }
            else if acc > 50 { score -= 20; reasons.append("accuracy \(Int(acc))m (-20)") }
            else if acc > 20 { score -= 10; reasons.append("accuracy \(Int(acc))m (-10)") }
        } else {
            score -= 25
            reasons.append("accuracy nil (-25)")
        }
        
        let age: Double? = {
            if let ts = locationManager.lastLocation?.timestamp { return now.timeIntervalSince(ts) }
            if let t = locationManager.lastUpdateAt { return now.timeIntervalSince(t) }
            return nil
        }()
        
        if let a = age {
            if a > 20 { score -= 60; reasons.append("stale \(Int(a))s (-60)") }
            else if a > 10 { score -= 35; reasons.append("stale \(Int(a))s (-35)") }
            else if a > 5 { score -= 15; reasons.append("stale \(Int(a))s (-15)") }
        } else {
            score -= 40
            reasons.append("age unknown (-40)")
        }
        
        if locationManager.stateDebug == "stalled" {
            let stoppedish = (locationManager.lastValidSpeedMps ?? 999) < 1.0
            if stoppedish {
                score -= 10
                reasons.append("stalled but stopped (-10)")
            } else {
                score -= 40
                reasons.append("stalled while moving (-40)")
            }
        }
        
        score = max(0, min(100, score))
        return CertaintyDetail(score: score, ageSeconds: age, reasons: reasons)
    }
    
    private func motionCertaintyDetail(now: Date = Date()) -> CertaintyDetail {
        var score = 100
        var reasons: [String] = []
        
        if model.motionState == .unsure {
            return CertaintyDetail(
                score: 25,
                ageSeconds: model.lastSpeedSampleAt.map { now.timeIntervalSince($0) },
                reasons: ["motionState UNSURE (cap 25)"]
            )
        }
        
        let age: Double? = model.lastSpeedSampleAt.map { now.timeIntervalSince($0) }
        if let a = age {
            if a > 10 { score -= 70; reasons.append("stale \(Int(a))s (-70)") }
            else if a > 5 { score -= 35; reasons.append("stale \(Int(a))s (-35)") }
            else if a > 2.5 { score -= 15; reasons.append("stale \(String(format: "%.1f", a))s (-15)") }
        } else {
            score -= 70
            reasons.append("no samples (-70)")
        }
        
        if model.lastKnownSpeedMps == nil {
            score -= 40
            reasons.append("no lastKnownSpeed (-40)")
        }
        
        if let v = model.lastKnownSpeedMps, v >= 5.5, model.speedSamples.count < 3 {
            score -= 15
            reasons.append("few speed samples (\(model.speedSamples.count)) (-15)")
        }
        
        score = max(0, min(100, score))
        return CertaintyDetail(score: score, ageSeconds: age, reasons: reasons)
    }
    
    private var timelineForensicsContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent("Total Events", value: "\(model.events.count)")
            LabeledContent("Segments Today", value: "\(model.timelineSegmentsIncludingCurrent.count)")
            LabeledContent("Confirmed Loads", value: "\(model.confirmedLoads.count)")
            
            if let last = model.events.last {
                LabeledContent("Last Event", value: last.kind.rawValue)
                LabeledContent("Event Time", value: formatTime(last.time))
            }
            
            NavigationLink {
                TimelineDebugView()
                    .environmentObject(model)
            } label: {
                Text("View Events List")
            }
            
            if !model.confirmedLoads.isEmpty {
                NavigationLink {
                    ConfirmedLoadsDebugView()
                        .environmentObject(model)
                } label: {
                    Text("Inspect Confirmed Loads")
                }
            }
        }
    }
    
    private var autosaveManagementContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                showingAutosaveInspector = true
            } label: {
                Label("Inspect Autosave Files", systemImage: "doc.text.magnifyingglass")
            }
            
            Button {
                model.autosave?.flushNow(reason: "Debug: Manual flush")
            } label: {
                Label("Force Autosave Now", systemImage: "arrow.down.doc.fill")
            }
            
            if let lastSave = model.autosave?.lastAutosaveAt {
                LabeledContent("Last Save", value: formatTimeAgo(lastSave))
            }
            
            if let stats = getAutosaveStats() {
                LabeledContent("Total Size", value: formatBytes(stats.bytes))
                LabeledContent("File Count", value: "\(stats.count)")
            }
            
            Divider()
            
            Button("Print Saves folder path") {
                SaveStore().debugPrintSaveFolder()
            }
            
            Button("Print JSON folders") {
                SaveStore().debugPrintJSONFolders()
            }
        }
    }
    
    private var edgeCaseTriggersContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                triggerOdoDeadlock()
            } label: {
                Label("Trigger ODO Deadlock", systemImage: "lock.fill")
            }
            
            Text("⚠️ Simulates a stuck ODO gate for testing recovery paths.")
                .font(.caption2)
                .foregroundColor(.orange)
        }
    }
    
    private var destructiveActionsContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            
            Button(role: .destructive) {
                model.saveStore.clearAutosaves()
                model.resetTransientWorkflows()
                model.requestLmResetShiftMetersFromUI?("Debug: Clear autosave & unlock workflow")
            } label: {
                Label("Clear Autosave & Unlock Workflow", systemImage: "lock.open.fill")
            }
            
            Text("Use if app reopens stuck in ODO/Load after a crash.")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Divider()
            
            Button(role: .destructive) {
                showingClearConfirm = true
            } label: {
                Label("Clear All Autosaves", systemImage: "trash.fill")
            }
            .confirmationDialog(
                "Clear all autosave files? This cannot be undone.",
                isPresented: $showingClearConfirm,
                titleVisibility: .visible
            ) {
                Button("Clear Autosaves", role: .destructive) {
                    model.saveStore.clearAutosaves()
                    model.resetTransientWorkflows()
                    model.requestLmResetShiftMetersFromUI?("Debug: Clear autosave")
                }
                Button("Cancel", role: .cancel) {}
            }
            
            Button(role: .destructive) {
                showingResetConfirm = true
            } label: {
                Label("End Shift + Wipe Shift Data (in-memory)", systemImage: "arrow.counterclockwise.circle.fill")
            }
            .confirmationDialog(
                "End shift and wipe today’s in-memory shift data? (Pre-persistence only)",
                isPresented: $showingResetConfirm,
                titleVisibility: .visible
            ) {
                Button("Wipe Shift Data", role: .destructive) {
                    wipeShiftData()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
    
    //==================================
    // MARK: - Helpers
    //==================================
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        return String(format: "%dh %02dm", h, m)
    }
    
    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: date)
    }
    
    private var backgroundGapRecordsContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            let active = Array(model.backgroundGapRecords.filter { !$0.isResolved }.reversed())
            let resolved = Array(model.backgroundGapRecords.filter { $0.isResolved }.reversed())
            
            if active.isEmpty && resolved.isEmpty {
                Text("No gap records yet")
                    .foregroundColor(.secondary)
            }
            
            if !active.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Active")
                        .font(.subheadline.bold())
                        .foregroundColor(.orange)
                    
                    ForEach(active, id: \.id) { gap in
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Active gap")
                                .font(.headline)
                            
                            Text("ID: \(gap.id.uuidString.prefix(6))")
                                .font(.caption2.monospaced())
                                .foregroundColor(.secondary)
                            
                            Text("Elapsed: \(Int(gap.elapsedSeconds))s")
                                .font(.caption)
                            
                            Text("Straight-line: \(String(format: "%.2f", gap.straightLineKm)) km")
                                .font(.caption)
                            
                            Text("Road estimate: \(String(format: "%.2f", gap.estimatedRoadKm ?? 0)) km")
                                .font(.caption)
                            
                            Text("Start: \(String(format: "%.6f", gap.startLat)), \(String(format: "%.6f", gap.startLon))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Text("End: \(String(format: "%.6f", gap.endLat)), \(String(format: "%.6f", gap.endLon))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Button("Mark resolved (debug)") {
                                resolveSingleBackgroundGap(id: gap.id)
                            }
                            .font(.caption)
                            .buttonStyle(.borderless)
                        }
                        .padding(.vertical, 4)
                        .id(gap.id)
                    }
                }
            }
            
            if !resolved.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Resolved")
                        .font(.subheadline.bold())
                        .foregroundColor(.secondary)
                    
                    ForEach(resolved, id: \.id) { gap in
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Resolved gap")
                                .font(.headline)
                            
                            Text("ID: \(gap.id.uuidString.prefix(6))")
                                .font(.caption2.monospaced())
                                .foregroundColor(.secondary)
                            
                            Text("Elapsed: \(Int(gap.elapsedSeconds))s")
                                .font(.caption)
                            
                            Text("Straight-line: \(String(format: "%.2f", gap.straightLineKm)) km")
                                .font(.caption)
                            
                            Text("Road estimate: \(String(format: "%.2f", gap.estimatedRoadKm ?? 0)) km")
                                .font(.caption)
                            
                            Text("Start: \(String(format: "%.6f", gap.startLat)), \(String(format: "%.6f", gap.startLon))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Text("End: \(String(format: "%.6f", gap.endLat)), \(String(format: "%.6f", gap.endLon))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            if let note = gap.resolutionNote {
                                Text("Resolution: \(note)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                        .id(gap.id)
                    }
                }
            }
        }
    }
    
    private func resolveSingleBackgroundGap(id: UUID) {
        let before = model.backgroundGapRecords.map { "\($0.id.uuidString.prefix(6)):\($0.isResolved ? "R" : "A")" }
        DebugLog.ui("🧪 BEFORE resolve -> \(before.joined(separator: ", "))")
        
        guard let idx = model.backgroundGapRecords.firstIndex(where: { $0.id == id }) else {
            DebugLog.ui("🧪 Resolve failed: no matching gap for id=\(id.uuidString)")
            return
        }
        
        model.backgroundGapRecords[idx].isResolved = true
        model.backgroundGapRecords[idx].resolutionNote = "Debug resolved"
        
        let after = model.backgroundGapRecords.map { "\($0.id.uuidString.prefix(6)):\($0.isResolved ? "R" : "A")" }
        DebugLog.ui("🧪 AFTER resolve  -> \(after.joined(separator: ", "))")
    }
    
    private func formatTimeAgo(_ date: Date) -> String {
        let seconds = Date().timeIntervalSince(date)
        if seconds < 60 { return "\(Int(seconds))s ago" }
        if seconds < 3600 { return "\(Int(seconds/60))m ago" }
        return "\(Int(seconds/3600))h ago"
    }
    
    private func formatBytes(_ bytes: Int) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1024 * 1024 { return String(format: "%.1f KB", Double(bytes)/1024) }
        return String(format: "%.2f MB", Double(bytes)/(1024*1024))
    }
    
    private func getAutosaveStats() -> (bytes: Int, count: Int)? {
        let urls = model.saveStore.debugAutosaveFileURLs()
        var total = 0
        var count = 0
        
        for url in urls {
            if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
               let size = attrs[.size] as? Int {
                total += size
                count += 1
            }
        }
        
        return count == 0 ? nil : (total, count)
    }
    
    private func fmtKm(_ km: Double) -> String {
        guard km.isFinite else { return "—" }
        return String(format: "%.2f", km)
    }
    
    private var shadowOdoDeltaText: String {
        guard model.shadowTelemetryAvailable,
              let km = model.lastShadowOdoDeltaKm else { return "—" }
        return "\(fmtKm(km)) km"
    }
    
    private var shadowRawGpsText: String {
        guard model.shadowTelemetryAvailable,
              let km = model.lastShadowRawGpsDeltaKm else { return "—" }
        return "\(fmtKm(km)) km"
    }
    
    private var shadowFilteredGpsText: String {
        guard model.shadowTelemetryAvailable,
              let km = model.lastShadowProcessedGpsDeltaKm else { return "—" }
        return "\(fmtKm(km)) km"
    }
    
    private var shadowCorrectedGpsText: String {
        guard model.shadowTelemetryAvailable,
              let chosenKm = model.lastShadowProcessedGpsDeltaKm else { return "—" }
        
        let corrected = chosenKm * model.alternateEffectiveCorrectionFactor
        return "\(fmtKm(corrected)) km"
    }
    
    private var shadowSourceText: String {
        guard model.shadowTelemetryAvailable,
              let source = model.lastShadowChosenSource else { return "—" }
        
        switch source {
        case .raw:
            return "Raw"
        case .filtered:
            return "Filtered"
        }
    }
    
    private var shadowErrorKmText: String {
        guard model.shadowTelemetryAvailable,
              let err = model.lastShadowErrorVsOdoKm else { return "—" }
        
        let sign = err >= 0 ? "+" : ""
        return "\(sign)\(fmtKm(err)) km"
    }
    
    private var shadowErrorPercentText: String {
        guard model.shadowTelemetryAvailable,
              let errPct = model.lastShadowErrorPercent else { return "—" }
        
        let sign = errPct >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", errPct))%"
    }
    
    private var shadowCorrectionFactorText: String {
        guard model.shadowTelemetryAvailable else { return "—" }
        return String(format: "%.3f", model.alternateEffectiveCorrectionFactor)
    }
    
    private func triggerOdoDeadlock() {
        model.pendingStartShiftCapture = true
        model.odoPromptContext = .shiftStart
        DebugLog.ui("⚠️ ODO Deadlock triggered")
    }
    
    private func wipeShiftData() {
        if model.isOnDuty {
            model.endShift()
        }
        
        model.events.removeAll()
        model.confirmedLoads.removeAll()
        model.gpsKmPendingUntilFirstSegment = 0
        model.gpsKmSinceLastOdoBySegment.removeAll()
        model.finalisedKmBySegment.removeAll()
        model.runningSegmentID = nil
        
        model.saveStore.clearAutosaves()
        model.resetTransientWorkflows()
        
        DebugLog.ui("💣 Shift data wiped")
    }
}

//======================================
// MARK: - Timeline Debug View (v0.1.292)
//======================================

struct TimelineDebugView: View {
    @EnvironmentObject var model: AppModel
    
    var body: some View {
        List {
            ForEach(model.events.indices.reversed(), id: \.self) { idx in
                let e = model.events[idx]
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(e.kind.rawValue)
                            .font(.headline)
                        Spacer()
                        Text("#\(idx)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(formatDateTime(e.time))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let note = e.note, !note.isEmpty {
                        Text(note)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .italic()
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Events (\(model.events.count))")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func formatDateTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .medium
        return f.string(from: date)
    }
}

//======================================
// MARK: - Confirmed Loads Debug View
//======================================

struct ConfirmedLoadsDebugView: View {
    @EnvironmentObject var model: AppModel
    
    private var rows: [(Int, ConfirmedLoad)] {
        Array(model.confirmedLoads.enumerated())
    }
    
    var body: some View {
        List {
            ForEach(rows, id: \.0) { idx, load in
                confirmedLoadSection(idx: idx, load: load)
            }
        }
        .navigationTitle("Confirmed Loads")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private struct ConfirmedLoadDetailView: View {
        let load: ConfirmedLoad
        let formatDateTime: (Date) -> String
        
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                
                LabeledContent("Mode", value: load.mode.displayName)
                LabeledContent("Time", value: formatDateTime(load.timestamp))
                
                ForEach(load.compartments.indices, id: \.self) { i in
                    let comp = load.compartments[i]
                    HStack {
                        Text(comp.name)
                        Spacer()
                        Text("\(Int(comp.litres.rounded()))L \(comp.productShort)")
                            .foregroundColor(.secondary)
                    }
                    .font(.caption)
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    @ViewBuilder
    private func confirmedLoadSection(idx: Int, load: ConfirmedLoad) -> some View {
        Section {
            ConfirmedLoadDetailView(
                load: load,
                formatDateTime: formatDateTime
            )
        } header: {
            Text("Load #\(idx + 1)")
                .font(.subheadline.bold())
        }
    }
    
    private func formatDateTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f.string(from: date)
    }
}

//======================================
// MARK: - Autosave Inspector Sheet
//======================================

struct AutosaveInspectorSheet: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                let urls = model.saveStore.debugAutosaveFileURLs()
                let fm = FileManager.default
                
                if urls.isEmpty {
                    Text("No autosave files found")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(urls.sorted(by: { $0.lastPathComponent > $1.lastPathComponent }), id: \.self) { url in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(url.lastPathComponent)
                                .font(.headline)
                            
                            if let attrs = try? fm.attributesOfItem(atPath: url.path) {
                                if let size = attrs[.size] as? Int {
                                    Text("Size: \(formatBytes(size))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                if let modified = attrs[.modificationDate] as? Date {
                                    Text("Modified: \(formatDateTime(modified))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Autosave Files")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
    
    private func formatBytes(_ bytes: Int) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1024 * 1024 { return String(format: "%.1f KB", Double(bytes)/1024) }
        return String(format: "%.2f MB", Double(bytes)/(1024*1024))
    }
    
    private func formatDateTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .medium
        return f.string(from: date)
    }
}

