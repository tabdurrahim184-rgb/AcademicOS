import Foundation

/// Service managing durable change history and notification filtering for university synchronization.
/// Prevents notification fatigue by strictly triggering alerts only on meaningful academic changes.
public actor NEUChangeHistoryService {
    public static let shared = NEUChangeHistoryService()

    private var changeRecords: [PortalChangeRecord] = []

    public init() {}

    /// Records a detected portal change and evaluates whether it qualifies for user notification.
    public func recordChange(
        changeType: PortalChangeType,
        entityId: String,
        courseCode: String? = nil,
        title: String,
        oldValue: String? = nil,
        newValue: String,
        source: AcademicDataSourceBadge
    ) -> (record: PortalChangeRecord, shouldNotify: Bool) {
        let record = PortalChangeRecord(
            changeType: changeType,
            entityId: entityId,
            courseCode: courseCode,
            title: title,
            oldValue: oldValue,
            newValue: newValue,
            source: source,
            detectedAt: Date()
        )
        changeRecords.insert(record, at: 0)

        // Notification Policy:
        // NEVER notify on routine sync or unchanged items.
        // ONLY notify on critical deadline, grade, exam date, or urgent announcement changes.
        let shouldNotify: Bool
        switch changeType {
        case .gradePublished:
            shouldNotify = true
        case .examDateChanged:
            shouldNotify = true
        case .assignmentDeadlineChanged:
            shouldNotify = true
        case .assignmentAdded:
            shouldNotify = true
        case .materialAdded:
            // Only notify if new course material is explicitly uploaded
            shouldNotify = false // kept in history/inbox, no push spam
        case .announcementUpdated:
            shouldNotify = false
        }

        return (record, shouldNotify)
    }

    /// Returns all durable change records for auditing.
    public func getHistory() -> [PortalChangeRecord] {
        return changeRecords
    }

    /// Clears change history.
    public func clearHistory() {
        changeRecords.removeAll()
    }

    /// Compares previous payload with fresh payload to extract delta records.
    public func detectDeltas(
        previousPayload: RemoteUniversityPayload?,
        freshPayload: RemoteUniversityPayload,
        source: AcademicDataSourceBadge
    ) -> [PortalChangeRecord] {
        guard let prev = previousPayload else {
            // Initial sync: do not blast notifications for existing history
            return []
        }

        var detected: [PortalChangeRecord] = []

        // 1. Detect New Grades
        let prevGradeIds = Set(prev.grades.map { "\($0.courseCode)_\($0.name)" })
        for grade in freshPayload.grades {
            let key = "\(grade.courseCode)_\(grade.name)"
            if !prevGradeIds.contains(key) {
                let rec = PortalChangeRecord(
                    changeType: .gradePublished,
                    entityId: key,
                    courseCode: grade.courseCode,
                    title: "\(grade.courseCode) - \(grade.name) Notu Açıklandı",
                    oldValue: nil,
                    newValue: "\(grade.letterGrade ?? String(grade.score ?? 0))",
                    source: source
                )
                detected.append(rec)
            }
        }

        // 2. Detect Exam Date Changes
        var prevExamMap: [String: RemoteExam] = [:]
        for e in prev.exams { prevExamMap["\(e.courseCode)_\(e.title)"] = e }
        for exam in freshPayload.exams {
            let key = "\(exam.courseCode)_\(exam.title)"
            if let old = prevExamMap[key], old.date != exam.date {
                let rec = PortalChangeRecord(
                    changeType: .examDateChanged,
                    entityId: key,
                    courseCode: exam.courseCode,
                    title: "\(exam.courseCode) Sınav Tarihi Güncellendi",
                    oldValue: old.date.formatted(date: .numeric, time: .shortened),
                    newValue: exam.date.formatted(date: .numeric, time: .shortened),
                    source: source
                )
                detected.append(rec)
            }
        }

        // 3. Detect Assignment Deadline Changes
        var prevAssignMap: [String: RemoteAssignment] = [:]
        for a in prev.assignments { prevAssignMap["\(a.courseCode)_\(a.title)"] = a }
        for assign in freshPayload.assignments {
            let key = "\(assign.courseCode)_\(assign.title)"
            if let old = prevAssignMap[key], old.dueDate != assign.dueDate {
                let rec = PortalChangeRecord(
                    changeType: .assignmentDeadlineChanged,
                    entityId: key,
                    courseCode: assign.courseCode,
                    title: "\(assign.courseCode) Ödev Teslim Tarihi Değişti",
                    oldValue: old.dueDate.formatted(date: .numeric, time: .shortened),
                    newValue: assign.dueDate.formatted(date: .numeric, time: .shortened),
                    source: source
                )
                detected.append(rec)
            } else if prevAssignMap[key] == nil {
                let rec = PortalChangeRecord(
                    changeType: .assignmentAdded,
                    entityId: key,
                    courseCode: assign.courseCode,
                    title: "\(assign.courseCode) Yeni Ödev: \(assign.title)",
                    oldValue: nil,
                    newValue: assign.dueDate.formatted(date: .numeric, time: .shortened),
                    source: source
                )
                detected.append(rec)
            }
        }

        for d in detected {
            changeRecords.insert(d, at: 0)
        }

        return detected
    }
}
