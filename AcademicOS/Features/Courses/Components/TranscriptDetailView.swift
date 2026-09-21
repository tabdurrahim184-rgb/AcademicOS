import SwiftUI

/// Raw transcript viewer with inline search, timestamp-to-audio seeking, manual editing, and note generation.
public struct TranscriptDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var container: AppContainer
    @ObservedObject private var player = AudioPlaybackService.shared

    public let transcript: Transcript
    public let audioMetadata: AudioRecordingMetadata?

    @State private var editableFullText: String = ""
    @State private var searchQuery: String = ""
    @State private var isEditing: Bool = false
    @State private var showingSavedToast: Bool = false
    @State private var showingAddNoteSheet: Bool = false
    @State private var noteTitleInput: String = ""
    @State private var selectedSnippet: String = ""

    public init(transcript: Transcript, audioMetadata: AudioRecordingMetadata? = nil) {
        self.transcript = transcript
        self.audioMetadata = audioMetadata
        _editableFullText = State(initialValue: transcript.fullText)
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Audio Playback Bar if audio file is available
            if let meta = audioMetadata {
                audioPlaybackBar(for: meta)
            }

            // Search Bar
            searchHeader

            // Transcript Content
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.medium) {
                    if isEditing {
                        TextEditor(text: $editableFullText)
                            .font(.commandBody)
                            .frame(minHeight: 300)
                            .padding(Spacing.small)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                    } else {
                        // Segment List with Timestamps
                        ForEach(filteredSegments) { segment in
                            segmentRow(for: segment)
                        }
                    }
                }
                .padding(.horizontal, Spacing.medium)
                .padding(.vertical, Spacing.medium)
                .padding(.bottom, Spacing.xxxLarge)
            }
        }
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
        .navigationTitle("Lecture Transcript")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(isEditing ? "Done" : "Edit") {
                    if isEditing {
                        saveManualEdit()
                    }
                    isEditing.toggle()
                }
            }
        }
        .sheet(isPresented: $showingAddNoteSheet) {
            addNoteFromSelectionSheet
        }
        .task {
            if let meta = audioMetadata {
                try? player.loadAudio(relativeFilePath: meta.localRelativePath)
            }
        }
        .onDisappear {
            player.stop()
        }
    }

    private var searchHeader: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Color.textTertiary)
            TextField("Search transcript keywords...", text: $searchQuery)
                .font(.commandBody)
            if !searchQuery.isEmpty {
                Button(action: { searchQuery = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Color.textTertiary)
                }
            }
        }
        .padding(Spacing.small)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        .padding(.horizontal, Spacing.medium)
        .padding(.top, Spacing.small)
    }

    private func audioPlaybackBar(for meta: AudioRecordingMetadata) -> some View {
        HStack(spacing: Spacing.medium) {
            Button(action: {
                if player.isPlaying {
                    player.pause()
                } else {
                    player.play()
                }
            }) {
                Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(Color.academicPrimary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(formattedTime(player.currentTime) + " / " + formattedTime(player.duration))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.textPrimary)

                ProgressView(value: player.currentTime, total: max(1.0, player.duration))
                    .tint(Color.academicPrimary)
            }

            // Speed Selector
            Button(action: cyclePlaybackRate) {
                Text("\(String(format: "%.2fx", player.playbackRate))")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .padding(.horizontal, Spacing.xSmall)
                    .padding(.vertical, Spacing.xxxSmall)
                    .background(Color(uiColor: .tertiarySystemBackground))
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, Spacing.small)
        .background(Color(uiColor: .tertiarySystemBackground).opacity(0.8))
    }

    private func segmentRow(for segment: TranscriptSegment) -> some View {
        AcademicCard(
            cornerRadius: CornerRadius.medium,
            padding: Spacing.small,
            borderColor: segment.isMarkedImportant ? Color.academicAmber.opacity(0.4) : nil,
            backgroundColor: Color(uiColor: .secondarySystemBackground)
        ) {
            VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                HStack {
                    // Tap timestamp -> Jumps audio player!
                    Button(action: {
                        player.seek(to: segment.startSeconds)
                        player.play()
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 8))
                            Text(segment.formattedTimestamp)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                        }
                        .foregroundColor(Color.academicCyan)
                        .padding(.horizontal, Spacing.xSmall)
                        .padding(.vertical, 2)
                        .background(Color.academicCyan.opacity(0.12))
                        .clipShape(Capsule())
                    }

                    Spacer()

                    // Action menu: Copy, Note from selection, Mark Important
                    Menu {
                        Button("Copy Text", action: {
                            UIPasteboard.general.string = segment.text
                        })
                        Button("Create Note from Segment", action: {
                            selectedSnippet = segment.text
                            noteTitleInput = "Note @ \(segment.formattedTimestamp)"
                            showingAddNoteSheet = true
                        })
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundColor(Color.textSecondary)
                            .padding(4)
                    }
                }

                Text(segment.text)
                    .font(.commandBody)
                    .foregroundColor(Color.textPrimary)
                    .textSelection(.enabled)
            }
        }
    }

    private var filteredSegments: [TranscriptSegment] {
        if searchQuery.isEmpty {
            return transcript.segments
        }
        return transcript.segments.filter { $0.text.localizedCaseInsensitiveContains(searchQuery) }
    }

    private func cyclePlaybackRate() {
        let rates: [Float] = [1.0, 1.25, 1.5, 2.0, 0.75]
        let current = player.playbackRate
        let nextIndex = ((rates.firstIndex(of: current) ?? 0) + 1) % rates.count
        player.setPlaybackRate(rates[nextIndex])
    }

    private func saveManualEdit() {
        var updated = transcript
        updated.fullText = editableFullText
        Task {
            try? await container.recordingRepository.saveTranscript(updated)
        }
    }

    private var addNoteFromSelectionSheet: some View {
        NavigationStack {
            Form {
                Section("NOTE DETAILS") {
                    TextField("Title", text: $noteTitleInput)
                    TextEditor(text: $selectedSnippet)
                        .frame(minHeight: 150)
                }
            }
            .navigationTitle("Create Note from Transcript")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingAddNoteSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save Note") {
                        let note = Note(
                            courseId: transcript.courseId,
                            lectureSessionId: transcript.lectureSessionId,
                            title: noteTitleInput,
                            rawContent: selectedSnippet,
                            sourceType: .transcriptNote
                        )
                        Task {
                            try? await container.notesRepository.saveNote(note)
                            await MainActor.run {
                                showingAddNoteSheet = false
                            }
                        }
                    }
                }
            }
        }
    }

    private func formattedTime(_ seconds: Double) -> String {
        let total = Int(seconds)
        let mins = total / 60
        let secs = total % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}
