import SwiftUI
import Combine

/// Central Dependency Injection container for AcademicOS.
/// Assembles persistence, networking, security, AI routing, and repositories.
@MainActor
public final class AppContainer: ObservableObject {
    public static let shared = AppContainer()

    // Core Services
    public let localStore: LocalStoreProtocol
    public let keychain: KeychainServiceProtocol
    public let networkMonitor: NetworkMonitorProtocol
    public let queueManager: OfflineQueueManager
    public let syncCoordinator: SyncCoordinator

    // AI Subsystem
    public let onlineAIProvider: OnlineAIProvider
    public let localAIProvider: LocalAIProvider
    public let aiRouter: AIRouterProtocol
    public let agentCoordinator: AgentCoordinatorProtocol
    public let contextBuilder: CourseContextBuilder

    // Phase 2B AI Pipelines & Specialized Services
    public let lecturePipeline: LectureIntelligencePipeline
    public let quizService: InteractiveQuizService
    public let flashcardGenService: FlashcardGenerationService

    // Repositories
    public let courseRepository: CourseRepositoryProtocol
    public let taskRepository: TaskRepositoryProtocol
    public let calendarRepository: CalendarRepositoryProtocol
    public let graduationRepository: GraduationRepositoryProtocol
    public let profileRepository: ProfileRepositoryProtocol
    public let studentRepository: StudentRepositoryProtocol
    public let semesterRepository: SemesterRepositoryProtocol
    public let lectureRepository: LectureRepositoryProtocol
    public let notesRepository: NotesRepositoryProtocol
    public let recordingRepository: RecordingRepositoryProtocol
    public let examRepository: ExamRepositoryProtocol
    public let flashcardRepository: FlashcardRepositoryProtocol
    public let searchRepository: SearchRepositoryProtocol
    public let memoryRepository: AIMemoryRepositoryProtocol
    public let noteVersionRepository: NoteVersionRepositoryProtocol
    public let masteryRepository: MasteryRepositoryProtocol
    public let emphasisRepository: ProfessorEmphasisRepositoryProtocol
    public let pipelineRepository: PipelineRepositoryProtocol

    public let transcriptionService: TranscriptionServiceProtocol
    public let dataHealthService: DataHealthServiceProtocol

    // Phase 2C University Integration & Academic Automation
    public let universityRepository: UniversityRepositoryProtocol
    public let domainPolicy: DomainPolicyServiceProtocol
    public let credentialManager: UniversityCredentialManagerProtocol
    public let universityConnector: UniversityConnectorProtocol
    public let documentDownloader: UniversityDocumentDownloaderProtocol
    public let universitySyncEngine: UniversitySyncEngine
    public let gpaCalculator: GPACalculator
    public let notificationService: AcademicNotificationServiceProtocol
    public let universityAgent: UniversityAgent

    // Observable status published to UI
    @Published public var networkStatus: NetworkStatus = .online
    @Published public var activeAIProviderType: AIProviderType = .online
    @Published public var pendingSyncCount: Int = 0

    private var cancellables = Set<AnyCancellable>()

    public init(
        localStore: LocalStoreProtocol = SQLiteDatabaseManager.shared,
        useMemoryKeychainOnly: Bool = false
    ) {
        self.localStore = localStore
        self.keychain = KeychainStorage(useMemoryFallbackOnly: useMemoryKeychainOnly)
        self.networkMonitor = NetworkMonitor.shared
        self.queueManager = OfflineQueueManager(localStore: localStore)
        self.syncCoordinator = SyncCoordinator(networkMonitor: networkMonitor, queueManager: queueManager)

        // Configure App Check safely before Firebase calls
        AppCheckConfigurationService.shared.configureAppCheckIfAvailable()

        // Repositories (real SQLite / LocalStore implementations)
        let cRepo = DatabaseCourseRepository(localStore: localStore)
        self.courseRepository = cRepo
        let tRepo = DatabaseTaskRepository(localStore: localStore)
        self.taskRepository = tRepo
        self.calendarRepository = CalendarRepository(localStore: localStore)
        self.graduationRepository = DatabaseGraduationRepository(localStore: localStore)
        self.profileRepository = ProfileRepository(localStore: localStore)
        self.studentRepository = DatabaseStudentRepository(localStore: localStore)
        self.semesterRepository = DatabaseSemesterRepository(localStore: localStore)
        self.lectureRepository = DatabaseLectureRepository(localStore: localStore)
        let nRepo = DatabaseNotesRepository(localStore: localStore)
        self.notesRepository = nRepo
        let recRepo = DatabaseRecordingRepository(localStore: localStore)
        self.recordingRepository = recRepo
        let eRepo = DatabaseExamRepository(localStore: localStore)
        self.examRepository = eRepo
        let fRepo = DatabaseFlashcardRepository(localStore: localStore)
        self.flashcardRepository = fRepo
        self.searchRepository = DatabaseSearchRepository(localStore: localStore)
        let memRepo = DatabaseAIMemoryRepository(localStore: localStore)
        self.memoryRepository = memRepo
        let nvRepo = DatabaseNoteVersionRepository(localStore: localStore)
        self.noteVersionRepository = nvRepo
        let mRepo = DatabaseMasteryRepository(localStore: localStore)
        self.masteryRepository = mRepo
        let empRepo = DatabaseProfessorEmphasisRepository(localStore: localStore)
        self.emphasisRepository = empRepo
        let pRepo = DatabasePipelineRepository(localStore: localStore)
        self.pipelineRepository = pRepo

        self.transcriptionService = TranscriptionService(recordingRepo: recRepo)
        self.dataHealthService = DataHealthService(localStore: localStore)

        // Context Builder
        self.contextBuilder = CourseContextBuilder(
            courseRepo: cRepo,
            notesRepo: nRepo,
            recordingRepo: recRepo,
            examRepo: eRepo,
            taskRepo: tRepo,
            memoryRepo: memRepo
        )

        // AI Setup: Gemini Developer API (Free Tier) + Apple Foundation Models
        let online = GeminiAIProvider(configuration: .zeroCostDefault)
        let local = AppleLocalAIProvider()
        let router = AIRouter(
            onlineProvider: online,
            localProvider: local,
            networkMonitor: networkMonitor
        )
        let coordinator = AgentCoordinator(router: router)

        self.onlineAIProvider = online
        self.localAIProvider = local
        self.aiRouter = router
        self.agentCoordinator = coordinator

        // Specialized AI Services
        self.lecturePipeline = LectureIntelligencePipeline(
            recordingRepo: recRepo,
            notesRepo: nRepo,
            noteVersionRepo: nvRepo,
            memoryRepo: memRepo,
            emphasisRepo: empRepo,
            pipelineRepo: pRepo,
            aiRouter: router
        )
        self.quizService = InteractiveQuizService(masteryRepo: mRepo, aiRouter: router)
        self.flashcardGenService = FlashcardGenerationService(flashcardRepo: fRepo, aiRouter: router)

        // Phase 2C University Subsystem
        let uRepo = DatabaseUniversityRepository(localStore: localStore)
        self.universityRepository = uRepo
        let dPolicy = DomainPolicyService.shared
        self.domainPolicy = dPolicy
        let credMgr = UniversityCredentialManager(keychain: self.keychain)
        self.credentialManager = credMgr
        let uConn = DemoUniversityConnector()
        self.universityConnector = uConn
        let docDownloader = UniversityDocumentDownloader(domainPolicy: dPolicy, localStore: localStore)
        self.documentDownloader = docDownloader
        let notifService = AcademicNotificationService.shared
        self.notificationService = notifService
        let gpaCalc = GPACalculator()
        self.gpaCalculator = gpaCalc

        let uSyncEngine = UniversitySyncEngine(
            connector: uConn,
            universityRepo: uRepo,
            courseRepo: cRepo,
            examRepo: eRepo,
            taskRepo: tRepo,
            calendarRepo: self.calendarRepository,
            documentDownloader: docDownloader,
            notificationService: notifService,
            gpaCalculator: gpaCalc
        )
        self.universitySyncEngine = uSyncEngine
        self.syncCoordinator.setUniversitySyncEngine(uSyncEngine)

        let uAgent = UniversityAgent(
            router: router,
            universityRepo: uRepo,
            examRepo: eRepo,
            taskRepo: tRepo
        )
        self.universityAgent = uAgent

        // Register default agents
        coordinator.register(agent: AcademicCommanderAgent(
            router: router,
            courseRepo: cRepo,
            examRepo: eRepo,
            taskRepo: tRepo,
            universityRepo: uRepo
        ))
        coordinator.register(agent: CourseAgent(router: router))
        coordinator.register(agent: StudyAgent(router: router))
        coordinator.register(agent: ExamAgent(router: router))
        coordinator.register(agent: NotesAgent(router: router))
        coordinator.register(agent: uAgent)

        setupObservability()
        startBackgroundServices()
    }

    public func buildCourseContext(forCourseId courseId: UUID) async throws -> [String: String] {
        return try await contextBuilder.buildContext(courseId: courseId)
    }

    private func setupObservability() {
        self.networkStatus = networkMonitor.currentStatus
        self.activeAIProviderType = aiRouter.activeProviderType

        networkMonitor.statusPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.networkStatus = status
            }
            .store(in: &cancellables)

        aiRouter.providerChangePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] providerType in
                self?.activeAIProviderType = providerType
            }
            .store(in: &cancellables)
    }

    private func startBackgroundServices() {
        networkMonitor.startMonitoring()
    }

    /// On-demand loading of realistic academic data for demonstration
    public func seedDeveloperDemoData() async throws {
        try await MockDataService.shared.seedData(into: localStore)
    }

    /// Resets all local records, enabling clean re-testing of the onboarding experience
    public func resetDatabase() async throws {
        try await localStore.clearAll()
    }
}
