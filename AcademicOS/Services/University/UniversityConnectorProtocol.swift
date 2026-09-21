import Foundation

/// Unified interface for university portal connectors (Demo, Moodle, Canvas, OBS).
public protocol UniversityConnectorProtocol: Sendable {
    /// Connector identification
    var portalType: UniversityPortalType { get }
    var displayName: String { get }

    /// Authenticates with the university portal using provided credentials.
    func authenticate(credentials: UniversityCredentials) async throws -> Bool

    /// Fetches all active enrolled courses from the university portal.
    func fetchCourses() async throws -> [RemoteCourse]

    /// Fetches latest university announcements.
    func fetchAnnouncements(courseCode: String?) async throws -> [RemoteAnnouncement]

    /// Fetches officially published exam dates and room assignments.
    func fetchExams(courseCode: String?) async throws -> [RemoteExam]

    /// Fetches homework, project, and lab assignment deadlines.
    func fetchAssignments(courseCode: String?) async throws -> [RemoteAssignment]

    /// Fetches recorded midterm, quiz, and final evaluation grades.
    func fetchGrades(courseCode: String?) async throws -> [RemoteGrade]

    /// Fetches course documents (syllabi, lecture slides, assignments).
    func fetchDocuments(courseCode: String?) async throws -> [RemoteDocument]

    /// Aggregated full sync method returning all entities in one pass.
    func fetchFullPayload() async throws -> RemoteUniversityPayload
}
