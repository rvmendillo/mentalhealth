import Foundation

/// Saves and loads `AppData` as a single JSON file. All data stays on the device.
public final class DataStore: @unchecked Sendable {
    public let fileURL: URL
    private let lock = NSLock()

    public enum LoadOutcome: Equatable, Sendable {
        case loaded
        case fresh
        /// The file could not be read; it was moved aside to `backupURL` and a fresh store started.
        case recoveredFromCorruption(backupURL: URL)
    }

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    /// The default location: Application Support/RenewedMind/data.json
    public static func defaultURL() throws -> URL {
        let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                               appropriateFor: nil, create: true)
        return base.appendingPathComponent("RenewedMind", isDirectory: true)
            .appendingPathComponent("data.json", isDirectory: false)
    }

    /// Storage encoder. Dates use Foundation's native reference-date encoding so they round-trip exactly.
    public static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .deferredToDate
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    public static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .deferredToDate
        return decoder
    }

    public func load() -> (AppData, LoadOutcome) {
        lock.lock()
        defer { lock.unlock() }
        let fm = FileManager.default
        guard fm.fileExists(atPath: fileURL.path) else { return (AppData(), .fresh) }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try Self.makeDecoder().decode(AppData.self, from: data)
            return (decoded, .loaded)
        } catch {
            let stamp = Int(Date().timeIntervalSince1970)
            let backup = fileURL.deletingLastPathComponent()
                .appendingPathComponent("data.unreadable-\(stamp).json")
            try? fm.moveItem(at: fileURL, to: backup)
            return (AppData(), .recoveredFromCorruption(backupURL: backup))
        }
    }

    public func save(_ appData: AppData) throws {
        let data = try Self.makeEncoder().encode(appData)
        lock.lock()
        defer { lock.unlock() }
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        #if os(iOS)
        try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
        #else
        try data.write(to: fileURL, options: [.atomic])
        #endif
    }

    /// Permanently removes the data file.
    public func deleteAll() throws {
        lock.lock()
        defer { lock.unlock() }
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }

    /// Human-readable export of everything stored.
    public static func exportJSON(_ appData: AppData) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(appData)
    }
}
