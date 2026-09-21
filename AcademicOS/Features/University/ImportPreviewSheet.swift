import SwiftUI

/// Pre-import confirmation sheet displaying discovered portal counts and category toggles.
/// CRITICAL: Nothing is committed to SQLite until the student explicitly taps "IMPORT SELECTED DATA".
public struct ImportPreviewSheet: View {
    public let universityName: String
    public let payload: RemoteUniversityPayload
    public let onCommit: ([String]) -> Void
    public let onCancel: () -> Void

    @State private var importCourses: Bool = true
    @State private var importExams: Bool = true
    @State private var importAssignments: Bool = true
    @State private var importAnnouncements: Bool = true
    @State private var importDocuments: Bool = true
    @State private var importGrades: Bool = true
    @State private var importAttendance: Bool = true

    public init(
        universityName: String,
        payload: RemoteUniversityPayload,
        onCommit: @escaping ([String]) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.universityName = universityName
        self.payload = payload
        self.onCommit = onCommit
        self.onCancel = onCancel
    }

    public var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(universityName)
                            .font(.headline)
                        Text("Aşağıdaki veriler üniversite portalından tespit edildi. İçeri aktarmak istediğiniz kategorileri seçin.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section("Keşfedilen Veriler") {
                    Toggle(isOn: $importCourses) {
                        Label("\(payload.courses.count) Kayıtlı Ders", systemImage: "book.closed.fill")
                    }

                    Toggle(isOn: $importExams) {
                        Label("\(payload.exams.count) Sınav Takvimi", systemImage: "calendar.badge.clock")
                    }

                    Toggle(isOn: $importAssignments) {
                        Label("\(payload.assignments.count) Ödev / Görev", systemImage: "doc.text.badge.plus")
                    }

                    Toggle(isOn: $importAnnouncements) {
                        Label("\(payload.announcements.count) Resmi Duyuru", systemImage: "megaphone.fill")
                    }

                    Toggle(isOn: $importDocuments) {
                        Label("\(payload.documents.count) Ders Materyali", systemImage: "folder.fill")
                    }

                    Toggle(isOn: $importGrades) {
                        Label("\(payload.grades.count) Not Değerlendirmesi", systemImage: "chart.bar.fill")
                    }

                    Toggle(isOn: $importAttendance) {
                        Label("\(payload.attendances.count) Devamsızlık Kaydı", systemImage: "person.crop.circle.badge.checkmark")
                    }
                }

                if hasAmbiguousItems {
                    Section("Doğrulama Uyarısı") {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Bazı sınav tarihleri veya ders eşleşmeleri tam netleşmemiştir. İçe aktarım sonrasında kontrol etmeniz önerilir.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("İçe Aktarma Önizleme")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("İÇE AKTAR") {
                        var selected: [String] = []
                        if importCourses { selected.append("Courses") }
                        if importExams { selected.append("Exams") }
                        if importAssignments { selected.append("Assignments") }
                        if importAnnouncements { selected.append("Announcements") }
                        if importDocuments { selected.append("Documents") }
                        if importGrades { selected.append("Grades") }
                        if importAttendance { selected.append("Attendance") }
                        onCommit(selected)
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }

    private var hasAmbiguousItems: Bool {
        return payload.exams.contains { $0.requiresUserConfirmation } ||
               payload.assignments.contains { $0.requiresUserConfirmation }
    }
}
