import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif

/// Dedicated parser for Near East University Student Portal Transcript (/StudentCourse/Transcript).
/// Strictly complies with Phase 2F:
/// - Generates SanitizedPortalEvidence (zero raw HTML persistence)
/// - Honors explicit portal pass/fail status text
/// - Flags letter-grade-only courses as AcademicStandingStatus.unverified
/// - Never allows unverified status to affect graduation eligibility
public final class NEUTranscriptParser: Sendable {
    public static let shared = NEUTranscriptParser()

    public init() {}

    /// Parses transcript HTML into structured courses and summary.
    public func parseTranscript(html rawHTML: String) -> NEUTranscriptSummary {
        guard !rawHTML.isEmpty else {
            return NEUTranscriptSummary(
                totalSemesters: 0,
                totalCourses: 0,
                passedCount: 0,
                failedCount: 0,
                unconfirmedCount: 0,
                portalReportedGPA: nil,
                gpaMappingStatus: "PORTAL IMPORT — UNVERIFIED GPA MAPPING",
                isVerified: false,
                courses: []
            )
        }

        var courses: [NEUTranscriptCourse] = []
        var detectedSemesters = Set<String>()

        let rowPattern = #"(?i)<tr[^>]*>(.*?)<\/tr>"#
        if let regex = try? NSRegularExpression(pattern: rowPattern, options: [.dotMatchesLineSeparators]) {
            let matches = regex.matches(in: rawHTML, options: [], range: NSRange(rawHTML.startIndex..<rawHTML.endIndex, in: rawHTML))

            var currentYear = "2024-2025"
            var currentSemester = "Güz"

            for match in matches {
                if let range = Range(match.range(at: 1), in: rawHTML) {
                    let rowContent = String(rawHTML[range])

                    // Detect semester / academic year header
                    if let yearMatch = rowContent.range(of: #"20\d{2}[-–/]\d{2,4}"#, options: .regularExpression) {
                        currentYear = String(rowContent[yearMatch])
                    }
                    if rowContent.localizedCaseInsensitiveContains("Güz") || rowContent.localizedCaseInsensitiveContains("Fall") {
                        currentSemester = "Güz"
                    } else if rowContent.localizedCaseInsensitiveContains("Bahar") || rowContent.localizedCaseInsensitiveContains("Spring") {
                        currentSemester = "Bahar"
                    }

                    // Extract cell values
                    let cells = extractCells(from: rowContent)
                    if cells.count >= 3 {
                        if let code = extractCourseCode(from: cells[0]) {
                            let name = cells.count > 1 ? cells[1] : code
                            let creditStr = cells.count > 2 ? cells[2].replacingOccurrences(of: ",", with: ".") : "3.0"
                            let grade = cells.count > 3 ? cells[3].trimmingCharacters(in: .whitespacesAndNewlines) : "-"
                            let rawStatusText = cells.count > 4 ? cells[4].trimmingCharacters(in: .whitespacesAndNewlines) : ""

                            let credits = Double(creditStr) ?? 3.0
                            let ects = cells.count > 5 ? (Double(cells[5].replacingOccurrences(of: ",", with: ".")) ?? (credits * 1.5)) : (credits * 1.5)

                            // Standing determination:
                            // ONLY mark passed or failed if the portal explicitly provided status text.
                            // If only letter grade is given without explicit portal confirmation, mark .unverified!
                            let standing: AcademicStandingStatus
                            let lowerStatus = rawStatusText.lowercased()
                            if lowerStatus.contains("geçti") || lowerStatus.contains("passed") || lowerStatus == "s" || lowerStatus.contains("muaf") {
                                standing = .portalReportedPassed
                            } else if lowerStatus.contains("kaldı") || lowerStatus.contains("failed") || lowerStatus == "u" {
                                standing = .portalReportedFailed
                            } else if lowerStatus.contains("çekildi") || lowerStatus.contains("withdrawn") || grade.uppercased() == "W" {
                                standing = .withdrawn
                            } else if lowerStatus.contains("eksik") || lowerStatus.contains("incomplete") || grade.uppercased() == "I" {
                                standing = .incomplete
                            } else if lowerStatus.contains("devam") || lowerStatus.contains("in progress") {
                                standing = .inProgress
                            } else {
                                // Letter grade present without explicit portal pass/fail text
                                standing = .unverified
                            }

                            // Generate Sanitized Evidence
                            let cleanRowText = "\(currentYear) \(currentSemester) | \(code) | \(name) | \(creditStr) | \(grade) | \(rawStatusText)"
                            let fingerprint = computeFingerprint(for: cleanRowText)
                            let evidence = SanitizedPortalEvidence(
                                sourceURL: "https://register.neu.edu.tr/StudentCourse/Transcript",
                                safeVisibleTextExcerpt: cleanRowText,
                                safeTableHeaders: ["Dönem", "Ders Kodu", "Ders Adı", "Kredi", "AKTS", "Harf Notu", "Durum"],
                                safeNormalizedFields: [
                                    "academicYear": currentYear,
                                    "semester": currentSemester,
                                    "courseCode": code,
                                    "courseName": name,
                                    "credits": String(credits),
                                    "grade": grade,
                                    "standing": standing.rawValue
                                ],
                                retrievedAt: Date(),
                                contentFingerprint: fingerprint,
                                portalRecordID: "\(currentYear)_\(currentSemester)_\(code)"
                            )

                            let semesterKey = "\(currentYear) \(currentSemester)"
                            detectedSemesters.insert(semesterKey)

                            courses.append(NEUTranscriptCourse(
                                academicYear: currentYear,
                                semester: currentSemester,
                                courseCode: code,
                                courseName: name,
                                grade: grade,
                                credits: credits,
                                ects: ects,
                                status: rawStatusText.isEmpty ? nil : rawStatusText,
                                academicStanding: standing,
                                evidence: evidence
                            ))
                        }
                    }
                }
            }
        }

        // Extract reported CGPA
        let portalGPA = extractPortalReportedGPA(from: rawHTML)

        let passed = courses.filter { $0.academicStanding == .portalReportedPassed }.count
        let failed = courses.filter { $0.academicStanding == .portalReportedFailed }.count
        let unconfirmed = courses.filter { $0.academicStanding == .unverified }.count

        return NEUTranscriptSummary(
            totalSemesters: detectedSemesters.count,
            totalCourses: courses.count,
            passedCount: passed,
            failedCount: failed,
            unconfirmedCount: unconfirmed,
            portalReportedGPA: portalGPA,
            gpaMappingStatus: "PORTAL IMPORT — UNVERIFIED GPA MAPPING",
            isVerified: false,
            courses: courses
        )
    }

    private func extractCells(from rowHTML: String) -> [String] {
        var cells: [String] = []
        let pattern = #"(?i)<td[^>]*>(.*?)<\/td>"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) {
            let matches = regex.matches(in: rowHTML, options: [], range: NSRange(rowHTML.startIndex..<rowHTML.endIndex, in: rowHTML))
            for match in matches {
                if let range = Range(match.range(at: 1), in: rowHTML) {
                    let text = String(rowHTML[range])
                        .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    cells.append(text)
                }
            }
        }
        return cells
    }

    private func extractCourseCode(from text: String) -> String? {
        let pattern = #"([A-ZÇĞİÖŞÜ]{2,5})\s*([0-9]{3}[A-Z]?)"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
            let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
            if let match = regex.firstMatch(in: text, options: [], range: nsRange) {
                if let r1 = Range(match.range(at: 1), in: text),
                   let r2 = Range(match.range(at: 2), in: text) {
                    return "\(text[r1].uppercased()) \(text[r2].uppercased())"
                }
            }
        }
        return nil
    }

    private func extractPortalReportedGPA(from rawHTML: String) -> Double? {
        let patterns = [
            #"(?i)(?:CGPA|Genel\s*Ortalama|GNO|Cumulative\s*GPA)[^0-9]*([0-3]\.\d{2}|4\.00)"#,
            #"class="[^"]*gpa[^"]*"[^>]*>\s*([0-3]\.\d{2}|4\.00)"#
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let nsRange = NSRange(rawHTML.startIndex..<rawHTML.endIndex, in: rawHTML)
                if let match = regex.firstMatch(in: rawHTML, options: [], range: nsRange),
                   match.numberOfRanges > 1,
                   let valRange = Range(match.range(at: 1), in: rawHTML) {
                    let str = String(rawHTML[valRange])
                    if let d = Double(str) {
                        return d
                    }
                }
            }
        }
        return nil
    }

    private func computeFingerprint(for text: String) -> String {
        #if canImport(CryptoKit)
        let hash = SHA256.hash(data: Data(text.utf8))
        return hash.compactMap { String(format: "%02x", $0) }.joined()
        #else
        return "\(text.hashValue)"
        #endif
    }
}
