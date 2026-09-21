import Foundation

/// Detailed report generated at the completion of an import and reconciliation cycle.
public struct SyncChangeReport: Sendable, Equatable {
    public let portalName: String
    public let newExamsCount: Int
    public let newAssignmentsCount: Int
    public let newGradesCount: Int
    public let newAnnouncementsCount: Int
    public let newDocumentsCount: Int
    public let totalChangesCount: Int
    public let durationSeconds: Double
    public let isReadOnly: Bool
    public let completedAt: Date

    public init(
        portalName: String,
        newExamsCount: Int,
        newAssignmentsCount: Int,
        newGradesCount: Int,
        newAnnouncementsCount: Int,
        newDocumentsCount: Int,
        durationSeconds: Double,
        isReadOnly: Bool = true,
        completedAt: Date = Date()
    ) {
        self.portalName = portalName
        self.newExamsCount = newExamsCount
        self.newAssignmentsCount = newAssignmentsCount
        self.newGradesCount = newGradesCount
        self.newAnnouncementsCount = newAnnouncementsCount
        self.newDocumentsCount = newDocumentsCount
        self.totalChangesCount = newExamsCount + newAssignmentsCount + newGradesCount + newAnnouncementsCount + newDocumentsCount
        self.durationSeconds = durationSeconds
        self.isReadOnly = isReadOnly
        self.completedAt = completedAt
    }
}

/// University Import & Reconciliation Engine (Phase 2C: Strictly Read-Only).
/// Responsibilities:
/// - READ: Safely fetch course schedules, announcements, exam halls, and grades.
/// - IMPORT: Map remote DTOs into sandboxed SQLite databases.
/// - ORGANIZE: Link evaluations to courses and schedule local notifications.
/// - ANALYZE: Calculate GPA and flag critical deadlines.
///
/// Strictly FORBIDDEN in Phase 2C:
/// - Submitting assignments or uploading files to university servers.
/// - Registering or dropping courses.
/// - Sending portal messages or altering university records.
public final class UniversityImportReconciliationEngine: @unchecked Sendable {
    public let isReadOnly: Bool = true

    private let connector: UniversityConnectorProtocol
    private let universityRepo: UniversityRepositoryProtocol
    private let courseRepo: CourseRepositoryProtocol
    private let examRepo: ExamRepositoryProtocol
    private let taskRepo: TaskRepositoryProtocol
    private let calendarRepo: CalendarRepositoryProtocol
    private let documentDownloader: UniversityDocumentDownloaderProtocol
    private let notificationService: AcademicNotificationServiceProtocol
    private let gpaCalculator: GPACalculator
    private let lock = NSLock()
    private var isSyncing: Bool = false

    public init(
        connector: UniversityConnectorProtocol,
        universityRepo: UniversityRepositoryProtocol,
        courseRepo: CourseRepositoryProtocol,
        examRepo: ExamRepositoryProtocol,
        taskRepo: TaskRepositoryProtocol,
        calendarRepo: CalendarRepositoryProtocol,
        documentDownloader: UniversityDocumentDownloaderProtocol,
        notificationService: AcademicNotificationServiceProtocol = AcademicNotificationService.shared,
        gpaCalculator: GPACalculator = GPACalculator()
    ) {
        self.connector = connector
        self.universityRepo = universityRepo
        self.courseRepo = courseRepo
        self.examRepo = examRepo
        self.taskRepo = taskRepo
        self.calendarRepo = calendarRepo
        self.documentDownloader = documentDownloader
        self.notificationService = notificationService
        self.gpaCalculator = gpaCalculator
    }

    /// Executes read-only import and reconciliation.
    public func performSync() async throws -> SyncChangeReport {
        lock.lock()
        if isSyncing {
            lock.unlock()
            throw AcademicOSError.networkError("Import and reconciliation cycle already running.")
        }
        isSyncing = true
        lock.unlock()

        defer {
            lock.lock()
            isSyncing = false
            lock.unlock()
        }

        let startTime = Date()

        do {
            // 1. Fetch remote payload (READ ONLY)
            let payload = try await connector.fetchFullPayload()

            // 2. Fetch local active courses for code-to-ID mapping
            let localCourses = try await courseRepo.getAllCourses()
            var courseCodeMap: [String: Course] = [:]
            for course in localCourses {
                let normalizedCode = course.code.replacingOccurrences(of: " ", with: "").uppercased()
                courseCodeMap[normalizedCode] = course
            }

            var newExams = 0
            var newAssignments = 0
            var newGrades = 0
            var newAnnouncements = 0
            var newDocs = 0

            let activePortal = try await universityRepo.fetchActivePortal()
            let portalId = activePortal?.id ?? UUID()
            let isDemoMode = connector.portalType == .demo

            // 3. Process Exams with Reconciliation & Update Detection (No Duplicates)
            let existingExams = try await examRepo.getAllExams()
            for remoteExam in payload.exams {
                let dummyRemoteCourse = RemoteCourse(remoteId: remoteExam.remoteId, code: remoteExam.courseCode, name: remoteExam.courseCode, instructor: "", credits: 3, ects: 5)
                let match = CourseReconciliationEngine.shared.reconcileSingle(remoteCourse: dummyRemoteCourse, localCourses: localCourses)
                guard let targetCourseId = match.matchedLocalCourse?.id ?? courseCodeMap[remoteExam.courseCode.replacingOccurrences(of: " ", with: "").uppercased()]?.id else {
                    continue // Do not assign to random course if unconfirmed
                }

                let existing = existingExams.first {
                    $0.courseId == targetCourseId && $0.title.caseInsensitiveCompare(remoteExam.title) == .orderedSame
                }

                if let existingExam = existing {
                    // Update if date or room changed
                    if existingExam.examDate != remoteExam.date || existingExam.room != remoteExam.room {
                        let updated = Exam(
                            id: existingExam.id,
                            courseId: targetCourseId,
                            title: existingExam.title,
                            examType: remoteExam.examType,
                            examDate: remoteExam.date,
                            room: remoteExam.room,
                            weightPercentage: remoteExam.weightPercentage
                        )
                        try await examRepo.saveExam(updated)
                        await notificationService.scheduleExamNotification(exam: updated, courseCode: remoteExam.courseCode)
                    }
                } else {
                    let exam = Exam(
                        id: UUID(),
                        courseId: targetCourseId,
                        title: remoteExam.title,
                        examType: remoteExam.examType,
                        examDate: remoteExam.date,
                        room: remoteExam.room,
                        weightPercentage: remoteExam.weightPercentage
                    )
                    try await examRepo.saveExam(exam)
                    await notificationService.scheduleExamNotification(exam: exam, courseCode: remoteExam.courseCode)

                    // Add inbox item with parsedPortal trust level
                    let inboxItem = UniversityInboxItem(
                        portalId: portalId,
                        courseId: targetCourseId,
                        courseCode: remoteExam.courseCode,
                        title: "Exam Scheduled: \(remoteExam.title)",
                        content: "\(remoteExam.courseCode) \(remoteExam.examType) on \(formatDate(remoteExam.date)) in \(remoteExam.room ?? "TBA")",
                        sender: remoteExam.courseCode,
                        category: .exam,
                        urgency: .high,
                        trustLevel: .parsedPortal,
                        isDemoData: isDemoMode
                    )
                    try await universityRepo.saveInboxItem(inboxItem)
                    newExams += 1
                }
            }

            // 4. Process Assignments -> AcademicTasks (Read Only)
            let existingTasks = try await taskRepo.getAllTasks()
            for remoteAsg in payload.assignments {
                let normalized = remoteAsg.courseCode.replacingOccurrences(of: " ", with: "").uppercased()
                let targetCourseId = courseCodeMap[normalized]?.id ?? localCourses.first?.id ?? UUID()

                let alreadyExists = existingTasks.contains {
                    $0.courseId == targetCourseId && $0.title.caseInsensitiveCompare(remoteAsg.title) == .orderedSame
                }

                if !alreadyExists {
                    let task = AcademicTask(
                        id: UUID(),
                        courseId: targetCourseId,
                        title: "\(remoteAsg.courseCode): \(remoteAsg.title)",
                        scheduledTime: remoteAsg.dueDate,
                        dueDate: remoteAsg.dueDate,
                        estimatedMinutes: 90,
                        isCompleted: false,
                        priority: .high,
                        category: .mission
                    )
                    try await taskRepo.saveTask(task)
                    await notificationService.scheduleAssignmentNotification(task: task, courseCode: remoteAsg.courseCode)

                    let inboxItem = UniversityInboxItem(
                        portalId: portalId,
                        courseId: targetCourseId,
                        courseCode: remoteAsg.courseCode,
                        title: "Assignment Due: \(remoteAsg.title)",
                        content: "\(remoteAsg.description)\nDue: \(formatDate(remoteAsg.dueDate))",
                        sender: remoteAsg.courseCode,
                        category: .assignment,
                        urgency: .medium,
                        trustLevel: .parsedPortal,
                        isDemoData: isDemoMode
                    )
                    try await universityRepo.saveInboxItem(inboxItem)
                    newAssignments += 1
                }
            }

            // 5. Process Announcements with Trust Level
            let existingAnnouncements = try await universityRepo.fetchAnnouncements(courseId: nil)
            for remoteAnn in payload.announcements {
                let normalized = (remoteAnn.courseCode ?? "").replacingOccurrences(of: " ", with: "").uppercased()
                let targetCourseId = courseCodeMap[normalized]?.id

                let alreadyExists = existingAnnouncements.contains {
                    $0.title.caseInsensitiveCompare(remoteAnn.title) == .orderedSame
                }

                if !alreadyExists {
                    let isUrgent = remoteAnn.isUrgent ||
                        remoteAnn.title.localizedCaseInsensitiveContains("vize") ||
                        remoteAnn.title.localizedCaseInsensitiveContains("final")

                    // Ambiguous AI-extracted dates require confirmation before being considered official
                    let trustLevel: PortalDataTrustLevel = isUrgent ? .parsedPortal : .officialPortal

                    let storedAnn = UniversityAnnouncement(
                        id: UUID(),
                        portalId: portalId,
                        courseId: targetCourseId,
                        title: remoteAnn.title,
                        body: remoteAnn.body,
                        importance: isUrgent ? "High" : "Normal",
                        isUrgent: isUrgent,
                        actionDeadline: nil,
                        processedByAI: true,
                        trustLevel: trustLevel,
                        isDemoData: isDemoMode,
                        announcedAt: remoteAnn.date
                    )
                    try await universityRepo.saveAnnouncement(storedAnn)

                    let inboxItem = UniversityInboxItem(
                        portalId: portalId,
                        courseId: targetCourseId,
                        courseCode: remoteAnn.courseCode,
                        title: remoteAnn.title,
                        content: remoteAnn.body,
                        sender: remoteAnn.author,
                        category: isUrgent ? .urgent : .announcement,
                        urgency: isUrgent ? .critical : .medium,
                        trustLevel: trustLevel,
                        isDemoData: isDemoMode
                    )
                    try await universityRepo.saveInboxItem(inboxItem)

                    if isUrgent {
                        await notificationService.postUrgentAnnouncementNotification(title: remoteAnn.title, body: remoteAnn.body)
                    }

                    newAnnouncements += 1
                }
            }

            // 6. Process Grades (Deterministic parsedPortal trust)
            let existingGrades = try await universityRepo.fetchGrades(courseId: nil)
            for remoteGrade in payload.grades {
                let normalized = remoteGrade.courseCode.replacingOccurrences(of: " ", with: "").uppercased()
                let targetCourseId = courseCodeMap[normalized]?.id ?? localCourses.first?.id ?? UUID()

                let alreadyExists = existingGrades.contains {
                    $0.courseId == targetCourseId && $0.evaluationName.caseInsensitiveCompare(remoteGrade.evaluationName) == .orderedSame
                }

                if !alreadyExists {
                    let storedGrade = UniversityGrade(
                        id: UUID(),
                        courseId: targetCourseId,
                        courseCode: remoteGrade.courseCode,
                        evaluationName: remoteGrade.evaluationName,
                        score: remoteGrade.score,
                        maxScore: remoteGrade.maxScore,
                        weightPercentage: remoteGrade.weightPercentage,
                        letterGrade: remoteGrade.letterGrade ?? GPACalculator.letterGrade(forScore: remoteGrade.score),
                        isFinal: remoteGrade.isFinal,
                        trustLevel: .officialPortal,
                        isDemoData: isDemoMode,
                        recordedAt: Date()
                    )
                    try await universityRepo.saveGrade(storedGrade)

                    let inboxItem = UniversityInboxItem(
                        portalId: portalId,
                        courseId: targetCourseId,
                        courseCode: remoteGrade.courseCode,
                        title: "Grade Released: \(remoteGrade.evaluationName)",
                        content: "\(remoteGrade.courseCode) - \(remoteGrade.score)/\(remoteGrade.maxScore) (\(storedGrade.letterGrade ?? ""))",
                        sender: remoteGrade.courseCode,
                        category: .grade,
                        urgency: .medium,
                        trustLevel: .officialPortal,
                        isDemoData: isDemoMode
                    )
                    try await universityRepo.saveInboxItem(inboxItem)
                    newGrades += 1
                }
            }

            // 7. Process Documents (Background Download with Checksum)
            for remoteDoc in payload.documents {
                let normalized = remoteDoc.courseCode.replacingOccurrences(of: " ", with: "").uppercased()
                let targetCourseId = courseCodeMap[normalized]?.id ?? localCourses.first?.id ?? UUID()

                if let _ = try? await documentDownloader.downloadDocument(from: remoteDoc, forCourseId: targetCourseId) {
                    newDocs += 1
                }
            }

            // 8. Update Last Sync Date & Audit Log
            try await universityRepo.updateLastSyncDate(portalId: portalId, date: Date())

            let duration = Date().timeIntervalSince(startTime)
            let log = UniversitySyncLog(
                portalId: portalId,
                status: "Success (Read-Only)",
                itemsImported: newExams + newAssignments + newAnnouncements + newGrades + newDocs,
                itemsUpdated: 0,
                errorMessage: nil,
                timestamp: Date()
            )
            try await universityRepo.recordSyncLog(log)

            return SyncChangeReport(
                portalName: connector.displayName,
                newExamsCount: newExams,
                newAssignmentsCount: newAssignments,
                newGradesCount: newGrades,
                newAnnouncementsCount: newAnnouncements,
                newDocumentsCount: newDocs,
                durationSeconds: duration,
                isReadOnly: true
            )
        } catch {
            let activePortal = try? await universityRepo.fetchActivePortal()
            let log = UniversitySyncLog(
                portalId: activePortal?.id ?? UUID(),
                status: "Failed",
                itemsImported: 0,
                itemsUpdated: 0,
                errorMessage: error.localizedDescription,
                timestamp: Date()
            )
            try? await universityRepo.recordSyncLog(log)
            throw error
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

/// Backwards compatibility alias
public typealias UniversitySyncEngine = UniversityImportReconciliationEngine
