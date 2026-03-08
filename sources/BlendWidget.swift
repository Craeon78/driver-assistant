
import SwiftUI

  

//======================================

// MARK: - Blend Calculator Widget

//======================================

//

// Purpose:

// - Quick helper for common fuel blend calculations

// - B5 (95% ADF + 5% B100)

// - PULP 95 (75% P98 + 25% P91)

//

// Workflow:

// - Driver enters base litres OR target total

// - Widget calculates required additive litres

//

// Design:

// - Self-contained (no AppModel dependency)

// - Embedded in LoadView left panel

// - Pure calculation (no persistence)

//

// Notes:

// - Accepts "18,000" or "18 000" (strips separators)

// - Rounds to whole litres for clarity

//

//======================================

  

struct BlendWidget: View {

    enum BlendMode: String, CaseIterable, Identifiable {

        case b5 = "B5 (ADF + B100)"

        case pulp95 = "PULP 95 (98 + 91)"

        var id: String { rawValue }

    }

    @State private var mode: BlendMode = .b5

    // Inputs support two workflows:

    // 1) "I have base litres"  → calculate additive litres to hit the blend ratio.

    // 2) "I want target total" → calculate both components of the final blend.

    @State private var baseLitresText: String = ""     // Meaning depends on mode: ADF (B5) or P98 (PULP95)

    @State private var targetTotalText: String = ""    // Optional: desired final total litres

    var body: some View {

        VStack(alignment: .leading, spacing: 12) {

            Text("Blend calculator")

                .font(.headline)

            Picker("Blend", selection: $mode) {

                ForEach(BlendMode.allCases) { m in

                    Text(m.rawValue).tag(m)

                }

            }

            .pickerStyle(.segmented)

            Group {

                if mode == .b5 {

                    // B5 = 95% ADF + 5% B100 (by volume)

                    LabeledTextField(

                        title: "ADF litres you have",

                        placeholder: "e.g. 18000",

                        text: $baseLitresText

                    )

                    LabeledTextField(

                        title: "OR target total litres (optional)",

                        placeholder: "e.g. 19000",

                        text: $targetTotalText

                    )

                    ResultBox(lines: b5Lines())

                } else {

                    // PULP 95 = 75% P98 + 25% P91 (by volume)

                    LabeledTextField(

                        title: "P98 litres you have",

                        placeholder: "e.g. 3000",

                        text: $baseLitresText

                    )

                    LabeledTextField(

                        title: "OR target total litres of P95 (optional)",

                        placeholder: "e.g. 8000",

                        text: $targetTotalText

                    )

                    ResultBox(lines: pulp95Lines())

                }

            }

        }

        .padding()

        .background(Color.gray.opacity(0.06))

        .cornerRadius(12)

        .onChange(of: mode) { _, _ in

            // Reset inputs when switching modes to avoid “wrong meaning” confusion.

            baseLitresText = ""

            targetTotalText = ""

        }

    }

    // MARK: - Maths

    private func b5Lines() -> [String] {

        let adf = parseLitres(baseLitresText)

        let targetTotal = parseLitres(targetTotalText)

        // Option 1: user has ADF litres, compute B100 to add so final is B5.

        // If final blend must be 95% ADF and 5% B100:

        // B100 = ADF * (0.05 / 0.95)

        if adf > 0 && targetTotal <= 0 {

            let b100 = adf * (0.05 / 0.95)

            let total = adf + b100

            return [

                "Add B100: \(fmt0(b100)) L",

                "Final total: \(fmt0(total)) L",

                "Check: B100 fraction ≈ 5%"

            ]

        }

        // Option 2: user wants a target total, compute both parts.

        // If target total is provided, it takes precedence over "base litres".

        // ADF = 95% of total, B100 = 5% of total

        if targetTotal > 0 {

            let adfNeed = targetTotal * 0.95

            let b100Need = targetTotal * 0.05

            return [

                "ADF in final: \(fmt0(adfNeed)) L",

                "B100 in final: \(fmt0(b100Need)) L"

            ]

        }

        return ["Enter ADF litres OR a target total."]

    }

    private func pulp95Lines() -> [String] {

        let p98 = parseLitres(baseLitresText)

        let targetTotal = parseLitres(targetTotalText)

        // PULP95 recipe: 75% P98 + 25% P91

        // If user has P98, compute required P91:

        // P98 / Total = 0.75 => Total = P98 / 0.75; P91 = Total - P98

        if p98 > 0 && targetTotal <= 0 {

            let total = p98 / 0.75

            let p91 = total - p98

            return [

                "Add P91: \(fmt0(p91)) L",

                "Final P95 total: \(fmt0(total)) L",

                "Ratio: 98 ≈ 75% / 91 ≈ 25%"

            ]

        }

        // If target total is provided, it takes precedence over "base litres".

        // If target total is provided, compute both components:

        if targetTotal > 0 {

            let p98Need = targetTotal * 0.75

            let p91Need = targetTotal * 0.25

            return [

                "P98 required: \(fmt0(p98Need)) L",

                "P91 required: \(fmt0(p91Need)) L"

            ]

        }

        return ["Enter P98 litres OR a target total."]

    }

    // MARK: - Parsing / formatting

    /// Accepts common driver inputs like "18,000" or "18 000".

    private func parseLitres(_ s: String) -> Double {

        let cleaned = s

            .replacingOccurrences(of: ",", with: "")

            .replacingOccurrences(of: " ", with: "")

            .trimmingCharacters(in: .whitespacesAndNewlines)

        return Double(cleaned) ?? 0

    }

    private func fmt0(_ v: Double) -> String {

        String(Int(round(v)))

    }

}

  

  

// MARK: - Small helpers (keeps widget self-contained)

  

private struct LabeledTextField: View {

    let title: String

    let placeholder: String

    @Binding var text: String

    var body: some View {

        VStack(alignment: .leading, spacing: 6) {

            Text(title).font(.subheadline)

            TextField(placeholder, text: $text)

                .keyboardType(.decimalPad)

                .textFieldStyle(.roundedBorder)

        }

    }

}

  

private struct ResultBox: View {

    let lines: [String]

    var body: some View {

        VStack(alignment: .leading, spacing: 6) {

            ForEach(lines, id: \.self) { line in

                Text("• \(line)")

                    .font(.caption)

                    .foregroundColor(.secondary)

            }

        }

        .padding(.top, 4)

    }

}
