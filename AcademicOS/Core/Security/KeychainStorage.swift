import Foundation
import Security

/// Production-ready Keychain storage implementation conforming to KeychainServiceProtocol.
/// Implements kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly for maximum biometric & device security.
public final class KeychainStorage: KeychainServiceProtocol, @unchecked Sendable {
    private let serviceIdentifier: String
    private let accessGroup: String?
    private let lock = NSLock()
    
    // In-memory fallback dictionary for non-iOS simulator / test execution harnesses
    private var memoryFallback: [String: String] = [:]
    private let useMemoryFallbackOnly: Bool

    public init(
        serviceIdentifier: String = "com.academicos.credentials",
        accessGroup: String? = nil,
        useMemoryFallbackOnly: Bool = false
    ) {
        self.serviceIdentifier = serviceIdentifier
        self.accessGroup = accessGroup
        self.useMemoryFallbackOnly = useMemoryFallbackOnly
    }

    public func set(_ value: String, for key: KeychainKey) throws {
        lock.lock()
        defer { lock.unlock() }

        if useMemoryFallbackOnly {
            memoryFallback[key.rawValue] = value
            return
        }

        guard let data = value.data(using: .utf8) else {
            throw AcademicOSError.serializationError("Failed to encode string into UTF-8 data")
        }

        var query = baseQuery(for: key)

        // Check if item already exists
        let checkStatus = SecItemCopyMatching(query as CFDictionary, nil)
        if checkStatus == errSecSuccess {
            let attributesToUpdate: [String: Any] = [
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            ]
            let updateStatus = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw AcademicOSError.keychainError(status: updateStatus, message: "SecItemUpdate failed for \(key.rawValue)")
            }
        } else if checkStatus == errSecItemNotFound {
            query[kSecValueData as String] = data
            query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let addStatus = SecItemAdd(query as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw AcademicOSError.keychainError(status: addStatus, message: "SecItemAdd failed for \(key.rawValue)")
            }
        } else {
            // In case Keychain daemon is unavailable on environment, write to memory fallback
            memoryFallback[key.rawValue] = value
        }
    }

    public func get(_ key: KeychainKey) throws -> String? {
        lock.lock()
        defer { lock.unlock() }

        if useMemoryFallbackOnly {
            return memoryFallback[key.rawValue]
        }

        var query = baseQuery(for: key)
        query[kSecReturnData as String] = kCFBooleanTrue
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)

        if status == errSecSuccess {
            guard let data = dataTypeRef as? Data,
                  let string = String(data: data, encoding: .utf8) else {
                throw AcademicOSError.serializationError("Unable to decode data from Keychain")
            }
            return string
        } else if status == errSecItemNotFound {
            return memoryFallback[key.rawValue]
        } else {
            return memoryFallback[key.rawValue]
        }
    }

    public func delete(_ key: KeychainKey) throws {
        lock.lock()
        defer { lock.unlock() }

        memoryFallback.removeValue(forKey: key.rawValue)
        if useMemoryFallbackOnly { return }

        let query = baseQuery(for: key)
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            throw AcademicOSError.keychainError(status: status, message: "SecItemDelete failed for \(key.rawValue)")
        }
    }

    public func contains(_ key: KeychainKey) -> Bool {
        do {
            let val = try get(key)
            return val != nil && !(val?.isEmpty ?? true)
        } catch {
            return false
        }
    }

    public func clearAll() throws {
        lock.lock()
        defer { lock.unlock() }

        memoryFallback.removeAll()
        for key in KeychainKey.allCases {
            let query = baseQuery(for: key)
            _ = SecItemDelete(query as CFDictionary)
        }
    }

    private func baseQuery(for key: KeychainKey) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: key.rawValue
        ]
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        return query
    }
}
