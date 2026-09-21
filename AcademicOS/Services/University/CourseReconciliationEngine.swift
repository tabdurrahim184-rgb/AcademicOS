import Foundation

/// Strategy or confidence tier by which a portal course was reconciled with a local course.
public enum CourseMatchStrategy: String, Codable, Sendable {
    case exactCode = "Exact Course Code"
    case normalizedCode = "Normalized Code"
    case exactTitle = "Exact Course Title"
    case highConfidenceTitle = "High-Confidence Title Match"
    case manualSelectionRequired = "Manual Selection Required"
}

/// Result of course reconciliation.
public struct CourseReconciliationResult: Identifiable, Sendable, Equatable {
    public var id: String { remoteCourse.remoteId }
    public let remoteCourse: RemoteCourse
    public let matchedLocalCourse: Course?
    public let strategy: CourseMatchStrategy
    public let confidenceScore: Double
    public let requiresUserConfirmation: Bool

    public init(
        remoteCourse: RemoteCourse,
        matchedLocalCourse: Course?,
        strategy: CourseMatchStrategy,
        confidenceScore: Double,
        requiresUserConfirmation: Bool
    ) {
        self.remoteCourse = remoteCourse
        self.matchedLocalCourse = matchedLocalCourse
        self.strategy = strategy
        self.confidenceScore = confidenceScore
        self.requiresUserConfirmation = requiresUserConfirmation
    }
}

/// Reconciles courses imported from real university portals with local AcademicOS courses.
/// Strictly enforces match order:
/// 1. Exact course code
/// 2. Normalized code (strip whitespace, punctuation, uppercase)
/// 3. Exact course title
/// 4. High-confidence title match (similarity >= 0.85)
/// 5. Manual selection required
///
/// CRITICAL: Never automatically merges low-confidence matches.
public final class CourseReconciliationEngine: Sendable {
    public static let shared = CourseReconciliationEngine()

    public init() {}

    /// Reconciles a list of remote courses against all locally enrolled courses.
    public func reconcile(
        remoteCourses: [RemoteCourse],
        localCourses: [Course]
    ) -> [CourseReconciliationResult] {
        return remoteCourses.map { remote in
            reconcileSingle(remoteCourse: remote, localCourses: localCourses)
        }
    }

    /// Reconciles a single remote course following the strict priority order.
    public func reconcileSingle(
        remoteCourse: RemoteCourse,
        localCourses: [Course]
    ) -> CourseReconciliationResult {
        let remoteRawCode = remoteCourse.code.trimmingCharacters(in: .whitespacesAndNewlines)
        let remoteNormalizedCode = normalizeCode(remoteRawCode)
        let remoteTitle = remoteCourse.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // 1. Tier 1: Exact Course Code
        if let exact = localCourses.first(where: { $0.code.caseInsensitiveCompare(remoteRawCode) == .orderedSame }) {
            return CourseReconciliationResult(
                remoteCourse: remoteCourse,
                matchedLocalCourse: exact,
                strategy: .exactCode,
                confidenceScore: 1.0,
                requiresUserConfirmation: false
            )
        }

        // 2. Tier 2: Normalized Code (e.g. "CENG-311" vs "CENG 311")
        if let normalized = localCourses.first(where: { normalizeCode($0.code) == remoteNormalizedCode }) {
            return CourseReconciliationResult(
                remoteCourse: remoteCourse,
                matchedLocalCourse: normalized,
                strategy: .normalizedCode,
                confidenceScore: 0.95,
                requiresUserConfirmation: false
            )
        }

        // 3. Tier 3: Exact Course Title
        if let exactTitle = localCourses.first(where: { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == remoteTitle }) {
            return CourseReconciliationResult(
                remoteCourse: remoteCourse,
                matchedLocalCourse: exactTitle,
                strategy: .exactTitle,
                confidenceScore: 0.90,
                requiresUserConfirmation: false
            )
        }

        // 4. Tier 4: High-Confidence Title Match (similarity >= 0.85)
        var bestMatch: Course? = nil
        var bestScore: Double = 0.0

        for local in localCourses {
            let localTitle = local.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let score = computeSimilarity(remoteTitle, localTitle)
            if score > bestScore {
                bestScore = score
                bestMatch = local
            }
        }

        if bestScore >= 0.85, let match = bestMatch {
            return CourseReconciliationResult(
                remoteCourse: remoteCourse,
                matchedLocalCourse: match,
                strategy: .highConfidenceTitle,
                confidenceScore: bestScore,
                requiresUserConfirmation: false
            )
        }

        // 5. Tier 5: Manual Selection Required (Low confidence or no match)
        return CourseReconciliationResult(
            remoteCourse: remoteCourse,
            matchedLocalCourse: bestMatch, // Suggested candidate, but not committed
            strategy: .manualSelectionRequired,
            confidenceScore: bestScore,
            requiresUserConfirmation: true // User confirmation strictly required
        )
    }

    private func normalizeCode(_ code: String) -> String {
        return code
            .uppercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: ".", with: "")
    }

    /// Computes token-based Jaccard similarity between two title strings.
    private func computeSimilarity(_ s1: String, _ s2: String) -> Double {
        if s1 == s2 { return 1.0 }
        let tokens1 = Set(s1.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { $0.count > 1 })
        let tokens2 = Set(s2.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { $0.count > 1 })

        guard !tokens1.isEmpty && !tokens2.isEmpty else { return 0.0 }
        let intersection = tokens1.intersection(tokens2)
        let union = tokens1.union(tokens2)

        return Double(intersection.count) / Double(union.count)
    }
}
