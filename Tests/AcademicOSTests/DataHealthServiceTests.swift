import XCTest
@testable import AcademicOSKit

/// Validates DataHealthService audit capabilities, orphan file detection, and storage size formatting.
final class DataHealthServiceTests: XCTestCase {
    private var localStore: InMemoryDatabaseManager!
    private var healthService: DataHealthService!

    override func setUp() async throws {
        try await super.setUp()
        localStore = InMemoryDatabaseManager()
        healthService = DataHealthService(localStore: localStore)
    }

    func testHealthyStateOnEmptyStore() async throws {
        let report = try await healthService.auditHealth()
        XCTAssertTrue(report.isHealthy)
        XCTAssertEqual(report.missingAudioFiles.count, 0)
        XCTAssertEqual(report.orphanAudioFiles.count, 0)
        XCTAssertEqual(report.incompleteTranscriptions.count, 0)
    }

    func testMissingAudioFilesDetection() async throws {
        // Metadata referencing a non-existent disk file
        let missingRec = AudioRecordingMetadata(
            courseId: UUID(),
            lectureSessionId: UUID(),
            filename: "non_existent_audio_file.m4a",
            localRelativePath: "Recordings/non_existent_audio_file.m4a",
            durationSeconds: 120.0,
            fileSizeBytes: 1024000
        )
        try await localStore.save(missingRec)

        let report = try await healthService.auditHealth()
        XCTAssertFalse(report.isHealthy)
        XCTAssertEqual(report.missingAudioFiles.count, 1)
        XCTAssertEqual(report.missingAudioFiles.first?.filename, "non_existent_audio_file.m4a")
    }

    func testIncompleteTranscriptionDetection() async throws {
        let rec = AudioRecordingMetadata(
            courseId: UUID(),
            lectureSessionId: UUID(),
            filename: "lecture_interrupted.m4a",
            localRelativePath: "Recordings/lecture_interrupted.m4a",
            durationSeconds: 300.0,
            fileSizeBytes: 2400000,
            transcriptionStatus: .failed
        )
        try await localStore.save(rec)

        let report = try await healthService.auditHealth()
        XCTAssertFalse(report.isHealthy)
        XCTAssertTrue(report.incompleteTranscriptions.contains(where: { $0.id == rec.id }))
    }

    func testStorageFormatting() {
        let report = DataHealthReport(
            missingAudioFiles: [],
            orphanAudioFiles: [],
            incompleteTranscriptions: [],
            totalAudioBytes: 52_428_800, // 50 MB
            totalDatabaseBytes: 2_097_152, // 2 MB
            totalDocumentBytes: 10_485_760 // 10 MB
        )

        XCTAssertTrue(report.isHealthy)
        XCTAssertFalse(report.totalStorageFormatted.isEmpty)
        XCTAssertFalse(report.audioStorageFormatted.isEmpty)
        XCTAssertFalse(report.databaseStorageFormatted.isEmpty)
    }
}
