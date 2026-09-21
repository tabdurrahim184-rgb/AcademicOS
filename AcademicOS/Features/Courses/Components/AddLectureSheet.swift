import SwiftUI

/// Modal sheet for creating a new lecture session under an academic course.
public struct AddLectureSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var container: AppContainer

    public let courseId: UUID
    public let defaultClassroom: String
    public let defaultProfessor: String
    public let onSave: () -> Void

    @State private var topic: String = ""
    @State private var sessionDate: Date = Date()
    @State private var startTime: String = "09:00"
    @State private var endTime: String = "10:50"
    @State private var classroom: String = ""
    @State private var professorName: String = ""
    @State private var attendanceStatus: AttendanceStatus = .upcoming
    @State private var manualNotes: String = ""
    @State private var isSaving: Bool = false

    public init(
        courseId: UUID,
        defaultClassroom: String = "Amphi 1",
        defaultProfessor: String = "",
        onSave: @escaping () -> Void
    ) {
        self.courseId = courseId
        self.defaultClassroom = defaultClassroom
        self.defaultProfessor = defaultProfessor
        self.onSave = onSave
        _classroom = State(initialValue: defaultClassroom)
        _professorName = State(initialValue: defaultProfessor)
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("LECTURE DETAILS") {
                    TextField("Lecture Topic / Title (e.g. Freedom of Expression)", text: $topic)
                    DatePicker("Session Date", selection: $sessionDate, displayedComponents: .date)

                    HStack {
                        TextField("Start", text: $startTime)
                        Text("to")
                        TextField("End", text: $endTime)
                    }

                    TextField("Classroom / Hall", text: $classroom)
                    TextField("Lecturer", text: $professorName)
                }

                Section("ATTENDANCE") {
                    Picker("Attendance Status", selection: $attendanceStatus) {
                        ForEach(AttendanceStatus.allCases, id: \.self) { status in
                            Text(status.rawValue).tag(status)
                        }
                    }
                }

                Section("PRE-LECTURE NOTES / AGENDA") {
                    TextField("Key reading chapters or session objectives...", text: $manualNotes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("New Lecture Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving..." : "Save") {
                        saveLecture()
                    }
                    .disabled(topic.isEmpty || isSaving)
                }
            }
        }
    }

    private func saveLecture() {
        isSaving = true
        let session = LectureSession(
            courseId: courseId,
            topic: topic.trimmingCharacters(in: .whitespacesAndNewlines),
            sessionDate: sessionDate,
            startTime: startTime,
            endTime: endTime,
            classroom: classroom,
            professorName: professorName,
            attendanceStatus: attendanceStatus,
            manualNotes: manualNotes
        )

        Task {
            try? await container.lectureRepository.saveLecture(session)
            await MainActor.run {
                self.isSaving = false
                self.onSave()
                self.dismiss()
            }
        }
    }
}
