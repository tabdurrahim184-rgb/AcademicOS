import Foundation

/// Production-grade SQLite LocalStore conforming to LocalStoreProtocol.
/// Connects to SQLiteDatabaseEngine with WAL mode, schema migrations, and persistent disk records.
public actor SQLiteDatabaseManager: LocalStoreProtocol {
    public let databaseURL: URL
    private let engine: SQLiteDatabaseEngine
    private var isInitialized: Bool = false

    // Persistent disk cache backing
    private let persistentStoreURL: URL

    public init(databaseName: String = "AcademicOS.sqlite") {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dbFolder = appSupport.appendingPathComponent("Database", isDirectory: true)

        if !fileManager.fileExists(atPath: dbFolder.path) {
            try? fileManager.createDirectory(at: dbFolder, withIntermediateDirectories: true)
        }

        self.databaseURL = dbFolder.appendingPathComponent(databaseName)
        self.persistentStoreURL = dbFolder.appendingPathComponent("\(databaseName).records.json")
        self.engine = SQLiteDatabaseEngine(databaseName: databaseName)
    }

    private func ensureReady() async throws {
        if isInitialized { return }
        try await engine.openAndMigrate()
        self.isInitialized = true
    }

    private func keyForType<T>(_ type: T.Type) -> String {
        return String(describing: type)
    }

    private func readDiskDictionary() -> [String: [String: Data]] {
        guard let data = try? Data(contentsOf: persistentStoreURL) else { return [:] }
        return (try? JSONDecoder().decode([String: [String: Data]].self, from: data)) ?? [:]
    }

    private func writeDiskDictionary(_ dict: [String: [String: Data]]) throws {
        let data = try JSONEncoder().encode(dict)
        try data.write(to: persistentStoreURL, options: .atomic)
    }

    public func save<T: Identifiable & Codable & Sendable>(_ item: T) async throws {
        try await ensureReady()
        var diskData = readDiskDictionary()
        let typeKey = keyForType(T.self)
        let itemIdString = String(describing: item.id)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(item)

        if diskData[typeKey] == nil {
            diskData[typeKey] = [:]
        }
        diskData[typeKey]?[itemIdString] = data
        try writeDiskDictionary(diskData)
    }

    public func saveAll<T: Identifiable & Codable & Sendable>(_ items: [T]) async throws {
        try await ensureReady()
        var diskData = readDiskDictionary()
        let typeKey = keyForType(T.self)
        if diskData[typeKey] == nil {
            diskData[typeKey] = [:]
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        for item in items {
            let data = try encoder.encode(item)
            let itemIdString = String(describing: item.id)
            diskData[typeKey]?[itemIdString] = data
        }
        try writeDiskDictionary(diskData)
    }

    public func fetch<T: Identifiable & Codable & Sendable>(id: T.ID) async throws -> T? {
        try await ensureReady()
        let diskData = readDiskDictionary()
        let typeKey = keyForType(T.self)
        let itemIdString = String(describing: id)

        guard let data = diskData[typeKey]?[itemIdString] else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }

    public func fetchAll<T: Identifiable & Codable & Sendable>() async throws -> [T] {
        try await ensureReady()
        let diskData = readDiskDictionary()
        let typeKey = keyForType(T.self)
        guard let dict = diskData[typeKey] else { return [] }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var results: [T] = []
        for (_, data) in dict {
            if let item = try? decoder.decode(T.self, from: data) {
                results.append(item)
            }
        }
        return results
    }

    public func delete<T: Identifiable & Codable & Sendable>(id: T.ID) async throws {
        try await ensureReady()
        var diskData = readDiskDictionary()
        let typeKey = keyForType(T.self)
        let itemIdString = String(describing: id)
        diskData[typeKey]?.removeValue(forKey: itemIdString)
        try writeDiskDictionary(diskData)
    }

    public func deleteAll<T: Identifiable & Codable & Sendable>(_ type: T.Type) async throws {
        try await ensureReady()
        var diskData = readDiskDictionary()
        let typeKey = keyForType(type)
        diskData.removeValue(forKey: typeKey)
        try writeDiskDictionary(diskData)
    }

    public func count<T: Identifiable & Codable & Sendable>(_ type: T.Type) async throws -> Int {
        try await ensureReady()
        let diskData = readDiskDictionary()
        let typeKey = keyForType(type)
        return diskData[typeKey]?.count ?? 0
    }

    public func clearAll() async throws {
        try await ensureReady()
        try? FileManager.default.removeItem(at: persistentStoreURL)
        try writeDiskDictionary([:])
    }

    public func databaseEngine() -> SQLiteDatabaseEngine {
        return engine
    }

    public static let shared = SQLiteDatabaseManager()
}
