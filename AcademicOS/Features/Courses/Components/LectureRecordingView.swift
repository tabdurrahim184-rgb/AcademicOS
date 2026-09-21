import SwiftUI

/// Live lecture audio recording cockpit with large primary controls, live waveform, elapsed timer, and moment tagging.
public struct LectureRecordingView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var container: AppContainer
    @ObservedObject private var recorder = AudioRecordingService.shared

    public let course: Course
    public let lectureSession: LectureSession?
    public let onRecordingFinished: () -> Void

    @State private var keepScreenAwake: Bool = true
    @State private var showingMarkerSheet: Bool = false
    @State private var markerNoteInput: String = ""
    @State private var selectedMarkerType: AudioMarkerType = .important
    @State private var errorMessage: String?

    public init(
        course: Course,
        lectureSession: LectureSession? = nil,
        onRecordingFinished: @escaping () -> Void
    ) {
        self.course = course
        self.lectureSession = lectureSession
        self.onRecordingFinished = onRecordingFinished
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.large) {
                // Header context
                headerContext

                Spacer()

                // Live Audio Waveform / Metering visualization
                waveformVisualizer

                // Elapsed Time Display
                Text(formattedTime(recorder.elapsedSeconds))
                    .font(.system(size: 54, weight: .black, design: .monospaced))
                    .foregroundColor(recorder.state == .recording ? Color.textPrimary : Color.textSecondary)

                // Recording State Status Badge
                stateBadge

                Spacer()

                // "MARK IMPORTANT" Moment Tagger
                if recorder.state == .recording || recorder.state == .paused {
                    markerActionButtons
                }

                // Primary Large Record / Pause / Stop Controls
                primaryControls
            }
            .padding(.horizontal, Spacing.large)
            .padding(.bottom, Spacing.xLarge)
            .background(Color(uiColor: .systemBackground).ignoresSafeArea())
            .navigationTitle("Live Lecture Recording")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        if recorder.state == .recording {
                            _ = recorder.stopRecording()
                        }
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Toggle(isOn: $keepScreenAwake) {
                        Image(systemName: keepScreenAwake ? "sun.max.fill" : "sun.min")
                            .font(.system(size: 13))
                    }
                    .toggleStyle(.button)
                }
            }
            .task {
                if !recorder.hasMicrophonePermission {
                    _ = await recorder.requestMicrophonePermission()
                }
            }
        }
    }

    private var headerContext: some View {
        AcademicCard(
            cornerRadius: CornerRadius.large,
            padding: Spacing.medium,
            backgroundColor: Color(uiColor: .secondarySystemBackground)
        ) {
            VStack(alignment: .leading, spacing: 3) {
                Text(course.code)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: course.colorHex))

                Text(lectureSession?.topic ?? course.name)
                    .font(.commandHeadline)
                    .foregroundColor(Color.textPrimary)

                Text(lectureSession?.topic ?? "Live Lecture Audio")
                    .font(.commandCaption)
                    .foregroundColor(Color.textSecondary)
            }

            Spacer()

            Button("Cancel") {
                if recorder.state.isRecordingOrPaused {
                    _ = recorder.stopRecording()
                }
                dismiss()
            }
            .font(.commandSubheadline)
            .foregroundColor(Color.textSecondary)
        }
    }

    private var waveformVisualizer: some View {
        HStack(spacing: 4) {
            ForEach(0..<24, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(barColor(for: index))
                    .frame(width: 4, height: barHeight(for: index))
                    .animation(.spring(response: 0.2, dampingFraction: 0.5), value: recorder.audioPowerLevel)
            }
        }
        .frame(height: 100)
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .strokeBorder(Color.borderSubtle, lineWidth: 1)
        )
    }

    private func barColor(for index: Int) -> Color {
        if recorder.state == .recording {
            return Color.academicCrimson
        } else if recorder.state == .pausedByUser || recorder.state == .interruptedBySystem {
            return Color.academicAmber
        } else {
            return Color.textTertiary
        }
    }

    private func barHeight(for index: Int) -> CGFloat {
        guard recorder.state == .recording else { return 8.0 }
        let power = recorder.audioPowerLevel
        let wave = sin(Double(index) * 0.4 + recorder.elapsedSeconds * 4)
        let normalizedPower = CGFloat(power) * (CGFloat(wave + 1.2) / 2.0)
        return max(0.15, min(1.0, normalizedPower)) * 80.0
    }

    private var stateBadge: some View {
        Group {
            switch recorder.state {
            case .idle:
                StatusBadge("STANDBY", style: .neutral)
            case .recording:
                StatusBadge("RECORDING LIVE", icon: "circle.fill", style: .crimson)
            case .pausedByUser:
                StatusBadge("PAUSED BY USER", icon: "pause.fill", style: .amber)
            case .interruptedBySystem:
                StatusBadge("INTERRUPTED (AUDIO SAFE)", icon: "phone.down.circle.fill", style: .amber)
            case .resuming:
                StatusBadge("RESUMING AUDIO...", icon: "arrow.triangle.2.circlepath", style: .cyan)
            case .stopped:
                StatusBadge("RECORDING SAVED", icon: "checkmark", style: .emerald)
            case .failed(let err):
                StatusBadge("ERROR: \(err)", style: .crimson)
            }
        }
    }

    private var markerActionButtons: some View {
        VStack(spacing: Spacing.xSmall) {
            HStack {
                Text("TAG LECTURE MOMENT")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.textTertiary)
                Spacer()
                Text("\(recorder.currentMarkers.count) Pinned")
                    .font(.commandCaption)
                    .foregroundColor(Color.textSecondary)
            }

            HStack(spacing: Spacing.xSmall) {
                markerPill(type: .examHint)
                markerPill(type: .important)
                markerPill(type: .definition)
                markerPill(type: .reviewLater)
            }
        }
        .padding(.horizontal, Spacing.small)
    }

    private func markerPill(type: AudioMarkerType) -> some View {
        Button(action: {
            recorder.markImportant(type: type)
        }) {
            HStack(spacing: 3) {
                Image(systemName: type.iconName)
                    .font(.system(size: 10))
                Text(type.rawValue.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
            }
            .padding(.horizontal, Spacing.small)
            .padding(.vertical, Spacing.xSmall)
            .background(Color(hex: type.tagColorHex).opacity(0.15))
            .foregroundColor(Color(hex: type.tagColorHex))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(Color(hex: type.tagColorHex).opacity(0.4), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private var primaryControls: some View {
        HStack(spacing: Spacing.large) {
            if recorder.state == .recording {
                // Pause button
                Button(action: { recorder.pauseRecording() }) {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color.textPrimary)
                        .frame(width: 56, height: 56)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .clipShape(Circle())
                }

                // Stop & Save button (Large Primary)
                Button(action: { saveAndFinishRecording() }) {
                    ZStack {
                        Circle()
                            .fill(Color.academicCrimson)
                            .frame(width: 78, height: 78)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white)
                            .frame(width: 26, height: 26)
                    }
                }

            } else if recorder.state == .pausedByUser || recorder.state == .interruptedBySystem {
                // Resume button
                Button(action: { recorder.resumeRecording() }) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 26))
                        .foregroundColor(Color.white)
                        .frame(width: 78, height: 78)
                        .background(Color.academicEmerald)
                        .clipShape(Circle())
                }

                // Finish button
                Button(action: { saveAndFinishRecording() }) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 22))
                        .foregroundColor(Color.textPrimary)
                        .frame(width: 56, height: 56)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .clipShape(Circle())
                }

            } else if recorder.state == .resuming {
                ProgressView()
                    .tint(Color.academicCyan)
                    .frame(width: 78, height: 78)

            } else {
                // Initial Record Button (Extra Large)
                Button(action: {
                    do {
                        try recorder.startRecording(
                            courseId: course.id,
                            lectureSessionId: lectureSession?.id,
                            keepScreenAwake: keepScreenAwake
                        )
                    } catch {
                        self.errorMessage = error.localizedDescription
                    }
                }) {
                    ZStack {
                        Circle()
                            .stroke(Color.academicCrimson.opacity(0.3), lineWidth: 6)
                            .frame(width: 86, height: 86)
                        Circle()
                            .fill(Color.academicCrimson)
                            .frame(width: 72, height: 72)
                        Circle()
                            .fill(Color.white)
                            .frame(width: 24, height: 24)
                    }
                }
            }
        }
        .padding(.vertical, Spacing.small)
    }

    private func saveAndFinishRecording() {
        guard let (metadata, markers) = recorder.stopRecording() else { return }

        Task {
            // Save recording metadata to SQLite
            try? await container.recordingRepository.saveRecording(metadata)

            // Save all moment markers to SQLite
            for marker in markers {
                try? await container.recordingRepository.saveMarker(marker)
            }

            // Update lecture session if linked
            if var session = lectureSession {
                session.recordingState = .recorded
                session.recordingId = metadata.id
                try? await container.lectureRepository.saveLecture(session)
            }

            await MainActor.run {
                self.onRecordingFinished()
                self.dismiss()
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
