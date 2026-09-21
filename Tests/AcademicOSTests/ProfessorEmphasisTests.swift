import XCTest
import Foundation
@testable import AcademicOS

final class ProfessorEmphasisTests: XCTestCase {
    var detector: ProfessorEmphasisDetector!
    let courseId = UUID()
    let recordingId = UUID()

    override func setUp() {
        super.setUp()
        detector = ProfessorEmphasisDetector()
    }

    func testExplicitExamHintClassification_RedTier() {
        let segments = [
            TranscriptSegment(
                recordingId: recordingId,
                courseId: courseId,
                startSeconds: 120.0,
                endSeconds: 125.0,
                text: "Bu ayrım çok kritik arkadaşlar, finalde sorabilirim lütfen dikkat edin."
            )
        ]

        let items = detector.detectEmphasis(
            segments: segments,
            courseId: courseId,
            lectureSessionId: nil,
            recordingId: recordingId
        )

        XCTAssertFalse(items.isEmpty)
        let first = items.first!
        XCTAssertEqual(first.classification, .explicitExamHint, "Phrases mentioning final exam must be classified as explicitExamHint.")
        XCTAssertEqual(first.startTime, 120.0)
        XCTAssertEqual(first.classification.title, "PROFESSOR EXPLICITLY MENTIONED EXAM")
    }

    func testProfessorEmphasisClassification_OrangeTier() {
        let segments = [
            TranscriptSegment(
                recordingId: recordingId,
                courseId: courseId,
                startSeconds: 300.0,
                endSeconds: 305.0,
                text: "Burası önemli, bu iki kuramı birbirine asla karıştırmayın."
            )
        ]

        let items = detector.detectEmphasis(
            segments: segments,
            courseId: courseId,
            lectureSessionId: nil,
            recordingId: recordingId
        )

        XCTAssertFalse(items.isEmpty)
        let first = items.first!
        XCTAssertEqual(first.classification, .professorEmphasis, "'Burası önemli' must be classified as professorEmphasis.")
        XCTAssertEqual(first.classification.title, "PROFESSOR STRONGLY EMPHASIZED")
    }

    func testManualAudioMarkerPriority() {
        let segments = [
            TranscriptSegment(
                recordingId: recordingId,
                courseId: courseId,
                startSeconds: 60.0,
                endSeconds: 70.0,
                text: "Habitus kavramı bireyin toplumsal yapıyı içselleştirmesidir."
            )
        ]

        let marker = AudioMarker(
            recordingId: recordingId,
            courseId: courseId,
            timestampSeconds: 65.0,
            markerType: .examHint,
            noteText: "Student tapped exam bookmark"
        )

        let items = detector.detectEmphasis(
            segments: segments,
            markers: [marker],
            courseId: courseId,
            lectureSessionId: nil,
            recordingId: recordingId
        )

        XCTAssertFalse(items.isEmpty)
        let examHintItem = items.first { $0.classification == .explicitExamHint }
        XCTAssertNotNil(examHintItem)
        XCTAssertEqual(examHintItem?.detectionMethod, .audioMarker)
    }

    func testFormattedTimestampDisplay() {
        let emphasis = ProfessorEmphasis(
            courseId: courseId,
            recordingId: recordingId,
            startTime: 2236.0, // 00:37:16
            endTime: 2240.0,
            exactSourceSnippet: "Final sorusudur",
            classification: .explicitExamHint
        )

        XCTAssertEqual(emphasis.formattedTimestamp, "00:37:16")
    }
}
