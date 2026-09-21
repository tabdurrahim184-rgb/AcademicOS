import SwiftUI

/// Filter modes for the Notes section supporting the 3 AI Note modes + Manual notes.
public enum NoteFilterMode: String, CaseIterable {
    case all = "Tümü"
    case full = "Full Not"
    case study = "Çalışma"
    case nokta = "Nokta Atışı"
}

/// Notes tab inside Course Detail displaying AI-structured and manual lecture notes
/// with support for 3 note modalities and edit protection.
public struct CourseNotesSection: View {
    @EnvironmentObject private var container: AppContainer
    public let course: Course

    @State private var notes: [Note] = []
    @State private var selectedFilter: NoteFilterMode = .all
    @State private var showingAddNoteSheet: Bool = false
    @State private var selectedNoteToEdit: Note?
    @State private var isLoading: Bool = false

    public init(course: Course) {
        self.course = course
    }

    private var filteredNotes: [Note] {
        switch selectedFilter {
        case .all:
            return notes
        case .full:
            return notes.filter { !$0.rawContent.isEmpty }
        case .study:
            return notes.filter { !$0.studyNotesContent.isEmpty }
        case .nokta:
            return notes.filter { !$0.noktaAtisiContent.isEmpty }
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            // New Note Action Button
            ActionButton(
                "New Lecture Note",
                icon: "square.and.pencil",
                style: .primary
            ) {
                selectedNoteToEdit = nil
                showingAddNoteSheet = true
            }

            // Mode Selector Picker
            Picker("Note Mode", selection: $selectedFilter) {
                ForEach(NoteFilterMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(SegmentedPickerStyle())

            if isLoading && notes.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.large)
            } else if filteredNotes.isEmpty {
                EmptyStateView(
                    icon: "note.text",
                    title: "No Notes in '\(selectedFilter.rawValue)'",
                    message: "Process a lecture or create manual notes to generate notes in this mode."
                )
            } else {
                ForEach(filteredNotes) { note in
                    AcademicCard(
                        cornerRadius: CornerRadius.medium,
                        padding: Spacing.medium,
                        backgroundColor: Color(uiColor: .secondarySystemBackground)
                    ) {
                        VStack(alignment: .leading, spacing: Spacing.small) {
                            HStack {
                                Text(note.title)
                                    .font(.commandHeadline)
                                    .foregroundColor(Color.textPrimary)

                                Spacer()

                                if note.isPinned {
                                    Image(systemName: "pin.fill")
                                        .font(.system(size: 11))
                                        .foregroundColor(Color.academicAmber)
                                }

                                if note.isUserEdited {
                                    StatusBadge("USER EDITED", style: .amber)
                                }

                                StatusBadge(note.sourceType.rawValue.uppercased(), style: note.sourceType == .aiStructuredNote ? .emerald : .neutral)
                            }

                            // Content preview based on selected mode
                            Text(contentPreview(for: note))
                                .font(.commandBody)
                                .foregroundColor(Color.textSecondary)
                                .lineLimit(3)

                            HStack {
                                HStack(spacing: 4) {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .font(.system(size: 10))
                                    Text("v\(note.activeVersion)")
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                }
                                .foregroundColor(Color.textTertiary)

                                Spacer()

                                if !note.tags.isEmpty {
                                    HStack(spacing: Spacing.xxSmall) {
                                        ForEach(note.tags.prefix(3), id: \.self) { tag in
                                            Text("#\(tag)")
                                                .font(.commandCaption)
                                                .foregroundColor(Color.academicPrimary)
                                        }
                                    }
                                }
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedNoteToEdit = note
                            showingAddNoteSheet = true
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddNoteSheet) {
            NoteEditorView(
                courseId: course.id,
                existingNote: selectedNoteToEdit
            ) {
                Task { await loadNotes() }
            }
        }
        .task {
            await loadNotes()
        }
    }

    private func contentPreview(for note: Note) -> String {
        switch selectedFilter {
        case .all, .full:
            return note.rawContent
        case .study:
            return note.studyNotesContent.isEmpty ? note.rawContent : note.studyNotesContent
        case .nokta:
            return note.noktaAtisiContent.isEmpty ? note.rawContent : note.noktaAtisiContent
        }
    }

    private func loadNotes() async {
        isLoading = true
        do {
            self.notes = try await container.notesRepository.getNotes(forCourseId: course.id)
        } catch {
            print("Notes load error: \(error)")
        }
        isLoading = false
    }
}
