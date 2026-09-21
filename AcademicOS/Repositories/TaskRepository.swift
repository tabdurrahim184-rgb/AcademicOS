import Foundation

/// Concrete repository implementation for tasks and mission agenda.
public final class TaskRepository: TaskRepositoryProtocol, @unchecked Sendable {
    private let localStore: LocalStoreProtocol

    public init(localStore: LocalStoreProtocol) {
        self.localStore = localStore
    }

    public func getTasks() async throws -> [AcademicTask] {
        let tasks: [AcademicTask] = try await localStore.fetchAll()
        return tasks.sorted { ($0.priority.sortOrder, $0.scheduledTime ?? "") < ($1.priority.sortOrder, $1.scheduledTime ?? "") }
    }

    public func getTodaysMissions() async throws -> [AcademicTask] {
        let tasks: [AcademicTask] = try await localStore.fetchAll()
        return tasks
            .filter { $0.category == .mission }
            .sorted { ($0.scheduledTime ?? "") < ($1.scheduledTime ?? "") }
    }

    public func saveTask(_ task: AcademicTask) async throws {
        try await localStore.save(task)
    }

    public func toggleTaskCompletion(id: UUID) async throws {
        if var task: AcademicTask = try await localStore.fetch(id: id) {
            task.isCompleted.toggle()
            task.completedAt = task.isCompleted ? Date() : nil
            try await localStore.save(task)
        }
    }

    public func deleteTask(id: UUID) async throws {
        try await localStore.delete(id: id)
    }
}
