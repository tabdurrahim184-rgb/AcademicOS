import Foundation

/// Represents a locally indexed text chunk extracted from a course document or syllabus.
public struct DocumentChunk: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let courseId: UUID
    public let documentTitle: String
    public let pageNumber: Int?
    public let chunkIndex: Int
    public let text: String

    public init(
        id: UUID = UUID(),
        courseId: UUID,
        documentTitle: String,
        pageNumber: Int? = nil,
        chunkIndex: Int = 0,
        text: String
    ) {
        self.id = id
        self.courseId = courseId
        self.documentTitle = documentTitle
        self.pageNumber = pageNumber
        self.chunkIndex = chunkIndex
        self.text = text
    }
}

/// Service that manages local document text chunking and isolated in-memory course excerpt search.
public final class DocumentContextService: @unchecked Sendable {
    public static let shared = DocumentContextService()

    private var indexedChunks: [UUID: [DocumentChunk]] = [:] // Keyed by courseId
    private let lock = NSLock()

    private init() {}

    /// Ingests a local document's text, chunks it into manageable windows, and associates it with courseId.
    public func ingestDocument(
        courseId: UUID,
        documentTitle: String,
        rawText: String,
        chunkSize: Int = 800
    ) {
        lock.lock()
        defer { lock.unlock() }

        var chunks: [DocumentChunk] = []
        var currentIndex = rawText.startIndex
        var chunkIndex = 0

        while currentIndex < rawText.endIndex {
            let nextIndex = rawText.index(currentIndex, offsetBy: chunkSize, limitedBy: rawText.endIndex) ?? rawText.endIndex
            let chunkString = String(rawText[currentIndex..<nextIndex])

            let chunk = DocumentChunk(
                courseId: courseId,
                documentTitle: documentTitle,
                pageNumber: (chunkIndex / 2) + 1,
                chunkIndex: chunkIndex,
                text: chunkString
            )
            chunks.append(chunk)

            chunkIndex += 1
            currentIndex = nextIndex
        }

        if indexedChunks[courseId] == nil {
            indexedChunks[courseId] = []
        }
        indexedChunks[courseId]?.append(contentsOf: chunks)
    }

    /// Searches document excerpts strictly for the specified course.
    public func searchExcerpts(forCourseId courseId: UUID, query: String, maxCount: Int = 3) -> [DocumentChunk] {
        lock.lock()
        defer { lock.unlock() }

        guard let courseChunks = indexedChunks[courseId] else { return [] }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return Array(courseChunks.prefix(maxCount)) }

        let queryTokens = trimmed.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }

        return courseChunks
            .filter { chunk in
                let chunkLower = chunk.text.lowercased()
                return queryTokens.contains(where: { chunkLower.contains($0) })
            }
            .prefix(maxCount)
            .map { $0 }
    }
}
