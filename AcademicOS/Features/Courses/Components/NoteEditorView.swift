import SwiftUI

/// Rich academic note editor supporting manual, transcript, and AI structured notes with autosave.
public struct NoteEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var container: AppContainer

    public let courseId: UUID
    public let existingNote: Note?
    public let onSave: () -> Void

    @State private var title: String = ""
    @State private var rawContent: String = ""
    @State private var sourceType: NoteSourceType = .manualNote
    @State private var isPinned: Bool = false
    @State private var tagsString: String = ""
    @State private var isSaving: Bool = false

    public init(
        courseId: UUID,
        existingNote: Note? = nil,
        onSave: @escaping () -> Void
    ) {
        self.courseId = courseId
        self.existingNote = existingNote
        self.onSave = onSave

        if let note = existingNote {
            _title = State(initialValue: note.title)
            _rawContent = State(initialValue: note.rawContent)
            _sourceType = State(initialValue: note.sourceType)
            _isPinned = State(initialValue: note.isPinned)
            _tagsString = State(initialValue: note.tags.joined(separator: ", "))
        }
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("NOTE HEADER") {
                    TextField("Note Title", text: $title)
                    Picker("Note Type", selection: $sourceType) {
                        ForEach(NoteSourceType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    Toggle("Pin Note to Top", isOn: $isPinned)
                    TextField("Tags (comma separated)", text: $tagsString)
                }

                Section("CONTENT") {
                    TextEditor(text: $rawContent)
                        .font(.commandBody)
                        .frame(minHeight: 250)
                }
            }
            .navigationTitle(existingNote == nil ? "New Note" : "Edit Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving..." : "Save") {
                        saveNote()
                    }
                    .disabled(title.isEmpty || isSaving)
                }
            }
        }
    }

    private func saveNote() {
        isSaving = true
        let tags = tagsString
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var note = existingNote ?? Note(courseId: courseId, title: title, rawContent: rawContent)
        note.title = title
        note.rawContent = rawContent
        note.sourceType = sourceType
        note.isPinned = isPinned
        note.tags = tags
        note.updatedAt = Date()

        Task {
            try? await container.notesRepository.saveNote(note)
            await MainActor.run {
                self.isSaving = false
                self.onSave()
                self.dismiss()
            }
        }
    }
}
