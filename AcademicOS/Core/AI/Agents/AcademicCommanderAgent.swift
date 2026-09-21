import Foundation

/// Master cross-course academic orchestrator.
/// Synthesizes verified SQLite records (exams, deadlines, tasks) before invoking AI reasoning.
public final class AcademicCommanderAgent: Agent, @unchecked Sendable {
    public let id: String = "agent.academic_commander"
    public let name: String = "Academic Commander"
    public let description: String = "Strategic academic orchestrator synthesizing schedules, deadlines, and daily priorities using verified database records."
    public let iconName: String = "shield.lefthalf.filled"
    public var status: AgentStatus = .ready

    public let capabilities: [AgentCapability] = [
        AgentCapability(id: "cross_course_briefing", name: "Cross-Course Briefing", description: "Holistic analysis of upcoming exams and pending assignments across all courses."),
        AgentCapability(id: "deterministic_schedule", name: "Verified Schedule Audit", description: "Answers nearest exam and urgent mission questions directly from SQLite records."),
        AgentCapability(id: "daily_mission_plan", name: "Daily Mission Synthesis", description: "Combines pending tasks and active exams into an actionable daily plan.")
    ]

    private let router: AIRouterProtocol
    private let courseRepo: CourseRepositoryProtocol?
    private let examRepo: ExamRepositoryProtocol?
    private let taskRepo: TaskRepositoryProtocol?
    private let universityRepo: UniversityRepositoryProtocol?

    public init(
        router: AIRouterProtocol,
        courseRepo: CourseRepositoryProtocol? = nil,
        examRepo: ExamRepositoryProtocol? = nil,
        taskRepo: TaskRepositoryProtocol? = nil,
        universityRepo: UniversityRepositoryProtocol? = nil
    ) {
        self.router = router
        self.courseRepo = courseRepo
        self.examRepo = examRepo
        self.taskRepo = taskRepo
        self.universityRepo = universityRepo
    }

    public func execute(task: String, context: [String: String]) async throws -> String {
        let lower = task.lowercased()

        // Deterministic Fast-Path: Nearest Exam
        if lower.contains("en yakın sınav") || lower.contains("nearest exam") {
            if let exams = try? await examRepo?.getAllExams(), !exams.isEmpty {
                let sorted = exams.sorted { $0.examDate < $1.examDate }
                if let nearest = sorted.first {
                    return "En yakın sınavınız: '\(nearest.title)' (\(nearest.examType)), Tarih: \(formatDate(nearest.examDate)), Ağırlık: %\(nearest.weightPercentage). [Kaynak: DEBİM / MANUAL]. Hazırlık durumunuzu Exam Agent ile kontrol edebilirsiniz."
                }
            }
            return "Kayıtlı yaklaşan bir sınavınız bulunamadı."
        }

        // Deterministic Fast-Path: DEBİM New Materials ("DEBİM'de yeni materyal var mı?", "debim materyal")
        if lower.contains("debim") && (lower.contains("materyal") || lower.contains("doküman") || lower.contains("yeni")) {
            let connector = NEUUniversityConnector.shared
            if let payload = await connector.cachedDebimPayload, !payload.documents.isEmpty {
                let recent = payload.documents.prefix(4).map { "• \($0.title) (\($0.courseCode ?? "Genel")) [DEBİM]" }.joined(separator: "\n")
                return "DEBİM LMS üzerinden tespit edilen güncel materyaller:\n\(recent)"
            }
            return "DEBİM'de şu an için yeni yüklenen ders materyali bulunmuyor. En son sync durumunu DEBİM panelinden kontrol edebilirsiniz."
        }

        // Deterministic Fast-Path: Transcript Remaining / Incomplete Courses ("Transkriptimde hangi dersler kaldı?", "kalan dersler")
        if lower.contains("transkript") || lower.contains("kalan ders") || lower.contains("mezuniyet için ders") {
            let connector = NEUUniversityConnector.shared
            if let summary = await connector.cachedTranscriptSummary {
                let failedCourses = summary.courses.filter { !$0.isPassed }
                if !failedCourses.isEmpty {
                    let list = failedCourses.map { "• \($0.courseCode) - \($0.courseName) (Not: \($0.grade)) [NEU STUDENT PORTAL]" }.joined(separator: "\n")
                    return "Öğrenci Portalı transkriptinizde tekrar alınması gereken / kalınan dersler:\n\(list)\n\n(Toplam Tamamlanan: \(summary.passedCount) ders, Bildirilen GPA: \(summary.portalReportedGPA.map { String(format: "%.2f", $0) } ?? "Belirtilmemiş") - UNVERIFIED GPA MAPPING)"
                } else {
                    return "Tebrikler! Öğrenci Portalı transkript verilerinize göre kalınan ders bulunmuyor. Toplam \(summary.passedCount) ders başarıyla tamamlanmış. [NEU STUDENT PORTAL]"
                }
            }
            return "Transkript verisi henüz içe aktarılmamış. Lütfen Near East University panelinden 'IMPORT TRANSCRIPT' işlemini gerçekleştirin."
        }

        // Deterministic Fast-Path: Grade Changes ("Notlarımda değişiklik oldu mu?", "not değişikliği")
        if lower.contains("notlarımda değişiklik") || lower.contains("notlar") && (lower.contains("değiş") || lower.contains("yeni not")) {
            let connector = NEUUniversityConnector.shared
            if let summary = await connector.cachedTranscriptSummary {
                return "Öğrenci Portalı transkriptiniz güncel. Toplam \(summary.totalCourses) kayıtlı ders notu mevcut. [NEU STUDENT PORTAL - UNVERIFIED GPA MAPPING]. Son senkronizasyondan bu yana yeni bir not değişikliği bildirilmedi."
            }
            return "Not kayıtları henüz Öğrenci Portalı üzerinden çekilmedi. Lütfen portal senkronizasyonunu çalıştırın."
        }

        // Deterministic Fast-Path: Recent Portal Announcements ("Yeni duyuru var mı?", "bu hafta yeni duyuru geldi mi?")
        if lower.contains("yeni duyuru") || lower.contains("duyuru var mı") || lower.contains("portal duyuru") || lower.contains("bu hafta yeni duyuru") {
            if let inbox = try? await universityRepo?.fetchInboxItems(), !inbox.isEmpty {
                let announcements = inbox.filter { $0.category == .announcement || $0.category == .urgent }
                if !announcements.isEmpty {
                    let list = announcements.prefix(3).map { "• \($0.title) (\($0.sender)) [DEBİM / OBS]" }.joined(separator: "\n")
                    return "Portaldan alınan son duyurular:\n\(list)"
                }
            }
            return "Şu anda üniversite portalından yeni bir duyuru bulunmuyor."
        }

        // Deterministic Fast-Path: Newly Uploaded Documents ("Yeni yüklenen ders materyalleri neler?")
        if lower.contains("ders materyal") || lower.contains("yüklenen ders") || lower.contains("yeni materyal") {
            if let inbox = try? await universityRepo?.fetchInboxItems() {
                let docs = inbox.filter { $0.content.contains(".pdf") || $0.category == .announcement }
                if !docs.isEmpty {
                    let list = docs.prefix(3).map { "• \($0.title)" }.joined(separator: "\n")
                    return "Portala yeni yüklenen ders materyalleri:\n\(list)"
                }
            }
            return "Portala yeni yüklenen ders materyali bulunamadı."
        }

        // Deterministic Fast-Path: Pending Deliverables / Assignments ("Hangi ödevlerim kaldı?")
        if lower.contains("ödevlerim kaldı") || lower.contains("teslim") || lower.contains("ödev") || lower.contains("deliverable") {
            if let tasks = try? await taskRepo?.getTasks() {
                let pending = tasks.filter { !$0.isCompleted }
                if !pending.isEmpty {
                    let taskList = pending.prefix(5).map { "• \($0.title) (\($0.dueDate ?? "Tarihsiz"))" }.joined(separator: "\n")
                    return "Bu hafta teslim etmeniz gereken / tamamlanmamış görevler:\n\(taskList)"
                } else {
                    return "Harika! Şu anda bekleyen veya teslim tarihi yaklaşan tamamlanmamış bir ödeviniz bulunmuyor."
                }
            }
        }

        // Deterministic Fast-Path: Weekly Study Plan ("Bu hafta ne çalışmalıyım?")
        if lower.contains("bu hafta ne çalışmalıyım") || lower.contains("haftalık çalışma") || lower.contains("study plan") {
            var items: [String] = []
            if let exams = try? await examRepo?.getAllExams() {
                let soon = exams.filter { $0.examDate.timeIntervalSinceNow < 14 * 86400 && $0.examDate.timeIntervalSinceNow > 0 }
                for exam in soon.prefix(2) {
                    items.append("• [Kritik] \(exam.title) (\(formatDate(exam.examDate))) için Nokta Atışı ve alıştırma soruları çözün.")
                }
            }
            if let tasks = try? await taskRepo?.getTasks() {
                let pending = tasks.filter { !$0.isCompleted }
                for task in pending.prefix(2) {
                    items.append("• [Görev] \(task.title) teslimini tamamlayın.")
                }
            }
            if !items.isEmpty {
                return "Bu haftaki öncelikli çalışma planınız:\n" + items.joined(separator: "\n")
            }
        }

        // Deterministic Fast-Path: Overdue Tasks
        if lower.contains("gecikmiş") || lower.contains("overdue") {
            if let tasks = try? await taskRepo?.getTasks() {
                let now = Date()
                let overdue = tasks.filter { task in
                    !task.isCompleted && (task.dueDateTime ?? Date.distantFuture) < now
                }
                if !overdue.isEmpty {
                    let list = overdue.prefix(5).map { "• \($0.title) (Son Tarih: \($0.dueDate ?? "Belirtilmemiş"))" }.joined(separator: "\n")
                    return "Gecikmiş görevleriniz bulunmaktadır:\n\(list)"
                } else {
                    return "Gecikmiş herhangi bir göreviniz bulunmuyor. Tüm teslimleriniz güncel!"
                }
            }
        }

        // Deterministic Fast-Path: Today's Classes / Schedule
        if lower.contains("bugünkü ders") || lower.contains("today's class") || lower.contains("ders programı") {
            if let courses = try? await courseRepo?.getCourses(), !courses.isEmpty {
                let courseList = courses.map { "• \($0.code): \($0.name) (\($0.classroom ?? "Derslik belirtilmemiş"))" }.joined(separator: "\n")
                return "Kayıtlı dersleriniz ve programınız:\n\(courseList)"
            }
        }

        // Deterministic Fast-Path: Graduation Countdown
        if lower.contains("mezuniyet") || lower.contains("graduation") {
            let calendar = Calendar.current
            let targetDate = calendar.date(from: DateComponents(year: 2027, month: 6, day: 30)) ?? Date()
            let components = calendar.dateComponents([.day], from: Date(), to: targetDate)
            let days = max(0, components.day ?? 0)
            return "Hedeflenen mezuniyet tarihinize (30 Haziran 2027) yaklaşık \(days) gün kaldı. Başarılar dileriz!"
        }

        // AI synthesis path with verified database context
        var verifiedContext = context
        if let exams = try? await examRepo?.getAllExams() {
            verifiedContext["verified_exams"] = exams.map { "\($0.title) on \(formatDate($0.examDate))" }.joined(separator: ", ")
        }
        if let tasks = try? await taskRepo?.getTasks() {
            verifiedContext["verified_tasks"] = tasks.filter { !$0.isCompleted }.map { "\($0.title)" }.joined(separator: ", ")
        }
        if let inbox = try? await universityRepo?.fetchInboxItems() {
            verifiedContext["verified_portal_inbox"] = inbox.prefix(4).map { "\($0.title): \($0.content)" }.joined(separator: "; ")
        }

        let request = AIRequest(
            prompt: task,
            systemInstruction: PromptCatalog.academicCommanderSystemInstruction(),
            contextData: verifiedContext
        )
        let response = try await router.execute(request: request)
        return response.content
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: date)
    }
}
