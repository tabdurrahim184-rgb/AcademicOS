import Foundation

/// Types of contextual moment markers placed during lecture recording.
public enum AudioMarkerType: String, Codable, Sendable, CaseIterable {
    case important = "Important"
    case examHint = "Exam Hint"
    case definition = "Definition"
    case question = "Question"
    case assignment = "Assignment"
    case reviewLater = "Review Later"

    public var iconName: String {
        switch self {
        case .important: return "exclamationmark.circle.fill"
        case .examHint: return "flame.fill"
        case .definition: return "book.fill"
        case .question: return "questionmark.circle.fill"
        case .assignment: return "doc.text.fill"
        case .reviewLater: return "clock.fill"
        }
    }

    public var tagColorHex: String {
        switch self {
        case .important: return "#EF4444" // Crimson
        case .examHint: return "#F59E0B" // Amber
        case .definition: return "#06B6D4" // Cyan
        case .question: return "#8B5CF6" // Purple
        case .assignment: return "#6366F1" // Indigo
        case .reviewLater: return "#10B981" // Emerald
        }
    }
}

/// A timestamped marker pinned to an audio recording during a lecture.
public struct AudioMarker: Identifiable, Codable, Equatable, Sendable, Hashable {
    public let id: UUID
    public var recordingId: UUID
    public var courseId: UUID
    public var lectureSessionId: UUID?
    public var timestampSeconds: Double
    public var markerType: AudioMarkerType
    public var noteText: String
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        recordingId: UUID,
        courseId: UUID,
        lectureSessionId: UUID? = nil,
        timestampSeconds: Double,
        markerType: AudioMarkerType = .important,
        noteText: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.recordingId = recordingId
        self.courseId = courseId
        self.lectureSessionId = lectureSessionId
        self.timestampSeconds = timestampSeconds
        self.markerType = markerType
        self.noteText = noteText
        self.createdAt = createdAt
    }

    public var formattedTimestamp: String {
        let totalSeconds = Int(timestampSeconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}
