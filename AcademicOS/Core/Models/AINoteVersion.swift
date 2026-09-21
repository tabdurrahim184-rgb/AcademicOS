import Foundation

/// The three structured lecture note modalities supported by AcademicOS.
public enum NoteMode: String, Codable, Sendable, CaseIterable {
    case fullLecture = "fullLecture"
    case studyNotes = "studyNotes"
    case noktaAtisi = "noktaAtisi"

    public var title: String {
        switch self {
        case .fullLecture: return "Full Lecture Notes"
        case .studyNotes: return "Study Notes"
        case .noktaAtisi: return "Nokta Atışı"
        }
    }

    public var iconName: String {
        switch self {
        case .fullLecture: return "doc.text.fill"
        case .studyNotes: return "highlighter"
        case .noktaAtisi: return "target"
        }
    }
}

/// Represents an immutable or user-edited version of an AI-generated note.
public struct AINoteVersion: Identifiable, Codable, Sendable, Equatable, Hashable {
    public let id: UUID
    public let noteId: UUID
    public let courseId: UUID
    public let versionNumber: Int
    public let mode: NoteMode
    public let provider: String
    public let modelIdentifier: String
    public let createdAt: Date
    public let sourceTranscriptRevision: String?
    public let promptVersion: String
    public var content: String
    public var isUserEdited: Bool
    public var lastUserEditDate: Date?

    public init(
        id: UUID = UUID(),
        noteId: UUID,
        courseId: UUID,
        versionNumber: Int = 1,
        mode: NoteMode = .fullLecture,
        provider: String = "Apple Foundation Models",
        modelIdentifier: String = "apple-foundation-system",
        createdAt: Date = Date(),
        sourceTranscriptRevision: String? = nil,
        promptVersion: String = "v1",
        content: String,
        isUserEdited: Bool = false,
        lastUserEditDate: Date? = nil
    ) {
        self.id = id
        self.noteId = noteId
        self.courseId = courseId
        self.versionNumber = versionNumber
        self.mode = mode
        self.provider = provider
        self.modelIdentifier = modelIdentifier
        self.createdAt = createdAt
        self.sourceTranscriptRevision = sourceTranscriptRevision
        self.promptVersion = promptVersion
        self.content = content
        self.isUserEdited = isUserEdited
        self.lastUserEditDate = lastUserEditDate
    }
}
