import Foundation

/// SQLite-backed repository for tracking lecture pipeline processing progress.
public final class DatabasePipelineRepository: PipelineRepositoryProtocol, @unchecked Sendable {
    private let localStore: LocalStoreProtocol

    public init(localStore: LocalStoreProtocol) {
        self.localStore = localStore
    }

    public func getPipeline(forRecordingId recordingId: UUID) async throws -> LecturePipelineRecord? {
        let all: [LecturePipelineRecord] = try await localStore.fetchAll()
        return all.first { $0.recordingId == recordingId }
    }

    public func getPipelines(forCourseId courseId: UUID) async throws -> [LecturePipelineRecord] {
        let all: [LecturePipelineRecord] = try await localStore.fetchAll()
        return all.filter { $0.courseId == courseId }.sorted { $0.updatedAt > $1.updatedAt }
    }

    public func savePipeline(_ record: LecturePipelineRecord) async throws {
        try await localStore.save(record)
    }

    public func deletePipeline(id: UUID) async throws {
        try await localStore.delete(type: LecturePipelineRecord.self, id: id)
    }
}
