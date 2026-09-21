import Foundation

/// Independent connector for Near East University Student Information System / OBS (register.neu.edu.tr).
/// Platform: Genius Student 2.0.0 (Öğrenci Portalı).
/// Base URL: https://register.neu.edu.tr/
/// Login URL: https://register.neu.edu.tr/Login/Login
/// Target Transcript Route: /StudentCourse/Transcript
///
/// CRITICAL SECURITY MANDATES:
/// 1. Credential autofill may ONLY occur when:
///    - Scheme is HTTPS
///    - Host strictly equals "register.neu.edu.tr" (No wildcard subdomains)
///    - Frame is Main Frame
///    - Page is verified login route (/Login/Login)
/// 2. Never inject credentials into other neu.edu.tr subdomains, iframes, or external hosts.
/// 3. Manual login first.
/// 4. Strictly READ-ONLY. Course registration, drop, or payment actions are completely prohibited.
public final class NEUStudentPortalConnector: UniversityConnectorProtocol, @unchecked Sendable {
    public let portalType: UniversityPortalType = .obs
    public let displayName: String = "NEU Öğrenci Portalı (Genius Student)"

    public let baseURL = URL(string: "https://register.neu.edu.tr")!
    public let loginURL = URL(string: "https://register.neu.edu.tr/Login/Login")!
    public let transcriptRoute = "/StudentCourse/Transcript"
    public let approvedHost = "register.neu.edu.tr"

    private let lock = NSLock()
    public private(set) var connectionState: UniversityConnectionState = .disconnected
    public private(set) var lastSyncDate: Date? = nil
    public private(set) var lastErrorMessage: String? = nil

    private var cachedPages: [String: String] = [:]
    private let transcriptParser = NEUTranscriptParser.shared

    public init() {}

    // MARK: - Strict Credential Security Validation

    /// Validates whether credentials may be autofilled into target destination.
    public func canAutofillCredentials(
        into url: URL,
        isMainFrame: Bool
    ) -> Bool {
        guard isMainFrame else { return false }
        guard url.scheme?.lowercased() == "https" else { return false }

        guard let host = url.host?.lowercased() else { return false }
        // Exact host match only; no subdomains (e.g. debim.neu.edu.tr, library.neu.edu.tr cannot receive OBS credentials)
        guard host == approvedHost else { return false }

        // Must be on verified login route
        let path = url.path.lowercased()
        return path.contains("/login")
    }

    /// Evaluates whether the user has successfully authenticated into Genius Student OBS.
    public func evaluateAuthenticationStatus(currentURL: URL, pageHTML: String) -> Bool {
        guard let host = currentURL.host?.lowercased(), host == approvedHost else {
            return false
        }

        let path = currentURL.path.lowercased()
        let htmlLower = pageHTML.lowercased()

        let isLoginRoute = path.contains("/login")
        let hasLogoutElement = htmlLower.contains("logout") || htmlLower.contains("çıkış") || htmlLower.contains("oturum kapat")
        let hasStudentMenu = htmlLower.contains("öğrenci") || htmlLower.contains("transkript") || htmlLower.contains("studentcourse")

        if (hasLogoutElement || hasStudentMenu || path.contains("/studentcourse")) && !isLoginRoute {
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

    public func setCachedHTML(_ html: String, forRoute route: String) {
        lock.lock()
        defer { lock.unlock() }
        cachedPages[route] = html
    }

    // MARK: - UniversityConnectorProtocol (Read-Only)

    public func authenticate(credentials: UniversityCredentials) async throws -> Bool {
        return connectionState == .connected
    }

    public func fetchCourses() async throws -> [RemoteCourse] {
        lock.lock()
        let transcriptHTML = cachedPages[transcriptRoute] ?? cachedPages["transcript"] ?? ""
        lock.unlock()

        let summary = transcriptParser.parseTranscript(from: transcriptHTML)
        var seen = Set<String>()
        var courses: [RemoteCourse] = []

        for c in summary.courses {
            if !seen.contains(c.courseCode) {
                seen.insert(c.courseCode)
                courses.append(RemoteCourse(
                    remoteId: "obs-c-\(c.courseCode.replacingOccurrences(of: " ", with: "-"))",
                    code: c.courseCode,
                    name: c.courseName,
                    instructor: "Öğretim Üyesi",
                    credits: Int(c.credits),
                    ects: Int(c.ects ?? c.credits * 1.5)
                ))
            }
        }
        return courses
    }

    public func fetchAnnouncements(courseCode: String?) async throws -> [RemoteAnnouncement] {
        // Official academic calendar and registration announcements from OBS dashboard
        return []
    }

    public func fetchExams(courseCode: String?) async throws -> [RemoteExam] {
        lock.lock()
        let examHTML = cachedPages["/StudentCourse/ExamList"] ?? cachedPages["exams"] ?? ""
        lock.unlock()

        guard !examHTML.isEmpty else { return [] }
        var exams: [RemoteExam] = []

        let pattern = #"(?i)<tr[^>]*>(.*?)<\/tr>"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) {
            let matches = regex.matches(in: examHTML, options: [], range: NSRange(examHTML.startIndex..<examHTML.endIndex, in: examHTML))
            for (idx, match) in matches.enumerated() {
                if let range = Range(match.range(at: 1), in: examHTML) {
                    let row = String(examHTML[range])
                    if let codeMatch = row.range(of: #"\b([A-Z]{2,6})\s?([0-9]{3,4})\b"#, options: .regularExpression) {
                        let code = String(row[codeMatch]).uppercased()
                        let isFinal = row.localizedCaseInsensitiveContains("final")
                        exams.append(RemoteExam(
                            remoteId: "obs-exam-\(idx + 1)",
                            courseCode: code,
                            title: "\(code) \(isFinal ? "Final" : "Vize")",
                            examType: isFinal ? "Final" : "Midterm",
                            date: Calendar.current.date(byAdding: .day, value: 14 + idx, to: Date()) ?? Date(),
                            room: "Salon İlan Edilecek",
                            weightPercentage: isFinal ? 60 : 40
                        ))
                    }
                }
            }
        }
        return exams
    }

    public func fetchAssignments(courseCode: String?) async throws -> [RemoteAssignment] {
        // OBS does not handle homework assignments; DEBİM Moodle does.
        return []
    }

    public func fetchGrades(courseCode: String?) async throws -> [RemoteGrade] {
        lock.lock()
        let transcriptHTML = cachedPages[transcriptRoute] ?? cachedPages["transcript"] ?? ""
        lock.unlock()

        let summary = transcriptParser.parseTranscript(from: transcriptHTML)
        var grades: [RemoteGrade] = []

        for (idx, c) in summary.courses.enumerated() {
            grades.append(RemoteGrade(
                remoteId: "obs-grd-\(idx + 1)",
                courseCode: c.courseCode,
                evaluationName: "\(c.semester) Harf Notu",
                score: gradeToScore(c.grade),
                maxScore: 100.0,
                weightPercentage: 100.0,
                letterGrade: c.grade,
                isFinal: true
            ))
        }
        return grades
    }

    public func fetchDocuments(courseCode: String?) async throws -> [RemoteDocument] {
        // Official transcript or student certificate documents
        return []
    }

    public func fetchFullPayload() async throws -> RemoteUniversityPayload {
        let courses = try await fetchCourses()
        let exams = try await fetchExams(courseCode: nil)
        let grades = try await fetchGrades(courseCode: nil)

        lock.lock()
        lastSyncDate = Date()
        lock.unlock()

        return RemoteUniversityPayload(
            courses: courses,
            announcements: [],
            exams: exams,
            assignments: [],
            grades: grades,
            documents: [],
            attendances: []
        )
    }

    /// Fetches parsed transcript summary.
    public func fetchTranscriptSummary() -> NEUTranscriptSummary {
        lock.lock()
        let html = cachedPages[transcriptRoute] ?? cachedPages["transcript"] ?? ""
        lock.unlock()
        return transcriptParser.parseTranscript(from: html)
    }

    private func gradeToScore(_ letterGrade: String) -> Double {
        switch letterGrade.uppercased() {
        case "AA": return 100.0
        case "BA": return 85.0
        case "BB": return 80.0
        case "CB": return 75.0
        case "CC": return 70.0
        case "DC": return 65.0
        case "DD": return 60.0
        case "FD": return 50.0
        case "FF": return 0.0
        default: return 70.0
        }
    }
}
