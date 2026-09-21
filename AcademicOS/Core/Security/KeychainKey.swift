import Foundation

/// Type-safe keys used across AcademicOS for sensitive Keychain storage.
public enum KeychainKey: String, Sendable, CaseIterable {
    case geminiApiKey = "academicos.auth.gemini_api_key"
    case lmsUsername = "academicos.auth.lms_username"
    case lmsPassword = "academicos.auth.lms_password"
    case lmsAuthToken = "academicos.auth.lms_token"
    case uzemSessionCookie = "academicos.auth.uzem_session"
    case encryptionPassphrase = "academicos.auth.db_passphrase"
}
