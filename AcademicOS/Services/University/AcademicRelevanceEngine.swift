import Foundation

/// Academic priority ranking for imported portal items and events.
public enum AcademicRelevanceTier: String, Codable, Sendable, Comparable {
    case critical = "CRITICAL"
    case high = "HIGH"
    case normal = "NORMAL"
    case low = "LOW"

    private var priorityValue: Int {
        switch self {
        case .critical: return 4
        case .high: return 3
        case .normal: return 2
        case .low: return 1
        }
    }

    public static func < (lhs: AcademicRelevanceTier, rhs: AcademicRelevanceTier) -> Bool {
        return lhs.priorityValue < rhs.priorityValue
    }
}

/// Evaluated relevance item with reasoning.
public struct EvaluatedRelevanceItem: Sendable, Equatable {
    public let title: String
    public let tier: AcademicRelevanceTier
    public let rationale: String
    public let actionRequired: Bool

    public init(
        title: String,
        tier: AcademicRelevanceTier,
        rationale: String,
        actionRequired: Bool
    ) {
        self.title = title
        self.tier = tier
        self.rationale = rationale
        self.actionRequired = actionRequired
    }
}

/// Evaluates real university portal records and prioritizes them based on time urgency, exam impact, and deadlines.
public final class AcademicRelevanceEngine: Sendable {
    public static let shared = AcademicRelevanceEngine()

    public init() {}

    /// Evaluates an exam delta.
    public func evaluateExamDelta(delta: PortalItemDelta, examDate: Date) -> EvaluatedRelevanceItem {
        if delta.status == .updated {
            return EvaluatedRelevanceItem(
                title: delta.title,
                tier: .critical,
                rationale: "Sınav tarihi veya yeri değişti! Acil kontrol gerekli.",
                actionRequired: true
            )
        } else if delta.status == .new {
            return EvaluatedRelevanceItem(
                title: delta.title,
                tier: .high,
                rationale: "Yeni sınav programlandı. Takvim ve çalışma planı güncellendi.",
                actionRequired: false
            )
        }
        return EvaluatedRelevanceItem(
            title: delta.title,
            tier: .normal,
            rationale: "Sınav bilgisi güncel.",
            actionRequired: false
        )
    }

    /// Evaluates an assignment deadline.
    public func evaluateAssignmentDeadline(dueDate: Date, title: String) -> EvaluatedRelevanceItem {
        let timeRemaining = dueDate.timeIntervalSince(Date())
        let hoursRemaining = timeRemaining / 3600.0

        if hoursRemaining <= 24 && hoursRemaining >= 0 {
            return EvaluatedRelevanceItem(
                title: title,
                tier: .critical,
                rationale: "Son 24 saat içinde teslim edilmesi gerekiyor! (\(Int(hoursRemaining)) saat kaldı)",
                actionRequired: true
            )
        } else if hoursRemaining < 0 {
            return EvaluatedRelevanceItem(
                title: title,
                tier: .critical,
                rationale: "Teslim süresi dolmuş görev.",
                actionRequired: true
            )
        } else if hoursRemaining <= 72 {
            return EvaluatedRelevanceItem(
                title: title,
                tier: .high,
                rationale: "Yaklaşan ödev teslimi (3 gün içinde).",
                actionRequired: false
            )
        }
        return EvaluatedRelevanceItem(
            title: title,
            tier: .normal,
            rationale: "Normal teslim süreli ödev.",
            actionRequired: false
        )
    }

    /// Evaluates a grade release.
    public func evaluateGradeRelease(grade: RemoteGrade) -> EvaluatedRelevanceItem {
        return EvaluatedRelevanceItem(
            title: "\(grade.courseCode) \(grade.evaluationName): \(grade.score)",
            tier: .high,
            rationale: "Yeni resmi not açıklandı.",
            actionRequired: false
        )
    }

    /// Evaluates an announcement based on content and urgency.
    public func evaluateAnnouncement(announcement: RemoteAnnouncement) -> EvaluatedRelevanceItem {
        let lower = (announcement.title + " " + announcement.body).lowercased()

        if announcement.isUrgent || lower.contains("acil") || lower.contains("iptal") || lower.contains("ertelem") || lower.contains("deadline") {
            return EvaluatedRelevanceItem(
                title: announcement.title,
                tier: .critical,
                rationale: "Acil duyuru: Program değişikliği veya kritik uyarı içeriyor.",
                actionRequired: true
            )
        }

        if lower.contains("sınav") || lower.contains("vize") || lower.contains("final") || lower.contains("kapsam") || lower.contains("ödev") {
            return EvaluatedRelevanceItem(
                title: announcement.title,
                tier: .high,
                rationale: "Sınav veya ödev ile doğrudan ilgili akademik duyuru.",
                actionRequired: false
            )
        }

        if lower.contains("slayt") || lower.contains("materyal") || lower.contains("hafta") {
            return EvaluatedRelevanceItem(
                title: announcement.title,
                tier: .normal,
                rationale: "Ders içeriği ve haftalık materyal duyurusu.",
                actionRequired: false
            )
        }

        return EvaluatedRelevanceItem(
            title: announcement.title,
            tier: .low,
            rationale: "Genel duyuru veya bilgilendirme.",
            actionRequired: false
        )
    }
}
