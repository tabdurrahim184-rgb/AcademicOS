import Foundation
#if canImport(SQLite3)
import SQLite3
#endif

/// Thread-safe, direct SQLite database engine managing schema migrations, WAL mode, foreign keys, and transactions.
public actor SQLiteDatabaseEngine {
    public let databaseURL: URL
    private var dbPointer: OpaquePointer?
    private let fileManager = FileManager.default

    public init(databaseName: String = "AcademicOS.sqlite") {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dbFolder = appSupport.appendingPathComponent("Database", isDirectory: true)

        if !fileManager.fileExists(atPath: dbFolder.path) {
            try? fileManager.createDirectory(at: dbFolder, withIntermediateDirectories: true)
        }

        self.databaseURL = dbFolder.appendingPathComponent(databaseName)
    }

    deinit {
        #if canImport(SQLite3)
        if let db = dbPointer {
            sqlite3_close(db)
        }
        #endif
    }

    /// Opens the SQLite database connection and runs pending migrations.
    public func openAndMigrate() throws {
        #if canImport(SQLite3)
        if dbPointer != nil { return }

        var db: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        let status = sqlite3_open_v2(databaseURL.path, &db, flags, nil)

        guard status == SQLITE_OK, let validDB = db else {
            let errorMsg = db != nil ? String(cString: sqlite3_errmsg(db)) : "Unknown"
            throw AcademicOSError.databaseError("Failed to open SQLite database at \(databaseURL.path): \(errorMsg)")
        }

        self.dbPointer = validDB

        // Enable WAL mode, Foreign Keys, and Normal synchronous mode
        try execute(sql: "PRAGMA journal_mode = WAL;")
        try execute(sql: "PRAGMA foreign_keys = ON;")
        try execute(sql: "PRAGMA synchronous = NORMAL;")

        // Execute migrations
        try applyMigrations()
        #else
        // Non-Apple environment fallback notification
        print("SQLite3 native library compiled in simulator/fallback mode.")
        #endif
    }

    /// Executes raw SQL query without results (e.g. PRAGMA, CREATE TABLE).
    public func execute(sql: String) throws {
        #if canImport(SQLite3)
        guard let db = dbPointer else {
            throw AcademicOSError.databaseError("Database is not open")
        }

        var errorMsg: UnsafeMutablePointer<CChar>?
        let status = sqlite3_exec(db, sql, nil, nil, &errorMsg)

        if status != SQLITE_OK {
            let message = errorMsg != nil ? String(cString: errorMsg!) : "Unknown error"
            sqlite3_free(errorMsg)
            throw AcademicOSError.databaseError("SQL Execution Failed: \(message)\nSQL: \(sql)")
        }
        #endif
    }

    /// Runs a transactional block. Rollbacks automatically on error.
    public func withTransaction<T>(_ block: (SQLiteDatabaseEngine) throws -> T) throws -> T {
        try execute(sql: "BEGIN IMMEDIATE TRANSACTION;")
        do {
            let result = try block(self)
            try execute(sql: "COMMIT TRANSACTION;")
            return result
        } catch {
            try? execute(sql: "ROLLBACK TRANSACTION;")
            throw error
        }
    }

    /// Queries the current schema user_version.
    public func userVersion() throws -> Int32 {
        #if canImport(SQLite3)
        guard let db = dbPointer else { return 0 }
        var statement: OpaquePointer?
        let status = sqlite3_prepare_v2(db, "PRAGMA user_version;", -1, &statement, nil)
        guard status == SQLITE_OK else { return 0 }
        defer { sqlite3_finalize(statement) }

        if sqlite3_step(statement) == SQLITE_ROW {
            return sqlite3_column_int(statement, 0)
        }
        return 0
        #else
        return 1
        #endif
    }

    /// Schema Migration Pipeline
    private func applyMigrations() throws {
        let currentVersion = try userVersion()

        if currentVersion < 1 {
            try migrateToV1()
            try execute(sql: "PRAGMA user_version = 1;")
        }

        if currentVersion < 2 {
            try migrateToV2()
            try execute(sql: "PRAGMA user_version = 2;")
        }

        if currentVersion < 3 {
            try migrateToV3()
            try execute(sql: "PRAGMA user_version = 3;")
        }
    }

    /// Migration V1: 21 Core Academic Tables with relational foreign keys and indexes
    private func migrateToV1() throws {
        let v1Statements = [
            """
            CREATE TABLE IF NOT EXISTS students (
                id TEXT PRIMARY KEY,
                first_name TEXT NOT NULL,
                last_name TEXT NOT NULL,
                university_name TEXT NOT NULL,
                faculty TEXT,
                department TEXT,
                student_number TEXT,
                current_semester TEXT,
                academic_year TEXT,
                expected_graduation_date TEXT,
                gpa_scale REAL DEFAULT 4.00,
                target_gpa REAL DEFAULT 3.80,
                email TEXT,
                biometric_lock INTEGER DEFAULT 1,
                preferred_ai TEXT,
                allow_cloud_sync INTEGER DEFAULT 1,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            );
            """,
            """
            CREATE TABLE IF NOT EXISTS semesters (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                academic_year TEXT NOT NULL,
                term TEXT NOT NULL,
                start_date TEXT NOT NULL,
                end_date TEXT NOT NULL,
                is_active INTEGER DEFAULT 1,
                target_gpa REAL DEFAULT 3.80,
                created_at TEXT NOT NULL
            );
            """,
            """
            CREATE TABLE IF NOT EXISTS professors (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                title TEXT,
                email TEXT,
                office_location TEXT,
                office_hours TEXT,
                notes TEXT
            );
            """,
            """
            CREATE TABLE IF NOT EXISTS courses (
                id TEXT PRIMARY KEY,
                code TEXT NOT NULL,
                name TEXT NOT NULL,
                department TEXT,
                credits INTEGER DEFAULT 3,
                ects INTEGER DEFAULT 5,
                semester_id TEXT NOT NULL,
                professor_id TEXT,
                color_hex TEXT DEFAULT '#4F46E5',
                icon_name TEXT DEFAULT 'books.vertical.fill',
                ai_memory_summary TEXT,
                lecture_room TEXT,
                weekly_class_day TEXT,
                start_time TEXT,
                end_time TEXT,
                notes TEXT,
                status TEXT DEFAULT 'Active',
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                FOREIGN KEY(semester_id) REFERENCES semesters(id) ON DELETE CASCADE
            );
            """,
            """
            CREATE TABLE IF NOT EXISTS lecture_sessions (
                id TEXT PRIMARY KEY,
                course_id TEXT NOT NULL,
                topic TEXT NOT NULL,
                session_date TEXT NOT NULL,
                start_time TEXT,
                end_time TEXT,
                duration_minutes INTEGER DEFAULT 90,
                classroom TEXT,
                professor_name TEXT,
                attendance_status TEXT DEFAULT 'Scheduled',
                manual_notes TEXT,
                recording_state TEXT DEFAULT 'Not Recorded',
                recording_id TEXT,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                FOREIGN KEY(course_id) REFERENCES courses(id) ON DELETE CASCADE
            );
            """,
            """
            CREATE TABLE IF NOT EXISTS notes (
                id TEXT PRIMARY KEY,
                course_id TEXT NOT NULL,
                lecture_session_id TEXT,
                title TEXT NOT NULL,
                raw_content TEXT,
                ai_structured_summary TEXT,
                key_takeaways TEXT,
                tags TEXT,
                source_type TEXT DEFAULT 'Manual Note',
                is_pinned INTEGER DEFAULT 0,
                is_ai_processed INTEGER DEFAULT 0,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                FOREIGN KEY(course_id) REFERENCES courses(id) ON DELETE CASCADE
            );
            """,
            """
            CREATE TABLE IF NOT EXISTS audio_recordings (
                id TEXT PRIMARY KEY,
                course_id TEXT NOT NULL,
                lecture_session_id TEXT,
                local_relative_path TEXT NOT NULL,
                duration_seconds REAL DEFAULT 0.0,
                file_size_bytes INTEGER DEFAULT 0,
                sample_rate REAL DEFAULT 44100.0,
                audio_format TEXT DEFAULT 'm4a',
                transcription_status TEXT DEFAULT 'notStarted',
                recorded_at TEXT NOT NULL,
                FOREIGN KEY(course_id) REFERENCES courses(id) ON DELETE CASCADE
            );
            """,
            """
            CREATE TABLE IF NOT EXISTS transcripts (
                id TEXT PRIMARY KEY,
                recording_id TEXT NOT NULL,
                course_id TEXT NOT NULL,
                lecture_session_id TEXT,
                full_text TEXT NOT NULL,
                language TEXT DEFAULT 'tr-TR',
                is_processed_by_ai INTEGER DEFAULT 0,
                generated_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                FOREIGN KEY(recording_id) REFERENCES audio_recordings(id) ON DELETE CASCADE
            );
            """,
            """
            CREATE TABLE IF NOT EXISTS transcript_segments (
                id TEXT PRIMARY KEY,
                transcript_id TEXT NOT NULL,
                recording_id TEXT NOT NULL,
                course_id TEXT NOT NULL,
                lecture_session_id TEXT,
                start_seconds REAL NOT NULL,
                end_seconds REAL NOT NULL,
                speaker_tag TEXT,
                text TEXT NOT NULL,
                confidence REAL DEFAULT 0.95,
                is_marked_important INTEGER DEFAULT 0,
                importance_tag TEXT,
                FOREIGN KEY(transcript_id) REFERENCES transcripts(id) ON DELETE CASCADE
            );
            """,
            """
            CREATE TABLE IF NOT EXISTS audio_markers (
                id TEXT PRIMARY KEY,
                recording_id TEXT NOT NULL,
                course_id TEXT NOT NULL,
                lecture_session_id TEXT,
                timestamp_seconds REAL NOT NULL,
                marker_type TEXT NOT NULL,
                note_text TEXT,
                created_at TEXT NOT NULL,
                FOREIGN KEY(recording_id) REFERENCES audio_recordings(id) ON DELETE CASCADE
            );
            """,
            """
            CREATE TABLE IF NOT EXISTS exams (
                id TEXT PRIMARY KEY,
                course_id TEXT NOT NULL,
                title TEXT NOT NULL,
                exam_type TEXT NOT NULL,
                exam_date TEXT NOT NULL,
                room TEXT,
                weight_percentage INTEGER DEFAULT 40,
                target_grade REAL,
                achieved_grade REAL,
                topics_covered TEXT,
                notes TEXT,
                FOREIGN KEY(course_id) REFERENCES courses(id) ON DELETE CASCADE
            );
            """,
            """
            CREATE TABLE IF NOT EXISTS assignments (
                id TEXT PRIMARY KEY,
                course_id TEXT NOT NULL,
                title TEXT NOT NULL,
                prompt TEXT,
                due_date TEXT NOT NULL,
                status TEXT DEFAULT 'Pending',
                max_score REAL DEFAULT 100.0,
                achieved_score REAL,
                priority TEXT DEFAULT 'High',
                submission_url TEXT,
                attachments TEXT,
                created_at TEXT NOT NULL,
                FOREIGN KEY(course_id) REFERENCES courses(id) ON DELETE CASCADE
            );
            """,
            """
            CREATE TABLE IF NOT EXISTS academic_tasks (
                id TEXT PRIMARY KEY,
                course_id TEXT,
                title TEXT NOT NULL,
                scheduled_time TEXT,
                due_date TEXT,
                estimated_minutes INTEGER DEFAULT 30,
                is_completed INTEGER DEFAULT 0,
                priority TEXT DEFAULT 'Medium',
                category TEXT DEFAULT 'Mission',
                completed_at TEXT,
                created_at TEXT NOT NULL
            );
            """,
            """
            CREATE TABLE IF NOT EXISTS flashcards (
                id TEXT PRIMARY KEY,
                course_id TEXT NOT NULL,
                deck_title TEXT NOT NULL,
                question TEXT NOT NULL,
                answer TEXT NOT NULL,
                difficulty INTEGER DEFAULT 3,
                review_count INTEGER DEFAULT 0,
                next_review_date TEXT NOT NULL,
                ease_factor REAL DEFAULT 2.5,
                interval_days INTEGER DEFAULT 1,
                created_at TEXT NOT NULL,
                FOREIGN KEY(course_id) REFERENCES courses(id) ON DELETE CASCADE
            );
            """,
            """
            CREATE TABLE IF NOT EXISTS study_sessions (
                id TEXT PRIMARY KEY,
                course_id TEXT NOT NULL,
                title TEXT NOT NULL,
                scheduled_date TEXT NOT NULL,
                target_duration_minutes INTEGER DEFAULT 45,
                actual_duration_minutes INTEGER DEFAULT 0,
                agent_assisted INTEGER DEFAULT 0,
                agent_name TEXT,
                focus_rating INTEGER DEFAULT 4,
                notes TEXT,
                is_completed INTEGER DEFAULT 0,
                FOREIGN KEY(course_id) REFERENCES courses(id) ON DELETE CASCADE
            );
            """,
            """
            CREATE TABLE IF NOT EXISTS documents (
                id TEXT PRIMARY KEY,
                course_id TEXT NOT NULL,
                file_name TEXT NOT NULL,
                file_extension TEXT NOT NULL,
                local_relative_path TEXT NOT NULL,
                file_size_bytes INTEGER DEFAULT 0,
                doc_type TEXT DEFAULT 'Slides',
                uploaded_at TEXT NOT NULL,
                is_indexed_for_ai INTEGER DEFAULT 0,
                ai_summary TEXT,
                FOREIGN KEY(course_id) REFERENCES courses(id) ON DELETE CASCADE
            );
            """,
            """
            CREATE TABLE IF NOT EXISTS gpa_records (
                id TEXT PRIMARY KEY,
                semester_id TEXT NOT NULL,
                semester_name TEXT NOT NULL,
                current_gpa REAL NOT NULL,
                cumulative_gpa REAL NOT NULL,
                total_credits_attempted INTEGER DEFAULT 0,
                total_credits_earned INTEGER DEFAULT 0,
                target_graduation_gpa REAL DEFAULT 3.80,
                honor_roll INTEGER DEFAULT 0,
                recorded_at TEXT NOT NULL
            );
            """,
            """
            CREATE TABLE IF NOT EXISTS graduation_requirements (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                is_satisfied INTEGER DEFAULT 0,
                category TEXT DEFAULT 'Core',
                details TEXT
            );
            """,
            """
            CREATE TABLE IF NOT EXISTS graduation_progress (
                id TEXT PRIMARY KEY,
                codename TEXT DEFAULT 'OPERATION GRADUATION',
                target_graduation_date TEXT NOT NULL,
                days_remaining INTEGER DEFAULT 0,
                total_credits_required INTEGER DEFAULT 240,
                completed_credits INTEGER DEFAULT 0,
                progress_percentage REAL DEFAULT 0.0
            );
            """,
            """
            CREATE TABLE IF NOT EXISTS ai_memory (
                id TEXT PRIMARY KEY,
                course_id TEXT NOT NULL,
                topic TEXT NOT NULL,
                key_fact TEXT NOT NULL,
                importance_score REAL DEFAULT 0.8,
                source_reference TEXT,
                tags TEXT,
                created_at TEXT NOT NULL,
                FOREIGN KEY(course_id) REFERENCES courses(id) ON DELETE CASCADE
            );
            """,
            """
            CREATE TABLE IF NOT EXISTS queued_jobs (
                id TEXT PRIMARY KEY,
                job_type TEXT NOT NULL,
                payload_json TEXT NOT NULL,
                status TEXT DEFAULT 'Pending',
                priority INTEGER DEFAULT 1,
                retry_count INTEGER DEFAULT 0,
                max_retries INTEGER DEFAULT 5,
                created_at TEXT NOT NULL,
                last_attempt_at TEXT,
                error_message TEXT
            );
            """
        ]

        for sql in v1Statements {
            try execute(sql: sql)
        }

        // Relational Indexes for course isolation & instant query lookups
        let indexes = [
            "CREATE INDEX IF NOT EXISTS idx_courses_semester ON courses(semester_id);",
            "CREATE INDEX IF NOT EXISTS idx_lectures_course ON lecture_sessions(course_id);",
            "CREATE INDEX IF NOT EXISTS idx_notes_course ON notes(course_id);",
            "CREATE INDEX IF NOT EXISTS idx_recordings_course ON audio_recordings(course_id);",
            "CREATE INDEX IF NOT EXISTS idx_markers_recording ON audio_markers(recording_id);",
            "CREATE INDEX IF NOT EXISTS idx_markers_course ON audio_markers(course_id);",
            "CREATE INDEX IF NOT EXISTS idx_transcripts_recording ON transcripts(recording_id);",
            "CREATE INDEX IF NOT EXISTS idx_segments_transcript ON transcript_segments(transcript_id);",
            "CREATE INDEX IF NOT EXISTS idx_flashcards_course ON flashcards(course_id);",
            "CREATE INDEX IF NOT EXISTS idx_exams_course ON exams(course_id);",
            "CREATE INDEX IF NOT EXISTS idx_assignments_course ON assignments(course_id);",
            "CREATE INDEX IF NOT EXISTS idx_ai_memory_course ON ai_memory(course_id);"
        ]

        for indexSql in indexes {
            try execute(sql: indexSql)
        }
    }

    /// Migration V2: Phase 2B Tables for Note Versions, Professor Emphasis, Academic Mastery, and Course AI Chat
    private func migrateToV2() throws {
        let v2Statements = [
            """
            CREATE TABLE IF NOT EXISTS note_versions (
                id TEXT PRIMARY KEY,
                note_id TEXT NOT NULL,
                course_id TEXT NOT NULL,
                version_number INTEGER DEFAULT 1,
                mode TEXT NOT NULL,
                provider TEXT,
                model_identifier TEXT,
                source_transcript_revision TEXT,
                prompt_version TEXT,
                content TEXT NOT NULL,
                is_user_edited INTEGER DEFAULT 0,
                last_user_edit_date TEXT,
                created_at TEXT NOT NULL,
                FOREIGN KEY(note_id) REFERENCES notes(id) ON DELETE CASCADE
            );
            """,
            """
            CREATE TABLE IF NOT EXISTS professor_emphasis (
                id TEXT PRIMARY KEY,
                course_id TEXT NOT NULL,
                lecture_session_id TEXT,
                recording_id TEXT NOT NULL,
                transcript_segment_id TEXT,
                start_time REAL NOT NULL,
                end_time REAL NOT NULL,
                exact_source_snippet TEXT NOT NULL,
                classification TEXT NOT NULL,
                confidence REAL DEFAULT 0.95,
                detection_method TEXT NOT NULL,
                created_at TEXT NOT NULL,
                FOREIGN KEY(course_id) REFERENCES courses(id) ON DELETE CASCADE
            );
            """,
            """
            CREATE TABLE IF NOT EXISTS academic_mastery (
                id TEXT PRIMARY KEY,
                course_id TEXT NOT NULL,
                topic TEXT NOT NULL,
                attempts INTEGER DEFAULT 0,
                correct_answers INTEGER DEFAULT 0,
                incorrect_answers INTEGER DEFAULT 0,
                confidence REAL DEFAULT 0.5,
                last_reviewed TEXT NOT NULL,
                mastery_score REAL DEFAULT 0.0,
                FOREIGN KEY(course_id) REFERENCES courses(id) ON DELETE CASCADE
            );
            """,
            """
            CREATE TABLE IF NOT EXISTS lecture_pipeline_records (
                id TEXT PRIMARY KEY,
                recording_id TEXT NOT NULL,
                course_id TEXT NOT NULL,
                lecture_session_id TEXT,
                current_stage TEXT NOT NULL,
                progress_percentage REAL DEFAULT 0.0,
                last_processed_chunk INTEGER DEFAULT 0,
                total_chunks INTEGER DEFAULT 0,
                last_error TEXT,
                updated_at TEXT NOT NULL,
                FOREIGN KEY(recording_id) REFERENCES audio_recordings(id) ON DELETE CASCADE
            );
            """,
            """
            CREATE TABLE IF NOT EXISTS course_chat_messages (
                id TEXT PRIMARY KEY,
                course_id TEXT NOT NULL,
                sender TEXT NOT NULL,
                message_text TEXT NOT NULL,
                provider_badge TEXT,
                source_citations TEXT,
                created_at TEXT NOT NULL,
                FOREIGN KEY(course_id) REFERENCES courses(id) ON DELETE CASCADE
            );
            """
        ]

        for sql in v2Statements {
            try execute(sql: sql)
        }

        // Add indexes for Phase 2B tables
        let v2Indexes = [
            "CREATE INDEX IF NOT EXISTS idx_note_versions_note ON note_versions(note_id);",
            "CREATE INDEX IF NOT EXISTS idx_note_versions_course ON note_versions(course_id);",
            "CREATE INDEX IF NOT EXISTS idx_professor_emphasis_course ON professor_emphasis(course_id);",
            "CREATE INDEX IF NOT EXISTS idx_professor_emphasis_recording ON professor_emphasis(recording_id);",
            "CREATE INDEX IF NOT EXISTS idx_academic_mastery_course ON academic_mastery(course_id);",
            "CREATE INDEX IF NOT EXISTS idx_lecture_pipeline_recording ON lecture_pipeline_records(recording_id);",
            "CREATE INDEX IF NOT EXISTS idx_lecture_pipeline_course ON lecture_pipeline_records(course_id);",
            "CREATE INDEX IF NOT EXISTS idx_course_chat_course ON course_chat_messages(course_id);"
        ]

        for indexSql in v2Indexes {
            try execute(sql: indexSql)
        }

        // Schema evolution for existing tables (ALTER TABLE column additions if needed)
        let alterStatements = [
            "ALTER TABLE notes ADD COLUMN study_notes_content TEXT DEFAULT '';",
            "ALTER TABLE notes ADD COLUMN nokta_atisi_content TEXT DEFAULT '';",
            "ALTER TABLE notes ADD COLUMN is_user_edited INTEGER DEFAULT 0;",
            "ALTER TABLE notes ADD COLUMN last_user_edit_date TEXT;",
            "ALTER TABLE notes ADD COLUMN active_version INTEGER DEFAULT 1;",
            "ALTER TABLE ai_memory ADD COLUMN lecture_session_id TEXT;",
            "ALTER TABLE ai_memory ADD COLUMN type TEXT DEFAULT 'concept';",
            "ALTER TABLE ai_memory ADD COLUMN is_user_verified INTEGER DEFAULT 0;",
            "ALTER TABLE ai_memory ADD COLUMN is_pinned INTEGER DEFAULT 0;",
            "ALTER TABLE ai_memory ADD COLUMN updated_at TEXT;"
        ]

        for alterSql in alterStatements {
            try? execute(sql: alterSql)
        }
    }

    /// Migration V3: University Integration & Automation Tables (Phase 2C)
    private func migrateToV3() throws {
        let v3Statements = [
            """
            CREATE TABLE IF NOT EXISTS university_portals (
                id TEXT PRIMARY KEY,
                portal_type TEXT NOT NULL,
                name TEXT NOT NULL,
                base_url TEXT NOT NULL,
                is_active INTEGER DEFAULT 1,
                last_sync_at TEXT,
                sync_interval_minutes INTEGER DEFAULT 60,
                auth_method TEXT DEFAULT 'SessionCookie'
            );
            """,
            """
            CREATE TABLE IF NOT EXISTS university_inbox_items (
                id TEXT PRIMARY KEY,
                portal_id TEXT NOT NULL,
                course_id TEXT,
                course_code TEXT,
                title TEXT NOT NULL,
                content TEXT NOT NULL,
                sender TEXT NOT NULL,
                category TEXT NOT NULL,
                urgency TEXT DEFAULT 'Medium',
                is_read INTEGER DEFAULT 0,
                raw_payload TEXT,
                received_at TEXT NOT NULL,
                FOREIGN KEY(portal_id) REFERENCES university_portals(id) ON DELETE CASCADE
            );
            """,
            """
            CREATE TABLE IF NOT EXISTS university_grades (
                id TEXT PRIMARY KEY,
                course_id TEXT NOT NULL,
                course_code TEXT NOT NULL,
                evaluation_name TEXT NOT NULL,
                score REAL NOT NULL,
                max_score REAL DEFAULT 100.0,
                weight_percentage REAL DEFAULT 40.0,
                letter_grade TEXT,
                is_final INTEGER DEFAULT 0,
                recorded_at TEXT NOT NULL,
                FOREIGN KEY(course_id) REFERENCES courses(id) ON DELETE CASCADE
            );
            """,
            """
            CREATE TABLE IF NOT EXISTS university_announcements (
                id TEXT PRIMARY KEY,
                portal_id TEXT NOT NULL,
                course_id TEXT,
                title TEXT NOT NULL,
                body TEXT NOT NULL,
                importance TEXT DEFAULT 'Normal',
                is_urgent INTEGER DEFAULT 0,
                action_deadline TEXT,
                processed_by_ai INTEGER DEFAULT 0,
                announced_at TEXT NOT NULL,
                FOREIGN KEY(portal_id) REFERENCES university_portals(id) ON DELETE CASCADE
            );
            """,
            """
            CREATE TABLE IF NOT EXISTS university_sync_history (
                id TEXT PRIMARY KEY,
                portal_id TEXT NOT NULL,
                status TEXT NOT NULL,
                items_imported INTEGER DEFAULT 0,
                items_updated INTEGER DEFAULT 0,
                error_message TEXT,
                timestamp TEXT NOT NULL,
                FOREIGN KEY(portal_id) REFERENCES university_portals(id) ON DELETE CASCADE
            );
            """
        ]

        for sql in v3Statements {
            try execute(sql: sql)
        }

        let v3Indexes = [
            "CREATE INDEX IF NOT EXISTS idx_univ_inbox_portal ON university_inbox_items(portal_id);",
            "CREATE INDEX IF NOT EXISTS idx_univ_inbox_course ON university_inbox_items(course_id);",
            "CREATE INDEX IF NOT EXISTS idx_univ_grades_course ON university_grades(course_id);",
            "CREATE INDEX IF NOT EXISTS idx_univ_announcements_portal ON university_announcements(portal_id);",
            "CREATE INDEX IF NOT EXISTS idx_univ_announcements_course ON university_announcements(course_id);",
            "CREATE INDEX IF NOT EXISTS idx_univ_sync_portal ON university_sync_history(portal_id);"
        ]

        for indexSql in v3Indexes {
            try execute(sql: indexSql)
        }
    }

    /// Vacuum and check integrity
    public func checkIntegrity() throws -> String {
        #if canImport(SQLite3)
        guard let db = dbPointer else { return "Database closed" }
        var statement: OpaquePointer?
        let status = sqlite3_prepare_v2(db, "PRAGMA integrity_check;", -1, &statement, nil)
        guard status == SQLITE_OK else { return "Failed to prepare integrity check" }
        defer { sqlite3_finalize(statement) }

        if sqlite3_step(statement) == SQLITE_ROW {
            return String(cString: sqlite3_column_text(statement, 0))
        }
        return "OK"
        #else
        return "OK (Simulated Environment)"
        #endif
    }
}
