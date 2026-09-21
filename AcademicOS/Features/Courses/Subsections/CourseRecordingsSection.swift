import SwiftUI

/// Recordings tab inside Course Detail displaying audio captures, live transcription status, playback, and transcript viewing.
public struct CourseRecordingsSection: View {
    @EnvironmentObject private var container: AppContainer
    public let course: Course

    @State private var recordings: [AudioRecordingMetadata] = []
    @State private var showingRecordingCockpit: Bool = false
    @State private var selectedTranscript: Transcript?
    @State private var selectedAudioForTranscript: AudioRecordingMetadata?
    @State private var recordingToDelete: AudioRecordingMetadata?
    @State private var showingDeleteConfirmation: Bool = false
    @State private var isLoading: Bool = false

    public init(course: Course) {
        self.course = course
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            // Action button to start live lecture recording
            ActionButton(
                "Record Live Lecture",
                icon: "waveform.badge.mic",
                style: .primary
            ) {
                showingRecordingCockpit = true
            }

            if isLoading && recordings.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.large)
            } else if recordings.isEmpty {
                EmptyStateView(
                    icon: "waveform.circle",
                    title: "No Recordings for This Course",
                    message: "Tap 'Record Live Lecture' to start streaming audio progressively to disk with speech transcription."
                )
            } else {
                VStack(spacing: Spacing.small) {
                    ForEach(recordings) { rec in
                        recordingRow(for: rec)
                    }
                }
            }
        }
        .sheet(isPresented: $showingRecordingCockpit) {
            LectureRecordingView(course: course) {
                Task { await loadRecordings() }
            }
        }
        .sheet(item: $selectedTranscript) { transcript in
            TranscriptDetailView(
                transcript: transcript,
                audioMetadata: selectedAudioForTranscript
            )
        }
        .confirmationDialog(
            "Delete Lecture Recording?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Recording", role: .destructive) {
                if let rec = recordingToDelete {
                    deleteRecording(rec)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove the audio file from disk. Generated notes and transcripts will remain intact.")
        }
        .task {
            await loadRecordings()
        }
    }

    private func recordingRow(for rec: AudioRecordingMetadata) -> some View {
        AcademicCard(
            cornerRadius: CornerRadius.medium,
            padding: Spacing.medium,
            backgroundColor: Color(uiColor: .secondarySystemBackground)
        ) {
            VStack(alignment: .leading, spacing: Spacing.small) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(DateFormatter.localizedString(from: rec.recordedAt, dateStyle: .medium, timeStyle: .short))
                            .font(.commandHeadline)
                            .foregroundColor(Color.textPrimary)

                        HStack(spacing: Spacing.small) {
                            Text(formatDuration(rec.durationSeconds))
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(Color.academicCyan)

                            Text("•")

                            Text(formatFileSize(rec.fileSizeByte))
                                .font(.commandCaption)
                                .foregroundColor(Color.textSecondary)
                        }
                    }

                    Spacer()

                    StatusBadge(rec.transcriptionStatus.rawValue.uppercased(), style: badgeStyle(for: rec.transcriptionStatus))
                }

                Divider().background(Color.borderSubtle)

                HStack {
                    // View / Transcribe button
                    Button(action: {
                        openTranscriptOrTranscribe(for: rec)
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: rec.transcriptionStatus == .completed ? "doc.text.magnifyingglass" : "sparkles")
                                .font(.system(size: 11))
                            Text(rec.transcriptionStatus == .completed ? "View Transcript" : "Transcribe Now")
                                .font(.commandCaption)
                        }
                        .foregroundColor(Color.academicPrimary)
                    }

                    Spacer()

                    // Delete button
                    Button(action: {
                        recordingToDelete = rec
                        showingDeleteConfirmation = true
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundColor(Color.textTertiary)
                    }
                }
            }
        }
    }

    private func loadRecordings() async {
        isLoading = true
        do {
            self.recordings = try await container.recordingRepository.getRecordings(forCourseId: course.id)
        } catch {
            print("Recordings load error: \(error)")
        }
        isLoading = false
    }

    private func openTranscriptOrTranscribe(for rec: AudioRecordingMetadata) {
        Task {
            if let existing = try? await container.recordingRepository.getTranscript(forRecordingId: rec.id) {
                await MainActor.run {
                    self.selectedAudioForTranscript = rec
                    self.selectedTranscript = existing
                }
            } else {
                // Trigger speech transcription
                do {
                    let transcript = try await container.transcriptionService.transcribeRecording(
                        recording: rec,
                        requireOnDevice: true
                    )
                    await MainActor.run {
                        self.selectedAudioForTranscript = rec
                        self.selectedTranscript = transcript
                        Task { await loadRecordings() }
                    }
                } catch {
                    print("Transcription failed: \(error)")
                }
            }
        }
    }

    private func deleteRecording(_ rec: AudioRecordingMetadata) {
        Task {
            try? await container.recordingRepository.deleteRecording(id: rec.id)
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let fileURL = docs.appendingPathComponent(rec.localRelativePath)
            try? FileManager.default.removeItem(at: fileURL)
            await loadRecordings()
        }
    }

    private func badgeStyle(for status: TranscriptionStatus) -> StatusBadge.Style {
        switch status {
        case .completed: return .emerald
        case .transcribingLocal, .transcribingCloud: return .cyan
        case .failed: return .crimson
        default: return .neutral
        }
    }

    private func formatDuration(_ seconds: Double) -> String {
        let total = Int(seconds)
        let mins = total / 60
        let secs = total % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
