import Foundation

/// Health diagnostics report assessing data safety and filesystem/database synchronicity.
public struct DataHealthReport: Sendable {
    public let missingAudioFiles: [AudioRecordingMetadata]
    public let orphanAudioFiles: [URL]
    public let incompleteTranscriptions: [AudioRecordingMetadata]
    public let totalAudioBytes: Int64
    public let totalDatabaseBytes: Int64
    public let totalDocumentBytes: Int64

    public var isHealthy: Bool {
        missingAudioFiles.isEmpty && orphanAudioFiles.isEmpty && incompleteTranscriptions.isEmpty
    }

    public var totalStorageFormatted: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalAudioBytes + totalDatabaseBytes + totalDocumentBytes)
    }

    public var audioStorageFormatted: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalAudioBytes)
    }

    public var databaseStorageFormatted: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalDatabaseBytes)
    }
}

/// Protocol defining data safety diagnostics and sandbox storage inspection.
public protocol DataHealthServiceProtocol: Sendable {
    func auditHealth() async throws -> DataHealthReport
    func runDiagnostics() async throws -> DataHealthReport
}

/// Audits data safety, checks for orphaned or missing files, and calculates local storage breakdown.
public final class DataHealthService: DataHealthServiceProtocol, @unchecked Sendable {
    private let localStore: LocalStoreProtocol
    private let fileManager: FileManager

    public init(localStore: LocalStoreProtocol, fileManager: FileManager = .default) {
        self.localStore = localStore
        self.fileManager = fileManager
    }

    public func auditHealth() async throws -> DataHealthReport {
        let docsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let appSupportDir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? docsDir

        // 1. Fetch metadata
        let recordings: [AudioRecordingMetadata] = try await localStore.fetchAll()
        let documents: [AcademicDocument] = try await localStore.fetchAll()

        var missingFiles: [AudioRecordingMetadata] = []
        var incompleteTranscripts: [AudioRecordingMetadata] = []
        var totalAudioSize: Int64 = 0

        for rec in recordings {
            let fullURL = docsDir.appendingPathComponent(rec.localRelativePath)
            if !fileManager.fileExists(atPath: fullURL.path) {
                missingFiles.append(rec)
            } else {
                let attrs = try? fileManager.attributesOfItem(atPath: fullURL.path)
                totalAudioSize += (attrs?[.size] as? Int64) ?? 0
            }

            if rec.transcriptionStatus == .transcribingLocal || rec.transcriptionStatus == .transcribingCloud || rec.transcriptionStatus == .failed {
                incompleteTranscripts.append(rec)
            }
        }

        // 2. Scan Recordings directory for orphan files
        let recordingsDir = docsDir.appendingPathComponent("Recordings", isDirectory: true)
        var orphanFiles: [URL] = []
        if let diskFiles = try? fileManager.contentsOfDirectory(at: recordingsDir, includingPropertiesForKeys: nil) {
            let knownPaths = Set(recordings.map { docsDir.appendingPathComponent($0.localRelativePath).path })
            for file in diskFiles {
                if !knownPaths.contains(file.path) && file.pathExtension == "m4a" {
                    orphanFiles.append(file)
                }
            }
        }

        // 3. Measure Database file size
        let dbFile = appSupportDir.appendingPathComponent("Database/AcademicOS.sqlite")
        let dbAttrs = try? fileManager.attributesOfItem(atPath: dbFile.path)
        let dbSize = (dbAttrs?[.size] as? Int64) ?? 0

        // 4. Measure Documents file size
        var totalDocSize: Int64 = 0
        for doc in documents {
            let docURL = docsDir.appendingPathComponent(doc.localRelativePath)
            let attrs = try? fileManager.attributesOfItem(atPath: docURL.path)
            totalDocSize += (attrs?[.size] as? Int64) ?? 0
        }

        return DataHealthReport(
            missingAudioFiles: missingFiles,
            orphanAudioFiles: orphanFiles,
            incompleteTranscriptions: incompleteTranscripts,
            totalAudioBytes: totalAudioSize,
            totalDatabaseBytes: dbSize,
            totalDocumentBytes: totalDocSize
        )
    }
}
