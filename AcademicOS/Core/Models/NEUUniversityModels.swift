import Foundation

// MARK: - Data Source Provenance

/// Provenance badges identifying the exact university source of imported academic data.
public enum AcademicDataSourceBadge: String, Codable, Sendable, CaseIterable {
    case debim = "DEBİM"
    case neuStudentPortal = "NEU STUDENT PORTAL"
    case manual = "MANUAL"
    case aiDerived = "AI DERIVED"

    public var displayName: String { rawValue }

    public var systemIcon: String {
        switch self {
        case .debim: return "graduationcap.fill"
        case .neuStudentPortal: return "building.columns.fill"
        case .manual: return "hand.tap.fill"
        case .aiDerived: return "sparkles"
        }
    }
}

// MARK: - Academic Standing & Verification Status

/// Official academic standing status of a transcript course.
/// Crucial safety guarantee: Never assumes pass/fail from letter grades without verified NEU catalog rules.
public enum AcademicStandingStatus: String, Codable, Sendable, CaseIterable {
    case portalReportedPassed = "PORTAL_PASSED"
    case portalReportedFailed = "PORTAL_FAILED"
    case unverified = "UNVERIFIED"
    case inProgress = "IN_PROGRESS"
    case withdrawn = "WITHDRAWN"
    case incomplete = "INCOMPLETE"
    case unknown = "UNKNOWN"

    public var displayName: String {
        switch self {
        case .portalReportedPassed: return "Geçti (Portal)"
        case .portalReportedFailed: return "Kaldı (Portal)"
        case .unverified: return "Doğrulanmamış"
        case .inProgress: return "Devam Ediyor"
        case .withdrawn: return "Çekildi (W)"
        case .incomplete: return "Eksik (I)"
        case .unknown: return "Bilinmiyor"
        }
    }

    public var isOfficiallyConfirmed: Bool {
        return self == .portalReportedPassed || self == .portalReportedFailed
    }
}

// MARK: - Sanitized Portal Evidence

/// Sanitized forensic evidence captured from an authenticated university page.
/// Stored instead of arbitrary raw HTML. All cookies, tokens, and PII are stripped.
public struct SanitizedPortalEvidence: Codable, Sendable, Equatable {
    public let sourceURL: String
    public let safeVisibleTextExcerpt: String
    public let safeTableHeaders: [String]
    public let safeNormalizedFields: [String: String]
    public let retrievedAt: Date
    public let contentFingerprint: String
    public let portalRecordID: String?

    public init(
        sourceURL: String,
        safeVisibleTextExcerpt: String,
        safeTableHeaders: [String] = [],
        safeNormalizedFields: [String: String] = [:],
        retrievedAt: Date = Date(),
        contentFingerprint: String,
        portalRecordID: String? = nil
    ) {
        self.sourceURL = sourceURL
        self.safeVisibleTextExcerpt = safeVisibleTextExcerpt
        self.safeTableHeaders = safeTableHeaders
        self.safeNormalizedFields = safeNormalizedFields
        self.retrievedAt = retrievedAt
        self.contentFingerprint = contentFingerprint
        self.portalRecordID = portalRecordID
    }
}

// MARK: - Selector Versioning & Learning

/// Status of a portal selector profile.
public enum SelectorProfileStatus: String, Codable, Sendable {
    case implemented = "IMPLEMENTED"
    case awaitingLiveValidation = "AWAITING LIVE VALIDATION"
    case liveVerified = "LIVE VERIFIED"
    case needsReview = "SELECTOR PROFILE NEEDS REVIEW"
}

/// Profile managing verified DOM selectors for a university portal.
/// Prevents parsing failures when university updates their web interface.
public struct PortalSelectorProfile: Identifiable, Codable, Sendable, Equatable {
    public var id: String { "\(portal)_\(profileVersion)" }
    public let portal: String
    public let profileVersion: String
    public let capturedAt: Date
    public let pageFingerprint: String
    public var selectors: [String: String]
    public var verifiedFields: [String]
    public var unverifiedFields: [String]
    public var status: SelectorProfileStatus

    public init(
        portal: String,
        profileVersion: String = "1.0.0",
        capturedAt: Date = Date(),
        pageFingerprint: String,
        selectors: [String: String] = [:],
        verifiedFields: [String] = [],
        unverifiedFields: [String] = [],
        status: SelectorProfileStatus = .awaitingLiveValidation
    ) {
        self.portal = portal
        self.profileVersion = profileVersion
        self.capturedAt = capturedAt
        self.pageFingerprint = pageFingerprint
        self.selectors = selectors
        self.verifiedFields = verifiedFields
        self.unverifiedFields = unverifiedFields
        self.status = status
    }
}

// MARK: - Change Tracking & History

/// Categorization of changes detected during university synchronization.
public enum PortalChangeType: String, Codable, Sendable, CaseIterable {
    case gradePublished = "GRADE_PUBLISHED"
    case assignmentAdded = "ASSIGNMENT_ADDED"
    case assignmentDeadlineChanged = "ASSIGNMENT_DEADLINE_CHANGED"
    case materialAdded = "MATERIAL_ADDED"
    case examDateChanged = "EXAM_DATE_CHANGED"
    case announcementUpdated = "ANNOUNCEMENT_UPDATED"
}

/// Durable audit record of a detected portal change.
public struct PortalChangeRecord: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let changeType: PortalChangeType
    public let entityId: String
    public let courseCode: String?
    public let title: String
    public let oldValue: String?
    public let newValue: String
    public let source: AcademicDataSourceBadge
    public let detectedAt: Date

    public init(
        id: UUID = UUID(),
        changeType: PortalChangeType,
        entityId: String,
        courseCode: String? = nil,
        title: String,
        oldValue: String? = nil,
        newValue: String,
        source: AcademicDataSourceBadge,
        detectedAt: Date = Date()
    ) {
        self.id = id
        self.changeType = changeType
        self.entityId = entityId
        self.courseCode = courseCode
        self.title = title
        self.oldValue = oldValue
        self.newValue = newValue
        self.source = source
        self.detectedAt = detectedAt
    }
}

// MARK: - Source Discrepancies

/// Discrepancy detected when DEBİM (Moodle) and Student Portal (OBS) report conflicting data.
public struct SourceConflict: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let entityId: String
    public let entityType: String
    public let fieldName: String
    public let primaryValue: String
    public let primarySource: AcademicDataSourceBadge
    public let conflictingValue: String
    public let conflictingSource: AcademicDataSourceBadge
    public var requiresUserConfirmation: Bool
    public var resolvedValue: String?
    public let detectedAt: Date

    public init(
        id: UUID = UUID(),
        entityId: String,
        entityType: String,
        fieldName: String,
        primaryValue: String,
        primarySource: AcademicDataSourceBadge,
        conflictingValue: String,
        conflictingSource: AcademicDataSourceBadge,
        requiresUserConfirmation: Bool = true,
        resolvedValue: String? = nil,
        detectedAt: Date = Date()
    ) {
        self.id = id
        self.entityId = entityId
        self.entityType = entityType
        self.fieldName = fieldName
        self.primaryValue = primaryValue
        self.primarySource = primarySource
        self.conflictingValue = conflictingValue
        self.conflictingSource = conflictingSource
        self.requiresUserConfirmation = requiresUserConfirmation
        self.resolvedValue = resolvedValue
        self.detectedAt = detectedAt
    }
}

// MARK: - Transcript Models

/// DTO representing a course entry from the Near East University transcript (/StudentCourse/Transcript).
public struct NEUTranscriptCourse: Identifiable, Codable, Sendable, Equatable {
    public var id: String { "\(academicYear)_\(semester)_\(courseCode)" }
    public let academicYear: String
    public let semester: String
    public let courseCode: String
    public let courseName: String
    public let grade: String
    public let credits: Double
    public let ects: Double?
    public let status: String?
    public let academicStanding: AcademicStandingStatus
    public let evidence: SanitizedPortalEvidence
    public let retrievedAt: Date

    /// Computed property ensuring backwards-compatibility while honoring official standing.
    public var isPassed: Bool {
        return academicStanding == .portalReportedPassed
    }

    /// Explicitly nil if pass/fail status is unverified.
    public var isOfficiallyPassed: Bool? {
        switch academicStanding {
        case .portalReportedPassed: return true
        case .portalReportedFailed: return false
        default: return nil
        }
    }

    public init(
        academicYear: String,
        semester: String,
        courseCode: String,
        courseName: String,
        grade: String,
        credits: Double,
        ects: Double? = nil,
        status: String? = nil,
        academicStanding: AcademicStandingStatus = .unverified,
        evidence: SanitizedPortalEvidence,
        retrievedAt: Date = Date()
    ) {
        self.academicYear = academicYear
        self.semester = semester
        self.courseCode = courseCode
        self.courseName = courseName
        self.grade = grade
        self.credits = credits
        self.ects = ects
        self.status = status
        self.academicStanding = academicStanding
        self.evidence = evidence
        self.retrievedAt = retrievedAt
    }
}

/// Aggregated summary of an imported Near East University transcript.
public struct NEUTranscriptSummary: Codable, Sendable, Equatable {
    public let totalSemesters: Int
    public let totalCourses: Int
    public let passedCount: Int
    public let failedCount: Int
    public let unconfirmedCount: Int
    public let portalReportedGPA: Double?
    public let gpaMappingStatus: String
    public let isVerified: Bool
    public let courses: [NEUTranscriptCourse]
    public let parsedAt: Date

    public init(
        totalSemesters: Int,
        totalCourses: Int,
        passedCount: Int,
        failedCount: Int,
        unconfirmedCount: Int = 0,
        portalReportedGPA: Double? = nil,
        gpaMappingStatus: String = "PORTAL IMPORT — UNVERIFIED GPA MAPPING",
        isVerified: Bool = false,
        courses: [NEUTranscriptCourse] = [],
        parsedAt: Date = Date()
    ) {
        self.totalSemesters = totalSemesters
        self.totalCourses = totalCourses
        self.passedCount = passedCount
        self.failedCount = failedCount
        self.unconfirmedCount = unconfirmedCount
        self.portalReportedGPA = portalReportedGPA
        self.gpaMappingStatus = gpaMappingStatus
        self.isVerified = isVerified
        self.courses = courses
        self.parsedAt = parsedAt
    }
}

// MARK: - Connector Diagnostics

/// Diagnostic item evaluation result.
public enum DiagnosticsEvaluationResult: String, Codable, Sendable {
    case pass = "PASS"
    case fail = "FAIL"
    case pending = "PENDING"
}

/// Diagnostic health report for Near East University connector subsystems.
public struct NEUConnectorDiagnosticsReport: Codable, Sendable {
    public let debimLogin: DiagnosticsEvaluationResult
    public let debimDashboard: DiagnosticsEvaluationResult
    public let debimCourses: DiagnosticsEvaluationResult
    public let debimMaterials: DiagnosticsEvaluationResult
    public let debimAssignments: DiagnosticsEvaluationResult
    public let debimAnnouncements: DiagnosticsEvaluationResult

    public let portalLogin: DiagnosticsEvaluationResult
    public let portalNavigation: DiagnosticsEvaluationResult
    public let portalTranscript: DiagnosticsEvaluationResult
    public let portalGrades: DiagnosticsEvaluationResult
    public let portalExamData: DiagnosticsEvaluationResult

    public let evaluatedAt: Date
    public let selectorProfileVersion: String

    public init(
        debimLogin: DiagnosticsEvaluationResult = .pending,
        debimDashboard: DiagnosticsEvaluationResult = .pending,
        debimCourses: DiagnosticsEvaluationResult = .pending,
        debimMaterials: DiagnosticsEvaluationResult = .pending,
        debimAssignments: DiagnosticsEvaluationResult = .pending,
        debimAnnouncements: DiagnosticsEvaluationResult = .pending,
        portalLogin: DiagnosticsEvaluationResult = .pending,
        portalNavigation: DiagnosticsEvaluationResult = .pending,
        portalTranscript: DiagnosticsEvaluationResult = .pending,
        portalGrades: DiagnosticsEvaluationResult = .pending,
        portalExamData: DiagnosticsEvaluationResult = .pending,
        evaluatedAt: Date = Date(),
        selectorProfileVersion: String = "1.0.0"
    ) {
        self.debimLogin = debimLogin
        self.debimDashboard = debimDashboard
        self.debimCourses = debimCourses
        self.debimMaterials = debimMaterials
        self.debimAssignments = debimAssignments
        self.debimAnnouncements = debimAnnouncements
        self.portalLogin = portalLogin
        self.portalNavigation = portalNavigation
        self.portalTranscript = portalTranscript
        self.portalGrades = portalGrades
        self.portalExamData = portalExamData
        self.evaluatedAt = evaluatedAt
        self.selectorProfileVersion = selectorProfileVersion
    }
}
