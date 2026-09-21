import Foundation

/// Defines secure credential storage contract backed by iOS Keychain.
public protocol KeychainServiceProtocol: Sendable {
    func set(_ value: String, for key: KeychainKey) throws
    func get(_ key: KeychainKey) throws -> String?
    func delete(_ key: KeychainKey) throws
    func contains(_ key: KeychainKey) -> Bool
    func clearAll() throws
}
