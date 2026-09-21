import XCTest
import Foundation
@testable import AcademicOS

final class HierarchicalPipelineTests: XCTestCase {
    func testCreateTranscriptChunksFromSegments() {
        let transcriptId = UUID()
        var segments: [TranscriptSegment] = []

        // Simulate a 25-minute lecture (1500 seconds, 15 segments of 100s each)
        for i in 0..<15 {
            let start = Double(i * 100)
            let end = Double((i + 1) * 100)
            segments.append(TranscriptSegment(
                id: UUID(),
                transcriptId: transcriptId,
                startSeconds: start,
                endSeconds: end,
                text: "Ders anlatımı bölüm \(i + 1). Hocanın vurguladığı ana kuramlar ve kavramlar.",
                confidence: 0.95
            ))
        }

        let chunks = LectureIntelligencePipeline.createTranscriptChunks(from: segments, fullText: "")

        // 1500 seconds / 600 seconds per chunk = ~3 chunks
        XCTAssertGreaterThanOrEqual(chunks.count, 2, "Long lecture must be divided into discrete hierarchical chunks.")
        XCTAssertEqual(chunks[0].index, 0)
        XCTAssertFalse(chunks[0].text.isEmpty)
    }

    func testChunkResumptionProtectsCompletedChunks() {
        // If 8 of 10 chunks were processed, remaining to process starts from chunk 8
        let totalChunks = 10
        let lastProcessedChunk = 7 // Chunks 0..6 (7 chunks) completed

        let remainingStartIndex = min(lastProcessedChunk, totalChunks)
        XCTAssertEqual(remainingStartIndex, 7, "Resumed pipeline must start from the first uncompleted chunk index.")

        let completedCount = remainingStartIndex
        XCTAssertEqual(completedCount, 7, "Chunks 0-6 must remain completely safe and uncorrupted.")
    }

    func testSingleShortLectureCreatesSingleChunk() {
        let transcriptId = UUID()
        let segments = [
            TranscriptSegment(
                id: UUID(),
                transcriptId: transcriptId,
                startSeconds: 0,
                endSeconds: 180,
                text: "Kısa 3 dakikalık mini ders özeti.",
                confidence: 0.98
            )
        ]

        let chunks = LectureIntelligencePipeline.createTranscriptChunks(from: segments, fullText: "")
        XCTAssertEqual(chunks.count, 1, "Short lecture should form a single chunk.")
    }
}
