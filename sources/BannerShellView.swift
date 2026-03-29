//======================================
// MARK: - BannerShellView
//======================================
//
// Path:
// - Views/Screens/BannerShellView.swift
//
// Purpose:
// - Always-visible top banner across the whole app.
// - Acts as the driver’s persistent “at a glance” shell:
//   - integrity / attention indicator (far left)
//   - NOW context (speed + current live signal)
//   - navigation tabs (centre)
//   - advisory / telemetry / future-facing context (right)
//   - settings access (far right)
//
// Responsibilities:
// - Keep high-value driver context visible regardless of tab.
// - Surface unresolved attention items via the yellow numbered square.
// - Show the appropriate live badge/content for the selected tab:
//   - motion
//   - heading
//   - odo suggestion
//   - live cost
// - Provide a compact top-right telemetry/advisory area for current
//   diagnostic or future-facing shift information.
// - Keep tab navigation accessible without relying on the native tab bar.
//
// Notes:
// - Layout is intentionally stable: left, centre, and right regions
//   keep their footprint even when content is sparse.
// - The left warning surface is no longer a simple triangle placeholder;
//   it is evolving into the app’s structured attention indicator.
// - Current right-side “future” content is still transitional:
//   at present it shows shadow telemetry / reconciliation evidence,
//   but longer-term it is expected to host cleaner driver-facing
//   advisory output (for example unresolved missing-km guidance).
// - This file is a shell/composition layer, not the owner of truth.
//   It reads from AppModel and presents already-derived state.
//
// UI intent:
// - Fast glanceability while driving or stopped.
// - Minimal navigation friction.
// - Clear separation between:
//   - truth / attention (left)
//   - current live state (middle-left)
//   - navigation (centre)
//   - advisory / telemetry (middle-right)
//   - app controls (right)
//
// Future direction:
// - Replace transitional telemetry in the right-side area with a more
//   deliberate advisory surface once background-gap / reconciliation
//   flow is fully wired.
// - Allow the yellow square to open a dedicated attention/review sheet.
// - Support stronger distinction between:
//   - live shift attention
//   - end-of-shift review / finalisation attention
//======================================

import SwiftUI

struct SpeedBadge: View {
    let speedKmh: Int
    
    private let limitGate = HysteresisGate(upper: 101, lower: 99)
    @State private var isOverLimit: Bool = false
    

    var body: some View {
        ZStack {
            Circle()
                .stroke(.primary.opacity(0.35), lineWidth: 2)
            
            // optional outer ring (OFF by default)
            if isOverLimit {
                Circle()
                    .stroke(.red, lineWidth: 6)
                    .padding(-3) // makes it sit slightly outside
            }
            
            Text("\(speedKmh)")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(isOverLimit ? .red : .primary)
        }
        .frame(width: 44, height: 44)
        .accessibilityLabel("Speed \(speedKmh) kilometres per hour")
        .onAppear {
            isOverLimit = limitGate.nextState(current: speedKmh, isActive: isOverLimit)
        }
        .onChange(of: speedKmh) { _, newValue in
            isOverLimit = limitGate.nextState(current: newValue, isActive: isOverLimit)
        }
    }
}

import SwiftUI

struct HeadingBadge: View {
    let degrees: Double?   // nil = unknown
    let fill: Color        // pass in .green/.yellow etc
    
    var body: some View {
        ZStack {
            // ticks
            TicksRing(tickCount: 32)
            
            // heading marker (moves with heading)
            if let d = normalizedDegrees {
                Rectangle()
                    .fill(.red)
                    .frame(width: 2, height: 10)
                    .offset(y: -22) // radius from centre
                    .rotationEffect(.degrees(d)) // <- clockwise compass heading
            } else {
                // Optional: show a faint "north" hint when unknown
                Rectangle()
                    .fill(.red.opacity(0.25))
                    .frame(width: 2, height: 10)
                    .offset(y: -22)
            }
            
            // inner disc
            Circle()
                .fill(fill.opacity(0.85))
                .frame(width: 34, height: 34)
            
            Text(compassText(degrees))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.black.opacity(0.85))
        }
        .frame(width: 44, height: 44)
        .accessibilityLabel(accessibilityString)
    }
    
    private var accessibilityString: String {
        if let d = normalizedDegrees { return "Heading \(Int(d)) degrees" }
        return "Heading unknown"
    }
    
    private var normalizedDegrees: Double? {
        guard let deg = degrees, deg.isFinite else { return nil }
        // normalize to 0..<360
        return (deg.truncatingRemainder(dividingBy: 360) + 360)
            .truncatingRemainder(dividingBy: 360)
    }
    
    private let compassDirs16: [String] = [
        "N","NNE","NE","ENE",
        "E","ESE","SE","SSE",
        "S","SSW","SW","WSW",
        "W","WNW","NW","NNW"
    ]
    
    private func compassText(_ degrees: Double?) -> String {
        guard let deg = degrees, deg.isFinite else { return "—" }
        
        let normalized = (deg.truncatingRemainder(dividingBy: 360) + 360)
            .truncatingRemainder(dividingBy: 360)
        
        let step = 360.0 / 16.0   // 22.5°
        let rawIndex = (normalized / step).rounded()
        let idx = Int(rawIndex) % 16
        
        return compassDirs16[idx]
    }
}

struct TicksRing: View {
    let tickCount: Int
    
    var body: some View {
        ZStack {
            ForEach(0..<tickCount, id: \.self) { i in
                Rectangle()
                    .fill(.primary.opacity(i % 2 == 0 ? 0.45 : 0.25))
                    .frame(width: 2, height: i % 2 == 0 ? 8 : 5) // every 2nd tick longer
                    .offset(y: -22)
                    .rotationEffect(.degrees(Double(i) * (360.0 / Double(tickCount))))
            }
            Circle()
                .stroke(.primary.opacity(0.35), lineWidth: 2)
        }
    }
}

struct BannerShellView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var locationManager: LocationManager
    
    @Binding var selectedTab: MainTab
    
    // Banner height — tune later.
    private let height: CGFloat = 70
    
    var body: some View {
        HStack(spacing: 12) {
            integrityArea
                .frame(width: 44)
            
            nowArea
                .frame(minWidth: 250, maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)
            
            navArea
                .frame(maxWidth: .infinity, alignment: .center)
                .layoutPriority(10)
            
            futureArea
                .frame(minWidth: 220, alignment: .trailing)
                .layoutPriority(1)
            
            settingsArea
                .frame(width: 44)
        }
        .frame(height: height)
        .padding(.horizontal, 12)
        .background(.ultraThinMaterial)
        .overlay(Divider(), alignment: .bottom)
    }
    
    // MARK: - Areas
    
    private var integrityArea: some View {
        ZStack {
            
            Color.clear.frame(width: 44, height: 44)
            
            if model.integrityIssueCount > 0 {
                
                Button {
                    model.presentIntegritySheet()
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.yellow)
                            .frame(width: 28, height: 28)
                        
                        Text("\(model.integrityIssueCount)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.black)
                    }
                }
                
            } else {
                
                #if DEBUG
                if DebugFlags.all || DebugFlags.trianglePlaceholder {
                    Circle()
                        .stroke(.green, lineWidth: 1.5)
                        .frame(width: 10, height: 10)
                }
                #endif
            }
        }
        .frame(width: 44, height: 44)
    }
    
    
    private var nowArea: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                SpeedBadge(speedKmh: Int(model.speedKmh ?? 0))
                
                Spacer(minLength: 4)
                
                switch model.bannerContext(for: selectedTab) {
                case .motion:
                    MotionPillView()
                        .environmentObject(model)
                        .environmentObject(locationManager)
                    
                case .heading:
                    HeadingBadge(
                        degrees: locationManager.courseDegrees,
                        fill: .green
                    )
                    
                case .odo:
                    if let est = model.suggestedOdoFromGps {
                        Text("Odo ~\(est)")
                            .font(.caption.monospaced())
                            .lineLimit(1)
                    } else {
                        Text("Odo: \(model.odoText)")
                            .font(.caption.monospaced())
                            .lineLimit(1)
                    }
                    
                case .cost:
                    Text(model.liveCostPerKmText)
                        .font(.caption)
                }
                
                Spacer(minLength: 5)
                
                Text(locationManager.liveSuburb)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .font(.system(size: 20))
            }
            
            if model.motionState == .unsure, !model.motionUncertaintyReasons.isEmpty {
                Text("Unsure: \(model.motionUncertaintyReasons.prefix(3).joined(separator: " • "))")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.orange)
                    .lineLimit(1)
            }
        }
    }
    
    private var navArea: some View {
        HStack(spacing: 10) {
            tabButton(.today, title: "Today", system: "clock")
            tabButton(.load,  title: "Load",  system: "shippingbox")
            tabButton(.map,   title: "Map",   system: "map")
            tabButton(.sim,   title: "Sim",   system: "speedometer")
            tabButton(.command, title: "Cmd", system: "command")
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .layoutPriority(1) // ✅ don’t squeeze me first
    }
    
    private func tabButton(_ tab: MainTab, title: String, system: String) -> some View {
        Button {
            selectedTab = tab
        } label: {
            Label(title, systemImage: system)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 12)
                .background(selectedTab == tab ? Color.primary.opacity(0.10) : Color.clear)
                .clipShape(Capsule())
                .contentShape(Rectangle()) // <- easiest “fat finger” win
                .lineLimit(1)
        }
        .buttonStyle(.plain)
    }
    
    private var futureArea: some View {
        HStack(alignment: .top, spacing: 16) {
            
            VStack(alignment: .leading, spacing: 4) {
                shadowLine("ODO Δ", shadowOdoDeltaText)
                shadowLine("GPS raw", shadowRawGpsText)
                shadowLine("GPS filt", shadowFilteredGpsText)
                shadowLine("Source", shadowSourceText)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                shadowLine("Error", shadowErrorKmText)
                shadowLine("Error %", shadowErrorPercentText)
                shadowLine("Corr", shadowCorrectionFactorText)
                shadowLine("GPS corr", shadowCorrectedGpsText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
    
    private var settingsArea: some View {
        Button {
            model.isShowingSettingsSheet = true // stub; or use navigation
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 20))
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Helpers (BannerShellView)
    
    private func fmtKm(_ km: Double) -> String {
        guard km.isFinite else { return "—" }
        return String(format: "%.1f", km)
    }
    
    private func parseOdoKm(_ text: String) -> Int? {
        // Accept "123456", "123,456", "123 456", "123456km"
        let digits = text.filter { $0.isNumber }
        return Int(digits)
    }
    
    private func gpsWindowKmSinceLastOdo() -> Double? {
        // Raw GPS evidence since last odo anchor (segments are keyed by UUID)
        let sum = model.gpsKmSinceLastOdoBySegment.values.reduce(0, +)
        return sum.isFinite ? sum : nil
    }
    
    private func odoVsGpsLine() -> String? {
        guard
            let anchor = model.lastOdoAnchorKm,
            let current = parseOdoKm(model.odoText)
        else { return nil }
        
        let odoDelta = max(0, current - anchor)
        guard let gpsDelta = gpsWindowKmSinceLastOdo() else { return nil }
        
        let err = Double(odoDelta) - gpsDelta
        return "ODOΔ \(odoDelta) | GPSΔ \(fmtKm(gpsDelta)) | err \(fmtKm(err))"
    }
    @ViewBuilder
    private func shadowLine(_ label: String, _ value: String) -> some View {
        HStack(spacing: 6) {
            Text("\(label):")
                .foregroundStyle(.secondary)
            Text(value)
                .foregroundStyle(.primary)
        }
        .font(.caption2.monospaced())
        .lineLimit(1)
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
    
    private var shadowSpanStatusText: String {
        if model.shadowTelemetryAvailable {
            return "Closed"
        } else {
            return "Open"
        }
    }
}
