import Foundation

/// Manages local disk storage for audio recordings, academic PDFs, and generated notes.
public final class DocumentFileManager: Sendable {
    public static let shared = DocumentFileManager()

    private let fileManager = FileManager.default

    public var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    public var audioRecordingsDirectory: URL {
        let dir = documentsDirectory.appendingPathComponent("Recordings", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    public var academicPdfsDirectory: URL {
        let dir = documentsDirectory.appendingPathComponent("AcademicDocs", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    public init() {}

    public func saveFile(data: Data, relativePath: String) throws -> URL {
        let destination = documentsDirectory.appendingPathComponent(relativePath)
        let parentDir = destination.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: parentDir.path) {
            try fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true)
        }
        try data.write(to: destination, options: .atomic)
        return destination
    }

    public func readFile(relativePath: String) throws -> Data {
        let url = documentsDirectory.appendingPathComponent(relativePath)
        guard fileManager.fileExists(atPath: url.path) else {
            throw AcademicOSError.fileSystemError("File not found at: \(relativePath)")
        }
        return try Data(contentsOf: url)
    }

    public func deleteFile(relativePath: String) throws {
        let url = documentsDirectory.appendingPathComponent(relativePath)
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }
}
