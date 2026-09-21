import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif

/// Classification of a portal item compared to local state.
public enum PortalItemDeltaStatus: String, Codable, Sendable {
    case new = "NEW"
    case updated = "UPDATED"
    case unchanged = "UNCHANGED"
    case possiblyRemoved = "POSSIBLY_REMOVED"
}

/// Change detection record for a specific portal entity.
public struct PortalItemDelta: Identifiable, Sendable, Equatable {
    public var id: String { entityID }
    public let entityType: String
    public let entityID: String
    public let title: String
    public let status: PortalItemDeltaStatus
    public let detail: String
    public let previousFingerprint: String?
    public let newFingerprint: String?

    public init(
        entityType: String,
        entityID: String,
        title: String,
        status: PortalItemDeltaStatus,
        detail: String,
        previousFingerprint: String? = nil,
        newFingerprint: String? = nil
    ) {
        self.entityType = entityType
        self.entityID = entityID
        self.title = title
        self.status = status
        self.detail = detail
        self.previousFingerprint = previousFingerprint
        self.newFingerprint = newFingerprint
    }
}

/// Result of a change detection pass over a university payload.
public struct PortalSyncDeltaSummary: Sendable, Equatable {
    public let newCount: Int
    public let updatedCount: Int
    public let unchangedCount: Int
    public let possiblyRemovedCount: Int
    public let deltas: [PortalItemDelta]

    public init(deltas: [PortalItemDelta]) {
        self.deltas = deltas
        self.newCount = deltas.filter { $0.status == .new }.count
        self.updatedCount = deltas.filter { $0.status == .updated }.count
        self.unchangedCount = deltas.filter { $0.status == .unchanged }.count
        self.possiblyRemovedCount = deltas.filter { $0.status == .possiblyRemoved }.count
    }
}

/// Detects changes between remote portal state and local AcademicOS SQLite state.
/// Strictly preserves local data: never silently deletes existing local records.
public final class PortalChangeDetectionEngine: Sendable {
    public static let shared = PortalChangeDetectionEngine()

    public init() {}

    /// Evaluates incoming exams against existing exams.
    public func evaluateExams(
        remoteExams: [RemoteExam],
        localExams: [Exam]
    ) -> [PortalItemDelta] {
        var deltas: [PortalItemDelta] = []
        var matchedLocalIds = Set<UUID>()

        for remote in remoteExams {
            let remoteFingerprint = computeFingerprint("\(remote.courseCode)|\(remote.title)|\(remote.examType)|\(remote.date)|\(remote.room ?? "")")
            let localMatch = localExams.first {
                $0.title.caseInsensitiveCompare(remote.title) == .orderedSame
            }

            if let local = localMatch {
                matchedLocalIds.insert(local.id)
                let localFingerprint = computeFingerprint("\(local.title)|\(local.examType)|\(local.examDate)|\(local.room ?? "")")

                if remoteFingerprint == localFingerprint {
                    deltas.append(PortalItemDelta(
                        entityType: "Exam",
                        entityID: remote.remoteId,
                        title: remote.title,
                        status: .unchanged,
                        detail: "Tarih ve salon değişmedi.",
                        previousFingerprint: localFingerprint,
                        newFingerprint: remoteFingerprint
                    ))
                } else {
                    deltas.append(PortalItemDelta(
                        entityType: "Exam",
                        entityID: remote.remoteId,
                        title: remote.title,
                        status: .updated,
                        detail: "Sınav tarihi veya salonu güncellendi: \(remote.room ?? "TBA")",
                        previousFingerprint: localFingerprint,
                        newFingerprint: remoteFingerprint
                    ))
                }
            } else {
                deltas.append(PortalItemDelta(
                    entityType: "Exam",
                    entityID: remote.remoteId,
                    title: remote.title,
                    status: .new,
                    detail: "Yeni sınav programlandı.",
                    previousFingerprint: nil,
                    newFingerprint: remoteFingerprint
                ))
            }
        }

        // Check for exams in local store not present in latest remote fetch
        for local in localExams {
            if !matchedLocalIds.contains(local.id) {
                deltas.append(PortalItemDelta(
                    entityType: "Exam",
                    entityID: local.id.uuidString,
                    title: local.title,
                    status: .possiblyRemoved,
                    detail: "Portalda artık listelenmiyor. Güvenlik gereği yerel kayıt silinmedi.",
                    previousFingerprint: nil,
                    newFingerprint: nil
                ))
            }
        }

        return deltas
    }

    /// Evaluates incoming assignments against existing tasks.
    public func evaluateAssignments(
        remoteAssignments: [RemoteAssignment],
        localTasks: [AcademicTask]
    ) -> [PortalItemDelta] {
        var deltas: [PortalItemDelta] = []
        for remote in remoteAssignments {
            let remoteFingerprint = computeFingerprint("\(remote.courseCode)|\(remote.title)|\(remote.dueDate)")
            let localMatch = localTasks.first {
                $0.title.contains(remote.title) || remote.title.contains($0.title)
            }

            if let local = localMatch {
                let localFingerprint = computeFingerprint("\(local.title)|\(local.dueDate ?? Date.distantPast)")
                if remoteFingerprint == localFingerprint {
                    deltas.append(PortalItemDelta(
                        entityType: "Assignment",
                        entityID: remote.remoteId,
                        title: remote.title,
                        status: .unchanged,
                        detail: "Teslim tarihi değişmedi.",
                        previousFingerprint: localFingerprint,
                        newFingerprint: remoteFingerprint
                    ))
                } else {
                    deltas.append(PortalItemDelta(
                        entityType: "Assignment",
                        entityID: remote.remoteId,
                        title: remote.title,
                        status: .updated,
                        detail: "Son teslim tarihi değişti.",
                        previousFingerprint: localFingerprint,
                        newFingerprint: remoteFingerprint
                    ))
                }
            } else {
                deltas.append(PortalItemDelta(
                    entityType: "Assignment",
                    entityID: remote.remoteId,
                    title: remote.title,
                    status: .new,
                    detail: "Yeni ödev eklendi.",
                    previousFingerprint: nil,
                    newFingerprint: remoteFingerprint
                ))
            }
        }
        return deltas
    }

    public func computeFingerprint(_ text: String) -> String {
        #if canImport(CryptoKit)
        let hash = SHA256.hash(data: Data(text.utf8))
        return hash.map { String(format: "%02x", $0) }.joined()
        #else
        return "fp-\(text.hashValue)"
        #endif
    }
}
