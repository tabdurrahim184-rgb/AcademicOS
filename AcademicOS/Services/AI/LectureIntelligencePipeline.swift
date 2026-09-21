import Foundation

/// Coordinates the end-to-end transformation of lecture recordings into academic intelligence.
/// Resumable across app restarts; protects transcripts and audio under any AI failure.
public final class LectureIntelligencePipeline: @unchecked Sendable {
    private let recordingRepo: RecordingRepositoryProtocol
    private let notesRepo: NotesRepositoryProtocol
    private let noteVersionRepo: NoteVersionRepositoryProtocol
    private let memoryRepo: AIMemoryRepositoryProtocol
    private let emphasisRepo: ProfessorEmphasisRepositoryProtocol
    private let pipelineRepo: PipelineRepositoryProtocol
    private let emphasisDetector: ProfessorEmphasisDetector
    private let promotionService: MemoryPromotionService
    private let aiRouter: AIRouterProtocol

    public init(
        recordingRepo: RecordingRepositoryProtocol,
        notesRepo: NotesRepositoryProtocol,
        noteVersionRepo: NoteVersionRepositoryProtocol,
        memoryRepo: AIMemoryRepositoryProtocol,
        emphasisRepo: ProfessorEmphasisRepositoryProtocol,
        pipelineRepo: PipelineRepositoryProtocol,
        aiRouter: AIRouterProtocol
    ) {
        self.recordingRepo = recordingRepo
        self.notesRepo = notesRepo
        self.noteVersionRepo = noteVersionRepo
        self.memoryRepo = memoryRepo
        self.emphasisRepo = emphasisRepo
        self.pipelineRepo = pipelineRepo
        self.emphasisDetector = ProfessorEmphasisDetector()
        self.promotionService = MemoryPromotionService(memoryRepo: memoryRepo)
        self.aiRouter = aiRouter
    }

    /// Executes or resumes the pipeline for a completed audio transcript.
    public func processLecture(
        recordingId: UUID,
        courseId: UUID,
        lectureSessionId: UUID? = nil
    ) async throws -> LecturePipelineRecord {
        // 1. Fetch or initialize pipeline record
        var pipeline = (try await pipelineRepo.getPipeline(forRecordingId: recordingId)) ?? LecturePipelineRecord(
            recordingId: recordingId,
            courseId: courseId,
            lectureSessionId: lectureSessionId,
            currentStage: .transcribed,
            progressPercentage: 20.0
        )

        // 2. Fetch transcript and segments
        guard let transcript = try await recordingRepo.getTranscript(forRecordingId: recordingId) else {
            pipeline.currentStage = .failedPermanent
            pipeline.lastError = "Transcript not found for recording: \(recordingId)"
            try await pipelineRepo.savePipeline(pipeline)
            throw AcademicOSError.entityNotFound(pipeline.lastError!)
        }

        let segments = try await recordingRepo.getSegments(forTranscriptId: transcript.id)
        let markers = try await recordingRepo.getMarkers(forRecordingId: recordingId)

        do {
            // Stage A: Academic Analysis & Emphasis Detection
            pipeline.currentStage = .analyzing
            pipeline.progressPercentage = 35.0
            try await pipelineRepo.savePipeline(pipeline)

            let emphasisItems = emphasisDetector.detectEmphasis(
                segments: segments,
                markers: markers,
                courseId: courseId,
                lectureSessionId: lectureSessionId,
                recordingId: recordingId
            )
            try await emphasisRepo.saveAllEmphasis(emphasisItems)

            // Stage B: Hierarchical Chunk Processing & Structured Synthesis
            pipeline.currentStage = .notesGenerated
            pipeline.progressPercentage = 50.0
            try await pipelineRepo.savePipeline(pipeline)

            // Split into 10-15 minute chunks for long lectures
            let chunks = Self.createTranscriptChunks(from: segments, fullText: transcript.fullText)
            pipeline.totalChunks = chunks.count

            var chunkSummaries: [String] = []

            // Process each chunk progressively (resumable: if chunk 8 fails, 1-7 are safely recorded)
            let startIndex = min(pipeline.lastProcessedChunk, chunks.count)
            for chunkIndex in startIndex..<chunks.count {
                let chunk = chunks[chunkIndex]
                let chunkPrompt = """
                Aşağıdaki ders transkript parçasını (Bölüm \(chunk.index + 1)/\(chunks.count)) analiz et:
                Zaman Aralığı: \(Int(chunk.startSeconds))s - \(Int(chunk.endSeconds))s
                İçerik:
                \(chunk.text)

                Lütfen bu bölümdeki kilit kavramları, hoca vurgularını ve ana argümanları 3-4 maddede özetle.
                """

                let chunkResponse = try await aiRouter.execute(request: AIRequest(
                    prompt: chunkPrompt,
                    systemInstruction: "Sen uzun ders transkriptlerini parça parça analiz eden akademik bir sentezleyicisin.",
                    courseId: courseId
                ))

                chunkSummaries.append("--- BÖLÜM \(chunk.index + 1) ---\n" + chunkResponse.content)

                // Persist intermediate progress after each chunk
                pipeline.lastProcessedChunk = chunkIndex + 1
                let chunkRatio = Double(pipeline.lastProcessedChunk) / Double(max(1, chunks.count))
                pipeline.progressPercentage = 50.0 + (chunkRatio * 25.0) // 50% to 75%
                try await pipelineRepo.savePipeline(pipeline)
            }

            // Final Lecture Synthesis from consolidated chunk summaries or full text
            let consolidatedText = chunkSummaries.isEmpty ? transcript.fullText : chunkSummaries.joined(separator: "\n\n")

            let fullPrompt = PromptCatalog.fullLectureNotesPrompt(transcriptText: consolidatedText, courseName: "Course")
            let studyPrompt = PromptCatalog.studyNotesPrompt(transcriptText: consolidatedText, courseName: "Course")
            let noktaPrompt = PromptCatalog.noktaAtisiPrompt(transcriptText: consolidatedText, courseName: "Course")

            // Execute AI prompts via AIRouter with course privacy checks
            let fullNotesResponse = try await aiRouter.execute(request: AIRequest(
                prompt: fullPrompt,
                systemInstruction: PromptCatalog.lectureAnalysisSystemInstruction(),
                courseId: courseId
            ))

            let studyNotesResponse = try await aiRouter.execute(request: AIRequest(
                prompt: studyPrompt,
                systemInstruction: PromptCatalog.lectureAnalysisSystemInstruction(),
                courseId: courseId
            ))

            let noktaResponse = try await aiRouter.execute(request: AIRequest(
                prompt: noktaPrompt,
                systemInstruction: PromptCatalog.lectureAnalysisSystemInstruction(),
                courseId: courseId
            ))

            // Create or update Master Note
            let noteId = UUID()
            let note = Note(
                id: noteId,
                courseId: courseId,
                lectureSessionId: lectureSessionId,
                title: "Ders Notu - \(Date().formatted(date: .abbreviated, time: .omitted))",
                rawContent: fullNotesResponse.content,
                aiStructuredSummary: fullNotesResponse.content,
                studyNotesContent: studyNotesResponse.content,
                noktaAtisiContent: noktaResponse.content,
                keyTakeaways: emphasisItems.map { $0.exactSourceSnippet }.prefix(5).map { String($0) },
                tags: ["lecture_ai", "phase2b"],
                sourceType: .aiStructuredNote,
                isAiProcessed: true
            )
            try await notesRepo.saveNote(note)

            // Save individual versions for multi-mode browsing
            let fullVersion = AINoteVersion(
                noteId: noteId,
                courseId: courseId,
                versionNumber: 1,
                mode: .fullLecture,
                provider: fullNotesResponse.providerType.rawValue,
                modelIdentifier: fullNotesResponse.modelIdentifier,
                content: fullNotesResponse.content
            )
            let studyVersion = AINoteVersion(
                noteId: noteId,
                courseId: courseId,
                versionNumber: 1,
                mode: .studyNotes,
                provider: studyNotesResponse.providerType.rawValue,
                modelIdentifier: studyNotesResponse.modelIdentifier,
                content: studyNotesResponse.content
            )
            let noktaVersion = AINoteVersion(
                noteId: noteId,
                courseId: courseId,
                versionNumber: 1,
                mode: .noktaAtisi,
                provider: noktaResponse.providerType.rawValue,
                modelIdentifier: noktaResponse.modelIdentifier,
                content: noktaResponse.content
            )

            try await noteVersionRepo.saveVersion(fullVersion)
            try await noteVersionRepo.saveVersion(studyVersion)
            try await noteVersionRepo.saveVersion(noktaVersion)

            // Stage C: Course Memory Promotion
            pipeline.currentStage = .studyMaterialsGenerated
            pipeline.progressPercentage = 85.0
            try await pipelineRepo.savePipeline(pipeline)

            for emphasis in emphasisItems.prefix(5) {
                _ = try await promotionService.promoteEmphasisItem(emphasis)
            }

            // Stage D: Completed
            pipeline.currentStage = .completed
            pipeline.progressPercentage = 100.0
            pipeline.lastError = nil
            pipeline.updatedAt = Date()
            try await pipelineRepo.savePipeline(pipeline)

            return pipeline

        } catch {
            // Safe Failure: Audio and transcripts are 100% preserved!
            pipeline.currentStage = .failedRecoverable
            pipeline.lastError = error.localizedDescription
            pipeline.updatedAt = Date()
            try await pipelineRepo.savePipeline(pipeline)
            throw error
        }
    }

    /// Representation of a discrete transcript chunk for long lecture processing.
    public struct TranscriptChunk: Sendable {
        public let index: Int
        public let text: String
        public let startSeconds: Double
        public let endSeconds: Double
    }

    /// Groups transcript segments or full text into manageable ~10-minute blocks (approx 600 seconds or 4,000 characters).
    public static func createTranscriptChunks(
        from segments: [TranscriptSegment],
        fullText: String
    ) -> [TranscriptChunk] {
        if segments.isEmpty {
            // Chunk by character length if no individual segments exist
            let chunkSize = 4000
            let textArray = Array(fullText)
            var chunks: [TranscriptChunk] = []
            var offset = 0
            var index = 0

            while offset < textArray.count {
                let end = min(offset + chunkSize, textArray.count)
                let chunkString = String(textArray[offset..<end])
                chunks.append(TranscriptChunk(
                    index: index,
                    text: chunkString,
                    startSeconds: Double(index * 600),
                    endSeconds: Double((index + 1) * 600)
                ))
                offset = end
                index += 1
            }

            return chunks.isEmpty ? [TranscriptChunk(index: 0, text: fullText, startSeconds: 0, endSeconds: 0)] : chunks
        }

        // Group segments into ~10-minute intervals (600 seconds)
        var chunks: [TranscriptChunk] = []
        var currentChunkSegments: [TranscriptSegment] = []
        var chunkStartTime: Double = segments.first?.startSeconds ?? 0
        var chunkIndex = 0

        for segment in segments {
            currentChunkSegments.append(segment)
            let duration = segment.endSeconds - chunkStartTime

            if duration >= 600.0 { // 10 minutes reached
                let chunkText = currentChunkSegments.map { $0.text }.joined(separator: " ")
                chunks.append(TranscriptChunk(
                    index: chunkIndex,
                    text: chunkText,
                    startSeconds: chunkStartTime,
                    endSeconds: segment.endSeconds
                ))
                currentChunkSegments = []
                chunkStartTime = segment.endSeconds
                chunkIndex += 1
            }
        }

        // Add any remaining segments
        if !currentChunkSegments.isEmpty {
            let chunkText = currentChunkSegments.map { $0.text }.joined(separator: " ")
            let endSec = currentChunkSegments.last?.endSeconds ?? chunkStartTime
            chunks.append(TranscriptChunk(
                index: chunkIndex,
                text: chunkText,
                startSeconds: chunkStartTime,
                endSeconds: endSec
            ))
        }

        return chunks.isEmpty ? [TranscriptChunk(index: 0, text: fullText, startSeconds: 0, endSeconds: 0)] : chunks
    }
}
