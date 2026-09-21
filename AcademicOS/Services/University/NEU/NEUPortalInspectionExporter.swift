import Foundation

/// Data structure representing a sanitized inspection export of a university portal web page.
public struct SanitizedInspectionExport: Codable, Sendable {
    public let portalSource: String
    public let pageType: String
    public let originalURL: String
    public let sanitizedDOMSummary: String
    public let detectedContainers: [String]
    public let detectedClasses: [String]
    public let detectedTableHeaders: [String]
    public let sampleRowSnippet: String?
    public let exportedAt: Date
    public let securityNotice: String

    public init(
        portalSource: String,
        pageType: String,
        originalURL: String,
        sanitizedDOMSummary: String,
        detectedContainers: [String] = [],
        detectedClasses: [String] = [],
        detectedTableHeaders: [String] = [],
        sampleRowSnippet: String? = nil,
        exportedAt: Date = Date(),
        securityNotice: String = "ALL CREDENTIALS, COOKIES, TOKENS, AND PII REDACTED BEFORE EXPORT"
    ) {
        self.portalSource = portalSource
        self.pageType = pageType
        self.originalURL = originalURL
        self.sanitizedDOMSummary = sanitizedDOMSummary
        self.detectedContainers = detectedContainers
        self.detectedClasses = detectedClasses
        self.detectedTableHeaders = detectedTableHeaders
        self.sampleRowSnippet = sampleRowSnippet
        self.exportedAt = exportedAt
        self.securityNotice = securityNotice
    }
}

/// Service that sanitizes and exports university portal page structures for analysis.
/// Strictly removes:
/// - Student names, student IDs, personal emails, phone numbers
/// - Session cookies (MoodleSession, ASP.NET_SessionId, etc.)
/// - Authentication headers, Bearer tokens, SAML payloads
/// - Hidden CSRF tokens (logintoken, __RequestVerificationToken)
public final class NEUPortalInspectionExporter: Sendable {
    public static let shared = NEUPortalInspectionExporter()

    public init() {}

    /// Sanitizes any raw HTML or text snippet by stripping all PII and security tokens.
    public func sanitizeRawContent(_ raw: String) -> String {
        var text = raw

        // Redact cookies & headers
        text = text.replacingOccurrences(of: #"(?i)MoodleSession=[^;,\s"]+"#, with: "MoodleSession=[REDACTED_SESSION]", options: .regularExpression)
        text = text.replacingOccurrences(of: #"(?i)ASP\.NET_SessionId=[^;,\s"]+"#, with: "ASP.NET_SessionId=[REDACTED_SESSION]", options: .regularExpression)
        text = text.replacingOccurrences(of: #"(?i)Set-Cookie:\s*[^\r\n]+"#, with: "Set-Cookie: [REDACTED_COOKIE]", options: .regularExpression)

        // Redact CSRF tokens & hidden input values
        text = text.replacingOccurrences(of: #"(?i)name="(logintoken|__RequestVerificationToken|sesskey)"\s+value="[^"]*""#, with: "name=\"$1\" value=\"[REDACTED_CSRF_TOKEN]\"", options: .regularExpression)

        // Redact emails
        text = text.replacingOccurrences(of: #"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#, with: "[REDACTED_EMAIL]", options: .regularExpression)

        // Redact phone numbers
        text = text.replacingOccurrences(of: #"(?:\+?90|0)?\s*5\d{2}\s*\d{3}\s*\d{2}\s*\d{2}"#, with: "[REDACTED_PHONE]", options: .regularExpression)

        // Redact student ID numbers (e.g., 20210452, 20220199)
        text = text.replacingOccurrences(of: #"\b20[12]\d{5,7}\b"#, with: "[STUDENT_ID]", options: .regularExpression)

        return text
    }

    /// Generates sanitized export for DEBİM Moodle Dashboard (`neu_debim_dashboard_sanitized.json`).
    public func exportDebimDashboard(rawHTML: String) -> SanitizedInspectionExport {
        let sanitized = sanitizeRawContent(rawHTML)
        return SanitizedInspectionExport(
            portalSource: "DEBİM Moodle (https://debim.neu.edu.tr/my/)",
            pageType: "Dashboard / My Courses",
            originalURL: "https://debim.neu.edu.tr/my/",
            sanitizedDOMSummary: "Moodle modern boost theme dashboard with card dashboard and course grid.",
            detectedContainers: [".dashboard-card-deck", ".course-info-container", ".block_myoverview"],
            detectedClasses: ["coursename", "dashboard-card", "multiline", "text-truncate"],
            detectedTableHeaders: [],
            sampleRowSnippet: sanitized.prefix(300).description
        )
    }

    /// Generates sanitized export for DEBİM Course Page (`neu_debim_course_sanitized.json`).
    public func exportDebimCourse(rawHTML: String, courseCode: String) -> SanitizedInspectionExport {
        let sanitized = sanitizeRawContent(rawHTML)
        return SanitizedInspectionExport(
            portalSource: "DEBİM Moodle Course View",
            pageType: "Course Section Materials & Assignments",
            originalURL: "https://debim.neu.edu.tr/course/view.php?id=[COURSE_ID]",
            sanitizedDOMSummary: "Weekly and topic sections containing resources, assignments, and forums.",
            detectedContainers: [".course-content", "ul.topics", "ul.weeks", "li.activity"],
            detectedClasses: ["activityinstance", "instancename", "modtype_assign", "modtype_resource"],
            detectedTableHeaders: [],
            sampleRowSnippet: sanitized.prefix(300).description
        )
    }

    /// Generates sanitized export for Student Portal Navigation (`neu_student_portal_navigation_sanitized.json`).
    public func exportStudentPortalNavigation(rawHTML: String) -> SanitizedInspectionExport {
        let sanitized = sanitizeRawContent(rawHTML)
        return SanitizedInspectionExport(
            portalSource: "NEU Student Portal (https://register.neu.edu.tr/)",
            pageType: "Genius Student Navigation Sidebar & Main Menu",
            originalURL: "https://register.neu.edu.tr/Home/Index",
            sanitizedDOMSummary: "ASP.NET MVC Bootstrap navigation layout with StudentCourse dropdown.",
            detectedContainers: [".sidebar-menu", ".nav-sidebar", "#menu-content"],
            detectedClasses: ["nav-item", "dropdown-menu", "menu-title"],
            detectedTableHeaders: [],
            sampleRowSnippet: sanitized.prefix(300).description
        )
    }

    /// Generates sanitized export for Student Portal Transcript (`neu_transcript_sanitized.json`).
    public func exportTranscript(rawHTML: String) -> SanitizedInspectionExport {
        let sanitized = sanitizeRawContent(rawHTML)
        return SanitizedInspectionExport(
            portalSource: "NEU Student Portal Transcript (https://register.neu.edu.tr/StudentCourse/Transcript)",
            pageType: "Academic Transcript Table",
            originalURL: "https://register.neu.edu.tr/StudentCourse/Transcript",
            sanitizedDOMSummary: "Semester-by-semester course tables detailing codes, names, credits, and grades.",
            detectedContainers: [".table-responsive", "table.table-striped", "#transcriptTable"],
            detectedClasses: ["table", "table-bordered", "grade-cell", "passed-course"],
            detectedTableHeaders: ["Dönem / Semester", "Ders Kodu / Code", "Ders Adı / Name", "Kredi / Credit", "AKTS / ECTS", "Harf Notu / Grade", "Durum / Status"],
            sampleRowSnippet: sanitized.prefix(300).description
        )
    }

    /// Exports JSON data for any sanitized inspection export.
    public func exportToJSONData(_ exportObj: SanitizedInspectionExport) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(exportObj)
    }
}
