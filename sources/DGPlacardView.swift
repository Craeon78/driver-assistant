
import SwiftUI

//======================================

// MARK: - DGPlacardView.swift

//======================================

// 

// NOTE:

// Placard layout intentionally prioritises correctness & legibility over

// perfect typographic balance.

// Fine-grain spacing / tightening is deferred to Phase 4 cosmetics.

// Do NOT reintroduce nested borders or fixed heights without revisiting aspect math.

  

struct DGPlacardView: View {

    @EnvironmentObject var model: AppModel

    private var decision: DGPlacardDecision { model.displayedDGPlacardDecision }

    // Single source of truth for layout constants

    private let border: CGFloat = 3

    private let aspect: CGFloat = 700.0 / 410.0

    private let diamondWidth: CGFloat = 200

    var body: some View {

        GeometryReader { geo in

            let w = geo.size.width

            let h = w / aspect

            let topH = h * (250.0 / 410.0)

            let bottomH = h * (160.0 / 410.0)

            ZStack(alignment: .topLeading) {

                Color.white

                VStack(spacing: 0) {

                    topHalf

                        .frame(height: topH)

                    // Single horizontal divider between top + bottom

                    Rectangle()

                        .fill(Color.black)

                        .frame(height: border)

                    bottomHalf

                        .frame(height: bottomH)

                }

                .frame(width: w, height: h, alignment: .topLeading)

                .clipped()

            }

            // One outer border only

            .overlay(

                Rectangle().stroke(Color.black, lineWidth: border)

            )

            .frame(width: w, height: h, alignment: .topLeading)

        }

        .aspectRatio(aspect, contentMode: .fit)

        .accessibilityLabel(accessibilityText)

    }

    //======================================

    // MARK: - TOP HALF

    //======================================

    @ViewBuilder

    private var topHalf: some View {

        switch decision {

        case .combustibleLiquid:

            // Full width, no diamond column (diesel-only case in AU practice).

            VStack(spacing: 6) {

                Text("COMBUSTIBLE")

                Text("LIQUID")

            }

            .font(.system(size: 52, weight: .bold))

            .fitText(minScale: 0.6, lines: 1)

            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .blankTopHalf, .blankUnknown:

            // `blankUnknown` is used when we don't have enough evidence (pre-persistence or corrupt history).

            // `blankTopHalf` is the explicit "degassed" / suppressed state.

            Color.white

                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .petrol1203(let hazchem):

            topWithDiamond(

                left: unLeftBlock(title: "PETROL", un: "1203", hazchem: hazchem)

            )

        case .petroleumFuel1270(let hazchem):

            topWithDiamond(

                left: unLeftBlock(title: "PETROLEUM FUEL", un: "1270", hazchem: hazchem)

            )

        }

    }

    /// Standard "UN block + Class 3 diamond" layout.

    private func topWithDiamond(left: some View) -> some View {

        HStack(spacing: 0) {

            left

                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Single vertical divider

            Rectangle()

                .fill(Color.black)

                .frame(width: border)

            FlammableLiquidDiamond()

                .frame(width: diamondWidth)

                .frame(maxHeight: .infinity)

        }

    }

    //======================================

    // MARK: - LEFT UN BLOCK

    //======================================

    private func unLeftBlock(title: String, un: String, hazchem: String) -> some View {

        GeometryReader { g in

            let h = g.size.height

            // Row proportions (tweak these 3 numbers if needed)

            let titleH  = h * 0.22

            let unH     = h * 0.39

            let hazH    = h * 0.39

            VStack(spacing: 0) {

                // TITLE ROW (shorter, avoids wasted air)

                Text(title)

                    .font(.system(size: 30, weight: .bold))

                    .fitText(minScale: 0.5, lines: 1)

                    .frame(height: titleH)

                    .frame(maxWidth: .infinity)

                    .padding(.horizontal, 10)

                Rectangle().fill(Color.black).frame(height: border)

                // UN ROW (label + number)

                VStack(spacing: 4) {

                    HStack {

                        Text("UN No.")

                            .font(.system(size: 16))

                        Spacer()

                    }

                    .padding(.horizontal, 12)

                    .padding(.top, 4)

                    Text(un)

                        .font(.system(size: 70, weight: .semibold))

                        .fitText(minScale: 0.6, lines: 1)

                        .padding(.bottom, 2)

                }

                .frame(height: unH)

                Rectangle().fill(Color.black).frame(height: border)

                // HAZCHEM ROW (label + code)

                VStack(spacing: 4) {

                    HStack {

                        Text("HAZCHEM")

                            .font(.system(size: 16))

                        Spacer()

                    }

                    .padding(.horizontal, 12)

                    .padding(.top, 4)

                    Text(hazchem)

                        .font(.system(size: 70, weight: .semibold))

                        .fitText(minScale: 0.6, lines: 1)

                        .padding(.bottom, 2)

                }

                .frame(height: hazH)

            }

        }

    }

    //======================================

    // MARK: - BOTTOM HALF

    //======================================

    private var bottomHalf: some View {

        HStack(spacing: 0) {

            VStack(alignment: .leading, spacing: 6) {

                Text("IN EMERGENCY DIAL")

                    .font(.system(size: 16, weight: .semibold))

                Text("000-POLICE OR\nFIRE BRIGADE")

                    .font(.system(size: 20, weight: .semibold))

                    .fitText(minScale: 0.75, lines: 2)

            }

            .padding(12)

            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

            Rectangle()

                .fill(Color.black)

                .frame(width: border)

            VStack(alignment: .leading, spacing: 8) {

                Text("SPECIALIST ADVICE")

                    .font(.system(size: 16, weight: .semibold))

                Text("ISS FIRST RESPONSE")

                    .font(.system(size: 26, weight: .semibold))

                    .fitText(minScale: 0.65, lines: 1)

                Text("   1300 131 001")

                    .font(.system(size: 30, weight: .bold))

                    .fitText(minScale: 0.6, lines: 1)

            }

            .padding(12)

            .frame(minWidth: 260, maxWidth: 320)

            .frame(maxHeight: .infinity, alignment: .leading)

        }

    }

    private var accessibilityText: String {

        switch decision {

        case .petrol1203(let h):         return "Placard PETROL UN 1203 Hazchem \(h)"

        case .petroleumFuel1270(let h):  return "Placard PETROLEUM FUEL UN 1270 Hazchem \(h)"

        case .combustibleLiquid:         return "Placard COMBUSTIBLE LIQUID"

        case .blankTopHalf:              return "Placard blank top half"

        case .blankUnknown:              return "Placard blank top half"

        }

    }

}

  

//======================================

// MARK: - FLAMMABLE DIAMOND

//======================================

  

struct FlammableLiquidDiamond: View {

    var body: some View {

        ZStack {

            DiamondShape()

                .fill(Color.red)

            DiamondShape()

                .stroke(Color.black, lineWidth: 5)

            VStack(spacing: 6) {

                // System flame is good enough for Phase 1/2.

                // If you later want an ADR-perfect flame, swap to `FlameIcon()` (below).

                Image(systemName: "flame.fill")

                    .resizable()

                    .scaledToFit()

                    .foregroundStyle(.black)

                    .frame(width: 46, height: 46)

                    .padding(.top, 4)

                Text("FLAMMABLE\nLIQUID")

                    .font(.system(size: 15, weight: .bold))

                    .multilineTextAlignment(.center)

                    .foregroundColor(.black)

                Text("3")

                    .font(.system(size: 20, weight: .bold))

                    .foregroundColor(.black)

                    .padding(.bottom, 3)

            }

        }

        // IMPORTANT: let the parent size it (don’t hardcode here)

        .frame(maxWidth: .infinity, maxHeight: .infinity)

        .padding(6)

    }

}

  

struct DiamondShape: Shape {

    func path(in rect: CGRect) -> Path {

        var p = Path()

        let midX = rect.midX

        let midY = rect.midY

        p.move(to: CGPoint(x: midX, y: rect.minY))

        p.addLine(to: CGPoint(x: rect.maxX, y: midY))

        p.addLine(to: CGPoint(x: midX, y: rect.maxY))

        p.addLine(to: CGPoint(x: rect.minX, y: midY))

        p.closeSubpath()

        return p

    }

}

  

// DEAD CODE (for now):

// Not referenced anywhere in the UI. Kept as a ready-made “custom flame”

// if you ever decide the SF Symbol isn’t good enough for placard fidelity.

// Safe to delete later.

struct FlameIcon: View {

    var body: some View {

        GeometryReader { geo in

            let w = geo.size.width

            let h = geo.size.height

            Path { p in

                p.move(to: CGPoint(x: 0.5*w, y: 1.0*h))

                p.addCurve(to: CGPoint(x: 0.1*w, y: 0.6*h),

                           control1: CGPoint(x: 0.35*w, y: 0.9*h),

                           control2: CGPoint(x: 0.15*w, y: 0.8*h))

                p.addCurve(to: CGPoint(x: 0.4*w, y: 0.1*h),

                           control1: CGPoint(x: 0.0*w, y: 0.35*h),

                           control2: CGPoint(x: 0.25*w, y: 0.2*h))

                p.addCurve(to: CGPoint(x: 0.6*w, y: 0.0*h),

                           control1: CGPoint(x: 0.45*w, y: 0.05*h),

                           control2: CGPoint(x: 0.55*w, y: 0.0*h))

                p.addCurve(to: CGPoint(x: 0.9*w, y: 0.45*h),

                           control1: CGPoint(x: 0.85*w, y: 0.05*h),

                           control2: CGPoint(x: 0.95*w, y: 0.25*h))

                p.addCurve(to: CGPoint(x: 0.5*w, y: 1.0*h),

                           control1: CGPoint(x: 0.85*w, y: 0.75*h),

                           control2: CGPoint(x: 0.7*w, y: 0.92*h))

                p.closeSubpath()

            }

            .fill(Color.black)

        }

    }

}
