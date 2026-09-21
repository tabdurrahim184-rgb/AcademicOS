import Foundation

/// High-fidelity demo connector simulating a real Turkish university portal (UZEM / OBS / LMS).
/// ALL items produced by this connector are explicitly marked as [DEMO DATA] to ensure
/// synthetic demo records can NEVER be confused with genuine student records in production.
public final class DemoUniversityConnector: UniversityConnectorProtocol, @unchecked Sendable {
    public let portalType: UniversityPortalType = .demo
    public let displayName: String = "Demo University (UZEM / OBS) [DEMO DATA]"

    private let simulatedDelayNanoseconds: UInt64

    public init(simulatedDelayNanoseconds: UInt64 = 300_000_000) {
        self.simulatedDelayNanoseconds = simulatedDelayNanoseconds
    }

    public func authenticate(credentials: UniversityCredentials) async throws -> Bool {
        try await Task.sleep(nanoseconds: simulatedDelayNanoseconds)
        return true
    }

    public func fetchCourses() async throws -> [RemoteCourse] {
        try await Task.sleep(nanoseconds: simulatedDelayNanoseconds)
        return [
            RemoteCourse(remoteId: "DEMO-CENG311", code: "CENG 311", name: "[DEMO] Operating Systems", instructor: "Prof. Dr. Ahmet Yılmaz", credits: 4, ects: 6),
            RemoteCourse(remoteId: "DEMO-CENG382", code: "CENG 382", name: "[DEMO] Analysis of Algorithms", instructor: "Doç. Dr. Selin Kaya", credits: 3, ects: 5),
            RemoteCourse(remoteId: "DEMO-MATH251", code: "MATH 251", name: "[DEMO] Linear Algebra", instructor: "Dr. Mehmet Demir", credits: 3, ects: 5),
            RemoteCourse(remoteId: "DEMO-CENG351", code: "CENG 351", name: "[DEMO] Data Management", instructor: "Dr. Emre Can", credits: 3, ects: 5)
        ]
    }

    public func fetchAnnouncements(courseCode: String?) async throws -> [RemoteAnnouncement] {
        try await Task.sleep(nanoseconds: simulatedDelayNanoseconds)
        let now = Date()
        let calendar = Calendar.current

        let all = [
            RemoteAnnouncement(
                remoteId: "demo-ann-01",
                courseCode: "CENG 311",
                title: "[DEMO] Vize Sınav Salonları ve Kuralları İlan Edildi",
                body: "Arkadaşlar, CENG 311 Vize sınavı Perşembe günü B-204 salonunda yapılacaktır. Hesap makinesi kullanımı serbesttir. Peterson algoritması ve Semafor uygulamalarına özellikle çalışınız.",
                author: "Prof. Dr. Ahmet Yılmaz",
                isUrgent: true,
                date: calendar.date(byAdding: .hour, value: -2, to: now) ?? now
            ),
            RemoteAnnouncement(
                remoteId: "demo-ann-02",
                courseCode: "CENG 382",
                title: "[DEMO] Dinamik Programlama Ödev Teslim Tarihi Uzatıldı",
                body: "Öğrencilerden gelen talep üzerine Ödev 1 teslim tarihi Pazar gecesi 23:59'a kadar uzatılmıştır. Geç teslim kabul edilmeyecektir.",
                author: "Doç. Dr. Selin Kaya",
                isUrgent: false,
                date: calendar.date(byAdding: .day, value: -1, to: now) ?? now
            ),
            RemoteAnnouncement(
                remoteId: "demo-ann-03",
                courseCode: nil,
                title: "[DEMO] Rektörlük: 2026-2027 Güz Yarıyılı Vize Haftası Düzenlemeleri",
                body: "Üniversitemiz Senatosu kararı gereğince ara sınav haftasında dersler yapılmayacak olup kütüphanelerimiz 7/24 hizmet verecektir.",
                author: "Öğrenci İşleri Daire Başkanlığı",
                isUrgent: false,
                date: calendar.date(byAdding: .day, value: -3, to: now) ?? now
            )
        ]

        if let code = courseCode {
            return all.filter { $0.courseCode == code }
        }
        return all
    }

    public func fetchExams(courseCode: String?) async throws -> [RemoteExam] {
        try await Task.sleep(nanoseconds: simulatedDelayNanoseconds)
        let now = Date()
        let calendar = Calendar.current

        let all = [
            RemoteExam(
                remoteId: "demo-exam-311-midterm",
                courseCode: "CENG 311",
                title: "[DEMO] CENG 311 Midterm Exam",
                examType: "Midterm",
                date: calendar.date(byAdding: .day, value: 4, to: now) ?? now,
                room: "B-204",
                weightPercentage: 35
            ),
            RemoteExam(
                remoteId: "demo-exam-382-midterm",
                courseCode: "CENG 382",
                title: "[DEMO] CENG 382 Midterm Exam",
                examType: "Midterm",
                date: calendar.date(byAdding: .day, value: 12, to: now) ?? now,
                room: "A-101",
                weightPercentage: 30
            ),
            RemoteExam(
                remoteId: "demo-exam-251-final",
                courseCode: "MATH 251",
                title: "[DEMO] MATH 251 Final Examination",
                examType: "Final",
                date: calendar.date(byAdding: .day, value: 28, to: now) ?? now,
                room: "C-302",
                weightPercentage: 40
            )
        ]

        if let code = courseCode {
            return all.filter { $0.courseCode == code }
        }
        return all
    }

    public func fetchAssignments(courseCode: String?) async throws -> [RemoteAssignment] {
        try await Task.sleep(nanoseconds: simulatedDelayNanoseconds)
        let now = Date()
        let calendar = Calendar.current

        let all = [
            RemoteAssignment(
                remoteId: "demo-asg-311-01",
                courseCode: "CENG 311",
                title: "[DEMO] Process Synchronization & Semaphore Project",
                description: "POSIX semaphores using C/pthread. Implement solution for dining philosophers without deadlock.",
                dueDate: calendar.date(byAdding: .day, value: 2, to: now) ?? now,
                maxScore: 100.0,
                submissionURL: "https://uzem.university.edu.tr/mod/assign/view.php?id=demo31101"
            ),
            RemoteAssignment(
                remoteId: "demo-asg-382-01",
                courseCode: "CENG 382",
                title: "[DEMO] Dynamic Programming Knapsack Implementation",
                description: "Compare 0/1 Knapsack recursive vs memoized vs bottom-up tabulation runtime complexity.",
                dueDate: calendar.date(byAdding: .day, value: 7, to: now) ?? now,
                maxScore: 100.0,
                submissionURL: "https://uzem.university.edu.tr/mod/assign/view.php?id=demo38201"
            )
        ]

        if let code = courseCode {
            return all.filter { $0.courseCode == code }
        }
        return all
    }

    public func fetchGrades(courseCode: String?) async throws -> [RemoteGrade] {
        try await Task.sleep(nanoseconds: simulatedDelayNanoseconds)

        let all = [
            RemoteGrade(
                remoteId: "demo-grd-311-q1",
                courseCode: "CENG 311",
                evaluationName: "[DEMO] Quiz 1: CPU Scheduling",
                score: 92.0,
                maxScore: 100.0,
                weightPercentage: 10.0,
                letterGrade: "AA",
                isFinal: false
            ),
            RemoteGrade(
                remoteId: "demo-grd-311-lab1",
                courseCode: "CENG 311",
                evaluationName: "[DEMO] Lab 1: Fork & Exec System Calls",
                score: 100.0,
                maxScore: 100.0,
                weightPercentage: 15.0,
                letterGrade: "AA",
                isFinal: false
            ),
            RemoteGrade(
                remoteId: "demo-grd-382-hw1",
                courseCode: "CENG 382",
                evaluationName: "[DEMO] Homework 1: Asymptotic Notations",
                score: 85.0,
                maxScore: 100.0,
                weightPercentage: 15.0,
                letterGrade: "BA",
                isFinal: false
            ),
            RemoteGrade(
                remoteId: "demo-grd-251-q1",
                courseCode: "MATH 251",
                evaluationName: "[DEMO] Quiz 1: Vector Spaces",
                score: 78.0,
                maxScore: 100.0,
                weightPercentage: 10.0,
                letterGrade: "BB",
                isFinal: false
            )
        ]

        if let code = courseCode {
            return all.filter { $0.courseCode == code }
        }
        return all
    }

    public func fetchDocuments(courseCode: String?) async throws -> [RemoteDocument] {
        try await Task.sleep(nanoseconds: simulatedDelayNanoseconds)

        let all = [
            RemoteDocument(
                remoteId: "demo-doc-311-01",
                courseCode: "CENG 311",
                fileName: "DEMO_CENG311_Syllabus_Fall2026",
                fileExtension: "pdf",
                downloadURL: URL(string: "https://uzem.university.edu.tr/docs/ceng311/syllabus.pdf")!,
                docType: "Syllabus"
            ),
            RemoteDocument(
                remoteId: "demo-doc-311-02",
                courseCode: "CENG 311",
                fileName: "DEMO_Lecture04_Peterson_Algorithm",
                fileExtension: "pdf",
                downloadURL: URL(string: "https://uzem.university.edu.tr/docs/ceng311/lec04.pdf")!,
                docType: "Slides"
            ),
            RemoteDocument(
                remoteId: "demo-doc-382-01",
                courseCode: "CENG 382",
                fileName: "DEMO_CENG382_Homework1_Specs",
                fileExtension: "pdf",
                downloadURL: URL(string: "https://uzem.university.edu.tr/docs/ceng382/hw1.pdf")!,
                docType: "Assignment"
            )
        ]

        if let code = courseCode {
            return all.filter { $0.courseCode == code }
        }
        return all
    }

    public func fetchFullPayload() async throws -> RemoteUniversityPayload {
        async let courses = fetchCourses()
        async let announcements = fetchAnnouncements(courseCode: nil)
        async let exams = fetchExams(courseCode: nil)
        async let assignments = fetchAssignments(courseCode: nil)
        async let grades = fetchGrades(courseCode: nil)
        async let documents = fetchDocuments(courseCode: nil)

        return try await RemoteUniversityPayload(
            courses: courses,
            announcements: announcements,
            exams: exams,
            assignments: assignments,
            grades: grades,
            documents: documents
        )
    }
}
