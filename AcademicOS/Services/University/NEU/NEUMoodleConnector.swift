import Foundation

/// Independent connector for Near East University Distance Education / LMS (DEBİM Moodle).
/// Base URL: https://debim.neu.edu.tr/
/// Login URL: https://debim.neu.edu.tr/login/index.php
/// Authentication: Manual Google SAML (accounts.google.com).
///
/// CRITICAL SECURITY MANDATES:
/// 1. NEVER autofill or inject credentials into accounts.google.com.
/// 2. Google SSO authentication is 100% manual in a secure WKWebView.
/// 3. Never inspect or capture Google passwords, session tokens, SAML payload contents, Google cookies, or MFA data.
/// 4. Detection of authentication success occurs ONLY after redirect back to debim.neu.edu.tr using deterministic signals (no AI).
/// Types of pages identified during DEBİM navigation
public enum NEUMoodlePageType: String, Sendable {
    case loginPage
    case googleSAMLRedirect
    case courseList
    case other
}

public final class NEUMoodleConnector: UniversityConnectorProtocol, @unchecked Sendable {
    public let portalType: UniversityPortalType = .moodle
    public let displayName: String = "NEU DEBİM (Moodle LMS)"

    public let baseURL = URL(string: "https://debim.neu.edu.tr")!
    public let loginURL = URL(string: "https://debim.neu.edu.tr/login/index.php")!
    public let approvedPortalHost = "debim.neu.edu.tr"
    public let approvedSSOHost = "accounts.google.com"

    private let lock = NSLock()
    public private(set) var connectionState: UniversityConnectionState = .disconnected
    public private(set) var lastSyncDate: Date? = nil
    public private(set) var lastErrorMessage: String? = nil

    private var cachedPages: [String: String] = [:]

    public init() {}

    // MARK: - Google SAML Authentication Policy

    /// Validates whether a given host is permitted during DEBİM navigation.
    public func isPermittedNavigationHost(_ host: String) -> Bool {
        let clean = host.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return clean == approvedPortalHost || clean == approvedSSOHost
    }

    /// Strictly determines whether credentials or autofill can be injected.
    /// GUARANTEE: accounts.google.com can NEVER receive automated credential injection.
    public func canAutofillCredentials(into host: String) -> Bool {
        // Explicitly forbidden on accounts.google.com and any third-party SSO host
        return false
    }

    public func canAutofillCredentials(on url: URL) -> Bool {
        guard let host = url.host else { return false }
        return canAutofillCredentials(into: host)
    }

    public func identifyPageType(url: URL) -> NEUMoodlePageType {
        let host = url.host?.lowercased() ?? ""
        let path = url.path.lowercased()
        if host == approvedSSOHost || url.absoluteString.contains("accounts.google.com") {
            return .googleSAMLRedirect
        }
        if path.contains("/login") || url.absoluteString.contains("login/index.php") {
            return .loginPage
        }
        if path.contains("/my") || path.contains("/course") {
            return .courseList
        }
        return .other
    }

    /// Evaluates whether the user has successfully authenticated into Moodle using deterministic signals.
    /// Does NOT use AI.
    public func evaluateAuthenticationStatus(currentURL: URL, pageHTML: String) -> Bool {
        guard let host = currentURL.host?.lowercased(), host == approvedPortalHost else {
            return false
        }

        let path = currentURL.path.lowercased()
        let htmlLower = pageHTML.lowercased()

        // 1. URL Signal: Redirected to authenticated home / dashboard / my courses
        let isAuthenticatedPath = path.contains("/my") || path.contains("/course/view.php") || path.contains("/user/profile.php")

        // 2. DOM Signal: Presence of logout link or user menu
        let hasLogoutElement = htmlLower.contains("login/logout.php") || htmlLower.contains("çıkış") || htmlLower.contains("log out")
        let hasUserMenu = htmlLower.contains("usermenu") || htmlLower.contains("user-menu") || htmlLower.contains("logininfo")

        let isLoginRoute = path.contains("/login") || currentURL.absoluteString.contains("login/index.php")

        if (isAuthenticatedPath || hasLogoutElement || hasUserMenu) && !isLoginRoute {
            lock.lock()
            connectionState = .connected
            lock.unlock()
            return true
        }

        lock.lock()
        connectionState = .authExpired
        lock.unlock()
        return false
    }

    // MARK: - Ingestion for Parsing

    public func setCachedHTML(_ html: String, forSection section: String) {
        lock.lock()
        defer { lock.unlock() }
        cachedPages[section] = html
    }

    // MARK: - UniversityConnectorProtocol (Read-Only)

    public func authenticate(credentials: UniversityCredentials) async throws -> Bool {
        // Manual Google SAML first: Automated credential submission prohibited.
        return connectionState == .connected
    }

    public func fetchCourses() async throws -> [RemoteCourse] {
        lock.lock()
        let html = cachedPages["courses"] ?? cachedPages["dashboard"] ?? ""
        lock.unlock()

        var courses: [RemoteCourse] = []
        guard !html.isEmpty else { return [] }

        // Moodle coursebox and card pattern
        let pattern = #"(?i)<(?:div|h3)[^>]*class=["'][^"']*(?:coursename|coursebox|dashboard-card)[^"']*["'][^>]*>(.*?)<\/(?:div|h3)>"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) {
            let matches = regex.matches(in: html, options: [], range: NSRange(html.startIndex..<html.endIndex, in: html))
            var seen = Set<String>()

            for (idx, match) in matches.enumerated() {
                if let range = Range(match.range(at: 1), in: html) {
                    let block = String(html[range]).replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
                        .trimmingCharacters(in: .whitespacesAndNewlines)

                    let codeMatch = extractCourseCode(from: block) ?? "DERS-\(idx + 1)"
                    if !seen.contains(codeMatch) {
                        seen.insert(codeMatch)
                        courses.append(RemoteCourse(
                            remoteId: "debim-c-\(idx + 1)",
                            code: codeMatch,
                            name: block,
                            instructor: "Öğretim Üyesi",
                            credits: 3,
                            ects: 5
                        ))
                    }
                }
            }
        }
        return courses
    }

    public func fetchAnnouncements(courseCode: String?) async throws -> [RemoteAnnouncement] {
        lock.lock()
        let html = cachedPages["announcements"] ?? cachedPages["dashboard"] ?? ""
        lock.unlock()

        var announcements: [RemoteAnnouncement] = []
        guard !html.isEmpty else { return [] }

        let pattern = #"(?i)<(?:div|article)[^>]*class=["'][^"']*(?:forumpost|announcement)[^"']*["'][^>]*>(.*?)<\/(?:div|article)>"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) {
            let matches = regex.matches(in: html, options: [], range: NSRange(html.startIndex..<html.endIndex, in: html))
            for (idx, match) in matches.prefix(15).enumerated() {
                if let range = Range(match.range(at: 1), in: html) {
                    let text = String(html[range]).replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    let title = String(text.prefix(70))
                    announcements.append(RemoteAnnouncement(
                        remoteId: "debim-a-\(idx + 1)",
                        courseCode: extractCourseCode(from: text),
                        title: title.isEmpty ? "DEBİM Duyurusu" : title,
                        body: text,
                        author: "DEBİM LMS",
                        isUrgent: text.lowercased().contains("acil") || text.lowercased().contains("important"),
                        date: Date()
                    ))
                }
            }
        }
        return announcements
    }

    public func fetchExams(courseCode: String?) async throws -> [RemoteExam] {
        // Exams in Moodle are typically posted via announcements or calendar events
        return []
    }

    public func fetchAssignments(courseCode: String?) async throws -> [RemoteAssignment] {
        lock.lock()
        let html = cachedPages["assignments"] ?? cachedPages["dashboard"] ?? ""
        lock.unlock()

        var assignments: [RemoteAssignment] = []
        guard !html.isEmpty else { return [] }

        let pattern = #"(?i)<tr[^>]*class=["'][^"']*(?:assign|modtype_assign)[^"']*["'][^>]*>(.*?)<\/tr>"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) {
            let matches = regex.matches(in: html, options: [], range: NSRange(html.startIndex..<html.endIndex, in: html))
            for (idx, match) in matches.enumerated() {
                if let range = Range(match.range(at: 1), in: html) {
                    let text = String(html[range]).replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    assignments.append(RemoteAssignment(
                        remoteId: "debim-asg-\(idx + 1)",
                        courseCode: extractCourseCode(from: text) ?? "CENG",
                        title: String(text.prefix(60)),
                        description: "DEBİM Moodle üzerinden verilen ödev.",
                        dueDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date(),
                        maxScore: 100,
                        submissionURL: nil // READ-ONLY: Never submit
                    ))
                }
            }
        }
        return assignments
    }

    public func fetchGrades(courseCode: String?) async throws -> [RemoteGrade] {
        // Moodle assignment / quiz feedback grades
        return []
    }

    public func fetchDocuments(courseCode: String?) async throws -> [RemoteDocument] {
        lock.lock()
        let html = cachedPages["materials"] ?? cachedPages["course"] ?? ""
        lock.unlock()

        var documents: [RemoteDocument] = []
        guard !html.isEmpty else { return [] }

        let pattern = #"(?i)<a\s+[^>]*href=["']([^"']*(?:mod\/resource|pluginfile\.php)[^"']*)["'][^>]*>(.*?)<\/a>"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let matches = regex.matches(in: html, options: [], range: NSRange(html.startIndex..<html.endIndex, in: html))
            for (idx, match) in matches.enumerated() {
                if let hrefRange = Range(match.range(at: 1), in: html),
                   let titleRange = Range(match.range(at: 2), in: html) {
                    let href = String(html[hrefRange])
                    let title = String(html[titleRange]).replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)

                    let fullURL = URL(string: href, relativeTo: baseURL) ?? baseURL
                    documents.append(RemoteDocument(
                        remoteId: "debim-doc-\(idx + 1)",
                        courseCode: extractCourseCode(from: title) ?? "DEBİM",
                        fileName: title.isEmpty ? "Ders Materyali \(idx + 1)" : title,
                        fileExtension: "pdf",
                        downloadURL: fullURL,
                        docType: "LectureSlides"
                    ))
                }
            }
        }
        return documents
    }

    public func fetchFullPayload() async throws -> RemoteUniversityPayload {
        let courses = try await fetchCourses()
        let announcements = try await fetchAnnouncements(courseCode: nil)
        let assignments = try await fetchAssignments(courseCode: nil)
        let documents = try await fetchDocuments(courseCode: nil)

        lock.lock()
        lastSyncDate = Date()
        lock.unlock()

        return RemoteUniversityPayload(
            courses: courses,
            announcements: announcements,
            exams: [],
            assignments: assignments,
            grades: [],
            documents: documents,
            attendances: []
        )
    }

    private func extractCourseCode(from text: String) -> String? {
        let pattern = #"\b([A-Z]{2,6})\s?[-_]?\s?([0-9]{3,4})\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        if let match = regex.firstMatch(in: text, options: [], range: range),
           let matchRange = Range(match.range, in: text) {
            return String(text[matchRange]).uppercased()
        }
        return nil
    }
}
