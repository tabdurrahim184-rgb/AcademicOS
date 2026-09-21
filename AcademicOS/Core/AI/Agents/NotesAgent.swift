import Foundation

/// Lecture notes synthesizer providing Full Notes, Study Notes, and Nokta Atışı sheet generation.
public final class NotesAgent: Agent, @unchecked Sendable {
    public let id: String = "agent.notes"
    public let name: String = "Notes Agent"
    public let description: String = "Multi-modal lecture note structuring intelligence producing Full Notes, Study Guides, and Nokta Atışı review sheets."
    public let iconName: String = "note.text.badge.plus"
    public var status: AgentStatus = .ready

    public let capabilities: [AgentCapability] = [
        AgentCapability(id: "full_lecture", name: "Full Lecture Notes", description: "Comprehensive, structured reconstruction of lecture discussions, concepts, and definitions."),
        AgentCapability(id: "study_notes", name: "Exam Study Notes", description: "Condensed high-yield notes focusing on comparisons and exam-oriented takeaways."),
        AgentCapability(id: "nokta_atisi", name: "Nokta Atışı Sheet", description: "Ultra-concise, 5-minute review sheet with Top 10 must-know items.")
    ]

    private let router: AIRouterProtocol

    public init(router: AIRouterProtocol) {
        self.router = router
    }

    public func execute(task: String, context: [String: String]) async throws -> String {
        let request = AIRequest(
            prompt: task,
            systemInstruction: PromptCatalog.lectureAnalysisSystemInstruction(),
            contextData: context
        )
        let response = try await router.execute(request: request)
        return response.content
    }

    /// Generates structured note content for a specific mode.
    public func generateNote(
        mode: NoteMode,
        transcriptText: String,
        courseName: String,
        courseId: UUID? = nil
    ) async throws -> String {
        let prompt: String
        switch mode {
        case .fullLecture:
            prompt = PromptCatalog.fullLectureNotesPrompt(transcriptText: transcriptText, courseName: courseName)
        case .studyNotes:
            prompt = PromptCatalog.studyNotesPrompt(transcriptText: transcriptText, courseName: courseName)
        case .noktaAtisi:
            prompt = PromptCatalog.noktaAtisiPrompt(transcriptText: transcriptText, courseName: courseName)
        }

        let request = AIRequest(
            prompt: prompt,
            systemInstruction: PromptCatalog.lectureAnalysisSystemInstruction(),
            temperature: 0.3,
            courseId: courseId,
            requiresStructuredOutput: true
        )

        let response = try await router.execute(request: request)
        return response.content
    }
}
