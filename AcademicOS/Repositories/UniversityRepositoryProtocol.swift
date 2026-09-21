import Foundation

/// Repository protocol defining data access for University Portal, Inbox, Announcements, Grades, and Sync Logs.
public protocol UniversityRepositoryProtocol: Sendable {
    // Portals
    func fetchActivePortal() async throws -> UniversityPortalConfig?
    func savePortal(_ portal: UniversityPortalConfig) async throws
    func updateLastSyncDate(portalId: UUID, date: Date) async throws

    // Inbox Items
    func fetchInboxItems() async throws -> [UniversityInboxItem]
    func fetchUnreadInboxCount() async throws -> Int
    func markInboxItemAsRead(id: UUID) async throws
    func saveInboxItem(_ item: UniversityInboxItem) async throws
    func saveInboxItems(_ items: [UniversityInboxItem]) async throws

    // Announcements
    func fetchAnnouncements(courseId: UUID?) async throws -> [UniversityAnnouncement]
    func saveAnnouncement(_ item: UniversityAnnouncement) async throws
    func saveAnnouncements(_ items: [UniversityAnnouncement]) async throws

    // Grades
    func fetchGrades(courseId: UUID?) async throws -> [UniversityGrade]
    func saveGrade(_ item: UniversityGrade) async throws
    func saveGrades(_ items: [UniversityGrade]) async throws

    // Sync Audit Logs
    func fetchRecentSyncLogs(limit: Int) async throws -> [UniversitySyncLog]
    func recordSyncLog(_ log: UniversitySyncLog) async throws
}
