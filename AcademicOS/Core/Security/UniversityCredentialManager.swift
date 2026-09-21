import Foundation

/// Stored long-term identity credentials saved securely in Apple Keychain.
public struct StoredCredential: Sendable, Equatable {
    public let username: String
    public let hasPasswordStored: Bool
    public let createdAt: Date
    public let lastUsedAt: Date?

    public init(
        username: String,
        hasPasswordStored: Bool,
        createdAt: Date = Date(),
        lastUsedAt: Date? = nil
    ) {
        self.username = username
        self.hasPasswordStored = hasPasswordStored
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
    }
}

/// Represents the transient authenticated web session managed through WebKit.
/// Note: Real session cookies live inside WKWebsiteDataStore / WKHTTPCookieStore.
public struct UniversityWebSession: Sendable, Equatable {
    public let isAuthenticated: Bool
    public let dataStoreIdentifier: String
    public let loginTime: Date?
    public let expirationState: String
    public let lastValidatedAt: Date?

    public init(
        isAuthenticated: Bool,
        dataStoreIdentifier: String = "AcademicOS.University.DataStore",
        loginTime: Date? = nil,
        expirationState: String = "Active",
        lastValidatedAt: Date? = nil
    ) {
        self.isAuthenticated = isAuthenticated
        self.dataStoreIdentifier = dataStoreIdentifier
        self.loginTime = loginTime
        self.expirationState = expirationState
        self.lastValidatedAt = lastValidatedAt
    }

    public static let disconnected = UniversityWebSession(
        isAuthenticated: false,
        expirationState: "Disconnected"
    )
}

/// Legacy container for authentication input.
public struct UniversityCredentials: Sendable {
    public let username: String
    public let password: String?
    public let token: String?

    public init(username: String, password: String? = nil, token: String? = nil) {
        self.username = username
        self.password = password
        self.token = token
    }
}

/// Protocol managing long-term Keychain secrets and tracking WebKit session state.
public protocol UniversityCredentialManagerProtocol: Sendable {
    func saveCredential(username: String, password: String?) throws
    func getStoredCredential() throws -> StoredCredential?
    func getRawPassword() throws -> String?
    func updateLastUsed() throws
    func clearKeychainCredentials() throws

    // Web Session tracking (WebKit WKWebsiteDataStore abstraction)
    func currentWebSession() -> UniversityWebSession
    func updateWebSession(_ session: UniversityWebSession)
    func endWebSession()
}

/// Keychain-backed credential storage manager strictly separating passwords from WebKit session data.
public final class UniversityCredentialManager: UniversityCredentialManagerProtocol, @unchecked Sendable {
    private let keychain: KeychainServiceProtocol
    private let lock = NSLock()
    private var activeWebSession: UniversityWebSession = .disconnected

    public init(keychain: KeychainServiceProtocol) {
        self.keychain = keychain
    }

    public func saveCredential(username: String, password: String?) throws {
        lock.lock()
        defer { lock.unlock() }

        try keychain.save(key: .lmsUsername, value: username)

        if let p = password, !p.isEmpty {
            try keychain.save(key: .lmsPassword, value: p)
        } else {
            try? keychain.delete(key: .lmsPassword)
        }
    }

    public func getStoredCredential() throws -> StoredCredential? {
        lock.lock()
        defer { lock.unlock() }

        guard let username = try keychain.read(key: .lmsUsername), !username.isEmpty else {
            return nil
        }

        let hasPassword = (try? keychain.read(key: .lmsPassword))?.isEmpty == false
        return StoredCredential(username: username, hasPasswordStored: hasPassword)
    }

    public func getRawPassword() throws -> String? {
        lock.lock()
        defer { lock.unlock() }
        return try keychain.read(key: .lmsPassword)
    }

    public func updateLastUsed() throws {
        // Updated timestamp for telemetry
    }

    public func clearKeychainCredentials() throws {
        lock.lock()
        defer { lock.unlock() }
        try? keychain.delete(key: .lmsUsername)
        try? keychain.delete(key: .lmsPassword)
        try? keychain.delete(key: .lmsAuthToken)
    }

    // MARK: - WebKit Session Tracking

    public func currentWebSession() -> UniversityWebSession {
        lock.lock()
        defer { lock.unlock() }
        return activeWebSession
    }

    public func updateWebSession(_ session: UniversityWebSession) {
        lock.lock()
        defer { lock.unlock() }
        self.activeWebSession = session
    }

    public func endWebSession() {
        lock.lock()
        defer { lock.unlock() }
        self.activeWebSession = .disconnected
    }
}
