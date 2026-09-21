import Foundation

/// Real database-backed repository implementing UniversityRepositoryProtocol.
public final class DatabaseUniversityRepository: UniversityRepositoryProtocol, @unchecked Sendable {
    private let localStore: LocalStoreProtocol

    public init(localStore: LocalStoreProtocol) {
        self.localStore = localStore
    }

    // MARK: - Portals

    public func fetchActivePortal() async throws -> UniversityPortalConfig? {
        let all: [UniversityPortalConfig] = try await localStore.fetchAll()
        return all.first(where: { $0.isActive }) ?? all.first
    }

    public func savePortal(_ portal: UniversityPortalConfig) async throws {
        try await localStore.save(portal)
    }

    public func updateLastSyncDate(portalId: UUID, date: Date) async throws {
        if var portal: UniversityPortalConfig = try await localStore.fetch(id: portalId) {
            portal.lastSyncAt = date
            try await localStore.save(portal)
        }
    }

    // MARK: - Inbox Items

    public func fetchInboxItems() async throws -> [UniversityInboxItem] {
        let all: [UniversityInboxItem] = try await localStore.fetchAll()
        return all.sorted { $0.receivedAt > $1.receivedAt }
    }

    public func fetchUnreadInboxCount() async throws -> Int {
        let all: [UniversityInboxItem] = try await localStore.fetchAll()
        return all.filter { !$0.isRead }.count
    }

    public func markInboxItemAsRead(id: UUID) async throws {
        if var item: UniversityInboxItem = try await localStore.fetch(id: id) {
            item.isRead = true
            try await localStore.save(item)
        }
    }

    public func saveInboxItem(_ item: UniversityInboxItem) async throws {
        try await localStore.save(item)
    }

    public func saveInboxItems(_ items: [UniversityInboxItem]) async throws {
        try await localStore.saveAll(items)
    }

    // MARK: - Announcements

    public func fetchAnnouncements(courseId: UUID?) async throws -> [UniversityAnnouncement] {
        let all: [UniversityAnnouncement] = try await localStore.fetchAll()
        let filtered = courseId == nil ? all : all.filter { $0.courseId == courseId }
        return filtered.sorted { $0.announcedAt > $1.announcedAt }
    }

    public func saveAnnouncement(_ item: UniversityAnnouncement) async throws {
        try await localStore.save(item)
    }

    public func saveAnnouncements(_ items: [UniversityAnnouncement]) async throws {
        try await localStore.saveAll(items)
    }

    // MARK: - Grades

    public func fetchGrades(courseId: UUID?) async throws -> [UniversityGrade] {
        let all: [UniversityGrade] = try await localStore.fetchAll()
        let filtered = courseId == nil ? all : all.filter { $0.courseId == courseId }
        return filtered.sorted { $0.recordedAt > $1.recordedAt }
    }

    public func saveGrade(_ item: UniversityGrade) async throws {
        try await localStore.save(item)
    }

    public func saveGrades(_ items: [UniversityGrade]) async throws {
        try await localStore.saveAll(items)
    }

    // MARK: - Sync Audit Logs

    public func fetchRecentSyncLogs(limit: Int) async throws -> [UniversitySyncLog] {
        let all: [UniversitySyncLog] = try await localStore.fetchAll()
        let sorted = all.sorted { $0.timestamp > $1.timestamp }
        return Array(sorted.prefix(limit))
    }

    public func recordSyncLog(_ log: UniversitySyncLog) async throws {
        try await localStore.save(log)
    }
}
