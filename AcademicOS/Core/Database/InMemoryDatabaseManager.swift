import Foundation

/// Thread-safe in-memory database implementation conforming to LocalStoreProtocol.
/// Used for tests, previews, and local transient session caching.
public actor InMemoryDatabaseManager: LocalStoreProtocol {
    private var storage: [String: [String: Data]] = [:]

    public init() {}

    private func keyForType<T>(_ type: T.Type) -> String {
        return String(describing: type)
    }

    public func save<T: Identifiable & Codable & Sendable>(_ item: T) async throws {
        let typeKey = keyForType(T.self)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(item)
        let itemIdString = String(describing: item.id)

        if storage[typeKey] == nil {
            storage[typeKey] = [:]
        }
        storage[typeKey]?[itemIdString] = data
    }

    public func saveAll<T: Identifiable & Codable & Sendable>(_ items: [T]) async throws {
        for item in items {
            try await save(item)
        }
    }

    public func fetch<T: Identifiable & Codable & Sendable>(_ type: T.Type, id: T.ID) async throws -> T? {
        let typeKey = keyForType(type)
        let itemIdString = String(describing: id)
        guard let data = storage[typeKey]?[itemIdString] else {
            return nil
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }

    public func fetch<T: Identifiable & Codable & Sendable>(id: T.ID) async throws -> T? {
        try await fetch(T.self, id: id)
    }

    public func fetchAll<T: Identifiable & Codable & Sendable>(_ type: T.Type) async throws -> [T] {
        let typeKey = keyForType(type)
        guard let dict = storage[typeKey] else { return [] }

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

    public func fetchAll<T: Identifiable & Codable & Sendable>() async throws -> [T] {
        try await fetchAll(T.self)
    }

    public func delete<T: Identifiable & Codable & Sendable>(_ type: T.Type, id: T.ID) async throws {
        let typeKey = keyForType(type)
        let itemIdString = String(describing: id)
        storage[typeKey]?.removeValue(forKey: itemIdString)
    }

    public func delete<T: Identifiable & Codable & Sendable>(type: T.Type, id: T.ID) async throws {
        try await delete(type, id: id)
    }

    public func deleteAll<T: Identifiable & Codable & Sendable>(_ type: T.Type) async throws {
        let typeKey = keyForType(type)
        storage.removeValue(forKey: typeKey)
    }

    public func count<T: Identifiable & Codable & Sendable>(_ type: T.Type) async throws -> Int {
        let typeKey = keyForType(type)
        return storage[typeKey]?.count ?? 0
    }

    public func clearAll() async throws {
        storage.removeAll()
    }
}
