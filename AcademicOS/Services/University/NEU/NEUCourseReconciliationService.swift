import Foundation

/// Unified representation of a course cross-referenced between DEBİM (Moodle), Student Portal (OBS), and local storage.
public struct NEUReconciledCourse: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let canonicalCode: String
    public var displayName: String
    public var debimCourse: RemoteCourse?
    public var portalCourse: NEUTranscriptCourse?
    public var matchedLocalCourseId: UUID?
    public var badges: [AcademicDataSourceBadge]
    public var conflicts: [SourceConflict]
    public var credits: Double
    public var ects: Double?
    public var instructor: String?

    public init(
        id: UUID = UUID(),
        canonicalCode: String,
        displayName: String,
        debimCourse: RemoteCourse? = nil,
        portalCourse: NEUTranscriptCourse? = nil,
        matchedLocalCourseId: UUID? = nil,
        badges: [AcademicDataSourceBadge] = [],
        conflicts: [SourceConflict] = [],
        credits: Double = 3.0,
        ects: Double? = nil,
        instructor: String? = nil
    ) {
        self.id = id
        self.canonicalCode = canonicalCode
        self.displayName = displayName
        self.debimCourse = debimCourse
        self.portalCourse = portalCourse
        self.matchedLocalCourseId = matchedLocalCourseId
        self.badges = badges
        self.conflicts = conflicts
        self.credits = credits
        self.ects = ects
        self.instructor = instructor
    }
}

/// Overall reconciliation report across both Near East University systems.
public struct NEUReconciliationReport: Codable, Sendable, Equatable {
    public let reconciledCourses: [NEUReconciledCourse]
    public let allConflicts: [SourceConflict]
    public var unresolvedConflictCount: Int {
        allConflicts.filter { $0.requiresUserConfirmation && $0.resolvedValue == nil }.count
    }
    public let generatedAt: Date

    public init(
        reconciledCourses: [NEUReconciledCourse],
        allConflicts: [SourceConflict],
        generatedAt: Date = Date()
    ) {
        self.reconciledCourses = reconciledCourses
        self.allConflicts = allConflicts
        self.generatedAt = generatedAt
    }
}

/// Service that coordinates dual-portal reconciliation for Near East University.
/// Integrates DEBİM (Moodle LMS) courses and Student Portal (Genius Student OBS) courses.
/// Strictly enforces:
/// - Exact code canonicalization (e.g. 'CENG311', 'CENG-311', 'CENG 311' -> 'CENG 311')
/// - Multi-source provenance tagging (.debim and .neuStudentPortal)
/// - Discrepancy detection generating SourceConflict records without overwriting
/// - Safe deduplication so courses are not cloned in the AcademicOS database
public final class NEUCourseReconciliationService: Sendable {
    public static let shared = NEUCourseReconciliationService()

    public init() {}

    /// Canonicalizes course codes by uppercase, stripping punctuation and inserting a standard space between department letters and course number.
    /// Examples:
    /// "ceng311" -> "CENG 311"
    /// "CENG-311" -> "CENG 311"
    /// "ECC-206" -> "ECC 206"
    /// "MATH 101" -> "MATH 101"
    public func canonicalizeCode(_ rawCode: String) -> String {
        let trimmed = rawCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        // Remove common punctuation: hyphens, underscores, dots
        let cleaned = trimmed.replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: ".", with: " ")
        
        // Match regex: (Letters) + optional space + (Digits + optional section/letter)
        let pattern = #"^([A-ZÇĞİÖŞÜ]+)\s*([0-9]+[A-Z]?)"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let nsRange = NSRange(cleaned.startIndex..<cleaned.endIndex, in: cleaned)
            if let match = regex.firstMatch(in: cleaned, options: [], range: nsRange) {
                if let r1 = Range(match.range(at: 1), in: cleaned),
                   let r2 = Range(match.range(at: 2), in: cleaned) {
                    let dept = String(cleaned[r1])
                    let num = String(cleaned[r2])
                    return "\(dept) \(num)"
                }
            }
        }

        // Fallback: compress whitespace
        let components = cleaned.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        return components.joined(separator: " ")
    }

    /// Reconciles courses scraped from DEBİM and Student Portal against local courses.
    public func reconcile(
        debimCourses: [RemoteCourse],
        portalCourses: [NEUTranscriptCourse],
        localCourses: [Course]
    ) -> NEUReconciliationReport {
        var reconciledMap: [String: NEUReconciledCourse] = [:]
        var allConflicts: [SourceConflict] = []

        // 1. Process Student Portal Courses (Primary Official Academic Records)
        for portalCourse in portalCourses {
            let canon = canonicalizeCode(portalCourse.courseCode)
            let existingLocal = localCourses.first {
                canonicalizeCode($0.code) == canon
            }

            var course = NEUReconciledCourse(
                canonicalCode: canon,
                displayName: portalCourse.courseName.trimmingCharacters(in: .whitespacesAndNewlines),
                portalCourse: portalCourse,
                matchedLocalCourseId: existingLocal?.id,
                badges: [.neuStudentPortal],
                conflicts: [],
                credits: portalCourse.credits,
                ects: portalCourse.ects,
                instructor: nil
            )

            if existingLocal != nil {
                course.badges.append(.manual)
            }

            reconciledMap[canon] = course
        }

        // 2. Process DEBİM Courses (LMS Activity / Materials / Assignments)
        for debimCourse in debimCourses {
            let canon = canonicalizeCode(debimCourse.code)
            let existingLocal = localCourses.first {
                canonicalizeCode($0.code) == canon
            }

            if var existing = reconciledMap[canon] {
                // Course exists in both DEBİM and Student Portal -> Merging!
                existing.debimCourse = debimCourse
                if !existing.badges.contains(.debim) {
                    existing.badges.append(.debim)
                }
                if debimCourse.instructor.isEmpty == false && existing.instructor == nil {
                    existing.instructor = debimCourse.instructor
                }

                // Discrepancy Check 1: Course Title / Name
                let debimName = debimCourse.name.trimmingCharacters(in: .whitespacesAndNewlines)
                let portalName = existing.displayName
                if !debimName.isEmpty && !portalName.isEmpty && debimName.caseInsensitiveCompare(portalName) != .orderedSame {
                    // Check if one is a superstring or if there is meaningful difference
                    if !debimName.lowercased().contains(portalName.lowercased()) &&
                       !portalName.lowercased().contains(debimName.lowercased()) {
                        let conflict = SourceConflict(
                            entityId: canon,
                            entityType: "Course",
                            fieldName: "courseName",
                            primaryValue: portalName,
                            primarySource: .neuStudentPortal,
                            conflictingValue: debimName,
                            conflictingSource: .debim,
                            requiresUserConfirmation: true
                        )
                        existing.conflicts.append(conflict)
                        allConflicts.append(conflict)
                    }
                }

                // Discrepancy Check 2: Credits
                if debimCourse.credits > 0 && Int(existing.credits) != debimCourse.credits {
                    let conflict = SourceConflict(
                        entityId: canon,
                        entityType: "Course",
                        fieldName: "credits",
                        primaryValue: "\(Int(existing.credits))",
                        primarySource: .neuStudentPortal,
                        conflictingValue: "\(debimCourse.credits)",
                        conflictingSource: .debim,
                        requiresUserConfirmation: true
                    )
                    existing.conflicts.append(conflict)
                    allConflicts.append(conflict)
                }

                reconciledMap[canon] = existing
            } else {
                // Course only exists in DEBİM
                var course = NEUReconciledCourse(
                    canonicalCode: canon,
                    displayName: debimCourse.name.trimmingCharacters(in: .whitespacesAndNewlines),
                    debimCourse: debimCourse,
                    portalCourse: nil,
                    matchedLocalCourseId: existingLocal?.id,
                    badges: [.debim],
                    conflicts: [],
                    credits: Double(debimCourse.credits),
                    ects: Double(debimCourse.ects),
                    instructor: debimCourse.instructor.isEmpty ? nil : debimCourse.instructor
                )

                if existingLocal != nil {
                    course.badges.append(.manual)
                }

                reconciledMap[canon] = course
            }
        }

        let sortedCourses = reconciledMap.values.sorted { $0.canonicalCode < $1.canonicalCode }
        return NEUReconciliationReport(
            reconciledCourses: sortedCourses,
            allConflicts: allConflicts
        )
    }
}
