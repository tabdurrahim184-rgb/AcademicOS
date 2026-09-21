import Foundation

/// Overall result of a dual-portal sync operation for Near East University.
public struct NEUSyncAllResult: Sendable, Equatable {
    public let isDebimSuccess: Bool
    public let isPortalSuccess: Bool
    public let debimCourseCount: Int
    public let portalCourseCount: Int
    public let reconciledCourseCount: Int
    public let conflictCount: Int
    public let debimItemsChanged: Int
    public let portalItemsChanged: Int
    public let transcriptSummary: NEUTranscriptSummary?
    public let debimError: String?
    public let portalError: String?
    public let syncTimestamp: Date

    public init(
        isDebimSuccess: Bool,
        isPortalSuccess: Bool,
        debimCourseCount: Int,
        portalCourseCount: Int,
        reconciledCourseCount: Int,
        conflictCount: Int,
        debimItemsChanged: Int = 0,
        portalItemsChanged: Int = 0,
        transcriptSummary: NEUTranscriptSummary? = nil,
        debimError: String? = nil,
        portalError: String? = nil,
        syncTimestamp: Date = Date()
    ) {
        self.isDebimSuccess = isDebimSuccess
        self.isPortalSuccess = isPortalSuccess
        self.debimCourseCount = debimCourseCount
        self.portalCourseCount = portalCourseCount
        self.reconciledCourseCount = reconciledCourseCount
        self.conflictCount = conflictCount
        self.debimItemsChanged = debimItemsChanged
        self.portalItemsChanged = portalItemsChanged
        self.transcriptSummary = transcriptSummary
        self.debimError = debimError
        self.portalError = portalError
        self.syncTimestamp = syncTimestamp
    }
}

/// Master coordinator for Near East University (Yakın Doğu Üniversitesi / NEU).
/// Orchestrates:
/// 1. DEBİM Moodle LMS (`debim.neu.edu.tr`) with manual Google SAML isolation
/// 2. Student Portal OBS (`register.neu.edu.tr`) with exact-host security
/// 3. Dual-portal course reconciliation and discrepancy detection
/// 4. Transcript parsing and unverified GPA preservation
/// 5. Live delta change detection and durable change history
/// 6. Strict separation of actual production data from synthetic demo fixtures
public actor NEUUniversityConnector {
    public static let shared = NEUUniversityConnector()

    public let debimConnector: NEUMoodleConnector
    public let studentPortalConnector: NEUStudentPortalConnector
    public let reconciliationService: NEUCourseReconciliationService
    public let transcriptParser: NEUTranscriptParser
    public let changeHistoryService: NEUChangeHistoryService

    // Environment & Mode
    public var isProductionMode: Bool = true

    // State Tracking
    public private(set) var debimState: UniversityConnectionState = .disconnected
    public private(set) var studentPortalState: UniversityConnectionState = .disconnected
    public private(set) var debimLastSync: Date?
    public private(set) var studentPortalLastSync: Date?

    public private(set) var cachedDebimPayload: RemoteUniversityPayload?
    public private(set) var cachedTranscriptSummary: NEUTranscriptSummary?
    public private(set) var cachedReconciliationReport: NEUReconciliationReport?
    public private(set) var activeConflicts: [SourceConflict] = []
    public private(set) var recentChanges: [PortalChangeRecord] = []

    public init(
        debimConnector: NEUMoodleConnector = .shared,
        studentPortalConnector: NEUStudentPortalConnector = .shared,
        reconciliationService: NEUCourseReconciliationService = .shared,
        transcriptParser: NEUTranscriptParser = .shared,
        changeHistoryService: NEUChangeHistoryService = .shared
    ) {
        self.debimConnector = debimConnector
        self.studentPortalConnector = studentPortalConnector
        self.reconciliationService = reconciliationService
        self.transcriptParser = transcriptParser
        self.changeHistoryService = changeHistoryService
    }

    // MARK: - Master Sync Pipeline

    /// Runs complete dual-portal synchronization.
    /// Resilient: if DEBİM fails, Student Portal is still processed, and vice versa.
    public func syncAll(localCourses: [Course]) async -> NEUSyncAllResult {
        var debimPayload: RemoteUniversityPayload?
        var debimErrorMsg: String?
        var portalTranscript: NEUTranscriptSummary?
        var portalErrorMsg: String?
        var debimChangesCount = 0
        var portalChangesCount = 0

        // 1. Sync DEBİM (Moodle LMS)
        debimState = .syncInProgress
        do {
            let payload = try await debimConnector.fetchFullPayload()
            // Detect deltas against previous payload
            let deltas = await changeHistoryService.detectDeltas(
                previousPayload: self.cachedDebimPayload,
                freshPayload: payload,
                source: .debim
            )
            debimChangesCount = deltas.count
            self.recentChanges.append(contentsOf: deltas)

            debimPayload = payload
            self.cachedDebimPayload = payload
            self.debimLastSync = Date()
            self.debimState = .connected
        } catch {
            debimErrorMsg = error.localizedDescription
            self.debimState = .error
        }

        // 2. Sync Student Portal (OBS)
        studentPortalState = .syncInProgress
        do {
            _ = try await studentPortalConnector.fetchEnrolledCourses()
            if let cachedHtml = studentPortalConnector.cachedTranscriptHTML {
                portalTranscript = transcriptParser.parseTranscript(html: cachedHtml)
                self.cachedTranscriptSummary = portalTranscript
                portalChangesCount = 1
            }
            self.studentPortalLastSync = Date()
            self.studentPortalState = .connected
        } catch {
            portalErrorMsg = error.localizedDescription
            self.studentPortalState = .error
        }

        // 3. Reconcile Courses
        let debimCourses = debimPayload?.courses ?? []
        let portalCourses = portalTranscript?.courses ?? []
        let report = reconciliationService.reconcile(
            debimCourses: debimCourses,
            portalCourses: portalCourses,
            localCourses: localCourses
        )

        self.cachedReconciliationReport = report
        self.activeConflicts = report.allConflicts

        let isDebimOk = (debimPayload != nil)
        let isPortalOk = (portalErrorMsg == nil)

        return NEUSyncAllResult(
            isDebimSuccess: isDebimOk,
            isPortalSuccess: isPortalOk,
            debimCourseCount: debimCourses.count,
            portalCourseCount: portalCourses.count,
            reconciledCourseCount: report.reconciledCourses.count,
            conflictCount: report.allConflicts.count,
            debimItemsChanged: debimChangesCount,
            portalItemsChanged: portalChangesCount,
            transcriptSummary: portalTranscript,
            debimError: debimErrorMsg,
            portalError: portalErrorMsg,
            syncTimestamp: Date()
        )
    }

    /// Formats human-readable stale data indicator for UI.
    public func formattedStaleDataStatus() -> String {
        guard let sync = debimLastSync ?? studentPortalLastSync else {
            return "Henüz senkronize edilmedi (AWAITING LIVE VALIDATION)"
        }
        let elapsed = Date().timeIntervalSince(sync)
        if elapsed < 3600 {
            let minutes = max(1, Int(elapsed / 60))
            return "\(minutes) dakika önce güncellendi"
        } else if elapsed < 86400 {
            let hours = Int(elapsed / 3600)
            return "Son senkronizasyon: \(hours) saat önce"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "d MMMM yyyy HH:mm"
            return "LAST VERIFIED: \(formatter.string(from: sync))"
        }
    }

    /// Imports transcript directly from raw HTML captured in the Student Portal WebView.
    public func importTranscriptHTML(_ html: String, localCourses: [Course]) -> NEUTranscriptSummary {
        let summary = transcriptParser.parseTranscript(html: html)
        self.cachedTranscriptSummary = summary

        // Trigger reconciliation update with current DEBİM courses
        let debimCourses = cachedDebimPayload?.courses ?? []
        let report = reconciliationService.reconcile(
            debimCourses: debimCourses,
            portalCourses: summary.courses,
            localCourses: localCourses
        )
        self.cachedReconciliationReport = report
        self.activeConflicts = report.allConflicts
        return summary
    }

    /// Resolves a detected discrepancy conflict with student's chosen value.
    public func resolveConflict(conflictId: UUID, resolvedValue: String) {
        if let idx = activeConflicts.firstIndex(where: { $0.id == conflictId }) {
            activeConflicts[idx].resolvedValue = resolvedValue
            activeConflicts[idx].requiresUserConfirmation = false
        }
    }

    /// Resets all local cached data for both Near East University systems.
    public func resetAll() {
        cachedDebimPayload = nil
        cachedTranscriptSummary = nil
        cachedReconciliationReport = nil
        activeConflicts.removeAll()
        recentChanges.removeAll()
        debimState = .disconnected
        studentPortalState = .disconnected
        debimLastSync = nil
        studentPortalLastSync = nil
    }
}
