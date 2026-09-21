import Foundation

/// Detection engine identifying high-yield professor statements, exam hints, and definitions in transcripts.
/// Prioritizes Turkish academic language and enforces strict truth standards for exam predictions.
public final class ProfessorEmphasisDetector: Sendable {
    // Explicit exam hint phrases (Tier: EXPLICIT_EXAM_HINT / RED)
    private static let explicitExamPhrases = [
        "sınavda çıkabilir",
        "sınavda sorabilirim",
        "finalde sorabilirim",
        "vizede sorabilirim",
        "geçen yıl sormuştum",
        "bu soru sınavda gelir",
        "sınav sorusudur",
        "final sorusu",
        "vize sorusu",
        "this may be on the exam",
        "this will be on the exam",
        "exam question"
    ]

    // Strong professor emphasis phrases (Tier: PROFESSOR_EMPHASIS / ORANGE)
    private static let professorEmphasisPhrases = [
        "burası önemli",
        "bunu bilin",
        "bunu unutmayın",
        "bunun altını çizin",
        "özellikle buraya dikkat",
        "bunu karıştırmayın",
        "arkadaşlar dikkat",
        "özellikle belirtiyorum",
        "en kritik nokta",
        "asla karıştırmayın",
        "this is important",
        "pay close attention",
        "remember this"
    ]

    // Definition & example cues
    private static let definitionCues = [
        "şöyle tanımlanır",
        "tanımı şudur",
        "kavram olarak",
        "demek istiyoruz",
        "is defined as",
        "refers to"
    ]

    private static let assignmentCues = [
        "ödev olarak",
        "teslim tarihi",
        "haftaya kadar hazırlayın",
        "proje konusu",
        "homework assignment",
        "due date"
    ]

    public init() {}

    /// Scans transcript segments and manual audio markers to extract verified emphasis items.
    public func detectEmphasis(
        segments: [TranscriptSegment],
        markers: [AudioMarker] = [],
        courseId: UUID,
        lectureSessionId: UUID?,
        recordingId: UUID
    ) -> [ProfessorEmphasis] {
        var results: [ProfessorEmphasis] = []

        // 1. Scan transcript segments with keyword matching and surrounding context
        for (index, seg) in segments.enumerated() {
            let textLower = seg.text.lowercased()

            // Check Explicit Exam Hint
            if let matchedPhrase = Self.explicitExamPhrases.first(where: { textLower.contains($0) }) {
                let snippet = extractSnippet(segments: segments, currentIndex: index)
                let item = ProfessorEmphasis(
                    courseId: courseId,
                    lectureSessionId: lectureSessionId,
                    recordingId: recordingId,
                    transcriptSegmentId: seg.id,
                    startTime: seg.startSeconds,
                    endTime: seg.endSeconds,
                    exactSourceSnippet: snippet,
                    classification: .explicitExamHint,
                    confidence: 0.98,
                    detectionMethod: .explicitPhrase
                )
                results.append(item)
                continue
            }

            // Check Strong Professor Emphasis
            if let matchedPhrase = Self.professorEmphasisPhrases.first(where: { textLower.contains($0) }) {
                let snippet = extractSnippet(segments: segments, currentIndex: index)
                let item = ProfessorEmphasis(
                    courseId: courseId,
                    lectureSessionId: lectureSessionId,
                    recordingId: recordingId,
                    transcriptSegmentId: seg.id,
                    startTime: seg.startSeconds,
                    endTime: seg.endSeconds,
                    exactSourceSnippet: snippet,
                    classification: .professorEmphasis,
                    confidence: 0.92,
                    detectionMethod: .explicitPhrase
                )
                results.append(item)
                continue
            }

            // Check Assignment cues
            if Self.assignmentCues.contains(where: { textLower.contains($0) }) {
                let snippet = extractSnippet(segments: segments, currentIndex: index)
                let item = ProfessorEmphasis(
                    courseId: courseId,
                    lectureSessionId: lectureSessionId,
                    recordingId: recordingId,
                    transcriptSegmentId: seg.id,
                    startTime: seg.startSeconds,
                    endTime: seg.endSeconds,
                    exactSourceSnippet: snippet,
                    classification: .assignmentInstruction,
                    confidence: 0.88,
                    detectionMethod: .explicitPhrase
                )
                results.append(item)
                continue
            }

            // Check Definition cues
            if Self.definitionCues.contains(where: { textLower.contains($0) }) {
                let snippet = extractSnippet(segments: segments, currentIndex: index)
                let item = ProfessorEmphasis(
                    courseId: courseId,
                    lectureSessionId: lectureSessionId,
                    recordingId: recordingId,
                    transcriptSegmentId: seg.id,
                    startTime: seg.startSeconds,
                    endTime: seg.endSeconds,
                    exactSourceSnippet: snippet,
                    classification: .importantDefinition,
                    confidence: 0.85,
                    detectionMethod: .explicitPhrase
                )
                results.append(item)
                continue
            }
        }

        // 2. Correlate manual Audio Markers (Student tapped timestamp during lecture)
        for marker in markers {
            let matchedSegment = segments.first { seg in
                marker.timestampSeconds >= seg.startSeconds && marker.timestampSeconds <= seg.endSeconds
            }

            let classification: ProfessorEmphasisClassification
            switch marker.markerType {
            case .examHint:
                classification = .explicitExamHint
            case .important:
                classification = .professorEmphasis
            case .assignment:
                classification = .assignmentInstruction
            case .question:
                classification = .reviewRecommendation
            case .bookmark:
                classification = .professorEmphasis
            }

            let snippet = matchedSegment?.text ?? marker.noteText ?? "Manual Student Bookmark"
            let item = ProfessorEmphasis(
                courseId: courseId,
                lectureSessionId: lectureSessionId,
                recordingId: recordingId,
                transcriptSegmentId: matchedSegment?.id,
                startTime: marker.timestampSeconds,
                endTime: marker.timestampSeconds + 15.0,
                exactSourceSnippet: snippet,
                classification: classification,
                confidence: 0.95,
                detectionMethod: .audioMarker
            )
            results.append(item)
        }

        // De-duplicate items within 5 seconds of each other
        var unique: [ProfessorEmphasis] = []
        for item in results.sorted(by: { $0.startTime < $1.startTime }) {
            if let last = unique.last, abs(last.startTime - item.startTime) < 5.0 && last.classification == item.classification {
                continue
            }
            unique.append(item)
        }

        return unique
    }

    /// Extracts a readable snippet with preceding and following context window.
    private func extractSnippet(segments: [TranscriptSegment], currentIndex: Int) -> String {
        let prev = currentIndex > 0 ? segments[currentIndex - 1].text : ""
        let current = segments[currentIndex].text
        let next = currentIndex < segments.count - 1 ? segments[currentIndex + 1].text : ""
        return [prev, current, next].filter { !$0.isEmpty }.joined(separator: " ")
    }
}
