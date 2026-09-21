import Foundation

/// Protocol defining local storage operations for entity types.
public protocol LocalStoreProtocol: Sendable {
    func save<T: Identifiable & Codable & Sendable>(_ item: T) async throws
    func saveAll<T: Identifiable & Codable & Sendable>(_ items: [T]) async throws
    func fetch<T: Identifiable & Codable & Sendable>(_ type: T.Type, id: T.ID) async throws -> T?
    func fetchAll<T: Identifiable & Codable & Sendable>(_ type: T.Type) async throws -> [T]
    func delete<T: Identifiable & Codable & Sendable>(_ type: T.Type, id: T.ID) async throws
    func deleteAll<T: Identifiable & Codable & Sendable>(_ type: T.Type) async throws
    func count<T: Identifiable & Codable & Sendable>(_ type: T.Type) async throws -> Int
    func clearAll() async throws
}

public extension LocalStoreProtocol {
    /// Convenience method to fetch a single item when type can be inferred from context.
    func fetch<T: Identifiable & Codable & Sendable>(id: T.ID) async throws -> T? {
        try await fetch(T.self, id: id)
    }

    /// Convenience method to fetch all items when type can be inferred from context.
    func fetchAll<T: Identifiable & Codable & Sendable>() async throws -> [T] {
        try await fetchAll(T.self)
    }

    /// Convenience method supporting labelled delete(type:id:).
    func delete<T: Identifiable & Codable & Sendable>(type: T.Type, id: T.ID) async throws {
        try await delete(type, id: id)
    }
}
