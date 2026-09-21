import Foundation

/// Classification of destination hosts during web navigation and API requests.
public enum HostSecurityClassification: String, Sendable {
    case approvedPortalHost
    case approvedSSOHost
    case approvedDocumentHost
    case externalSafeHost
    case blockedHost
}

/// Enforces general web navigation, browsing, and document download domain rules.
public final class NavigationDomainPolicy: @unchecked Sendable {
    public static let shared = NavigationDomainPolicy()

    private let lock = NSLock()
    private var customSafeDomains: Set<String> = []
    private var approvedSSOHosts: Set<String> = []
    private var approvedDocumentHosts: Set<String> = []

    private let defaultEducationalSuffixes: [String] = [
        ".edu.tr",
        ".edu",
        ".ac.uk",
        "university.edu.tr",
        "localhost",
        "127.0.0.1"
    ]

    public init(customSafeDomains: [String] = []) {
        self.customSafeDomains = Set(customSafeDomains.map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) })
    }

    public func authorizeSafeDomain(_ domain: String) {
        lock.lock()
        defer { lock.unlock() }
        let clean = domain.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if !clean.isEmpty {
            customSafeDomains.insert(clean)
        }
    }

    public func authorizeSSOHost(_ host: String) {
        lock.lock()
        defer { lock.unlock() }
        let clean = host.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if !clean.isEmpty {
            approvedSSOHosts.insert(clean)
        }
    }

    public func authorizeDocumentHost(_ host: String) {
        lock.lock()
        defer { lock.unlock() }
        let clean = host.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if !clean.isEmpty {
            approvedDocumentHosts.insert(clean)
        }
    }

    /// Classifies destination host for navigation and document downloads.
    public func classifyHost(url: URL) -> HostSecurityClassification {
        guard let host = url.host?.lowercased() else {
            return .blockedHost
        }

        // HTTPS enforcement (localhost allowed for Developer Demo)
        if url.scheme != "https" && host != "localhost" && host != "127.0.0.1" {
            return .blockedHost
        }

        lock.lock()
        defer { lock.unlock() }

        if approvedSSOHosts.contains(host) {
            return .approvedSSOHost
        }

        if approvedDocumentHosts.contains(host) {
            return .approvedDocumentHost
        }

        // Check custom domains
        for custom in customSafeDomains {
            if host == custom || host.hasSuffix("." + custom) {
                return .externalSafeHost
            }
        }

        // Check educational suffixes
        for suffix in defaultEducationalSuffixes {
            if host == suffix || host.hasSuffix(suffix) {
                return .externalSafeHost
            }
        }

        return .blockedHost
    }

    public func isAllowedForNavigation(url: URL) -> Bool {
        let classification = classifyHost(url: url)
        return classification != .blockedHost
    }
}

/// Strict policy governing where student credentials and authentication tokens may be injected.
/// Explicitly forbids broad wildcard matching (e.g. *.edu.tr). Requires EXACT host matches.
public final class CredentialDomainPolicy: @unchecked Sendable {
    public static let shared = CredentialDomainPolicy()

    private let lock = NSLock()
    private var approvedAuthenticationHosts: Set<String> = []
    private var approvedSSOHosts: Set<String> = []

    public init(initialHosts: [String] = []) {
        self.approvedAuthenticationHosts = Set(initialHosts.map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) })
    }

    /// Authorizes an EXACT host for credential autofill.
    /// Subdomains do NOT automatically inherit permission.
    public func registerApprovedAuthenticationHost(_ host: String) {
        lock.lock()
        defer { lock.unlock() }
        let clean = host.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if !clean.isEmpty {
            approvedAuthenticationHosts.insert(clean)
        }
    }

    /// Authorizes an explicit third-party SSO host (e.g. keycloak.university.edu.tr).
    public func registerApprovedSSOHost(_ host: String) {
        lock.lock()
        defer { lock.unlock() }
        let clean = host.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if !clean.isEmpty {
            approvedSSOHosts.insert(clean)
        }
    }

    /// Removes an authentication host.
    public func revokeAuthenticationHost(_ host: String) {
        lock.lock()
        defer { lock.unlock() }
        let clean = host.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        approvedAuthenticationHosts.remove(clean)
        approvedSSOHosts.remove(clean)
    }

    /// Strictly determines whether credentials may be sent or injected into the target URL.
    /// Requirements:
    /// 1. HTTPS scheme mandatory (localhost exempt only for local development).
    /// 2. Exact host match required; wildcard/parent domain matching is strictly forbidden.
    /// 3. Rejects frames that are not the approved main frame.
    public func canInjectCredentials(
        into url: URL,
        isMainFrame: Bool
    ) -> Bool {
        // Enforce main frame only
        guard isMainFrame else {
            return false
        }

        guard let host = url.host?.lowercased() else {
            return false
        }

        // HTTPS enforcement
        if url.scheme != "https" && host != "localhost" && host != "127.0.0.1" {
            return false
        }

        lock.lock()
        defer { lock.unlock() }

        // Must match an EXACT configured host (no broad *.edu.tr matching)
        if approvedAuthenticationHosts.contains(host) {
            return true
        }

        if approvedSSOHosts.contains(host) {
            return true
        }

        return false
    }
}

/// Backwards-compatible facade protocol combining both policies.
public protocol DomainPolicyServiceProtocol: Sendable {
    var navigationPolicy: NavigationDomainPolicy { get }
    var credentialPolicy: CredentialDomainPolicy { get }
    func isAuthorized(url: URL) -> Bool
}

public final class DomainPolicyService: DomainPolicyServiceProtocol, @unchecked Sendable {
    public static let shared = DomainPolicyService()

    public let navigationPolicy: NavigationDomainPolicy
    public let credentialPolicy: CredentialDomainPolicy

    public init(
        navigationPolicy: NavigationDomainPolicy = NavigationDomainPolicy.shared,
        credentialPolicy: CredentialDomainPolicy = CredentialDomainPolicy.shared
    ) {
        self.navigationPolicy = navigationPolicy
        self.credentialPolicy = credentialPolicy

        // Register default exact demo hosts
        credentialPolicy.registerApprovedAuthenticationHost("uzem.university.edu.tr")
        credentialPolicy.registerApprovedAuthenticationHost("obs.university.edu.tr")
        credentialPolicy.registerApprovedAuthenticationHost("localhost")
    }

    public func isAuthorized(url: URL) -> Bool {
        return navigationPolicy.isAllowedForNavigation(url: url)
    }
}
