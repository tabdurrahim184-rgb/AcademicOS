import Foundation
import Combine

/// User preference mode controlling how AIRouter prioritizes local vs cloud AI.
public enum AIRoutingMode: String, Codable, Sendable, CaseIterable {
    case automatic = "AUTOMATIC"
    case onlinePreferred = "ONLINE_PREFERRED"
    case offlinePreferred = "OFFLINE_PREFERRED"
    case localOnly = "LOCAL_ONLY"

    public var title: String {
        switch self {
        case .automatic: return "Smart Automatic"
        case .onlinePreferred: return "Cloud Preferred (Gemini)"
        case .offlinePreferred: return "Offline Preferred (Apple AI)"
        case .localOnly: return "Local Only (Air-Gapped)"
        }
    }
}

/// Upgraded protocol for the intelligent AI Router.
public protocol AIRouterProtocol: AnyObject, Sendable {
    var routingMode: AIRoutingMode { get }
    var activeProvider: AIProvider { get }
    var activeProviderType: AIProviderType { get }
    var isRoutingToCloud: Bool { get }
    var providerChangePublisher: AnyPublisher<AIProviderType, Never> { get }

    func setRoutingMode(_ mode: AIRoutingMode)
    func setCourseCloudAllowed(courseId: UUID, allowed: Bool)
    func isCourseCloudAllowed(courseId: UUID) -> Bool

    func route(for request: AIRequest, task: AITask?) -> AIProvider
    func execute(request: AIRequest) async throws -> AIResponse
    func execute(task: AITask, prompt: String, systemInstruction: String?, contextData: [String: String]) async throws -> AIResponse
}

/// Dynamic AI router coordinating between Gemini Cloud AI and Apple Foundation Models.
/// Strictly enforces privacy levels, course-level cloud toggles, and zero-cost fallback.
public final class AIRouter: AIRouterProtocol, @unchecked Sendable {
    private let onlineProvider: OnlineAIProvider
    private let localProvider: LocalAIProvider
    private let networkMonitor: NetworkMonitorProtocol
    private let telemetryService: AIUsageTelemetryService
    private let subject: CurrentValueSubject<AIProviderType, Never>
    private var cancellables = Set<AnyCancellable>()
    private let lock = NSLock()

    // Preferences
    private var internalMode: AIRoutingMode = .automatic
    private var courseCloudAllowedMap: [UUID: Bool] = [:]

    public var routingMode: AIRoutingMode {
        lock.lock()
        defer { lock.unlock() }
        return internalMode
    }

    public var activeProvider: AIProvider {
        lock.lock()
        defer { lock.unlock() }
        return determineDefaultProvider()
    }

    public var activeProviderType: AIProviderType {
        activeProvider.providerType
    }

    public var isRoutingToCloud: Bool {
        activeProviderType == .online
    }

    public var providerChangePublisher: AnyPublisher<AIProviderType, Never> {
        subject.removeDuplicates().eraseToAnyPublisher()
    }

    public init(
        onlineProvider: OnlineAIProvider,
        localProvider: LocalAIProvider,
        networkMonitor: NetworkMonitorProtocol,
        telemetryService: AIUsageTelemetryService = .shared
    ) {
        self.onlineProvider = onlineProvider
        self.localProvider = localProvider
        self.networkMonitor = networkMonitor
        self.telemetryService = telemetryService

        // Load persisted mode if available
        if let saved = UserDefaults.standard.string(forKey: "academicos_ai_routing_mode"),
           let mode = AIRoutingMode(rawValue: saved) {
            self.internalMode = mode
        }

        let initialType: AIProviderType = (networkMonitor.isConnected && onlineProvider.isAvailable && internalMode != .localOnly) ? .online : .local
        self.subject = CurrentValueSubject<AIProviderType, Never>(initialType)

        observeNetworkChanges()
    }

    public func setRoutingMode(_ mode: AIRoutingMode) {
        lock.lock()
        self.internalMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: "academicos_ai_routing_mode")
        let currentType = determineDefaultProvider().providerType
        lock.unlock()

        subject.send(currentType)
    }

    public func setCourseCloudAllowed(courseId: UUID, allowed: Bool) {
        lock.lock()
        defer { lock.unlock() }
        courseCloudAllowedMap[courseId] = allowed
        UserDefaults.standard.set(allowed, forKey: "course_cloud_allowed_\(courseId.uuidString)")
    }

    public func isCourseCloudAllowed(courseId: UUID) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if let explicit = courseCloudAllowedMap[courseId] {
            return explicit
        }
        // Default to true unless global mode is localOnly
        let stored = UserDefaults.standard.object(forKey: "course_cloud_allowed_\(courseId.uuidString)") as? Bool
        return stored ?? (internalMode != .localOnly)
    }

    private func observeNetworkChanges() {
        networkMonitor.statusPublisher
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.lock.lock()
                let current = self.determineDefaultProvider().providerType
                self.lock.unlock()
                self.subject.send(current)
            }
            .store(in: &cancellables)
    }

    private func determineDefaultProvider() -> AIProvider {
        switch internalMode {
        case .localOnly:
            return localProvider
        case .onlinePreferred:
            if networkMonitor.isConnected && onlineProvider.isAvailable {
                return onlineProvider
            }
            return localProvider
        case .offlinePreferred:
            if localProvider.isAvailable {
                return localProvider
            }
            if networkMonitor.isConnected && onlineProvider.isAvailable {
                return onlineProvider
            }
            return localProvider
        case .automatic:
            if networkMonitor.isConnected && onlineProvider.isAvailable {
                return onlineProvider
            }
            return localProvider
        }
    }

    public func route(for request: AIRequest, task: AITask? = nil) -> AIProvider {
        lock.lock()
        defer { lock.unlock() }

        // Privacy rule 1: Global LOCAL_ONLY setting
        if internalMode == .localOnly {
            return localProvider
        }

        // Privacy rule 2: Task-level LOCAL_ONLY or SENSITIVE
        if let t = task {
            if t.privacyLevel == .localOnly || t.privacyLevel == .sensitive {
                return localProvider
            }
            if let cid = t.courseId, !isCourseCloudAllowed(courseId: cid) {
                return localProvider
            }
            if t.requiresInternet && networkMonitor.isConnected && onlineProvider.isAvailable {
                return onlineProvider
            }
        }

        // Privacy rule 3: Course-level privacy check
        if let courseId = request.courseId, !isCourseCloudAllowed(courseId: courseId) {
            return localProvider
        }

        // Privacy rule 4: Prompt content contains credentials or keys
        if AIPrivacySanitizer.containsSensitiveContent(request.prompt) {
            return localProvider
        }

        // Apply Routing Mode Priority
        switch internalMode {
        case .localOnly:
            return localProvider

        case .onlinePreferred:
            if networkMonitor.isConnected && onlineProvider.isAvailable {
                return onlineProvider
            }
            return localProvider

        case .offlinePreferred:
            // Prefer Apple Local AI when available
            if localProvider.isAvailable {
                return localProvider
            }
            if networkMonitor.isConnected && onlineProvider.isAvailable {
                return onlineProvider
            }
            return localProvider

        case .automatic:
            if request.requiresStructuredOutput && networkMonitor.isConnected && onlineProvider.isAvailable {
                return onlineProvider
            }
            if networkMonitor.isConnected && onlineProvider.isAvailable {
                return onlineProvider
            }
            return localProvider
        }
    }

    public func execute(request: AIRequest) async throws -> AIResponse {
        let selectedProvider = route(for: request, task: nil)
        let startTime = Date()

        do {
            let response = try await selectedProvider.generateResponse(for: request)
            let elapsed = Int(Date().timeIntervalSince(startTime) * 1000)
            telemetryService.recordExecution(
                providerType: selectedProvider.providerType,
                modelIdentifier: response.modelIdentifier,
                latencyMs: elapsed,
                isFallback: response.isFallback
            )
            return response
        } catch let error as AIProviderError {
            // Automatic fallback if Gemini quota exhausted or network dropped
            if selectedProvider.providerType == .online && error.isRetryableWithLocalFallback && localProvider.isAvailable {
                telemetryService.recordQuotaError()
                let fallbackResponse = try await localProvider.generateResponse(for: request)
                let elapsed = Int(Date().timeIntervalSince(startTime) * 1000)
                telemetryService.recordExecution(
                    providerType: .local,
                    modelIdentifier: fallbackResponse.modelIdentifier,
                    latencyMs: elapsed,
                    isFallback: true
                )
                return fallbackResponse
            }
            throw error
        } catch {
            if selectedProvider.providerType == .online && localProvider.isAvailable {
                let fallbackResponse = try await localProvider.generateResponse(for: request)
                let elapsed = Int(Date().timeIntervalSince(startTime) * 1000)
                telemetryService.recordExecution(
                    providerType: .local,
                    modelIdentifier: fallbackResponse.modelIdentifier,
                    latencyMs: elapsed,
                    isFallback: true
                )
                return fallbackResponse
            }
            throw error
        }
    }

    public func execute(
        task: AITask,
        prompt: String,
        systemInstruction: String?,
        contextData: [String: String]
    ) async throws -> AIResponse {
        let request = AIRequest(
            prompt: prompt,
            systemInstruction: systemInstruction,
            contextData: contextData,
            temperature: 0.4,
            taskId: task.id,
            taskType: task.type.rawValue,
            courseId: task.courseId,
            requiresStructuredOutput: true
        )
        return try await execute(request: request)
    }
}
