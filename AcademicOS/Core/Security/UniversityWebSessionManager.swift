import Foundation
#if canImport(WebKit)
import WebKit
#endif

/// Decision result for navigation actions.
public enum NavigationDecision: Sendable, Equatable {
    case allowInWebView
    case openExternalBrowser
    case cancelAndBlock(reason: String)
}

/// Coordinates authenticated web sessions, cookie isolation via WKWebsiteDataStore, and navigation security.
public final class UniversityWebSessionManager: NSObject, @unchecked Sendable {
    public static let shared = UniversityWebSessionManager()

    private let credentialPolicy: CredentialDomainPolicy
    private let navigationPolicy: NavigationDomainPolicy
    private let credentialManager: UniversityCredentialManagerProtocol
    private let auditLogger: SecurityActivityLogger
    private let lock = NSLock()

    // State machine tracking active navigation and autofill eligibility
    private var isAutofillEligible: Bool = false
    private var expectedMainFrameHost: String? = nil

    public init(
        credentialPolicy: CredentialDomainPolicy = CredentialDomainPolicy.shared,
        navigationPolicy: NavigationDomainPolicy = NavigationDomainPolicy.shared,
        credentialManager: UniversityCredentialManagerProtocol = UniversityCredentialManager(keychain: KeychainStorage()),
        auditLogger: SecurityActivityLogger = SecurityActivityLogger.shared
    ) {
        self.credentialPolicy = credentialPolicy
        self.navigationPolicy = navigationPolicy
        self.credentialManager = credentialManager
        self.auditLogger = auditLogger
        super.init()
    }

    // MARK: - Navigation Policy & Decision Engine

    /// Validates an in-flight navigation action (e.g. from WKNavigationDelegate).
    public func decidePolicyForNavigation(
        targetURL: URL,
        isMainFrame: Bool,
        isRedirect: Bool = false
    ) -> NavigationDecision {
        let host = targetURL.host?.lowercased() ?? ""

        // 1. Enforce HTTPS (localhost exempt only for Developer Demo)
        if targetURL.scheme != "https" && host != "localhost" && host != "127.0.0.1" {
            auditLogger.record(event: .insecureHTTPBlocked, url: targetURL, safeDescription: "Blocked plain HTTP request to \(host)")
            clearAutofillEligibility()
            return .cancelAndBlock(reason: "Insecure HTTP is strictly prohibited.")
        }

        // 2. Classify host using NavigationDomainPolicy
        let classification = navigationPolicy.classifyHost(url: targetURL)

        switch classification {
        case .approvedPortalHost, .approvedSSOHost:
            // Check for unexpected redirect
            if isRedirect && isMainFrame {
                if let expected = expectedMainFrameHost, expected != host {
                    auditLogger.record(
                        event: .unexpectedRedirect,
                        url: targetURL,
                        safeDescription: "Unexpected redirect from \(expected) to \(host). Revoking autofill eligibility."
                    )
                    clearAutofillEligibility()
                }
            }

            // Set main frame host
            if isMainFrame {
                lock.lock()
                expectedMainFrameHost = host
                // Check if this exact host is approved for credentials
                isAutofillEligible = credentialPolicy.canInjectCredentials(into: targetURL, isMainFrame: true)
                lock.unlock()
            }

            return .allowInWebView

        case .approvedDocumentHost:
            // Documents are allowed to load but never eligible for credential autofill
            clearAutofillEligibility()
            return .allowInWebView

        case .externalSafeHost:
            // External safe educational link -> Open outside authenticated web view
            clearAutofillEligibility()
            return .openExternalBrowser

        case .blockedHost:
            auditLogger.record(
                event: .domainRejected,
                url: targetURL,
                safeDescription: "Navigation to unapproved domain blocked: \(host)"
            )
            clearAutofillEligibility()
            return .cancelAndBlock(reason: "Domain is not authorized for university communication.")
        }
    }

    /// Checks if credential autofill is currently safe and permitted for this specific frame.
    public func canAutofillCredentials(url: URL, isMainFrame: Bool) -> Bool {
        guard isMainFrame else {
            auditLogger.record(
                event: .iframeAutofillBlocked,
                url: url,
                safeDescription: "Blocked credential autofill attempt inside non-main frame."
            )
            return false
        }

        lock.lock()
        defer { lock.unlock() }

        guard isAutofillEligible else {
            return false
        }

        return credentialPolicy.canInjectCredentials(into: url, isMainFrame: isMainFrame)
    }

    public func clearAutofillEligibility() {
        lock.lock()
        defer { lock.unlock() }
        isAutofillEligible = false
        expectedMainFrameHost = nil
    }

    // MARK: - WKWebsiteDataStore / Cookie Management

    /// Clears university session and cookies from WKWebsiteDataStore without touching Keychain credentials unless requested.
    public func clearWebSession(deleteKeychainCredentials: Bool = false) {
        clearAutofillEligibility()
        credentialManager.endWebSession()

        auditLogger.record(
            event: .sessionCleared,
            url: nil,
            safeDescription: "University web session and cookies cleared from WKWebsiteDataStore."
        )

        if deleteKeychainCredentials {
            try? credentialManager.clearKeychainCredentials()
            auditLogger.record(
                event: .credentialsDeleted,
                url: nil,
                safeDescription: "Student requested permanent deletion of Keychain credentials."
            )
        }

        #if canImport(WebKit)
        DispatchQueue.main.async {
            let dataStore = WKWebsiteDataStore.default()
            let types = WKWebsiteDataStore.allWebsiteDataTypes()
            dataStore.fetchDataRecords(ofTypes: types) { records in
                let universityRecords = records.filter { record in
                    record.displayName.contains("university") ||
                    record.displayName.contains("uzem") ||
                    record.displayName.contains("obs") ||
                    record.displayName.contains("moodle")
                }
                dataStore.removeData(ofTypes: types, for: universityRecords, completionHandler: {})
            }
        }
        #endif
    }
}
