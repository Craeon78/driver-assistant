
import SwiftUI

  

struct FatigueEnginePanel: View {

    @Binding var scheme: FatigueScheme

    var segments: [WorkRestSegment]

    var now: Date

    var tz: TimeZone = TimeZone(identifier: "Australia/Brisbane") ?? .current

    var body: some View {

        let status = FatigueEngine.evaluate(

            scheme: scheme,

            segments: segments,

            now: now,

            tz: tz

        )

        VStack(alignment: .leading, spacing: 12) {

            HStack {

                Text("Fatigue Engine (Sim Harness)")

                    .font(.headline)

                Spacer()

                // Optional; delete if you don't want it yet

                Picker("", selection: $scheme) {

                    ForEach(FatigueScheme.allCases) { s in

                        Text(s.isAvailableNow ? s.rawValue : "\(s.rawValue) 🔒").tag(s)

                    }

                }

                .pickerStyle(.menu)

            }

            Text("As of: \(now.formatted(date: .abbreviated, time: .shortened))")

                .font(.caption)

                .foregroundStyle(.secondary)

            ForEach(Array(status.cards.enumerated()), id: \.offset) { _, card in

                HStack(alignment: .top, spacing: 12) {

                    Circle()

                        .frame(width: 10, height: 10)

                        .foregroundStyle(color(for: card.severity))

                        .padding(.top, 6)

                    VStack(alignment: .leading, spacing: 2) {

                        Text(card.title).font(.subheadline).fontWeight(.semibold)

                        Text(card.value).font(.body)

                        if let d = card.detail {

                            Text(d).font(.footnote).foregroundStyle(.secondary)

                        }

                    }

                    Spacer()

                }

            }

            if scheme == .bfmHV {

                Text("BFM extras (long/night 7d + 84h reset) are stubbed for now.")

                    .font(.footnote)

                    .foregroundStyle(.secondary)

            }

        }

        .padding()

        .background(.thinMaterial)

        .clipShape(RoundedRectangle(cornerRadius: 12))

    }

    private func color(for sev: FatigueSeverity) -> Color {

        switch sev {

        case .ok: return .green

        case .warn: return .orange

        case .over: return .red

        case .unavailable: return .gray

        }

    }

}
