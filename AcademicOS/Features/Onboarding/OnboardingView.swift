import SwiftUI

/// Onboarding flow presented on first launch to capture the student's academic profile locally.
public struct OnboardingView: View {
    @EnvironmentObject private var container: AppContainer

    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var universityName: String = ""
    @State private var faculty: String = ""
    @State private var department: String = ""
    @State private var studentNumber: String = ""
    @State private var currentSemester: String = "Semester 1 (Freshman)"
    @State private var academicYear: String = "2026 - 2027"
    @State private var expectedGraduationDate: Date = Calendar.current.date(byAdding: .year, value: 4, to: Date()) ?? Date()
    @State private var gpaScale: Double = 4.00
    @State private var isSaving: Bool = false
    @State private var errorMessage: String?

    public let onComplete: () -> Void

    public init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.large) {
                    // Hero Header
                    VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                        HStack(spacing: Spacing.xxSmall) {
                            Image(systemName: "terminal.fill")
                                .foregroundColor(Color.academicPrimary)
                            Text("ACADEMICOS INITIALIZATION")
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                                .foregroundColor(Color.academicCyan)
                        }

                        Text("Initialize Your Academic Operating System")
                            .font(.commandDisplay)
                            .foregroundColor(Color.textPrimary)

                        Text("AcademicOS stores all data 100% locally on your iPhone. No cloud accounts, no data harvesting.")
                            .font(.commandSubheadline)
                            .foregroundColor(Color.textSecondary)
                    }
                    .padding(.top, Spacing.small)

                    // Personal Identity Card
                    AcademicCard(
                        cornerRadius: CornerRadius.large,
                        padding: Spacing.medium,
                        backgroundColor: Color(uiColor: .secondarySystemBackground)
                    ) {
                        VStack(alignment: .leading, spacing: Spacing.small) {
                            Text("STUDENT IDENTITY")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(Color.textSecondary)

                            HStack(spacing: Spacing.small) {
                                inputField(label: "First Name", placeholder: "e.g. John", text: $firstName)
                                inputField(label: "Last Name", placeholder: "e.g. Doe", text: $lastName)
                            }

                            inputField(label: "Student ID / Number (Optional)", placeholder: "e.g. 202401089", text: $studentNumber)
                        }
                    }

                    // Institution & Department Card
                    AcademicCard(
                        cornerRadius: CornerRadius.large,
                        padding: Spacing.medium,
                        backgroundColor: Color(uiColor: .secondarySystemBackground)
                    ) {
                        VStack(alignment: .leading, spacing: Spacing.small) {
                            Text("ACADEMIC INSTITUTION")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(Color.textSecondary)

                            inputField(label: "University / College", placeholder: "e.g. Istanbul University", text: $universityName)
                            inputField(label: "Faculty", placeholder: "e.g. Faculty of Communication", text: $faculty)
                            inputField(label: "Department / Program", placeholder: "e.g. Journalism & Media Studies", text: $department)
                        }
                    }

                    // Trajectory & Graduation Parameters
                    AcademicCard(
                        cornerRadius: CornerRadius.large,
                        padding: Spacing.medium,
                        backgroundColor: Color(uiColor: .secondarySystemBackground)
                    ) {
                        VStack(alignment: .leading, spacing: Spacing.small) {
                            Text("GRADUATION ROADMAP")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(Color.textSecondary)

                            HStack(spacing: Spacing.small) {
                                inputField(label: "Current Academic Year", placeholder: "2026 - 2027", text: $academicYear)
                                inputField(label: "Current Semester", placeholder: "Semester 7", text: $currentSemester)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Target Commencement / Graduation Date")
                                    .font(.commandCaption)
                                    .foregroundColor(Color.textSecondary)

                                DatePicker("", selection: $expectedGraduationDate, displayedComponents: .date)
                                    .datePickerStyle(.compact)
                                    .labelsHidden()
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("GPA Scale (Default: 4.00)")
                                    .font(.commandCaption)
                                    .foregroundColor(Color.textSecondary)

                                Picker("GPA Scale", selection: $gpaScale) {
                                    Text("4.00 Scale (US / Standard)").tag(4.00)
                                    Text("5.00 Scale").tag(5.00)
                                    Text("100 Point Scale").tag(100.0)
                                }
                                .pickerStyle(.segmented)
                            }
                        }
                    }

                    if let err = errorMessage {
                        Text(err)
                            .font(.commandCaption)
                            .foregroundColor(Color.academicCrimson)
                    }

                    // Primary Action Button
                    ActionButton(
                        isSaving ? "Setting Up OS..." : "Initialize AcademicOS",
                        icon: "arrow.right.circle.fill",
                        style: .primary
                    ) {
                        saveAndInitialize()
                    }
                    .disabled(firstName.isEmpty || universityName.isEmpty || isSaving)
                }
                .padding(.horizontal, Spacing.medium)
                .padding(.bottom, Spacing.xxxLarge)
            }
            .background(Color(uiColor: .systemBackground).ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func inputField(label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.commandCaption)
                .foregroundColor(Color.textSecondary)

            TextField(placeholder, text: text)
                .font(.commandBody)
                .padding(Spacing.small)
                .background(Color(uiColor: .tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        }
    }

    private func saveAndInitialize() {
        isSaving = true
        errorMessage = nil

        let profile = StudentProfile(
            firstName: firstName,
            lastName: lastName,
            universityName: universityName,
            faculty: faculty,
            department: department,
            studentNumber: studentNumber,
            currentSemester: currentSemester,
            academicYear: academicYear,
            expectedGraduationDate: expectedGraduationDate,
            gpaScale: gpaScale,
            targetGPA: 3.80,
            email: ""
        )

        Task {
            do {
                try await container.studentRepository.saveStudent(profile)
                await MainActor.run {
                    self.isSaving = false
                    self.onComplete()
                }
            } catch {
                await MainActor.run {
                    self.isSaving = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}
