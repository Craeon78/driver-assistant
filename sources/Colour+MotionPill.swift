
import SwiftUI

  

//======================================

// MARK: - Motion Pill Colors

//======================================

//

// Purpose:

// - Central place for the motion pill palette.

// - Keeps TodayView clean.

// - Easy to tweak later.

//

// Palette request:

// - Green

// - Greeny-yellow (lime)

// - Yellowy-orange

// - Grey

//  Event flash (NOT a trust level):

//   - Manual override pulse = cyan

//=====================================

//======================================

  

extension Color {

    static let motionTrustHigh = Color.green

    static let motionTrustMed  = Color(red: 0.90, green: 0.90, blue: 0.10)      // lime-ish

    static let motionTrustLow  = Color(red: 0.98, green: 0.70, blue: 0.20)      // yellow-orange

    static let motionTrustBad  = Color.gray

    // Manual override pulse (event colour, NOT a trust level)

    static let motionManualOverride = Color(red: 0.00, green: 0.75, blue: 0.85)

}

  

//======================================

// MARK: - Motion Pill View (drop-in)

//======================================

//

// Usage:

// MotionPill(

//   title: model.motionStateLabel,

//   state: model.motionState,

//   isManualResetPulsing: model.isManualResetPulsing

// 

  

  

struct MotionPillView: View {

    @EnvironmentObject var model: AppModel

    @EnvironmentObject var locationManager: LocationManager

    // Local UI-only state for the cyan pulse

    @State private var isPulsingManualReset: Bool = false

    private let stuckSeconds: TimeInterval = 8

    private var isStuckUnsure: Bool {

        guard model.motionState == .unsure else { return false }

        guard let t = model.lastSpeedSampleAt else { return true }

        return Date().timeIntervalSince(t) >= stuckSeconds

    }

    private var baseBackground: Color {

        let band = model.overallCertaintyBandForUI()

        let base: Color = {

            switch band {

            case .high:          return .motionTrustHigh

            case .medium:        return .motionTrustMed

            case .low:           return .motionTrustLow

            case .untrustworthy: return .motionTrustBad

            }

        }()

        // UNSURE always washed out

        if model.motionState == .unsure {

            return Color.gray.opacity(0.25)

        }

        // Low-speed crawl muted but still reflects confidence

        let lowSpeedCrawl: Bool = {

            guard let speed = model.speedKmh else { return false }

            return model.motionState == .crawling && speed < 5

        }()

        return lowSpeedCrawl ? base.opacity(0.18) : base.opacity(0.22)

    }

    private var background: Color {

        // Manual override pulse is an exception colour

        if isPulsingManualReset {

            return Color.motionManualOverride.opacity(0.45)

        }

        return baseBackground

    }

    private var foreground: AnyShapeStyle {

        AnyShapeStyle(.primary.opacity(0.75))

    }

    var body: some View {

        HStack(spacing: 8) {

            if model.showMotionDebug {

                Text(model.motionState.shortLabel)

                    .font(.caption2.monospaced())

                    .padding(.horizontal, 6)

                    .padding(.vertical, 2)

                    .background(background)

                    .cornerRadius(6)

                    .foregroundStyle(foreground)

                    .contentShape(RoundedRectangle(cornerRadius: 6))

                    .onLongPressGesture(minimumDuration: 0.8) {

                        guard model.motionState == .unsure else { return }

                        // 1) Thump

                        Haptics.heavyImpact()

                        // 2) Cyan pulse (linger)

                        withAnimation(.easeInOut(duration: 0.25)) {

                            isPulsingManualReset = true

                        }

                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {

                            withAnimation(.easeInOut(duration: 0.25)) {

                                isPulsingManualReset = false

                            }

                        }

                        // 3) Logical reset + GPS kick

                        model.resetMotionInference(reason: "Pill long-press")

                        locationManager.kickUpdates(reason: "Pill long-press (stuck UNSURE)")

                    }

            }

        }

    }

}
