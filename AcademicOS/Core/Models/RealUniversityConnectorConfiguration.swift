import Foundation

/// Stored configuration for a student's real university portal / LMS / OBS.
/// All URLs and host white-lists are user-configured; no credentials are hardcoded.
public struct RealUniversityConnectorConfiguration: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public var universityName: String
    public var portalBaseURL: URL
    public var lmsBaseURL: URL?
    public var obsBaseURL: URL?
    public var loginURL: URL
    public var approvedAuthenticationHosts: Set<String>
    public var approvedPortalHosts: Set<String>
    public var approvedDocumentHosts: Set<String>
    public var approvedSSOHosts: Set<String>
    public var portalType: UniversityPortalType
    public var preferredLanguage: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        universityName: String,
        portalBaseURL: URL,
        lmsBaseURL: URL? = nil,
        obsBaseURL: URL? = nil,
        loginURL: URL,
        approvedAuthenticationHosts: Set<String> = [],
        approvedPortalHosts: Set<String> = [],
        approvedDocumentHosts: Set<String> = [],
        approvedSSOHosts: Set<String> = [],
        portalType: UniversityPortalType = .custom,
        preferredLanguage: String = "tr",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.universityName = universityName
        self.portalBaseURL = portalBaseURL
        self.lmsBaseURL = lmsBaseURL
        self.obsBaseURL = obsBaseURL
        self.loginURL = loginURL
        self.approvedAuthenticationHosts = approvedAuthenticationHosts
        self.approvedPortalHosts = approvedPortalHosts
        self.approvedDocumentHosts = approvedDocumentHosts
        self.approvedSSOHosts = approvedSSOHosts
        self.portalType = portalType
        self.preferredLanguage = preferredLanguage
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Verifies if a given host is permitted for document downloads.
    public func isApprovedDocumentHost(_ host: String) -> Bool {
        let clean = host.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return approvedDocumentHosts.contains(clean) || approvedPortalHosts.contains(clean)
    }

    /// Verifies if a given host is permitted for credential injection during manual login.
    public func isApprovedAuthenticationHost(_ host: String) -> Bool {
        let clean = host.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return approvedAuthenticationHosts.contains(clean) || approvedSSOHosts.contains(clean)
    }
}

/// Provenance and tracking metadata for any imported university record.
/// Preserves traceability for change detection and audit trails.
public struct PortalSourceRecord: Codable, Sendable, Equatable {
    public let connectorID: UUID
    public let portalRecordID: String?
    public let sourceURL: URL
    public let retrievedAt: Date
    public let lastVerifiedAt: Date
    public let trustLevel: PortalDataTrustLevel
    public let contentFingerprint: String

    public init(
        connectorID: UUID,
        portalRecordID: String?,
        sourceURL: URL,
        retrievedAt: Date = Date(),
        lastVerifiedAt: Date = Date(),
        trustLevel: PortalDataTrustLevel = .parsedPortal,
        contentFingerprint: String
    ) {
        self.connectorID = connectorID
        self.portalRecordID = portalRecordID
        self.sourceURL = sourceURL
        self.retrievedAt = retrievedAt
        self.lastVerifiedAt = lastVerifiedAt
        self.trustLevel = trustLevel
        self.contentFingerprint = contentFingerprint
    }
}

/// Configurable DOM and CSS selectors for parsing university web pages.
/// Supports a 3-tier fallback strategy:
/// 1. Configured CSS Selector
/// 2. Semantic Text / Table Header Detection
/// 3. Manual Mapping
public struct UniversitySelectorConfiguration: Codable, Sendable, Equatable {
    // Courses
    public var courseListSelector: String?
    public var courseCodeSelector: String?
    public var courseTitleSelector: String?

    // Announcements
    public var announcementListSelector: String?
    public var announcementTitleSelector: String?
    public var announcementDateSelector: String?
    public var announcementBodySelector: String?

    // Exams
    public var examTableSelector: String?
    public var examRowSelector: String?
    public var examDateSelector: String?
    public var examRoomSelector: String?

    // Assignments
    public var assignmentListSelector: String?
    public var assignmentTitleSelector: String?
    public var assignmentDueDateSelector: String?

    // Grades
    public var gradeTableSelector: String?
    public var gradeRowSelector: String?
    public var gradeEvaluationNameSelector: String?
    public var gradeScoreSelector: String?

    // Documents
    public var documentLinkSelector: String?
    public var documentTitleSelector: String?

    // Attendance
    public var attendanceTableSelector: String?

    public init(
        courseListSelector: String? = nil,
        courseCodeSelector: String? = nil,
        courseTitleSelector: String? = nil,
        announcementListSelector: String? = nil,
        announcementTitleSelector: String? = nil,
        announcementDateSelector: String? = nil,
        announcementBodySelector: String? = nil,
        examTableSelector: String? = nil,
        examRowSelector: String? = nil,
        examDateSelector: String? = nil,
        examRoomSelector: String? = nil,
        assignmentListSelector: String? = nil,
        assignmentTitleSelector: String? = nil,
        assignmentDueDateSelector: String? = nil,
        gradeTableSelector: String? = nil,
        gradeRowSelector: String? = nil,
        gradeEvaluationNameSelector: String? = nil,
        gradeScoreSelector: String? = nil,
        documentLinkSelector: String? = nil,
        documentTitleSelector: String? = nil,
        attendanceTableSelector: String? = nil
    ) {
        self.courseListSelector = courseListSelector
        self.courseCodeSelector = courseCodeSelector
        self.courseTitleSelector = courseTitleSelector
        self.announcementListSelector = announcementListSelector
        self.announcementTitleSelector = announcementTitleSelector
        self.announcementDateSelector = announcementDateSelector
        self.announcementBodySelector = announcementBodySelector
        self.examTableSelector = examTableSelector
        self.examRowSelector = examRowSelector
        self.examDateSelector = examDateSelector
        self.examRoomSelector = examRoomSelector
        self.assignmentListSelector = assignmentListSelector
        self.assignmentTitleSelector = assignmentTitleSelector
        self.assignmentDueDateSelector = assignmentDueDateSelector
        self.gradeTableSelector = gradeTableSelector
        self.gradeRowSelector = gradeRowSelector
        self.gradeEvaluationNameSelector = gradeEvaluationNameSelector
        self.gradeScoreSelector = gradeScoreSelector
        self.documentLinkSelector = documentLinkSelector
        self.documentTitleSelector = documentTitleSelector
        self.attendanceTableSelector = attendanceTableSelector
    }

    /// Common Moodle LMS defaults
    public static var moodleDefaults: UniversitySelectorConfiguration {
        UniversitySelectorConfiguration(
            courseListSelector: ".coursebox, .card.dashboard-card",
            courseCodeSelector: ".coursename .code, .coursename",
            courseTitleSelector: ".coursename",
            announcementListSelector: ".forumpost, .announcement-item",
            announcementTitleSelector: ".subject, .entry-title",
            announcementDateSelector: ".date, .entry-date",
            announcementBodySelector: ".post-content, .entry-content",
            examTableSelector: "table.exam-schedule, table.exams",
            assignmentListSelector: ".modtype_assign, .assign-list-item",
            assignmentTitleSelector: ".instancename",
            assignmentDueDateSelector: ".duedate",
            gradeTableSelector: "table.user-grades, table.grades",
            documentLinkSelector: "a.resourceworkaround, .modtype_resource a",
            attendanceTableSelector: "table.attendance-report"
        )
    }

    /// Common OBS (Öğrenci Bilgi Sistemi) defaults
    public static var obsDefaults: UniversitySelectorConfiguration {
        UniversitySelectorConfiguration(
            courseListSelector: "#grdDersListesi tr, table.dersler tr",
            courseCodeSelector: "td.dersKodu, td:nth-child(1)",
            courseTitleSelector: "td.dersAdi, td:nth-child(2)",
            announcementListSelector: ".duyuru-listesi li, table.duyurular tr",
            announcementTitleSelector: ".duyuru-baslik, td.baslik",
            announcementDateSelector: ".duyuru-tarih, td.tarih",
            examTableSelector: "#grdSinavlar, table.sinavlar",
            gradeTableSelector: "#grdNotlar, table.notlar",
            gradeRowSelector: "tr",
            gradeEvaluationNameSelector: "td.sinavTuru, td:nth-child(2)",
            gradeScoreSelector: "td.not, td:nth-child(3)",
            attendanceTableSelector: "#grdDevamsizlik, table.devamsizlik"
        )
    }
}

/// Configurable grade/evaluation aliases mapped to standard academic assessment categories.
public struct AssessmentAliases: Codable, Sendable, Equatable {
    public var midtermAliases: [String]
    public var finalAliases: [String]
    public var resitAliases: [String]
    public var quizAliases: [String]
    public var homeworkAliases: [String]
    public var projectAliases: [String]
    public var letterGradeAliases: [String]

    public init(
        midtermAliases: [String] = ["vize", "ara sınav", "midterm", "1. ara sınav", "2. ara sınav"],
        finalAliases: [String] = ["final", "genel sınav", "dönem sonu sınavı", "end of term"],
        resitAliases: [String] = ["bütünleme", "büt", "telafi", "resit", "makeup"],
        quizAliases: [String] = ["quiz", "kısa sınav", "kısa test"],
        homeworkAliases: [String] = ["ödev", "homework", "assignment", "lab"],
        projectAliases: [String] = ["proje", "term project", "dönem projesi"],
        letterGradeAliases: [String] = ["harf notu", "harf", "letter grade", "başarı notu"]
    ) {
        self.midtermAliases = midtermAliases
        self.finalAliases = finalAliases
        self.resitAliases = resitAliases
        self.quizAliases = quizAliases
        self.homeworkAliases = homeworkAliases
        self.projectAliases = projectAliases
        self.letterGradeAliases = letterGradeAliases
    }

    /// Normalizes a portal evaluation name into standard category.
    public func categorize(evaluationName: String) -> String {
        let lower = evaluationName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if midtermAliases.contains(where: { lower.contains($0) }) { return "Midterm" }
        if resitAliases.contains(where: { lower.contains($0) }) { return "Resit" }
        if finalAliases.contains(where: { lower.contains($0) }) { return "Final" }
        if quizAliases.contains(where: { lower.contains($0) }) { return "Quiz" }
        if homeworkAliases.contains(where: { lower.contains($0) }) { return "Homework" }
        if projectAliases.contains(where: { lower.contains($0) }) { return "Project" }
        return "Evaluation"
    }
}

/// DTO representing an attendance / absence record parsed from university OBS/LMS.
public struct RemoteAttendanceRecord: Codable, Sendable, Equatable {
    public let remoteId: String
    public let courseCode: String
    public let totalHours: Int
    public let absentHours: Int
    public let maxAllowedAbsenceHours: Int
    public let isCritical: Bool
    public let lastRecordedDate: Date?

    public init(
        remoteId: String,
        courseCode: String,
        totalHours: Int,
        absentHours: Int,
        maxAllowedAbsenceHours: Int,
        isCritical: Bool,
        lastRecordedDate: Date? = nil
    ) {
        self.remoteId = remoteId
        self.courseCode = courseCode
        self.totalHours = totalHours
        self.absentHours = absentHours
        self.maxAllowedAbsenceHours = maxAllowedAbsenceHours
        self.isCritical = isCritical
        self.lastRecordedDate = lastRecordedDate
    }

    public var absencePercentage: Double {
        guard totalHours > 0 else { return 0 }
        return (Double(absentHours) / Double(totalHours)) * 100.0
    }
}

/// Derived intelligence from an announcement, separating AI-inferred insights from original raw text.
public struct AnnouncementDerivedMetadata: Codable, Sendable, Equatable {
    public let summary: String
    public let importantDates: [Date]
    public let requiredActions: [String]
    public let affectedCourseCode: String?
    public let mentionsExam: Bool
    public let mentionsAssignment: Bool
    public let mentionsMaterial: Bool

    public init(
        summary: String,
        importantDates: [Date] = [],
        requiredActions: [String] = [],
        affectedCourseCode: String? = nil,
        mentionsExam: Bool = false,
        mentionsAssignment: Bool = false,
        mentionsMaterial: Bool = false
    ) {
        self.summary = summary
        self.importantDates = importantDates
        self.requiredActions = requiredActions
        self.affectedCourseCode = affectedCourseCode
        self.mentionsExam = mentionsExam
        self.mentionsAssignment = mentionsAssignment
        self.mentionsMaterial = mentionsMaterial
    }
}

/// Normalized student profile extracted from the university portal.
public struct StudentPortalIdentity: Codable, Sendable, Equatable {
    public let studentNumber: String?
    public let fullName: String?
    public let faculty: String?
    public let department: String?
    public let semester: String?
    public let advisorName: String?

    public init(
        studentNumber: String? = nil,
        fullName: String? = nil,
        faculty: String? = nil,
        department: String? = nil,
        semester: String? = nil,
        advisorName: String? = nil
    ) {
        self.studentNumber = studentNumber
        self.fullName = fullName
        self.faculty = faculty
        self.department = department
        self.semester = semester
        self.advisorName = advisorName
    }
}
