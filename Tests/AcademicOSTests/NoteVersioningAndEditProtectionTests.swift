import XCTest
import Foundation
@testable import AcademicOS

final class NoteVersioningAndEditProtectionTests: XCTestCase {
    var localStore: LocalStoreProtocol!
    var notesRepo: NotesRepositoryProtocol!
    var versionRepo: NoteVersionRepositoryProtocol!
    let courseId = UUID()

    override func setUp() async throws {
        try await super.setUp()
        localStore = InMemoryDatabaseManager()
        notesRepo = DatabaseNotesRepository(localStore: localStore)
        versionRepo = DatabaseNoteVersionRepository(localStore: localStore)
    }

    func testThreeNoteModesPersistedSeparately() async throws {
        let noteId = UUID()
        let note = Note(
            id: noteId,
            courseId: courseId,
            title: "Hukuk Başlangıcı Dersi",
            rawContent: "Tam Ders Notu: Pozitif hukuk ve tabii hukuk ayrımları.",
            studyNotesContent: "Çalışma Notu: Pozitif vs Tabii Hukuk karşılaştırma tablosu.",
            noktaAtisiContent: "Nokta Atışı: 1. Pozitif Hukuk yürürlükteki hukuktur. 2. Tabii Hukuk ideal hukuktur."
        )
        try await notesRepo.saveNote(note)

        // Save versions for all 3 modes
        let v1 = AINoteVersion(noteId: noteId, courseId: courseId, versionNumber: 1, mode: .fullLecture, content: note.rawContent)
        let v2 = AINoteVersion(noteId: noteId, courseId: courseId, versionNumber: 1, mode: .studyNotes, content: note.studyNotesContent)
        let v3 = AINoteVersion(noteId: noteId, courseId: courseId, versionNumber: 1, mode: .noktaAtisi, content: note.noktaAtisiContent)

        try await versionRepo.saveVersion(v1)
        try await versionRepo.saveVersion(v2)
        try await versionRepo.saveVersion(v3)

        let allVersions = try await versionRepo.getVersions(forNoteId: noteId)
        XCTAssertEqual(allVersions.count, 3)

        let studyVersion = try await versionRepo.getLatestVersion(forNoteId: noteId, mode: .studyNotes)
        XCTAssertEqual(studyVersion?.mode, .studyNotes)
        XCTAssertTrue(studyVersion?.content.contains("Çalışma Notu") ?? false)
    }

    func testManualUserEditsAreSacredAndProtected() async throws {
        let noteId = UUID()
        var note = Note(
            id: noteId,
            courseId: courseId,
            title: "Orijinal AI Notu",
            rawContent: "Orijinal yapay zekâ metni."
        )
        try await notesRepo.saveNote(note)

        // Student makes manual edits
        note.rawContent = "Öğrencinin kendi el yazısıyla eklediği kritik sınav notu."
        note.isUserEdited = true
        note.lastUserEditDate = Date()
        try await notesRepo.saveNote(note)

        let fetchedNote = try await notesRepo.getNote(id: noteId)
        XCTAssertTrue(fetchedNote?.isUserEdited ?? false, "Student edit flag must be true.")
        XCTAssertEqual(fetchedNote?.rawContent, "Öğrencinin kendi el yazısıyla eklediği kritik sınav notu.")

        // When AI regenerates notes, it must create a new version instead of overwriting student edits
        let newAIVersion = AINoteVersion(
            noteId: noteId,
            courseId: courseId,
            versionNumber: 2,
            mode: .fullLecture,
            content: "Yeniden oluşturulan AI ders notu.",
            isUserEdited: false
        )
        try await versionRepo.saveVersion(newAIVersion)

        // The student's live edited note remains untouched
        let stillProtected = try await notesRepo.getNote(id: noteId)
        XCTAssertEqual(stillProtected?.rawContent, "Öğrencinin kendi el yazısıyla eklediği kritik sınav notu.")
    }
}
