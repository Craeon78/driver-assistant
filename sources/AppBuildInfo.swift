
import Foundation

  

//======================================

// MARK: - AppBuildInfo

//======================================

//

/// Reads PATCHLOG.md from the app bundle and exposes

/// the current version + build date based on the *topmost* entry.

///

/// Expected PATCHLOG header example:

/// ## [0.1.42] 20251231

struct AppBuildInfo {

    static let shared = AppBuildInfo()

    /// e.g. "0.1.42"

    let version: String

    /// e.g. "20251231" (raw yyyymmdd from the header)

    let buildDateRaw: String

    /// e.g. "31-12-2025" (AU-friendly)

    let buildDatePretty: String

    /// The full header line we parsed (useful for debugging).

    let headerLine: String

    private init() {

        let (line, v, d) = AppBuildInfo.loadFromPatchlog()

        self.headerLine      = line ?? ""

        self.version         = v ?? "0.0.0"

        self.buildDateRaw    = d ?? "unknown"

        self.buildDatePretty = AppBuildInfo.prettyDate(from: d)

    }

}

  

//======================================

// MARK: - Internal helpers

//======================================

  

private extension AppBuildInfo {

    /// Load PATCHLOG.md, find the first header line, and parse version + date.

    static func loadFromPatchlog() -> (String?, String?, String?) {

        guard let url = Bundle.main.url(forResource: "PATCHLOG", withExtension: "md"),

              let contents = try? String(contentsOf: url, encoding: .utf8)

        else {

            return (nil, nil, nil)

        }

        // Split into lines and grab the first that starts with "##"

        let lines = contents

            .split(whereSeparator: \.isNewline)

            .map { String($0) }

        guard let header = lines.first(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix("##") })

        else {

            return (nil, nil, nil)

        }

        let version = parseVersion(from: header)

        let date    = parseDate(from: header)

        return (header, version, date)

    }

    /// Extracts text between "[" and "]", e.g. "[0.1.42]" → "0.1.42".

    static func parseVersion(from line: String) -> String? {

        guard let open = line.firstIndex(of: "["),

              let close = line[open...].firstIndex(of: "]")

        else { return nil }

        let inner = line[line.index(after: open)..<close]

        let trimmed = inner.trimmingCharacters(in: .whitespaces)

        return trimmed.isEmpty ? nil : String(trimmed)

    }

    /// Assumes the last whitespace-separated token in the line is yyyymmdd.

    static func parseDate(from line: String) -> String? {

        let parts = line

            .split(separator: " ")

            .map { String($0) }

        guard let last = parts.last,

              last.count == 8,

              last.allSatisfy({ $0.isNumber })

        else {

            return nil

        }

        return last

    }

    /// Turn "20251231" into "31-12-2025", otherwise "unknown".

    static func prettyDate(from raw: String?) -> String {

        guard let raw = raw, raw.count == 8 else { return "unknown" }

        let year  = raw.prefix(4)

        let month = raw.dropFirst(4).prefix(2)

        let day   = raw.suffix(2)

        return "\(day)-\(month)-\(year)"

    }

}
