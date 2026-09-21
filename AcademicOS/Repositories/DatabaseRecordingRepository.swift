import Foundation

/// Real database-backed audio recording and transcript repository.
public final class DatabaseRecordingRepository: RecordingRepositoryProtocol, @unchecked Sendable {
    private let localStore: LocalStoreProtocol

    public init(localStore: LocalStoreProtocol) {
        self.localStore = localStore
    }

    // Recordings
    public func getRecordings(forCourseId courseId: UUID) async throws -> [AudioRecordingMetadata] {
        let all: [AudioRecordingMetadata] = try await localStore.fetchAll()
        return all.filter { $0.courseId == courseId }.sorted { $0.recordedAt > $1.recordedAt }
    }

    public func getRecording(id: UUID) async throws -> AudioRecordingMetadata? {
        return try await localStore.fetch(id: id)
    }

    public func saveRecording(_ recording: AudioRecordingMetadata) async throws {
        try await localStore.save(recording)
    }

    public func deleteRecording(id: UUID) async throws {
        try await localStore.delete(AudioRecordingMetadata.self, id: id)
    }

    // Transcripts
    public func getTranscript(forRecordingId recordingId: UUID) async throws -> Transcript? {
        let all: [Transcript] = try await localStore.fetchAll()
        return all.first(where: { $0.recordingId == recordingId })
    }

    public func saveTranscript(_ transcript: Transcript) async throws {
        var updated = transcript
        updated.updatedAt = Date()
        try await localStore.save(updated)
    }

    public func saveTranscriptSegment(_ segment: TranscriptSegment) async throws {
        try await localStore.save(segment)
    }

    public func getSegments(forTranscriptId transcriptId: UUID) async throws -> [TranscriptSegment] {
        let all: [TranscriptSegment] = try await localStore.fetchAll()
        return all.filter { $0.recordingId == transcriptId || $0.id == transcriptId }.sorted { $0.startSeconds < $1.startSeconds }
    }

    // Moment Markers
    public func getMarkers(forRecordingId recordingId: UUID) async throws -> [AudioMarker] {
        let all: [AudioMarker] = try await localStore.fetchAll()
        return all.filter { $0.recordingId == recordingId }.sorted { $0.timestampSeconds < $1.timestampSeconds }
    }

    public func getMarkers(forCourseId courseId: UUID) async throws -> [AudioMarker] {
        let all: [AudioMarker] = try await localStore.fetchAll()
        return all.filter { $0.courseId == courseId }.sorted { $0.createdAt > $1.createdAt }
    }

    public func saveMarker(_ marker: AudioMarker) async throws {
        try await localStore.save(marker)
    }

    public func deleteMarker(id: UUID) async throws {
        try await localStore.delete(AudioMarker.self, id: id)
    }
}
