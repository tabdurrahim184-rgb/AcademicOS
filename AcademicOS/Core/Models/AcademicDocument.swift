import Foundation

/// Types of academic course materials.
public enum AcademicDocumentType: String, Codable, Sendable, CaseIterable {
    case syllabus = "Syllabus"
    case slides = "Slides"
    case pastExam = "Past Exam"
    case reading = "Reading"
    case paper = "Research Paper"
    case other = "Document"
}

/// Represents an uploaded or local PDF, handout, or academic reference file.
public struct AcademicDocument: Identifiable, Codable, Equatable, Sendable, Hashable {
    public let id: UUID
    public var courseId: UUID
    public var fileName: String
    public var fileExtension: String
    public var localRelativePath: String
    public var fileSizeByte: Int64
    public var docType: AcademicDocumentType
    public var uploadedAt: Date
    public var isIndexedForAI: Bool
    public var aiSummary: String

    public init(
        id: UUID = UUID(),
        courseId: UUID,
        fileName: String,
        fileExtension: String = "pdf",
        localRelativePath: String,
        fileSizeByte: Int64 = 0,
        docType: AcademicDocumentType = .slides,
        uploadedAt: Date = Date(),
        isIndexedForAI: Bool = false,
        aiSummary: String = ""
    ) {
        self.id = id
        self.courseId = courseId
        self.fileName = fileName
        self.fileExtension = fileExtension
        self.localRelativePath = localRelativePath
        self.fileSizeByte = fileSizeByte
        self.docType = docType
        self.uploadedAt = uploadedAt
        self.isIndexedForAI = isIndexedForAI
        self.aiSummary = aiSummary
    }

    public var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSizeByte)
    }
}
