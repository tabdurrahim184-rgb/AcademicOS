import Foundation

/// Classified types of pages encountered in university LMS and Student Information Systems (OBS).
public enum PortalPageType: String, Codable, Sendable, CaseIterable {
    case login = "Login Page"
    case dashboard = "Student Dashboard"
    case courses = "Course List"
    case courseDetail = "Course Detail"
    case announcements = "Announcements"
    case assignments = "Assignments / Submissions"
    case exams = "Exam Schedule"
    case grades = "Grades & Transcript"
    case documents = "Course Documents"
    case messages = "Portal Messages"
    case attendance = "Attendance & Absence"
    case unknown = "Unknown Page"
}

/// Result of portal page classification including confidence and matched signals.
public struct PageClassificationResult: Sendable, Equatable {
    public let pageType: PortalPageType
    public let confidence: Double
    public let matchedRule: String
    public let detectedCourseCode: String?

    public init(
        pageType: PortalPageType,
        confidence: Double,
        matchedRule: String,
        detectedCourseCode: String? = nil
    ) {
        self.pageType = pageType
        self.confidence = confidence
        self.matchedRule = matchedRule
        self.detectedCourseCode = detectedCourseCode
    }
}

/// Classifies university web pages using deterministic URL and DOM structural rules.
/// Optional AI classification may only be used as a last resort and NEVER receives credentials or cookies.
public final class PortalPageClassifier: Sendable {
    public static let shared = PortalPageClassifier()

    public init() {}

    /// Deterministically classifies a page based on its URL, page title, and sanitized DOM structure.
    public func classify(
        url: URL,
        pageTitle: String = "",
        sanitizedDOM: String = ""
    ) -> PageClassificationResult {
        let urlString = url.absoluteString.lowercased()
        let path = url.path.lowercased()
        let titleLower = pageTitle.lowercased()
        let domLower = sanitizedDOM.lowercased()

        // 1. Login Page Detection
        if path.contains("/login") || urlString.contains("login.php") || urlString.contains("cas/login") ||
           titleLower.contains("giriş") || titleLower.contains("login") || titleLower.contains("sign in") ||
           domLower.contains("password") && (domLower.contains("kullanıcı adı") || domLower.contains("username")) {
            return PageClassificationResult(pageType: .login, confidence: 0.98, matchedRule: "URL/DOM Login Pattern")
        }

        // 2. Exam Schedule Detection
        if path.contains("/exam") || path.contains("sinav") || urlString.contains("sinavlar") ||
           titleLower.contains("sınav programı") || titleLower.contains("sınavlar") || titleLower.contains("exam schedule") ||
           domLower.contains("sınav tarihi") || domLower.contains("vize tarihi") || domLower.contains("final programı") {
            return PageClassificationResult(pageType: .exams, confidence: 0.95, matchedRule: "Exam Path/Header Match")
        }

        // 3. Grades & Evaluation Detection
        if path.contains("/grade") || path.contains("notlar") || path.contains("transkript") ||
           titleLower.contains("not listesi") || titleLower.contains("notlar") || titleLower.contains("grades") ||
           domLower.contains("harf notu") || domLower.contains("başarı notu") || domLower.contains("dönem ortalaması") {
            return PageClassificationResult(pageType: .grades, confidence: 0.95, matchedRule: "Grade Path/Header Match")
        }

        // 4. Assignments / Tasks Detection
        if path.contains("/assign") || path.contains("odev") || urlString.contains("mod/assign") ||
           titleLower.contains("ödevler") || titleLower.contains("assignments") || titleLower.contains("teslim") ||
           domLower.contains("son teslim tarihi") || domLower.contains("due date") || domLower.contains("submission status") {
            return PageClassificationResult(pageType: .assignments, confidence: 0.92, matchedRule: "Assignment Path/Keyword Match")
        }

        // 5. Attendance Detection
        if path.contains("/attendance") || path.contains("devamsizlik") || path.contains("yoklama") ||
           titleLower.contains("devamsızlık") || titleLower.contains("attendance") ||
           domLower.contains("toplam saat") || domLower.contains("devamsızlık saati") || domLower.contains("absent") {
            return PageClassificationResult(pageType: .attendance, confidence: 0.92, matchedRule: "Attendance Keyword Match")
        }

        // 6. Announcements Detection
        if path.contains("/announcement") || path.contains("duyuru") || urlString.contains("mod/forum") ||
           titleLower.contains("duyurular") || titleLower.contains("announcements") || titleLower.contains("haberler") ||
           domLower.contains("duyuru metni") || domLower.contains("yayınlanma tarihi") {
            return PageClassificationResult(pageType: .announcements, confidence: 0.90, matchedRule: "Announcement Path Match")
        }

        // 7. Documents / Resources Detection
        if path.contains("/resource") || path.contains("/folder") || path.contains("materyal") || path.contains("dosyalar") ||
           titleLower.contains("ders materyalleri") || titleLower.contains("documents") || titleLower.contains("kaynaklar") ||
           domLower.contains(".pdf") && (domLower.contains("indir") || domLower.contains("download")) {
            return PageClassificationResult(pageType: .documents, confidence: 0.88, matchedRule: "Document Resource Match")
        }

        // 8. Course Detail Detection
        let courseCodeMatch = extractCourseCode(from: urlString + " " + titleLower + " " + domLower)
        if (path.contains("/course/view.php") || path.contains("/ders/")) && courseCodeMatch != nil {
            return PageClassificationResult(pageType: .courseDetail, confidence: 0.90, matchedRule: "Course Detail Pattern", detectedCourseCode: courseCodeMatch)
        }

        // 9. Course List Detection
        if path.contains("/my") || path.contains("/courses") || path.contains("/dersler") ||
           titleLower.contains("derslerim") || titleLower.contains("kayıtlı dersler") || titleLower.contains("my courses") {
            return PageClassificationResult(pageType: .courses, confidence: 0.85, matchedRule: "Course List Pattern")
        }

        // 10. Messages Detection
        if path.contains("/message") || path.contains("mesaj") || titleLower.contains("mesajlar") || titleLower.contains("inbox") {
            return PageClassificationResult(pageType: .messages, confidence: 0.90, matchedRule: "Messaging Pattern")
        }

        // 11. Dashboard Detection
        if path == "/" || path.contains("dashboard") || path.contains("ana-sayfa") || path.contains("ogrenci/anasayfa") ||
           titleLower.contains("öğrenci bilgi sistemi") || titleLower.contains("dashboard") || titleLower.contains("ana sayfa") {
            return PageClassificationResult(pageType: .dashboard, confidence: 0.80, matchedRule: "Dashboard Home Pattern")
        }

        return PageClassificationResult(pageType: .unknown, confidence: 0.0, matchedRule: "No deterministic rule matched")
    }

    /// Helper to identify course code pattern (e.g. CENG 311, MATH 101, BLM202).
    private func extractCourseCode(from text: String) -> String? {
        let pattern = #"\b([A-Z]{2,5})\s?[-_]?\s?([0-9]{3,4})\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        if let match = regex.firstMatch(in: text, options: [], range: range) {
            if let swiftRange = Range(match.range, in: text) {
                return String(text[swiftRange]).uppercased()
            }
        }
        return nil
    }
}
