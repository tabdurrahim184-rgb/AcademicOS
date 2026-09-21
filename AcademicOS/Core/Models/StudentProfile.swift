import Foundation

/// Identity, academic parameters, and preferences of the enrolled student.
public struct StudentProfile: Identifiable, Codable, Equatable, Sendable, Hashable {
    public let id: UUID
    public var firstName: String
    public var lastName: String
    public var universityName: String
    public var faculty: String
    public var department: String
    public var studentNumber: String
    public var currentSemester: String
    public var academicYear: String
    public var expectedGraduationDate: Date
    public var gpaScale: Double // Default 4.00
    public var targetGPA: Double
    public var email: String
    public var biometricLockEnabled: Bool
    public var preferredAIProvider: String
    public var allowCloudSync: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        firstName: String = "",
        lastName: String = "",
        universityName: String = "",
        faculty: String = "",
        department: String = "",
        studentNumber: String = "",
        currentSemester: String = "Semester 1",
        academicYear: String = "2026 - 2027",
        expectedGraduationDate: Date = Calendar.current.date(byAdding: .year, value: 2, to: Date()) ?? Date(),
        gpaScale: Double = 4.00,
        targetGPA: Double = 3.80,
        email: String = "",
        biometricLockEnabled: Bool = true,
        preferredAIProvider: String = "Auto (Smart Router)",
        allowCloudSync: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.universityName = universityName
        self.faculty = faculty
        self.department = department
        self.studentNumber = studentNumber
        self.currentSemester = currentSemester
        self.academicYear = academicYear
        self.expectedGraduationDate = expectedGraduationDate
        self.gpaScale = gpaScale
        self.targetGPA = targetGPA
        self.email = email
        self.biometricLockEnabled = biometricLockEnabled
        self.preferredAIProvider = preferredAIProvider
        self.allowCloudSync = allowCloudSync
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var fullName: String {
        let combined = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        return combined.isEmpty ? "Student" : combined
    }

    /// Real-time countdown calculation from expectedGraduationDate
    public var graduationCountdown: (totalDays: Int, years: Int, months: Int, days: Int) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let target = calendar.startOfDay(for: expectedGraduationDate)

        let totalDays = max(0, calendar.dateComponents([.day], from: today, to: target).day ?? 0)
        let components = calendar.dateComponents([.year, .month, .day], from: today, to: target)

        let years = max(0, components.year ?? 0)
        let months = max(0, components.month ?? 0)
        let days = max(0, components.day ?? 0)

        return (totalDays, years, months, days)
    }

    public var countdownDDayFormatted: String {
        return "D-\(graduationCountdown.totalDays)"
    }
}
