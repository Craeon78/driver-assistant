//======================================
// MARK: - EventStore (V3 Core)
//======================================
//
// © 2026 Cory Russell Olsen. All rights reserved.
//
// Persistence + replay interface for the event spine.
// Chunk 1 implements a simple file-backed store sufficient for the gate.
// Later chunks may swap the backing store without changing callers.
//
// Phase: Chunk 1 — Silent spine
//======================================

import Foundation

public protocol EventStore: AnyObject {
    func append(_ event: Event) throws
    func append(_ events: [Event]) throws
    func allEvents() throws -> [Event]
    func events(from start: Date, to end: Date) throws -> [Event]
    func clear() throws
}

/// Simple JSON-file backed store. Good enough for fabricated-shift gate tests.
/// Not intended for production multi-day use; will be replaced or hardened later.
public final class FileEventStore: EventStore {
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
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

    // MARK: - Private

    private func ensureLoaded() throws {
        guard !loaded else { return }
        if FileManager.default.fileExists(atPath: fileURL.path) {
            let data = try Data(contentsOf: fileURL)
            cache = try decoder.decode([Event].self, from: data)
        }
        loaded = true
    }

    private func persist() throws {
        let data = try encoder.encode(cache)
        try data.write(to: fileURL, options: .atomic)
    }
}
