
import SwiftUI

  

//======================================

// MARK: - BannerShellView

//======================================

//

// Purpose:

// - Always-visible top banner across the whole app.

// - Holds: integrity triangle (left), NOW (gps/suburb/speed), nav tabs (center),

//          FUTURE projection (right), settings gear (far right).

//

// Notes:

// - Keeps layout stable: areas exist even when empty.

// - The triangle is hidden when there are no issues (does not collapse into NOW).

//======================================

  

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

    let degrees: Double?   // nil = unknown

    let fill: Color        // pass in .green/.yellow etc

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

        let step = 360.0 / 16.0   // 22.5°

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

                    Image(systemName: "exclamationmark.triangle.fill")

                        .font(.system(size: 22, weight: .semibold))

                        .foregroundStyle(.yellow)

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

                    fill: .green // later: map to confidence

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

                Text(model.liveCostPerKmText) // stub

                    .font(.caption)

            }

            Spacer(minLength: 5)

            Text(locationManager.liveSuburb)

                .font(.caption)

                .foregroundStyle(.secondary)

                .lineLimit(2)

                .font(.system(size:20))

        }

    }

    private var navArea: some View {

        HStack(spacing: 10) {

            tabButton(.today, title: "Today", system: "clock")

            tabButton(.load,  title: "Load",  system: "shippingbox")

            tabButton(.map,   title: "Map",   system: "map")

            tabButton(.sim,   title: "Sim",   system: "speedometer")

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

        VStack(alignment: .trailing, spacing: 4) {

            // ===== 1) OLD GPS (authoritative) =====

            Text("GPS \(fmtKm(model.gpsShiftMetersLive / 1000.0)) km")

                .font(.caption.monospaced())

            // ===== 2) NEW BG advisory (separate, never merges into totals) =====

            if let est = model.lastBackgroundGapEstimate {

                Text("BG +\(est.suggestedOdoDeltaKm) km  \(est.method.rawValue) / \(est.confidence.rawValue)")

                    .font(.caption2.monospaced())

                    .foregroundStyle(.secondary)

                    .lineLimit(1)

            } else {

                Text("BG —")

                    .font(.caption2.monospaced())

                    .foregroundStyle(.secondary)

            }

            // ===== 3) ODO delta vs GPS delta (error readout) =====

            if let odoCompareLine = odoVsGpsLine() {

                Text(odoCompareLine)

                    .font(.caption2.monospaced())

                    .foregroundStyle(.secondary)

                    .lineLimit(1)

            } else {

                Text("ODOΔ — | GPSΔ — | err —")

                    .font(.caption2.monospaced())

                    .foregroundStyle(.secondary)

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

}
