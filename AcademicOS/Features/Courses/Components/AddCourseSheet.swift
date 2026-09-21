import SwiftUI

/// Modal sheet for registering a new university course into local SQLite.
public struct AddCourseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var container: AppContainer

    @State private var courseCode: String = ""
    @State private var courseName: String = ""
    @State private var department: String = ""
    @State private var professorName: String = ""
    @State private var credits: Int = 3
    @State private var ects: Int = 5
    @State private var selectedDay: String = "Monday"
    @State private var startTime: String = "09:00"
    @State private var endTime: String = "11:50"
    @State private var classroom: String = "Amphi 1"
    @State private var selectedColorHex: String = "#4F46E5"
    @State private var notes: String = ""
    @State private var isSaving: Bool = false
    @State private var errorMessage: String?

    public let onSave: () -> Void

    private let availableDays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    private let availableColors = ["#4F46E5", "#06B6D4", "#10B981", "#F59E0B", "#EF4444", "#8B5CF6", "#EC4899"]

    public init(onSave: @escaping () -> Void) {
        self.onSave = onSave
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("COURSE IDENTIFIERS") {
                    TextField("Course Code (e.g. COMM 401)", text: $courseCode)
                    TextField("Course Name (e.g. Communication Law)", text: $courseName)
                    TextField("Department / Faculty", text: $department)
                    TextField("Instructor / Professor", text: $professorName)
                }

                Section("CREDITS & ACCREDITATION") {
                    Stepper("Local Credits: \(credits)", value: $credits, in: 1...12)
                    Stepper("ECTS Credits: \(ects)", value: $ects, in: 1...30)
                }

                Section("SCHEDULE & TIMETABLE") {
                    Picker("Class Day", selection: $selectedDay) {
                        ForEach(availableDays, id: \.self) { day in
                            Text(day).tag(day)
                        }
                    }

                    HStack {
                        TextField("Start Time", text: $startTime)
                        Text("to")
                        TextField("End Time", text: $endTime)
                    }

                    TextField("Lecture Hall / Room", text: $classroom)
                }

                Section("VISUAL BADGE") {
                    HStack(spacing: Spacing.medium) {
                        ForEach(availableColors, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: selectedColorHex == hex ? 2 : 0)
                                )
                                .onTapGesture {
                                    selectedColorHex = hex
                                }
                        }
                    }
                    .padding(.vertical, Spacing.xxSmall)
                }

                Section("SYLLABUS & PRELIMINARY NOTES") {
                    TextField("Course policies, grading rubric, or notes...", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                if let err = errorMessage {
                    Section {
                        Text(err)
                            .foregroundColor(Color.academicCrimson)
                            .font(.commandCaption)
                    }
                }
            }
            .navigationTitle("Add Course")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving..." : "Save") {
                        saveCourse()
                    }
                    .disabled(courseCode.isEmpty || courseName.isEmpty || isSaving)
                }
            }
        }
    }

    private func saveCourse() {
        isSaving = true
        errorMessage = nil

        Task {
            do {
                let activeSemester = try await container.semesterRepository.getActiveSemester()
                let semesterId = activeSemester?.id ?? UUID()

                let prof = professorName.isEmpty ? nil : Professor(name: professorName)

                let newCourse = Course(
                    code: courseCode.trimmingCharacters(in: .whitespacesAndNewlines),
                    name: courseName.trimmingCharacters(in: .whitespacesAndNewlines),
                    department: department.trimmingCharacters(in: .whitespacesAndNewlines),
                    credits: credits,
                    ects: ects,
                    semesterId: semesterId,
                    professor: prof,
                    colorHex: selectedColorHex,
                    lectureRoom: classroom,
                    weeklyClassDay: selectedDay,
                    startTime: startTime,
                    endTime: endTime,
                    notes: notes,
                    status: .active
                )

                try await container.courseRepository.saveCourse(newCourse)

                await MainActor.run {
                    self.isSaving = false
                    self.onSave()
                    self.dismiss()
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
