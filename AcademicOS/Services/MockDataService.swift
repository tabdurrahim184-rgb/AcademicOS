import Foundation

/// Seeds realistic academic data for demonstration and offline testing.
public final class MockDataService: Sendable {
    public static let shared = MockDataService()

    public init() {}

    public func seedData(into store: LocalStoreProtocol) async throws {
        // Only seed if store is empty
        let existingCourses: [Course] = try await store.fetchAll()
        guard existingCourses.isEmpty else { return }

        let semesterId = UUID()
        let semester = Semester(
            id: semesterId,
            name: "Fall 2026",
            academicYear: "2026 - 2027",
            startDate: Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date(),
            endDate: Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date(),
            isActive: true,
            targetGPA: 3.85
        )
        try await store.save(semester)

        // Professors
        let profLaw = Professor(name: "Dr. Selin Yılmaz", title: "Assoc. Prof.", email: "syilmaz@univ.edu", officeLocation: "Block C-302", officeHours: "Wed 14:00-16:00")
        let profTheories = Professor(name: "Dr. Murat Kaya", title: "Prof. Dr.", email: "mkaya@univ.edu", officeLocation: "Block A-114", officeHours: "Thu 10:00-12:00")
        let profMethods = Professor(name: "Dr. Zeynep Arslan", title: "Assist. Prof.", email: "zarslan@univ.edu", officeLocation: "Block B-205", officeHours: "Mon 13:00-15:00")
        let profWorkshop = Professor(name: "Kemal Demir", title: "Senior Lecturer", email: "kdemir@univ.edu", officeLocation: "Media Lab 2", officeHours: "Tue 15:00-17:00")

        // Courses (7 active courses)
        let commLaw = Course(
            code: "COMM 401",
            name: "Communication Law",
            department: "Media & Law",
            credits: 4,
            semesterId: semesterId,
            professor: profLaw,
            colorHex: "#4F46E5",
            aiMemorySummary: "Focused on Turkish press code, digital copyright, GDPR/KVKK compliance, and defamation precedents.",
            lectureRoom: "Amphi 1",
            weeklyClassDay: "Monday",
            startTime: "09:00",
            endTime: "12:00"
        )

        let commTheories = Course(
            code: "COMM 403",
            name: "Communication Theories",
            department: "Journalism",
            credits: 4,
            semesterId: semesterId,
            professor: profTheories,
            colorHex: "#06B6D4",
            aiMemorySummary: "Covers Frankfurt School, Agenda Setting theory, Cultivation Theory, and Network Society paradigms.",
            lectureRoom: "Amphi 3",
            weeklyClassDay: "Tuesday",
            startTime: "10:00",
            endTime: "13:00"
        )

        let researchMethods = Course(
            code: "COMM 405",
            name: "Research Methods",
            department: "Social Sciences",
            credits: 4,
            semesterId: semesterId,
            professor: profMethods,
            colorHex: "#10B981",
            aiMemorySummary: "Quantitative survey methodology, SPSS/Python regression analytics, and qualitative discourse analysis.",
            lectureRoom: "Seminar Hall 4",
            weeklyClassDay: "Wednesday",
            startTime: "14:00",
            endTime: "17:00"
        )

        let newsWorkshop = Course(
            code: "JOUR 407",
            name: "News Workshop",
            department: "Applied Media",
            credits: 3,
            semesterId: semesterId,
            professor: profWorkshop,
            colorHex: "#F59E0B",
            aiMemorySummary: "Hands-on investigative journalism, multimedia storytelling, deadline management, and editorial review.",
            lectureRoom: "Newsroom Lab",
            weeklyClassDay: "Thursday",
            startTime: "11:00",
            endTime: "14:00"
        )

        let mediaEthics = Course(
            code: "COMM 409",
            name: "Media Ethics & Society",
            department: "Media Studies",
            credits: 3,
            semesterId: semesterId,
            colorHex: "#8B5CF6",
            aiMemorySummary: "Journalistic independence, whistleblowing safeguards, verification protocols against disinformation.",
            lectureRoom: "Room 204",
            weeklyClassDay: "Friday",
            startTime: "09:30",
            endTime: "12:30"
        )

        let digitalJournalism = Course(
            code: "JOUR 411",
            name: "Digital Journalism & AI",
            department: "Digital Arts",
            credits: 3,
            semesterId: semesterId,
            colorHex: "#EC4899",
            aiMemorySummary: "Algorithmic curation, automated fact checking, synthetic media detection, and LLM news assistants.",
            lectureRoom: "Tech Lab 1",
            weeklyClassDay: "Wednesday",
            startTime: "09:00",
            endTime: "12:00"
        )

        let graduationProject = Course(
            code: "COMM 499",
            name: "Senior Capstone Project",
            department: "Faculty Deanery",
            credits: 6,
            semesterId: semesterId,
            colorHex: "#EF4444",
            aiMemorySummary: "Graduation capstone: comprehensive investigative documentary and interactive web feature.",
            lectureRoom: "Studio A",
            weeklyClassDay: "Friday",
            startTime: "14:00",
            endTime: "17:00"
        )

        let courses: [Course] = [commLaw, commTheories, researchMethods, newsWorkshop, mediaEthics, digitalJournalism, graduationProject]
        try await store.saveAll(courses)

        // Today's Missions & Tasks
        let missions: [AcademicTask] = [
            AcademicTask(
                courseId: commLaw.id,
                title: "09:00 Communication Law",
                scheduledTime: "09:00",
                estimatedMinutes: 90,
                isCompleted: true,
                priority: .urgent,
                category: .mission
            ),
            AcademicTask(
                courseId: newsWorkshop.id,
                title: "11:00 News Workshop",
                scheduledTime: "11:00",
                estimatedMinutes: 120,
                isCompleted: false,
                priority: .high,
                category: .mission
            ),
            AcademicTask(
                courseId: researchMethods.id,
                title: "14:30 Research Methods Study",
                scheduledTime: "14:30",
                estimatedMinutes: 60,
                isCompleted: false,
                priority: .medium,
                category: .mission
            ),
            AcademicTask(
                courseId: newsWorkshop.id,
                title: "18:00 Assignment Deadline",
                scheduledTime: "18:00",
                estimatedMinutes: 45,
                isCompleted: false,
                priority: .urgent,
                category: .mission
            )
        ]
        try await store.saveAll(missions)

        // Academic Tasks (3 tasks today)
        let generalTasks: [AcademicTask] = [
            AcademicTask(
                courseId: commLaw.id,
                title: "Review Defamation Case Briefs (Pages 45-72)",
                scheduledTime: "15:00",
                estimatedMinutes: 40,
                priority: .high,
                category: .study
            ),
            AcademicTask(
                courseId: commTheories.id,
                title: "Generate Flashcards for Agenda Setting Model",
                scheduledTime: "16:30",
                estimatedMinutes: 25,
                priority: .medium,
                category: .revision
            ),
            AcademicTask(
                courseId: researchMethods.id,
                title: "Draft Survey Sample Strategy (n=250)",
                scheduledTime: "19:30",
                estimatedMinutes: 50,
                priority: .high,
                category: .study
            )
        ]
        try await store.saveAll(generalTasks)

        // Upcoming Exams (2 upcoming exams)
        let examLaw = Exam(
            courseId: commLaw.id,
            title: "Communication Law Midterm",
            examType: .midterm,
            examDate: Calendar.current.date(byAdding: .day, value: 5, to: Date()) ?? Date(),
            room: "Amphi 1",
            weightPercentage: 40,
            targetGrade: 95.0,
            topicsCovered: ["Press Freedom", "Censorship Laws", "Digital Copyright Infringement", "KVKK Privacy Data Protection"],
            notes: "High weight on recent Supreme Court digital speech rulings."
        )

        let examTheories = Exam(
            courseId: commTheories.id,
            title: "Communication Theories Midterm",
            examType: .midterm,
            examDate: Calendar.current.date(byAdding: .day, value: 12, to: Date()) ?? Date(),
            room: "Amphi 3",
            weightPercentage: 40,
            targetGrade: 90.0,
            topicsCovered: ["Two-Step Flow", "Cultivation Theory", "Uses and Gratifications", "Structuralism"]
        )
        let exams: [Exam] = [examLaw, examTheories]
        try await store.saveAll(exams)

        // Upcoming Assignment (1 assignment due)
        let assignmentNews = Assignment(
            courseId: newsWorkshop.id,
            title: "Investigative News Draft & Source Dossier",
            prompt: "Submit a 1,200-word investigative article complete with at least 3 verified on-the-record sources.",
            dueDate: Calendar.current.date(byAdding: .hour, value: 18, to: Date()) ?? Date(),
            status: .inProgress,
            maxScore: 100,
            priority: .urgent,
            attachments: ["interview_transcript_01.pdf", "fact_sheet.xlsx"]
        )
        try await store.save(assignmentNews)

        // Notes for Communication Law
        let lawNote = Note(
            courseId: commLaw.id,
            title: "Digital Defamation and Intermediary Liability",
            rawContent: "Article 125 of TCK establishes defamation standards. In digital media, platform hosts have notice-and-take-down obligations. Key test is public interest vs individual honor.",
            aiStructuredSummary: "Core principles: 1) Public interest doctrine protects investigative journalism; 2) Host providers are exempt from proactive censorship but strictly liable post-notice.",
            keyTakeaways: [
                "Public figures possess narrower privacy protection in political critiques",
                "Notice-and-take-down must be acted on within 4 hours for urgent court orders",
                "KVKK Article 6 imposes criminal penalties on sensitive personal data breaches"
            ],
            tags: ["Law", "Digital Media", "TCK", "Privacy"],
            isAiProcessed: true
        )
        try await store.save(lawNote)

        // Flashcards
        let flashcard1 = Flashcard(
            courseId: commLaw.id,
            deckTitle: "TCK Law & Media",
            question: "What is the legal distinction between a content provider and a hosting provider?",
            answer: "A content provider produces and publishes original material and bears direct criminal liability. A hosting provider merely supplies server storage and bandwidth, bearing conditional liability upon notification."
        )
        let flashcard2 = Flashcard(
            courseId: commTheories.id,
            deckTitle: "Classic Theories",
            question: "Who formulated the Agenda Setting Theory and what is its core premise?",
            answer: "Maxwell McCombs and Donald Shaw (1972). Core premise: The media does not tell people what to think, but what to think about."
        )
        let flashcards: [Flashcard] = [flashcard1, flashcard2]
        try await store.saveAll(flashcards)

        // Graduation Progress (OPERATION GRADUATION D-126, 87%)
        let grad = GraduationProgress(
            codename: "OPERATION GRADUATION",
            daysRemaining: 126,
            totalCreditsRequired: 240,
            completedCredits: 208,
            progressPercentage: 87.0,
            requirements: [
                GraduationRequirementItem(title: "Senior Capstone Defense", isSatisfied: false, category: "Core Requirement", details: "Scheduled for June 2027"),
                GraduationRequirementItem(title: "Minimum Cumulative GPA ≥ 3.00", isSatisfied: true, category: "Academic Standing", details: "Current: 3.84 / 4.00"),
                GraduationRequirementItem(title: "Mandatory Media Internship (60 Days)", isSatisfied: true, category: "Fieldwork", details: "Completed at National News Agency"),
                GraduationRequirementItem(title: "Departmental Electives (24 ECTS)", isSatisfied: true, category: "Electives", details: "All 24 ECTS cleared")
            ]
        )
        try await store.save(grad)

        // Student Profile & GPA
        let profile = StudentProfile(
            firstName: "Student",
            lastName: "Commander",
            universityName: "Istanbul University",
            faculty: "Faculty of Communication",
            department: "Journalism",
            studentNumber: "202401089",
            currentSemester: "Semester 7 (Senior)",
            academicYear: "2026 - 2027",
            targetGPA: 3.85,
            email: "student@academicos.local"
        )
        try await store.save(profile)

        let gpa = GPARecord(
            semesterId: semesterId,
            semesterName: "Fall 2026",
            currentGPA: 3.84,
            cumulativeGPA: 3.78,
            totalCreditsAttempted: 112,
            totalCreditsEarned: 112,
            targetGraduationGPA: 3.80,
            honorRoll: true
        )
        try await store.save(gpa)
    }
}
