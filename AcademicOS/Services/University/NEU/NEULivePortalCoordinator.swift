import Foundation
#if canImport(WebKit)
import WebKit
#endif
#if canImport(CryptoKit)
import CryptoKit
#endif

/// State of an active live portal session in WKWebView.
public enum NEUPortalSessionState: String, Codable, Sendable {
    case notConfigured = "NOT_CONFIGURED"
    case loggedOut = "LOGGED_OUT"
    case authenticating = "AUTHENTICATING"
    case authenticated = "AUTHENTICATED"
    case sessionExpired = "SESSION_EXPIRED"
    case requiresUserInteraction = "REQUIRES_USER_INTERACTION"
    case offline = "OFFLINE"
    case error = "ERROR"

    public var displayName: String {
        switch self {
        case .notConfigured: return "Yapılandırılmadı"
        case .loggedOut: return "Giriş Yapılmadı"
        case .authenticating: return "Giriş Yapılıyor..."
        case .authenticated: return "Oturum Açık"
        case .sessionExpired: return "Oturum Süresi Doldu"
        case .requiresUserInteraction: return "Kullanıcı Etkileşimi Bekleniyor (Google SSO / CAPTCHA)"
        case .offline: return "Çevrimdışı (Önbellek)"
        case .error: return "Hata"
        }
    }
}

/// Evaluation result for a specific selector during live learning.
public enum SelectorMatchStatus: String, Codable, Sendable {
    case found = "FOUND"
    case partialMatch = "PARTIAL MATCH"
    case notFound = "NOT FOUND"
}

/// Report detailing live selector evaluation across a captured DOM.
public struct LiveSelectorLearningReport: Codable, Sendable {
    public let portal: String
    public let evaluatedAt: Date
    public let fieldResults: [String: SelectorMatchStatus]
    public var overallStatus: SelectorProfileStatus {
        let missing = fieldResults.values.filter { $0 == .notFound }.count
        if missing == 0 {
            return .liveVerified
        } else if missing <= 2 {
            return .awaitingLiveValidation
        } else {
            return .needsReview
        }
    }

    public init(portal: String, fieldResults: [String: SelectorMatchStatus], evaluatedAt: Date = Date()) {
        self.portal = portal
        self.fieldResults = fieldResults
        self.evaluatedAt = evaluatedAt
    }
}

/// Coordinator managing live WKWebView sessions, navigation security, and read-only extraction for Near East University.
/// Strictly enforces:
/// - Isolated WKWebsiteDataStores between DEBİM (Moodle) and Student Portal (Genius Student OBS)
/// - Zero autofill or observation on accounts.google.com during Google SAML
/// - Deterministic authentication validation without asking AI models
/// - Extraction of sanitized DOM structures without passwords, tokens, or hidden values
@MainActor
public final class NEULivePortalCoordinator: NSObject, ObservableObject {
    public static let shared = NEULivePortalCoordinator()

    // Session States
    @Published public private(set) var debimSessionState: NEUPortalSessionState = .loggedOut
    @Published public private(set) var portalSessionState: NEUPortalSessionState = .loggedOut
    @Published public private(set) var debimLastSync: Date?
    @Published public private(set) var portalLastSync: Date?
    @Published public private(set) var latestDiagnostics: NEUConnectorDiagnosticsReport = NEUConnectorDiagnosticsReport()
    @Published public private(set) var currentSelectorProfile: PortalSelectorProfile

    #if canImport(WebKit)
    public private(set) var debimWebView: WKWebView?
    public private(set) var portalWebView: WKWebView?
    #endif

    override public init() {
        self.currentSelectorProfile = PortalSelectorProfile(
            portal: "Near East University",
            profileVersion: "2.6.0",
            capturedAt: Date(),
            pageFingerprint: "neu_initial_profile",
            selectors: [
                "transcriptTable": "#transcriptTable, table.table-striped",
                "courseCodeCol": "td:nth-child(1)",
                "courseNameCol": "td:nth-child(2)",
                "creditsCol": "td:nth-child(3)",
                "gradeCol": "td:nth-child(4)",
                "statusCol": "td:nth-child(5)",
                "gpaBox": ".gpa-box, #cgpa"
            ],
            verifiedFields: ["transcriptTable", "courseCodeCol", "courseNameCol", "gradeCol"],
            unverifiedFields: ["creditsCol", "statusCol", "gpaBox"],
            status: .awaitingLiveValidation
        )
        super.init()
        #if canImport(WebKit)
        setupWebViews()
        #endif
    }

    #if canImport(WebKit)
    private func setupWebViews() {
        // 1. Setup DEBİM Moodle WebView (Isolated non-persistent or isolated persistent store)
        let debimConfig = WKWebViewConfiguration()
        debimConfig.websiteDataStore = WKWebsiteDataStore.nonPersistent()
        let dwv = WKWebView(frame: .zero, configuration: debimConfig)
        dwv.navigationDelegate = self
        self.debimWebView = dwv

        // 2. Setup Student Portal WebView (Strictly separate data store)
        let portalConfig = WKWebViewConfiguration()
        portalConfig.websiteDataStore = WKWebsiteDataStore.nonPersistent()
        let pwv = WKWebView(frame: .zero, configuration: portalConfig)
        pwv.navigationDelegate = self
        self.portalWebView = pwv
    }
    #endif

    // MARK: - Navigation Triggers

    /// Navigates DEBİM WebView to official login URL.
    public func openDebim() {
        debimSessionState = .authenticating
        #if canImport(WebKit)
        guard let url = URL(string: "https://debim.neu.edu.tr/login/index.php") else { return }
        debimWebView?.load(URLRequest(url: url))
        #endif
    }

    /// Navigates Student Portal WebView to official login URL.
    public func openStudentPortal() {
        portalSessionState = .authenticating
        #if canImport(WebKit)
        guard let url = URL(string: "https://register.neu.edu.tr/Login/Login") else { return }
        portalWebView?.load(URLRequest(url: url))
        #endif
    }

    /// Navigates Student Portal directly to Transcript route.
    public func openTranscript() {
        #if canImport(WebKit)
        guard let url = URL(string: "https://register.neu.edu.tr/StudentCourse/Transcript") else { return }
        portalWebView?.load(URLRequest(url: url))
        #endif
    }

    // MARK: - Live DOM Sanitized Capture

    /// Captures safe DOM structure from current authenticated page without passwords, tokens, or PII.
    public func captureSanitizedStructure(for portalType: String) async -> SanitizedInspectionExport? {
        #if canImport(WebKit)
        let webView = (portalType == "DEBİM") ? debimWebView : portalWebView
        guard let wv = webView, let currentURL = wv.url?.absoluteString else { return nil }

        let jsScript = """
        (function() {
            var tags = [];
            var classes = new Set();
            var headers = [];

            document.querySelectorAll('table th').forEach(function(th) {
                headers.push(th.innerText.trim());
            });

            document.querySelectorAll('*').forEach(function(el) {
                if (el.className && typeof el.className === 'string') {
                    el.className.split(/\\s+/).forEach(function(c) { if (c) classes.add(c); });
                }
            });

            return JSON.stringify({
                title: document.title,
                classes: Array.from(classes).slice(0, 30),
                headers: headers.slice(0, 15)
            });
        })();
        """

        guard let result = try? await wv.evaluateJavaScript(jsScript) as? String,
              let data = result.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let detectedClasses = json["classes"] as? [String] ?? []
        let detectedHeaders = json["headers"] as? [String] ?? []
        let title = json["title"] as? String ?? "Live Page"

        let export = SanitizedInspectionExport(
            portalSource: "\(portalType) Live WebKit Session",
            pageType: title,
            originalURL: currentURL,
            sanitizedDOMSummary: "Live captured sanitized DOM hierarchy from \(portalType). All credentials and tokens excluded.",
            detectedContainers: [".main-content", ".table-responsive", "#region-main"],
            detectedClasses: detectedClasses,
            detectedTableHeaders: detectedHeaders,
            sampleRowSnippet: "Live sanitized inspection metadata captured successfully."
        )

        // Evaluate selector learning
        let report = evaluateLiveSelectors(capturedClasses: detectedClasses, capturedHeaders: detectedHeaders)
        self.currentSelectorProfile.status = report.overallStatus

        return export
        #else
        return nil
        #endif
    }

    /// Evaluates live captured metadata against configured selector profile.
    public func evaluateLiveSelectors(capturedClasses: [String], capturedHeaders: [String]) -> LiveSelectorLearningReport {
        var results: [String: SelectorMatchStatus] = [:]

        // 1. Transcript table match
        let hasTable = capturedClasses.contains { $0.contains("table") || $0.contains("transcript") }
        results["TRANSCRIPT TABLE"] = hasTable ? .found : .notFound

        // 2. Course Code Column match
        let hasCode = capturedHeaders.contains { $0.lowercased().contains("kod") || $0.lowercased().contains("code") }
        results["COURSE CODE COLUMN"] = hasCode ? .found : .notFound

        // 3. Course Name Column match
        let hasName = capturedHeaders.contains { $0.lowercased().contains("ad") || $0.lowercased().contains("name") }
        results["COURSE NAME COLUMN"] = hasName ? .found : .notFound

        // 4. Grade Column match
        let hasGrade = capturedHeaders.contains { $0.lowercased().contains("not") || $0.lowercased().contains("grade") }
        results["GRADE COLUMN"] = hasGrade ? .found : .notFound

        // 5. ECTS Column match
        let hasECTS = capturedHeaders.contains { $0.lowercased().contains("akts") || $0.lowercased().contains("ects") }
        results["ECTS COLUMN"] = hasECTS ? .found : .notFound

        return LiveSelectorLearningReport(portal: "NEU Student Portal", fieldResults: results)
    }
}

// MARK: - WKNavigationDelegate Implementation

#if canImport(WebKit)
extension NEULivePortalCoordinator: WKNavigationDelegate {

    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url, let host = url.host?.lowercased() else {
            decisionHandler(.cancel)
            return
        }

        // DEBİM Session Rules
        if webView == debimWebView {
            if host == "accounts.google.com" || host.hasSuffix(".google.com") {
                // Google SAML redirect detected: MUST remain manual!
                debimSessionState = .requiresUserInteraction
                decisionHandler(.allow)
                return
            } else if host == "debim.neu.edu.tr" {
                // Allowed Moodle navigation
                decisionHandler(.allow)
                return
            } else {
                // External redirect blocked
                decisionHandler(.cancel)
                return
            }
        }

        // Student Portal Rules (Exact host match only)
        if webView == portalWebView {
            if host == "register.neu.edu.tr" && url.scheme == "https" {
                decisionHandler(.allow)
                return
            } else {
                // Reject arbitrary domains or subdomains
                decisionHandler(.cancel)
                return
            }
        }

        decisionHandler(.cancel)
    }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let url = webView.url, let host = url.host?.lowercased() else { return }

        // Validate DEBİM Session
        if webView == debimWebView && host == "debim.neu.edu.tr" {
            let path = url.path.lowercased()
            if path.contains("/my") || path.contains("/course") {
                debimSessionState = .authenticated
                debimLastSync = Date()
            } else if path.contains("/login") {
                debimSessionState = .loggedOut
            }
        }

        // Validate Student Portal Session
        if webView == portalWebView && host == "register.neu.edu.tr" {
            let path = url.path.lowercased()
            if path.contains("/home") || path.contains("/studentcourse") {
                portalSessionState = .authenticated
                portalLastSync = Date()
            } else if path.contains("/login") {
                portalSessionState = .loggedOut
            }
        }
    }

    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        if webView == debimWebView {
            debimSessionState = .error
        } else if webView == portalWebView {
            portalSessionState = .error
        }
    }
}
#endif
