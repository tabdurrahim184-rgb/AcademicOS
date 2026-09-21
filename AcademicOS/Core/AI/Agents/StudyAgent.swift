import Foundation

/// Active recall, spaced repetition, and exam timetable coach.
public final class StudyAgent: Agent, @unchecked Sendable {
    public let id: String = "agent.study"
    public let name: String = "Study Agent"
    public let description: String = "Cognitive study coach generating spaced-repetition schedules, realistic revision blocks, and active-recall plans."
    public let iconName: String = "brain.head.profile"
    public var status: AgentStatus = .ready

    public let capabilities: [AgentCapability] = [
        AgentCapability(id: "study_plan", name: "Dynamic Study Plan", description: "Constructs realistic revision blocks prioritized by upcoming exam dates and weak topics."),
        AgentCapability(id: "weakness_targeting", name: "Weakness Targeting", description: "Directs study focus to low-mastery concepts."),
        AgentCapability(id: "time_blocking", name: "Cognitive Time Blocking", description: "Optimizes Pomodoro blocks according to course credit weight.")
    ]

    private let router: AIRouterProtocol

    public init(router: AIRouterProtocol) {
        self.router = router
    }

    public func execute(task: String, context: [String: String]) async throws -> String {
        let request = AIRequest(
            prompt: task,
            systemInstruction: "Sen AcademicOS Çalışma Koçusun. Gerçekçi, dakikalara bölünmüş, uygulanabilir çalışma seansları planla.",
            contextData: context
        )
        let response = try await router.execute(request: request)
        return response.content
    }

    /// Generates a realistic, minute-by-minute study plan based on real exam dates and student weaknesses.
    public func createStudyPlan(
        courseName: String,
        examDate: String?,
        weakTopics: [String],
        targetMinutes: Int = 45,
        courseId: UUID? = nil
    ) async throws -> String {
        let examInfo = examDate != nil ? "Yaklaşan Sınav: \(examDate!)" : "Rutin Tekrar"
        let weaknesses = weakTopics.isEmpty ? "Genel Ders Tekrarı" : weakTopics.joined(separator: ", ")

        let prompt = """
        DERS: \(courseName) (\(examInfo))
        TOPLAM SÜRE: \(targetMinutes) Dakika
        ÖNCELİKLİ / ZAYIF KONULAR: \(weaknesses)

        Lütfen bu ders için gerçekçi, dakikası dakikasına bir çalışma planı oluştur:
        Örnek format:
        \(courseName)
        \(targetMinutes) dakika

        - 15 dk — Temel Kavramlar & Not İnceleme
        - 10 dk — Zayıf Konu (\(weakTopics.first ?? "Püf Noktaları"))
        - 10 dk — Aktif Hatırlama & Flashcard Tekrarı
        - 10 dk — Mini Quiz ile Kendini Test Etme
        """

        let request = AIRequest(
            prompt: prompt,
            systemInstruction: "Sen öğrencinin zamanını en verimli şekilde kullandıran bir akademik çalışma stratejistisin.",
            courseId: courseId
        )

        let response = try await router.execute(request: request)
        return response.content
    }
}
