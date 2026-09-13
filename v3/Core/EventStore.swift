//======================================
// MARK: - EventStore (V3 Core)
//======================================
//
// © 2026 Cory Russell Olsen. All rights reserved.
//
// Persistence + replay interface for the event spine.
// Chunk 1 provides two implementations:
//   - InMemoryEventStore  (pure logic, no disk)
//   - FileEventStore      (JSON, atomic write — for crash/relaunch proof)
//
// Later chunks may replace the backing store without changing callers.
//
// Phase: Chunk 1 — Silent spine
//======================================

import Foundation

public enum EventStoreError: Error, LocalizedError {
    case encodingFailed
    case decodingFailed
    case ioFailed(String)

    public var errorDescription: String? {
        switch self {
        case .encodingFailed: return "Failed to encode events"
        case .decodingFailed: return "Failed to decode events"
        case .ioFailed(let msg): return "I/O error: \(msg)"
        }
    }
}

public protocol EventStore: AnyObject {
    func append(_ event: Event) throws
    func append(_ events: [Event]) throws
    func allEvents() throws -> [Event]
    func events(from start: Date, to end: Date) throws -> [Event]
    func clear() throws
}

// MARK: - In-memory (no disk)

/// Pure in-memory store. Useful for logic tests and Playgrounds experimentation
/// without touching the filesystem.
public final class InMemoryEventStore: EventStore {
    private var cache: [Event] = []

    public init() {}

    public func append(_ event: Event) throws {
        cache.append(event)
    }

    public func append(_ events: [Event]) throws {
        cache.append(contentsOf: events)
    }

    public func allEvents() throws -> [Event] {
        cache.sorted { $0.occurredAt < $1.occurredAt }
    }

    public func events(from start: Date, to end: Date) throws -> [Event] {
        try allEvents().filter { $0.occurredAt >= start && $0.occurredAt <= end }
    }

    public func clear() throws {
        cache = []
    }
}

// MARK: - File-backed (atomic JSON)

/// Simple JSON-file backed store. Sufficient for the Chunk 1 gate.
/// Not intended for production multi-day use; will be replaced or hardened later.
public final class FileEventStore: EventStore {
    private let fileURL: URL
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.sortedKeys]
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
    private var cache: [Event] = []
    private var loaded = false

    public init(directory: URL, filename: String = "v3-events.json") throws {
        self.fileURL = directory.appendingPathComponent(filename)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    public func append(_ event: Event) throws {
        try ensureLoaded()
        cache.append(event)
        try persist()
    }

    public func append(_ events: [Event]) throws {
        try ensureLoaded()
        cache.append(contentsOf: events)
        try persist()
    }

    public func allEvents() throws -> [Event] {
        try ensureLoaded()
        return cache.sorted { $0.occurredAt < $1.occurredAt }
    }

    public func events(from start: Date, to end: Date) throws -> [Event] {
        try allEvents().filter { $0.occurredAt >= start && $0.occurredAt <= end }
    }

    public func clear() throws {
        cache = []
        loaded = true
        try persist()
    }

    /// Force a reload from disk (simulates process death + relaunch).
    public func reloadFromDisk() throws {
        loaded = false
        cache = []
        try ensureLoaded()
    }

    // MARK: - Private

    private func ensureLoaded() throws {
        guard !loaded else { return }
        if FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                let data = try Data(contentsOf: fileURL)
                cache = try decoder.decode([Event].self, from: data)
            } catch {
                throw EventStoreError.decodingFailed
            }
        }
        loaded = true
    }

    private func persist() throws {
        do {
            let data = try encoder.encode(cache)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            throw EventStoreError.encodingFailed
        }
    }
}
