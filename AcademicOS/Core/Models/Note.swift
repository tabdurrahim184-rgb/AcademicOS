import Foundation

/// Classification of how the lecture note was produced.
public enum NoteSourceType: String, Codable, Sendable, CaseIterable {
    case manualNote = "Manual Note"
    case transcriptNote = "Transcript Note"
    case aiStructuredNote = "AI Structured Note"
}

/// Represents a rich academic lecture or study note.
public struct Note: Identifiable, Codable, Equatable, Sendable, Hashable {
    public let id: UUID
    public var courseId: UUID
    public var lectureSessionId: UUID?
    public var title: String
    public var rawContent: String
    public var aiStructuredSummary: String
    public var studyNotesContent: String
    public var noktaAtisiContent: String
    public var keyTakeaways: [String]
    public var tags: [String]
    public var sourceType: NoteSourceType
    public var isPinned: Bool
    public var isAiProcessed: Bool
    public var isUserEdited: Bool
    public var lastUserEditDate: Date?
    public var activeVersion: Int
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        courseId: UUID,
        lectureSessionId: UUID? = nil,
        title: String,
        rawContent: String,
        aiStructuredSummary: String = "",
        studyNotesContent: String = "",
        noktaAtisiContent: String = "",
        keyTakeaways: [String] = [],
        tags: [String] = [],
        sourceType: NoteSourceType = .manualNote,
        isPinned: Bool = false,
        isAiProcessed: Bool = false,
        isUserEdited: Bool = false,
        lastUserEditDate: Date? = nil,
        activeVersion: Int = 1,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.courseId = courseId
        self.lectureSessionId = lectureSessionId
        self.title = title
        self.rawContent = rawContent
        self.aiStructuredSummary = aiStructuredSummary
        self.studyNotesContent = studyNotesContent
        self.noktaAtisiContent = noktaAtisiContent
        self.keyTakeaways = keyTakeaways
        self.tags = tags
        self.sourceType = sourceType
        self.isPinned = isPinned
        self.isAiProcessed = isAiProcessed
        self.isUserEdited = isUserEdited
        self.lastUserEditDate = lastUserEditDate
        self.activeVersion = activeVersion
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var body: String {
        get { rawContent }
        set { rawContent = newValue }
    }
}
