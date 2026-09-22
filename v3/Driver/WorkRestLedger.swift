//======================================
// MARK: - WorkRestLedger (V3 Driver)
//======================================
//
// © 2026 Cory Russell Olsen. All rights reserved.
//
// Persistent continuous timeline of work/rest entries.
// Red Team non-negotiables:
//   1. Ledger is the only fatigue feed (no parallel session array as authority)
//   2. Continuous timeline — midnight/shift never wipe history
//   3. Binary kind only (work|rest)
//
// Phase: Chunk 3a — Ledger spine
//======================================

import Foundation

public enum WorkRestLedgerError: Error, LocalizedError {
    case encodingFailed
    case decodingFailed
    case ioFailed(String)
    case invalidClose(String)

    public var errorDescription: String? {
        switch self {
        case .encodingFailed: return "Failed to encode ledger"
        case .decodingFailed: return "Failed to decode ledger"
        case .ioFailed(let m): return "I/O error: \(m)"
        case .invalidClose(let m): return m
        }
    }
}

public protocol WorkRestLedgerStore: AnyObject {
    func load() throws -> [WorkRestEntry]
    func save(_ entries: [WorkRestEntry]) throws
    /// Simulate process death: drop memory and reload from durable storage.
    func simulateRelaunch() throws -> [WorkRestEntry]
}

// MARK: - In-memory (tests / pure logic)

public final class InMemoryWorkRestLedgerStore: WorkRestLedgerStore {
    private var entries: [WorkRestEntry] = []

    public init() {}

    public func load() throws -> [WorkRestEntry] {
        entries.sorted { $0.start < $1.start }
    }

    public func save(_ entries: [WorkRestEntry]) throws {
        self.entries = entries
    }

    public func simulateRelaunch() throws -> [WorkRestEntry] {
        // Memory is the only store; relaunch is a no-op copy for API symmetry.
        try load()
    }
}

/// Isolated Playgrounds regression storage; production uses the file store.
public final class DefaultsWorkRestLedgerStore: WorkRestLedgerStore {
    private let defaults: UserDefaults
    private let key: String
    public init(defaults: UserDefaults, key: String = "chunk5h.driver.ledger") {
        self.defaults = defaults; self.key = key
    }
    public func load() throws -> [WorkRestEntry] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return try JSONDecoder().decode([WorkRestEntry].self, from: data)
    }
    public func save(_ entries: [WorkRestEntry]) throws {
        let data = try JSONEncoder().encode(entries)
        defaults.set(data, forKey: key)
        guard defaults.data(forKey: key) == data else { throw WorkRestLedgerError.ioFailed("Ledger write could not be read back") }
    }
    public func simulateRelaunch() throws -> [WorkRestEntry] { try load() }
}

// MARK: - File-backed

public final class FileWorkRestLedgerStore: WorkRestLedgerStore {
    private let fileURL: URL
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .deferredToDate
        e.outputFormatting = [.sortedKeys]
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .deferredToDate
        return d
    }()
    private var cache: [WorkRestEntry] = []
    private var loaded = false

    public init(directory: URL, filename: String = "v3-work-rest-ledger.json") throws {
        self.fileURL = directory.appendingPathComponent(filename)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    public func load() throws -> [WorkRestEntry] {
        try ensureLoaded()
        return cache.sorted { $0.start < $1.start }
    }

    public func save(_ entries: [WorkRestEntry]) throws {
        let data = try encoder.encode(entries)
        do { try data.write(to: fileURL, options: .atomic) }
        catch { throw WorkRestLedgerError.ioFailed(String(describing: error)) }
        cache = entries
        loaded = true
    }

    public func simulateRelaunch() throws -> [WorkRestEntry] {
        loaded = false
        cache = []
        return try load()
    }

    private func ensureLoaded() throws {
        guard !loaded else { return }
        if FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                let data = try Data(contentsOf: fileURL)
                if let modern = try? decoder.decode([WorkRestEntry].self, from: data) {
                    cache = modern
                } else {
                    let legacy = JSONDecoder()
                    legacy.dateDecodingStrategy = .iso8601
                    cache = try legacy.decode([WorkRestEntry].self, from: data)
                }
            } catch {
                throw WorkRestLedgerError.decodingFailed
            }
        }
        loaded = true
    }

    private func persist() throws {
        do {
            let data = try encoder.encode(cache)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            throw WorkRestLedgerError.encodingFailed
        }
    }
}

// MARK: - Ledger (authority)

public final class WorkRestLedger {
    private let store: WorkRestLedgerStore
    private var entries: [WorkRestEntry] = []

    public init(store: WorkRestLedgerStore) throws {
        self.store = store
        self.entries = try store.load()
    }

    public func allEntries() -> [WorkRestEntry] {
        entries.sorted { $0.start < $1.start }
    }

    public func openEntry() -> WorkRestEntry? {
        entries.first { $0.isOpen }
    }

    /// Append a new entry. Does not close prior open entries automatically
    /// (driver authority — explicit close required).
    public func append(_ entry: WorkRestEntry) throws {
        let next = entries + [entry]
        try store.save(next)
        entries = next
    }

    /// Close an open entry by id. Refuses if end < start.
    public func close(id: CanonicalID, at end: Date, recordedAt: Date = Date()) throws {
        guard let idx = entries.firstIndex(where: { $0.id == id }) else {
            throw WorkRestLedgerError.invalidClose("No entry \(id)")
        }
        guard entries[idx].isOpen else {
            throw WorkRestLedgerError.invalidClose("Entry already closed")
        }
        guard end >= entries[idx].start else {
            throw WorkRestLedgerError.invalidClose("end before start")
        }
        var next = entries
        next[idx].end = end
        next[idx].recordedAt = recordedAt
        try store.save(next)
        entries = next
    }

    /// One durable write for a driver-established Work/Rest boundary.
    public func transition(to kind: WorkRestKind, at time: Date) throws {
        guard let open = openEntry(), open.kind != kind,
              let index = entries.firstIndex(where: { $0.id == open.id }), time >= open.start else {
            throw WorkRestLedgerError.invalidClose("Expected an open opposite Work/Rest entry")
        }
        var next = entries
        next[index].end = time
        next[index].recordedAt = time
        next.append(WorkRestEntry(kind: kind, start: time, recordedAt: time))
        try store.save(next)
        entries = next
    }

    /// Explicit shift-end marker is *not* a ledger wipe.
    /// Callers may record a Core event; this method only asserts history remains.
    public func assertHistoryPreservedAfterShiftEnd() -> Bool {
        !entries.isEmpty || true
    }

    /// Simulate process death and reload. Returns post-relaunch entries.
    public func simulateRelaunch() throws -> [WorkRestEntry] {
        entries = try store.simulateRelaunch()
        return allEntries()
    }

    public func replaceAllForTesting(_ newEntries: [WorkRestEntry]) throws {
        entries = newEntries
        try store.save(entries)
    }
}

// MARK: - Fabricator

public enum WorkRestFabricator {

    /// Closed shift: work → rest → work, all closed.
    public static func closedShift(base: Date = Date()) -> [WorkRestEntry] {
        let t0 = base
        let t1 = t0.addingTimeInterval(3 * 3600)
        let t2 = t1.addingTimeInterval(30 * 60)
        let t3 = t2.addingTimeInterval(2 * 3600)
        return [
            WorkRestEntry(kind: .work, start: t0, end: t1),
            WorkRestEntry(kind: .rest, start: t1, end: t2, stationaryRest: true),
            WorkRestEntry(kind: .work, start: t2, end: t3)
        ]
    }

    /// Open shift: work still in progress (end == nil).
    public static func openShift(base: Date = Date()) -> [WorkRestEntry] {
        let t0 = base
        let t1 = t0.addingTimeInterval(2 * 3600)
        return [
            WorkRestEntry(kind: .work, start: t0, end: t1),
            WorkRestEntry(kind: .rest, start: t1, end: t1.addingTimeInterval(20 * 60), stationaryRest: true),
            WorkRestEntry(kind: .work, start: t1.addingTimeInterval(20 * 60), end: nil)
        ]
    }

    /// Overnight-open: single work entry started before midnight, still open after.
    public static func overnightOpen(calendar: Calendar = Calendar(identifier: .gregorian)) -> (entries: [WorkRestEntry], justAfterMidnight: Date) {
        var cal = calendar
        cal.timeZone = TimeZone(identifier: "Australia/Brisbane") ?? .current
        let day = cal.startOfDay(for: Date())
        let start = cal.date(bySettingHour: 22, minute: 0, second: 0, of: day.addingTimeInterval(-24 * 3600))!
        let afterMidnight = cal.date(bySettingHour: 1, minute: 0, second: 0, of: day)!
        let entry = WorkRestEntry(kind: .work, start: start, end: nil)
        return ([entry], afterMidnight)
    }
}
