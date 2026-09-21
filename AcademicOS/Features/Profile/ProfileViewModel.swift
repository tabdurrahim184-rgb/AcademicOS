import SwiftUI
import Combine

/// State management for the Student Profile and OS Settings screen.
@MainActor
public final class ProfileViewModel: ObservableObject {
    @Published public var profile: StudentProfile?
    @Published public var gpaRecord: GPARecord?
    @Published public var graduationProgress: GraduationProgress?
    @Published public var isBiometricLocked: Bool = true
    @Published public var aiModeSelection: String = "Automatic"
    @Published public var keepScreenAwake: Bool = true
    @Published public var recordingQualityHigh: Bool = true
    @Published public var healthReport: DataHealthReport?
    @Published public var offlineDatabaseSize: String = "Calculating..."
    @Published public var queuedSyncJobsCount: Int = 0
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String?

    private let studentRepo: StudentRepositoryProtocol
    private let profileRepo: ProfileRepositoryProtocol
    private let gradRepo: GraduationRepositoryProtocol
    private let queueManager: OfflineQueueManager
    private let dataHealthService: DataHealthServiceProtocol
    private let appContainer: AppContainer

    public init(
        studentRepo: StudentRepositoryProtocol? = nil,
        profileRepo: ProfileRepositoryProtocol? = nil,
        gradRepo: GraduationRepositoryProtocol? = nil,
        queueManager: OfflineQueueManager? = nil,
        dataHealthService: DataHealthServiceProtocol? = nil,
        appContainer: AppContainer? = nil
    ) {
        let container = appContainer ?? AppContainer.shared
        self.studentRepo = studentRepo ?? container.studentRepository
        self.profileRepo = profileRepo ?? container.profileRepository
        self.gradRepo = gradRepo ?? container.graduationRepository
        self.queueManager = queueManager ?? container.queueManager
        self.dataHealthService = dataHealthService ?? container.dataHealthService
        self.appContainer = container
    }

    public func loadProfileData() async {
        isLoading = true
        do {
            async let studentTask = studentRepo.getStudent()
            async let gpaTask = profileRepo.getGPARecord()
            async let gradTask = gradRepo.getGraduationProgress()
            async let pendingTask = queueManager.pendingJobsCount()
            async let healthTask = dataHealthService.runDiagnostics()

            let (student, gpa, grad, pending, health) = try await (studentTask, gpaTask, gradTask, pendingTask, healthTask)

            self.profile = student
            self.gpaRecord = gpa
            self.graduationProgress = grad
            self.queuedSyncJobsCount = pending
            self.healthReport = health
            self.offlineDatabaseSize = health.databaseStorageFormatted
            if let st = student {
                self.isBiometricLocked = st.biometricLockEnabled
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    public func toggleBiometricLock() {
        isBiometricLocked.toggle()
        if var p = profile {
            p.biometricLockEnabled = isBiometricLocked
            Task {
                try? await studentRepo.saveStudent(p)
            }
        }
    }

    public func seedDemoData() async {
        isLoading = true
        do {
            try await appContainer.seedDeveloperDemoData()
            await loadProfileData()
        } catch {
            self.errorMessage = "Failed to load demo data: \(error.localizedDescription)"
        }
        isLoading = false
    }

    public func resetDatabase() async {
        isLoading = true
        do {
            try await appContainer.resetDatabase()
            self.profile = nil
            self.gpaRecord = nil
            self.graduationProgress = nil
            await loadProfileData()
        } catch {
            self.errorMessage = "Failed to reset database: \(error.localizedDescription)"
        }
        isLoading = false
    }
}
