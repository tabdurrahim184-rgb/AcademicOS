import Foundation

// MARK: - Portal Configuration

/// Supported University Portal / LMS types.
public enum UniversityPortalType: String, Codable, Sendable, CaseIterable {
    case demo = "Demo Portal"
    case moodle = "Moodle LMS"
    case canvas = "Canvas LMS"
    case obs = "Student Information System (OBS)"
    case custom = "Custom University Portal"
}

/// Active connection and sync state of the university portal.
public enum UniversityConnectionState: String, Codable, Sendable {
    case disconnected = "Disconnected"
    case connecting = "Connecting..."
    case connected = "Connected"
    case syncInProgress = "Syncing..."
    case authExpired = "Session Expired"
    case offlineCached = "Offline (Cached)"
    case error = "Sync Error"
}

/// Stored configuration for a university portal connection.
public struct UniversityPortalConfig: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public var portalType: UniversityPortalType
    public var name: String
    public var baseURL: String
    public var isActive: Bool
    public var lastSyncAt: Date?
    public var syncIntervalMinutes: Int
    public var authMethod: String

    public init(
        id: UUID = UUID(),
        portalType: UniversityPortalType = .demo,
        name: String = "University Portal",
        baseURL: String = "https://uzem.university.edu.tr",
        isActive: Bool = true,
        lastSyncAt: Date? = nil,
        syncIntervalMinutes: Int = 60,
        authMethod: String = "SessionCookie"
    ) {
        self.id = id
        self.portalType = portalType
        self.name = name
        self.baseURL = baseURL
        self.isActive = isActive
        self.lastSyncAt = lastSyncAt
        self.syncIntervalMinutes = syncIntervalMinutes
        self.authMethod = authMethod
    }
}

// MARK: - Inbox & Announcements

/// Category of an item received from the university portal.
public enum UniversityInboxCategory: String, Codable, Sendable, CaseIterable {
    case announcement = "Announcement"
    case grade = "Grade Released"
    case exam = "Exam Scheduled"
    case assignment = "Assignment Due"
    case administrative = "Administrative"
    case urgent = "Urgent Notice"
}

/// Urgency level evaluated for the inbox item.
public enum UniversityUrgencyLevel: String, Codable, Sendable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case critical = "Critical"
}

/// Unified inbox entity representing university notices, grades, and deadlines.
public struct UniversityInboxItem: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let portalId: UUID
    public let courseId: UUID?
    public let courseCode: String?
    public let title: String
    public let content: String
    public let sender: String
    public let category: UniversityInboxCategory
    public let urgency: UniversityUrgencyLevel
    public let trustLevel: PortalDataTrustLevel
    public var isRead: Bool
    public let rawPayload: String?
    public let isDemoData: Bool
    public let receivedAt: Date

    public init(
        id: UUID = UUID(),
        portalId: UUID,
        courseId: UUID? = nil,
        courseCode: String? = nil,
        title: String,
        content: String,
        sender: String,
        category: UniversityInboxCategory,
        urgency: UniversityUrgencyLevel = .medium,
        trustLevel: PortalDataTrustLevel = .parsedPortal,
        isRead: Bool = false,
        rawPayload: String? = nil,
        isDemoData: Bool = false,
        receivedAt: Date = Date()
    ) {
        self.id = id
        self.portalId = portalId
        self.courseId = courseId
        self.courseCode = courseCode
        self.title = title
        self.content = content
        self.sender = sender
        self.category = category
        self.urgency = urgency
        self.trustLevel = trustLevel
        self.isRead = isRead
        self.rawPayload = rawPayload
        self.isDemoData = isDemoData
        self.receivedAt = receivedAt
    }
}

/// Stored official university announcement with AI-extracted metadata.
public struct UniversityAnnouncement: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let portalId: UUID
    public let courseId: UUID?
    public let title: String
    public let body: String
    public let originalBody: String?
    public let importance: String
    public let isUrgent: Bool
    public let actionDeadline: Date?
    public var processedByAI: Bool
    public let trustLevel: PortalDataTrustLevel
    public let isDemoData: Bool
    public let derivedMetadata: AnnouncementDerivedMetadata?
    public let sourceRecord: PortalSourceRecord?
    public let announcedAt: Date

    public init(
        id: UUID = UUID(),
        portalId: UUID,
        courseId: UUID? = nil,
        title: String,
        body: String,
        originalBody: String? = nil,
        importance: String = "Normal",
        isUrgent: Bool = false,
        actionDeadline: Date? = nil,
        processedByAI: Bool = false,
        trustLevel: PortalDataTrustLevel = .parsedPortal,
        isDemoData: Bool = false,
        derivedMetadata: AnnouncementDerivedMetadata? = nil,
        sourceRecord: PortalSourceRecord? = nil,
        announcedAt: Date = Date()
    ) {
        self.id = id
        self.portalId = portalId
        self.courseId = courseId
        self.title = title
        self.body = body
        self.originalBody = originalBody ?? body
        self.importance = importance
        self.isUrgent = isUrgent
        self.actionDeadline = actionDeadline
        self.processedByAI = processedByAI
        self.trustLevel = trustLevel
        self.isDemoData = isDemoData
        self.derivedMetadata = derivedMetadata
        self.sourceRecord = sourceRecord
        self.announcedAt = announcedAt
    }
}

// MARK: - Grades & Academic Evaluation

/// Official grade record imported from the Student Information System (OBS/LMS).
public struct UniversityGrade: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let courseId: UUID
    public let courseCode: String
    public let evaluationName: String
    public let score: Double
    public let maxScore: Double
    public let weightPercentage: Double
    public let letterGrade: String?
    public let isFinal: Bool
    public let trustLevel: PortalDataTrustLevel
    public let isDemoData: Bool
    public let recordedAt: Date

    public init(
        id: UUID = UUID(),
        courseId: UUID,
        courseCode: String,
        evaluationName: String,
        score: Double,
        maxScore: Double = 100.0,
        weightPercentage: Double = 40.0,
        letterGrade: String? = nil,
        isFinal: Bool = false,
        trustLevel: PortalDataTrustLevel = .parsedPortal,
        isDemoData: Bool = false,
        recordedAt: Date = Date()
    ) {
        self.id = id
        self.courseId = courseId
        self.courseCode = courseCode
        self.evaluationName = evaluationName
        self.score = score
        self.maxScore = maxScore
        self.weightPercentage = weightPercentage
        self.letterGrade = letterGrade
        self.isFinal = isFinal
        self.trustLevel = trustLevel
        self.isDemoData = isDemoData
        self.recordedAt = recordedAt
    }

    /// Normalized percentage score (0.0 to 100.0)
    public var percentage: Double {
        guard maxScore > 0 else { return 0 }
        return (score / maxScore) * 100.0
    }
}

// MARK: - Sync Log & Change Reporting

/// Audit log record documenting every university synchronization attempt.
public struct UniversitySyncLog: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let portalId: UUID
    public let status: String
    public let itemsImported: Int
    public let itemsUpdated: Int
    public let errorMessage: String?
    public let timestamp: Date

    public init(
        id: UUID = UUID(),
        portalId: UUID,
        status: String,
        itemsImported: Int,
        itemsUpdated: Int,
        errorMessage: String? = nil,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.portalId = portalId
        self.status = status
        self.itemsImported = itemsImported
        self.itemsUpdated = itemsUpdated
        self.errorMessage = errorMessage
        self.timestamp = timestamp
    }
}

// MARK: - Remote Data Transfer Objects (DTOs)

/// DTO representing a course scraped or fetched from remote portal.
public struct RemoteCourse: Codable, Sendable, Equatable {
    public let remoteId: String
    public let code: String
    public let name: String
    public let instructor: String
    public let credits: Int
    public let ects: Int

    public init(remoteId: String, code: String, name: String, instructor: String, credits: Int, ects: Int) {
        self.remoteId = remoteId
        self.code = code
        self.name = name
        self.instructor = instructor
        self.credits = credits
        self.ects = ects
    }
}

/// DTO representing a remote announcement.
public struct RemoteAnnouncement: Codable, Sendable, Equatable {
    public let remoteId: String
    public let courseCode: String?
    public let title: String
    public let body: String
    public let author: String
    public let isUrgent: Bool
    public let date: Date

    public init(remoteId: String, courseCode: String?, title: String, body: String, author: String, isUrgent: Bool, date: Date) {
        self.remoteId = remoteId
        self.courseCode = courseCode
        self.title = title
        self.body = body
        self.author = author
        self.isUrgent = isUrgent
        self.date = date
    }
}

/// DTO representing an exam scheduled in the university portal.
public struct RemoteExam: Codable, Sendable, Equatable {
    public let remoteId: String
    public let courseCode: String
    public let title: String
    public let examType: String
    public let date: Date
    public let room: String?
    public let weightPercentage: Int
    public let scope: String?
    public let sourceURL: URL?
    public let requiresUserConfirmation: Bool

    public init(
        remoteId: String,
        courseCode: String,
        title: String,
        examType: String,
        date: Date,
        room: String?,
        weightPercentage: Int,
        scope: String? = nil,
        sourceURL: URL? = nil,
        requiresUserConfirmation: Bool = false
    ) {
        self.remoteId = remoteId
        self.courseCode = courseCode
        self.title = title
        self.examType = examType
        self.date = date
        self.room = room
        self.weightPercentage = weightPercentage
        self.scope = scope
        self.sourceURL = sourceURL
        self.requiresUserConfirmation = requiresUserConfirmation
    }
}

/// DTO representing an assignment posted on the university LMS.
public struct RemoteAssignment: Codable, Sendable, Equatable {
    public let remoteId: String
    public let courseCode: String
    public let title: String
    public let description: String
    public let dueDate: Date
    public let maxScore: Double
    public let submissionURL: String?
    public let submissionStatus: String?
    public let attachments: [String]
    public let sourceURL: URL?
    public let requiresUserConfirmation: Bool

    public init(
        remoteId: String,
        courseCode: String,
        title: String,
        description: String,
        dueDate: Date,
        maxScore: Double,
        submissionURL: String?,
        submissionStatus: String? = nil,
        attachments: [String] = [],
        sourceURL: URL? = nil,
        requiresUserConfirmation: Bool = false
    ) {
        self.remoteId = remoteId
        self.courseCode = courseCode
        self.title = title
        self.description = description
        self.dueDate = dueDate
        self.maxScore = maxScore
        self.submissionURL = submissionURL
        self.submissionStatus = submissionStatus
        self.attachments = attachments
        self.sourceURL = sourceURL
        self.requiresUserConfirmation = requiresUserConfirmation
    }
}

/// DTO representing a grade entry posted on the university portal.
public struct RemoteGrade: Codable, Sendable, Equatable {
    public let remoteId: String
    public let courseCode: String
    public let evaluationName: String
    public let score: Double
    public let maxScore: Double
    public let weightPercentage: Double
    public let letterGrade: String?
    public let isFinal: Bool

    public init(remoteId: String, courseCode: String, evaluationName: String, score: Double, maxScore: Double, weightPercentage: Double, letterGrade: String?, isFinal: Bool) {
        self.remoteId = remoteId
        self.courseCode = courseCode
        self.evaluationName = evaluationName
        self.score = score
        self.maxScore = maxScore
        self.weightPercentage = weightPercentage
        self.letterGrade = letterGrade
        self.isFinal = isFinal
    }
}

/// DTO representing a document file hosted on the university portal.
public struct RemoteDocument: Codable, Sendable, Equatable {
    public let remoteId: String
    public let courseCode: String
    public let fileName: String
    public let fileExtension: String
    public let downloadURL: URL
    public let docType: String

    public init(remoteId: String, courseCode: String, fileName: String, fileExtension: String, downloadURL: URL, docType: String) {
        self.remoteId = remoteId
        self.courseCode = courseCode
        self.fileName = fileName
        self.fileExtension = fileExtension
        self.downloadURL = downloadURL
        self.docType = docType
    }
}

/// Aggregated container of all items returned during a university portal fetch.
public struct RemoteUniversityPayload: Codable, Sendable {
    public let courses: [RemoteCourse]
    public let announcements: [RemoteAnnouncement]
    public let exams: [RemoteExam]
    public let assignments: [RemoteAssignment]
    public let grades: [RemoteGrade]
    public let documents: [RemoteDocument]
    public let attendances: [RemoteAttendanceRecord]

    public init(
        courses: [RemoteCourse] = [],
        announcements: [RemoteAnnouncement] = [],
        exams: [RemoteExam] = [],
        assignments: [RemoteAssignment] = [],
        grades: [RemoteGrade] = [],
        documents: [RemoteDocument] = [],
        attendances: [RemoteAttendanceRecord] = []
    ) {
        self.courses = courses
        self.announcements = announcements
        self.exams = exams
        self.assignments = assignments
        self.grades = grades
        self.documents = documents
        self.attendances = attendances
    }
}
