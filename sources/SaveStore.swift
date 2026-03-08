
import Foundation

import CryptoKit

  

//======================================

// MARK: - SaveStore (Atomic write + rotation + validation)

//======================================

//

// Files:

// - autosave_tmp.json       (written first)

// - autosave_current.json   (last good save)

// - autosave_previous.json  (fallback)

//

// Validation:

// - SHA256 of payload bytes stored in envelope.

// - If current fails validation -> try previous.

  

final class SaveStore {

    struct Envelope<T: Codable>: Codable {

        let schemaVersion: Int

        let savedAt: Date

        let resumable: Bool         

        let byteCount: Int

        let sha256: String

        let payload: T

    }

    enum SaveError: Error {

        case cannotResolveDocuments

        case cannotCreateFolder

        case encodeFailed

        case decodeFailed

        case checksumMismatch

        case fileMissing

    }

    // Folder: Documents/DriverAssistant/Saves

    private let folderName = "DriverAssistant/Saves"

    private let currentName = "autosave_current.json"

    private let previousName = "autosave_previous.json"

    private let tmpName = "autosave_tmp.json"

    // MARK: - AppConfig

    private let appConfigFolder = "AppConfig"

    private let appConfigFile   = "appconfig.json"

    // MARK: - JSON Assets (Driver / Settings)

    private let jsonRoot = "DriverAssistant/JSON"

    private let driverFolder = "Driver"

    private let settingsFolder = "Settings"

    private let driverFile = "driver.json"

    private let settingsFile = "settings.json"

    private let encoder: JSONEncoder = {

        let e = JSONEncoder()

        e.outputFormatting = [.prettyPrinted, .sortedKeys]

        e.dateEncodingStrategy = .iso8601

        return e

    }()

    private let decoder: JSONDecoder = {

        let d = JSONDecoder()

        d.dateDecodingStrategy = .iso8601

        return d

    }()

    // MARK: - Public API

    private func writeJSON<T: Codable>(_ value: T, to url: URL) throws {

        let bytes = try encoder.encode(value)

        try bytes.write(to: url, options: [.atomic])

    }

    private func readJSON<T: Codable>(_ type: T.Type, from url: URL) throws -> T {

        let bytes = try Data(contentsOf: url)

        return try decoder.decode(T.self, from: bytes)

    }

    private func ensureFolder() throws -> URL {

        try ensureFolder(path: folderName)

    }

    func writeAutosave(payload: AppSaveV1, resumable: Bool) throws {

        let folderURL = try ensureFolder(path: folderName)

        let currentURL = folderURL.appendingPathComponent(currentName)

        let previousURL = folderURL.appendingPathComponent(previousName)

        let tmpURL = folderURL.appendingPathComponent(tmpName)

        // 1) Encode payload first (bytes)

        let payloadBytes = try encoder.encode(payload)

        // 2) Wrap in envelope with checksum

        let digest = SHA256.hash(data: payloadBytes)

        let sha = digest.map { String(format: "%02x", $0) }.joined()

        let env = Envelope<AppSaveV1>(

            schemaVersion: payload.schemaVersion,

            savedAt: payload.savedAt,

            resumable: resumable,     

            byteCount: payloadBytes.count,

            sha256: sha,

            payload: payload

        )

        let envBytes = try encoder.encode(env)

        // 3) Atomic-ish write:

        //    - write tmp

        //    - rotate current -> previous

        //    - replace current with tmp

        try envBytes.write(to: tmpURL, options: [.atomic])

        if FileManager.default.fileExists(atPath: currentURL.path) {

            // Replace previous with current

            _ = try? FileManager.default.removeItem(at: previousURL)

            try FileManager.default.copyItem(at: currentURL, to: previousURL)

        }

        // Replace current with tmp

        _ = try? FileManager.default.removeItem(at: currentURL)

        try FileManager.default.copyItem(at: tmpURL, to: currentURL)

        // Clean up tmp (optional)

        _ = try? FileManager.default.removeItem(at: tmpURL)

    }

    func loadBestResumableAutosave() -> AppSaveV1? {

        do {

            let folderURL = try ensureFolder(path: folderName)

            let currentURL = folderURL.appendingPathComponent(currentName)

            let previousURL = folderURL.appendingPathComponent(previousName)

            if let s = try? readValidatedResumable(from: currentURL) { return s }

            if let s = try? readValidatedResumable(from: previousURL) { return s }

            return nil

        } catch {

            return nil

        }

    }

    private func readValidatedResumable(from url: URL) throws -> AppSaveV1 {

        let bytes = try Data(contentsOf: url)

        let env = try decoder.decode(Envelope<AppSaveV1>.self, from: bytes)

        // checksum validation (same as you already do)

        let payloadBytes = try encoder.encode(env.payload)

        let digest = SHA256.hash(data: payloadBytes)

        let sha = digest.map { String(format: "%02x", $0) }.joined()

        guard sha == env.sha256, payloadBytes.count == env.byteCount else {

            throw SaveError.checksumMismatch

        }

        // ✅ resumable gate

        guard env.resumable else {

            throw SaveError.fileMissing // or a new error like .notResumable

        }

        return env.payload

    }

    func clearAutosaves() {

        do {

            let folderURL = try ensureFolder()

            let currentURL = folderURL.appendingPathComponent(currentName)

            let previousURL = folderURL.appendingPathComponent(previousName)

            let tmpURL = folderURL.appendingPathComponent(tmpName)

            _ = try? FileManager.default.removeItem(at: currentURL)

            _ = try? FileManager.default.removeItem(at: previousURL)

            _ = try? FileManager.default.removeItem(at: tmpURL)

        } catch {

            // ignore

        }

    }

    // MARK: - Driver Profile

    func writeDriverProfile(_ payload: DriverProfilePayloadV1) throws {

        let folder = try ensureFolder(path: "\(jsonRoot)/\(driverFolder)")

        let url = folder.appendingPathComponent(driverFile)

        try writeProfileEnvelope(payload, to: url)

    }

    func loadDriverProfile() -> DriverProfilePayloadV1? {

        do {

            let folder = try ensureFolder(path: "\(jsonRoot)/\(driverFolder)")

            let url = folder.appendingPathComponent(driverFile)

            guard FileManager.default.fileExists(atPath: url.path) else { return nil }

            let payload = try loadProfilePayload(DriverProfilePayloadV1.self, from: url)

            // Optional auto-upgrade: re-save in envelope format if it was legacy plain JSON

            // (We can’t easily detect which path succeeded without extra logic; simplest: just write it back.)

            try? writeDriverProfile(payload)

            return payload

        } catch {

            return nil

        }

    }

    //Mark: - Settings profiles.

    func writeSettings(_ payload: SettingsPayloadV1) throws {

        let folder = try ensureFolder(path: "\(jsonRoot)/\(settingsFolder)")

        let url = folder.appendingPathComponent(settingsFile)

        try writeProfileEnvelope(payload, to: url)

    }

    func loadSettings() -> SettingsPayloadV1? {

        do {

            let folder = try ensureFolder(path: "\(jsonRoot)/\(settingsFolder)")

            let url = folder.appendingPathComponent(settingsFile)

            guard FileManager.default.fileExists(atPath: url.path) else { return nil }

            let payload = try loadProfilePayload(SettingsPayloadV1.self, from: url)

            try? writeSettings(payload) // optional auto-upgrade

            return payload

        } catch {

            return nil

        }

    }

    // MARK: - AppConfig

    func writeAppConfig(_ payload: AppConfigV1) throws {

        let folder = try ensureFolder(path: "\(jsonRoot)/\(appConfigFolder)")

        let url = folder.appendingPathComponent(appConfigFile)

        try writeProfileEnvelope(payload, to: url)

    }

    func loadAppConfig() -> AppConfigV1? {

        do {

            let folder = try ensureFolder(path: "\(jsonRoot)/\(appConfigFolder)")

            let url = folder.appendingPathComponent(appConfigFile)

            guard FileManager.default.fileExists(atPath: url.path) else { return nil }

            let payload = try loadProfilePayload(AppConfigV1.self, from: url)

            try? writeAppConfig(payload) // optional auto-upgrade

            return payload

        } catch {

            return nil

        }

    }

    func debugPrintSaveFolder() {

        if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {

            DebugLog.autosave("💾 Saves folder = \(docs.appendingPathComponent(folderName, isDirectory: true))")

        }

    }

    func debugPrintJSONFolders() {

        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }

        DebugLog.autosave("📁 JSON root = \(docs.appendingPathComponent(jsonRoot, isDirectory: true))")

        DebugLog.autosave("📁 Driver = \(docs.appendingPathComponent("\(jsonRoot)/\(driverFolder)", isDirectory: true))")

        DebugLog.autosave("📁 Settings = \(docs.appendingPathComponent("\(jsonRoot)/\(settingsFolder)", isDirectory: true))")

        DebugLog.autosave("📁 AppConfig = \(docs.appendingPathComponent("\(jsonRoot)/\(appConfigFolder)", isDirectory: true))")

    }

    // MARK: - Internals

     private func ensureFolder(path: String) throws -> URL {

        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {

            throw SaveError.cannotResolveDocuments

        }

        let folderURL = docs.appendingPathComponent(path, isDirectory: true)

        if !FileManager.default.fileExists(atPath: folderURL.path) {

            do {

                try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)

            } catch {

                throw SaveError.cannotCreateFolder

            }

        }

        return folderURL

    }

    private func readValidated(from url: URL) throws -> AppSaveV1 {

        guard FileManager.default.fileExists(atPath: url.path) else {

            throw SaveError.fileMissing

        }

        let bytes = try Data(contentsOf: url)

        let env = try decoder.decode(Envelope<AppSaveV1>.self, from: bytes)

        // Re-encode payload exactly as we did when writing (same encoder settings)

        let payloadBytes = try encoder.encode(env.payload)

        let digest = SHA256.hash(data: payloadBytes)

        let sha = digest.map { String(format: "%02x", $0) }.joined()

        guard sha == env.sha256 else { throw SaveError.checksumMismatch }

        guard payloadBytes.count == env.byteCount else { throw SaveError.checksumMismatch }

        return env.payload

    }

}

  

extension SaveStore {

    func hasAutosaveFiles() -> Bool {

        do {

            let folderURL = try ensureFolder()

            let currentURL = folderURL.appendingPathComponent(currentName)

            let previousURL = folderURL.appendingPathComponent(previousName)

            let fm = FileManager.default

            return fm.fileExists(atPath: currentURL.path) ||

            fm.fileExists(atPath: previousURL.path)

        } catch {

            return false

        }

    }

}

  

extension SaveStore {

    /// Debug-only helper: returns the URLs of known autosave files if the folder exists.

    func debugAutosaveFileURLs() -> [URL] {

        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {

            return []

        }

        let folderURL = docs.appendingPathComponent(folderName, isDirectory: true)

        // Only the real autosaves (you can include tmp if you want)

        let names = [currentName, previousName]

        return names

            .map { folderURL.appendingPathComponent($0) }

            .filter { FileManager.default.fileExists(atPath: $0.path) }

    }

}

  

extension SaveStore {

    // inside SaveStore)

    private func writeProfileEnvelope<T: Codable>(_ payload: T, to url: URL) throws {

        let env = ProfileEnvelopeV1(payload: payload)

        try writeJSON(env, to: url)

    }

    private func loadProfilePayload<T: Codable>(_ type: T.Type, from url: URL) throws -> T {

        let bytes = try Data(contentsOf: url)

        // 1) Try envelope first (new format)

        if let env = try? decoder.decode(ProfileEnvelopeV1<T>.self, from: bytes) {

            return env.payload

        }

        // 2) Fallback: old “plain payload” (legacy format)

        //    If this succeeds, caller can re-save and “upgrade” the file.

        return try decoder.decode(T.self, from: bytes)

    }

}
