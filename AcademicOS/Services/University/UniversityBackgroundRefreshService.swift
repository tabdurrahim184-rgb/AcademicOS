import Foundation
#if canImport(BackgroundTasks)
import BackgroundTasks
#endif

/// Coordinates background synchronization via iOS BGAppRefreshTask.
public final class UniversityBackgroundRefreshService: @unchecked Sendable {
    public static let shared = UniversityBackgroundRefreshService()
    public static let taskIdentifier = "com.academicos.universityrefresh"

    private let syncEngineProvider: (@Sendable () -> UniversitySyncEngine?)?

    public init(syncEngineProvider: (@Sendable () -> UniversitySyncEngine?)? = nil) {
        self.syncEngineProvider = syncEngineProvider
    }

    /// Registers the background task handler with iOS BGTaskScheduler.
    public func registerBackgroundTask() {
        #if canImport(BackgroundTasks)
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.taskIdentifier, using: nil) { task in
            guard let appRefreshTask = task as? BGAppRefreshTask else { return }
            self.handleAppRefresh(task: appRefreshTask)
        }
        #endif
    }

    /// Schedules the next background sync trigger (minimum 1 hour).
    public func scheduleNextRefresh(intervalMinutes: Int = 60) {
        #if canImport(BackgroundTasks)
        let request = BGAppRefreshTaskRequest(identifier: Self.taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: Double(intervalMinutes * 60))

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // Background refresh may be restricted by low power mode or permissions
        }
        #endif
    }

    #if canImport(BackgroundTasks)
    private func handleAppRefresh(task: BGAppRefreshTask) {
        scheduleNextRefresh()

        let syncTask = Task {
            guard let engine = syncEngineProvider?() else {
                task.setTaskCompleted(success: true)
                return
            }

            do {
                _ = try await engine.performSync()
                task.setTaskCompleted(success: true)
            } catch {
                task.setTaskCompleted(success: false)
            }
        }

        task.expirationHandler = {
            syncTask.cancel()
        }
    }
    #endif
}
