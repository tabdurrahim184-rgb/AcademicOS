import Foundation

/// Course-specific intelligence maintaining isolated memory and material-grounded reasoning.
public final class CourseAgent: Agent, @unchecked Sendable {
    public let id: String = "agent.course"
    public let name: String = "Course Agent"
    public let description: String = "Subject matter specialist maintaining isolated memory for each university course."
    public let iconName: String = "books.vertical.fill"
    public var status: AgentStatus = .ready

    public let capabilities: [AgentCapability] = [
        AgentCapability(id: "my_materials_only", name: "Strict Material Grounding", description: "Answers strictly from stored lecture notes and transcripts without external hallucination."),
        AgentCapability(id: "isolated_memory", name: "Course AI Memory", description: "Maintains dedicated fact and emphasis memory restricted to this course."),
        AgentCapability(id: "concept_comparison", name: "Academic Concept Comparison", description: "Compares theories and case studies grounded in lecture records.")
    ]

    private let router: AIRouterProtocol

    public init(router: AIRouterProtocol) {
        self.router = router
    }

    public func execute(task: String, context: [String: String]) async throws -> String {
        let courseCode = context["course_code"] ?? "General Course"
        let myMaterialsOnly = (context["my_materials_only"] == "true")
        let courseIdString = context["course_id"]
        let courseId = courseIdString.flatMap { UUID(uuidString: $0) }

        let systemInstruction = PromptCatalog.courseChatSystemInstruction(
            courseName: courseCode,
            myMaterialsOnly: myMaterialsOnly
        )

        let request = AIRequest(
            prompt: task,
            systemInstruction: systemInstruction,
            contextData: context,
            temperature: myMaterialsOnly ? 0.1 : 0.4,
            courseId: courseId,
            requiresStructuredOutput: false
        )

        let response = try await router.execute(request: request)
        return response.content
    }

    /// Specialized execution supporting "My Materials Only" mode check.
    public func queryCourse(
        courseId: UUID,
        courseName: String,
        question: String,
        context: [String: String],
        myMaterialsOnly: Bool
    ) async throws -> (content: String, provider: AIProviderType, isGrounded: Bool) {
        var enrichedContext = context
        enrichedContext["my_materials_only"] = myMaterialsOnly ? "true" : "false"
        enrichedContext["course_id"] = courseId.uuidString
        enrichedContext["course_code"] = courseName

        // Data-layer check: If My Materials Only is active, verify material presence
        if myMaterialsOnly {
            let hasNotes = context["course_notes"] != nil && !(context["course_notes"]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            let hasTranscript = context["recent_lecture_transcript"] != nil && !(context["recent_lecture_transcript"]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            let hasMemory = context["course_memory"] != nil && !(context["course_memory"]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)

            if !hasNotes && !hasTranscript && !hasMemory {
                return (
                    content: "The answer is not present in the materials stored for this course. (Bu sorunun cevabı ders için kayıtlı mevcut materyallerde bulunmamaktadır.)",
                    provider: .local,
                    isGrounded: false
                )
            }
        }

        let systemInstruction = PromptCatalog.courseChatSystemInstruction(
            courseName: courseName,
            myMaterialsOnly: myMaterialsOnly
        )

        let request = AIRequest(
            prompt: question,
            systemInstruction: systemInstruction,
            contextData: enrichedContext,
            temperature: myMaterialsOnly ? 0.1 : 0.4,
            courseId: courseId
        )

        let response = try await router.execute(request: request)
        let isGrounded = !response.content.contains("bulunmamaktadır") && !response.content.contains("not present in the materials")

        return (response.content, response.providerType, isGrounded)
    }
}
