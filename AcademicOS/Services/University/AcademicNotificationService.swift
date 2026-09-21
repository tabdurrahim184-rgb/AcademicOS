import Foundation
#if canImport(UserNotifications)
import UserNotifications
#endif

/// Interface for managing academic alerts and local push notifications.
public protocol AcademicNotificationServiceProtocol: Sendable {
    func requestAuthorization() async -> Bool
    func scheduleExamNotification(exam: Exam, courseCode: String) async
    func scheduleAssignmentNotification(task: AcademicTask, courseCode: String) async
    func postUrgentAnnouncementNotification(title: String, body: String) async
    func cancelNotifications(for identifier: String) async
}

/// Dispatches native local notifications via UNUserNotificationCenter.
public final class AcademicNotificationService: AcademicNotificationServiceProtocol, @unchecked Sendable {
    public static let shared = AcademicNotificationService()

    public init() {}

    public func requestAuthorization() async -> Bool {
        #if canImport(UserNotifications)
        do {
            let center = UNUserNotificationCenter.current()
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            return false
        }
        #else
        return true
        #endif
    }

    public func scheduleExamNotification(exam: Exam, courseCode: String) async {
        #if canImport(UserNotifications)
        let center = UNUserNotificationCenter.current()

        // 1 day before exam
        let alertDate = exam.examDate.addingTimeInterval(-86400)
        guard alertDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Exam Tomorrow: \(courseCode)"
        content.body = "\(exam.title) is scheduled for \(formatDate(exam.examDate)). Check your notes and Nokta Atışı sheet!"
        content.sound = .default
        content.categoryIdentifier = "EXAM_REMINDER"

        let triggerComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: alertDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)

        let request = UNNotificationRequest(
            identifier: "academicos.exam.\(exam.id.uuidString)",
            content: content,
            trigger: trigger
        )

        try? await center.add(request)
        #endif
    }

    public func scheduleAssignmentNotification(task: AcademicTask, courseCode: String) async {
        #if canImport(UserNotifications)
        guard let due = task.dueDate else { return }
        let alertDate = due.addingTimeInterval(-43200) // 12 hours before
        guard alertDate > Date() else { return }

        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = "Assignment Due Soon: \(courseCode)"
        content.body = "\(task.title) is due in 12 hours."
        content.sound = .default

        let triggerComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: alertDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)

        let request = UNNotificationRequest(
            identifier: "academicos.task.\(task.id.uuidString)",
            content: content,
            trigger: trigger
        )

        try? await center.add(request)
        #endif
    }

    public func postUrgentAnnouncementNotification(title: String, body: String) async {
        #if canImport(UserNotifications)
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = "⚠️ URGENT: \(title)"
        content.body = body
        content.sound = .defaultCritical

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "academicos.urgent.\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        try? await center.add(request)
        #endif
    }

    public func cancelNotifications(for identifier: String) async {
        #if canImport(UserNotifications)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        #endif
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
