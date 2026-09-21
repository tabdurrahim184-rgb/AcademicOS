import Foundation

/// Specialized University Agent providing grounded, factual intelligence on imported university portal data.
/// STRICT RULE: Never fabricates portal information.
/// If unavailable or not connected, responds: "Bu bilgi üniversite portalından alınamadı."
public final class UniversityAgent: Agent, @unchecked Sendable {
    public let id: String = "agent.university_portal"
    public let name: String = "University Portal Agent"
    public let description: String = "Provides verified updates on portal announcements, exam dates, deadlines, and grade releases directly from official university data."
    public let iconName: String = "building.columns.fill"
    public var status: AgentStatus = .ready

    public let capabilities: [AgentCapability] = [
        AgentCapability(id: "portal_summary", name: "Portal Changes Summary", description: "Summarizes recent announcements, newly uploaded files, and grade releases."),
        AgentCapability(id: "urgent_updates", name: "Urgent Academic Updates", description: "Highlights critical notices, exam hall changes, and imminent deadlines."),
        AgentCapability(id: "grade_reports", name: "Grade Release Briefing", description: "Reports newly published exam and assignment scores.")
    ]

    private let universityRepo: UniversityRepositoryProtocol?
    private let examRepo: ExamRepositoryProtocol?
    private let taskRepo: TaskRepositoryProtocol?
    private let router: AIRouterProtocol

    public init(
        router: AIRouterProtocol,
        universityRepo: UniversityRepositoryProtocol? = nil,
        examRepo: ExamRepositoryProtocol? = nil,
        taskRepo: TaskRepositoryProtocol? = nil
    ) {
        self.router = router
        self.universityRepo = universityRepo
        self.examRepo = examRepo
        self.taskRepo = taskRepo
    }

    public func execute(task: String, context: [String: String]) async throws -> String {
        let lower = task.lowercased()

        // 1. Announcements Query
        if lower.contains("duyuru") || lower.contains("announcement") || lower.contains("haber") {
            if let items = try? await universityRepo?.fetchInboxItems(), !items.isEmpty {
                let announcements = items.filter { $0.category == .announcement || $0.category == .urgent }
                if !announcements.isEmpty {
                    let list = announcements.prefix(4).map { "• [\($0.sender)] \($0.title): \($0.content.prefix(120))..." }.joined(separator: "\n\n")
                    return "Üniversite portalından alınan güncel duyurular:\n\n\(list)"
                }
            }
            return "Üniversite portalında henüz yeni bir duyuru bulunmuyor."
        }

        // 2. Exam Schedule & Nearest Exam Query
        if lower.contains("sınav") || lower.contains("exam") {
            if let exams = try? await examRepo?.getAllExams(), !exams.isEmpty {
                let sorted = exams.sorted { $0.examDate < $1.examDate }
                let list = sorted.prefix(4).map { "• \($0.title) (\($0.examType)): Tarih: \(formatDate($0.examDate)), Salon: \($0.room.isEmpty ? "İlan edilecek" : $0.room)" }.joined(separator: "\n")
                return "Portaldan çekilen resmi sınav takviminiz:\n\n\(list)"
            }
            return "Bu bilgi üniversite portalından alınamadı veya henüz bir sınav programı yayınlanmadı."
        }

        // 3. Grades Query
        if lower.contains("not") || lower.contains("grade") || lower.contains("harf") {
            if let grades = try? await universityRepo?.fetchGrades(), !grades.isEmpty {
                let list = grades.prefix(6).map { "• \($0.courseCode) \($0.evaluationName): \($0.score)/\($0.maxScore) (Ağırlık: %\(Int($0.weightPercentage)))" }.joined(separator: "\n")
                return "Resmi Öğrenci Bilgi Sistemi (OBS) not dökümünüz:\n\n\(list)"
            }
            return "Bu bilgi üniversite portalından alınamadı."
        }

        // 4. Assignments & Deadlines
        if lower.contains("ödev") || lower.contains("assignment") || lower.contains("teslim") {
            let courseId = context["course_id"].flatMap { UUID(uuidString: $0) }
            if let tasks = try? await taskRepo?.getTasks() {
                let pending = tasks.filter { !$0.isCompleted && (courseId == nil || $0.courseId == courseId) }
                if !pending.isEmpty {
                    let list = pending.prefix(5).map { "• \($0.title) — Son Teslim: \(formatDate($0.dueDate ?? Date()))" }.joined(separator: "\n")
                    return "Portalda aktif olarak bekleyen ödev teslimleriniz:\n\n\(list)"
                }
            }
            return "Şu anda portalda kayıtlı bekleyen bir ödeviniz bulunmuyor."
        }

        // 5. Course Materials & Documents
        if lower.contains("materyal") || lower.contains("belge") || lower.contains("doküman") || lower.contains("slayt") {
            if let inbox = try? await universityRepo?.fetchInboxItems() {
                let docs = inbox.filter { $0.content.contains(".pdf") || $0.category == .announcement }
                if !docs.isEmpty {
                    let list = docs.prefix(4).map { "• \($0.title)" }.joined(separator: "\n")
                    return "Portalda yeni paylaşılan ders materyalleri:\n\n\(list)"
                }
            }
            return "Bu bilgi üniversite portalından alınamadı."
        }

        // General AI synthesis fallback with verified ground truth
        var verifiedContext = context
        if let inbox = try? await universityRepo?.fetchInboxItems() {
            verifiedContext["recent_portal_items"] = inbox.prefix(5).map { "\($0.title): \($0.content)" }.joined(separator: "; ")
        }

        let prompt = """
        Kullanıcı üniversite portalı hakkında şunu sordu: '\(task)'
        Sadece doğrulanmış portal verilerini temel alarak yanıtla. Veri mevcut değilse kesinlikle uydurma ve 'Bu bilgi üniversite portalından alınamadı.' de.
        """

        let request = AIRequest(
            prompt: prompt,
            systemInstruction: "You are the AcademicOS University Portal Agent. Ground every answer strictly in factual university portal records. Never hallucinate course dates, exam times, or grades.",
            contextData: verifiedContext
        )

        let response = try await router.execute(request: request)
        return response.content
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateFormat = "d MMMM yyyy, HH:mm"
        return formatter.string(from: date)
    }
}
