import Foundation

/// Real database-backed local offline search engine across courses, notes, transcripts, exams, and assignments.
public final class DatabaseSearchRepository: SearchRepositoryProtocol, @unchecked Sendable {
    private let localStore: LocalStoreProtocol

    public init(localStore: LocalStoreProtocol) {
        self.localStore = localStore
    }

    public func searchAll(query: String) async throws -> UnifiedSearchResults {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return UnifiedSearchResults(query: query, courses: [], notes: [], transcripts: [], exams: [], assignments: [])
        }

        async let coursesTask: [Course] = localStore.fetchAll()
        async let notesTask: [Note] = localStore.fetchAll()
        async let transcriptsTask: [Transcript] = localStore.fetchAll()
        async let examsTask: [Exam] = localStore.fetchAll()
        async let assignmentsTask: [Assignment] = localStore.fetchAll()

        let (allCourses, allNotes, allTranscripts, allExams, allAssignments) = try await (
            coursesTask, notesTask, transcriptsTask, examsTask, assignmentsTask
        )

        let matchingCourses = allCourses.filter {
            $0.name.localizedCaseInsensitiveContains(trimmed) ||
            $0.code.localizedCaseInsensitiveContains(trimmed) ||
            $0.department.localizedCaseInsensitiveContains(trimmed) ||
            $0.notes.localizedCaseInsensitiveContains(trimmed)
        }

        let matchingNotes = allNotes.filter {
            $0.title.localizedCaseInsensitiveContains(trimmed) ||
            $0.rawContent.localizedCaseInsensitiveContains(trimmed) ||
            $0.aiStructuredSummary.localizedCaseInsensitiveContains(trimmed) ||
            $0.tags.contains(where: { $0.localizedCaseInsensitiveContains(trimmed) })
        }

        let matchingTranscripts = allTranscripts.filter {
            $0.fullText.localizedCaseInsensitiveContains(trimmed) ||
            $0.segments.contains(where: { $0.text.localizedCaseInsensitiveContains(trimmed) })
        }

        let matchingExams = allExams.filter {
            $0.title.localizedCaseInsensitiveContains(trimmed) ||
            $0.topicsCovered.contains(where: { $0.localizedCaseInsensitiveContains(trimmed) }) ||
            $0.notes.localizedCaseInsensitiveContains(trimmed)
        }

        let matchingAssignments = allAssignments.filter {
            $0.title.localizedCaseInsensitiveContains(trimmed) ||
            $0.prompt.localizedCaseInsensitiveContains(trimmed)
        }

        return UnifiedSearchResults(
            query: trimmed,
            courses: matchingCourses,
            notes: matchingNotes,
            transcripts: matchingTranscripts,
            exams: matchingExams,
            assignments: matchingAssignments
        )
    }
}
