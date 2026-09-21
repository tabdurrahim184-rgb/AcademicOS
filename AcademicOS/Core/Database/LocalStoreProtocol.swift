import Foundation

/// Protocol defining local storage operations for an entity type.
public protocol LocalStoreProtocol: Sendable {
    func save<T: Identifiable & Codable & Sendable>(_ item: T) async throws
    func saveAll<T: Identifiable & Codable & Sendable>(_ items: [T]) async throws
    func fetch<T: Identifiable & Codable & Sendable>(id: T.ID) async throws -> T?
    func fetchAll<T: Identifiable & Codable & Sendable>() async throws -> [T]
    func delete<T: Identifiable & Codable & Sendable>(id: T.ID) async throws
    func deleteAll<T: Identifiable & Codable & Sendable>(_ type: T.Type) async throws
    func count<T: Identifiable & Codable & Sendable>(_ type: T.Type) async throws -> Int
    func clearAll() async throws
}
