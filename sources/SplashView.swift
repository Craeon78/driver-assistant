
import SwiftUI

  

//======================================

// MARK: - Splash Screen

//======================================

//

// Purpose:

// - Lightweight launch screen shown briefly on app startup.

// - Displays app name and build info parsed from PATCHLOG.md.

//

// Design notes:

// - Intentionally minimal to avoid delaying app load.

// - No animations or timers live here (handled by ContentView).

// - Safe to remain static even as the app grows.

//

// Future (optional):

// - Replace system icon with custom brand asset.

// - Add subtle animation if desired (fade / scale).

// - Optionally hide version/build info in release builds.

//======================================

  

struct SplashView: View {

    @Binding var progress: Double

    @Binding var status: String

    @Binding var didFinishSplash: Bool

    // MARK: - Build Info

    private var buildInfo: String {

        guard let url = Bundle.main.url(forResource: "PATCHLOG", withExtension: "md"),

              let content = try? String(contentsOf: url, encoding: .utf8)

        else {

            return "v?.?.? • unknown date"

        }

        let lines = content.split(separator: "\n").map { String($0) }

        // Find first header line starting with ##

        guard let header = lines.first(where: {

            $0.trimmingCharacters(in: .whitespaces).hasPrefix("##")

        }) else {

            return "v?.?.? • unknown date"

        }

        let version = parseVersion(from: header) ?? "?.?.?"

        let rawDate = parseDate(from: header)

        let pretty = prettyDate(from: rawDate)

        return "v\(version) • \(pretty)"

    }

    // MARK: - Parsing Helpers

    private func parseVersion(from line: String) -> String? {

        guard let open = line.firstIndex(of: "["),

              let close = line[open...].firstIndex(of: "]")

        else { return nil }

        let inner = line[line.index(after: open)..<close]

        let trimmed = inner.trimmingCharacters(in: .whitespaces)

        return trimmed.isEmpty ? nil : String(trimmed)

    }

    // Tolerant: finds last 8-digit numeric token

    private func parseDate(from line: String) -> String? {

        let tokens = line

            .split(whereSeparator: { $0.isWhitespace })

            .map { String($0) }

        guard let last = tokens.last,

              last.count == 8,

              last.allSatisfy({ $0.isNumber })

        else { return nil }

        return last

    }

    private func prettyDate(from yyyymmdd: String?) -> String {

        guard let raw = yyyymmdd else { return "unknown date" }

        let dfIn = DateFormatter()

        dfIn.locale = Locale(identifier: "en_AU")

        dfIn.dateFormat = "yyyyMMdd"

        let dfOut = DateFormatter()

        dfOut.locale = Locale(identifier: "en_AU")

        dfOut.dateFormat = "d MMM yyyy"

        guard let date = dfIn.date(from: raw) else {

            return raw

        }

        return dfOut.string(from: date)

    }

    // MARK: - UI

    var body: some View {

        ZStack {

            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 32) {

                Image(systemName: "fuelpump.fill")

                    .font(.system(size: 80))

                    .foregroundColor(.accentColor)

                Text("Driver Assistant")

                    .font(.largeTitle.bold())

                Text(status)

                    .font(.title3)

                    .foregroundColor(.secondary)

                    .multilineTextAlignment(.center)

                    .padding(.horizontal, 40)

                ProgressView(value: progress, total: 1.0)

                    .progressViewStyle(.linear)

                    .frame(maxWidth: 280)

                Text(buildInfo)

                    .font(.footnote)

                    .foregroundColor(.gray)

            }

        }

    }

}
