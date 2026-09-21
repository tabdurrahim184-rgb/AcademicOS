import Foundation
import Network
import Combine

/// Monitors device network transitions without blocking main thread.
/// Guarantees the application never crashes or disables itself when connectivity is lost.
public final class NetworkMonitor: NetworkMonitorProtocol, @unchecked Sendable {
    private let monitor: NWPathMonitor
    private let monitorQueue = DispatchQueue(label: "com.academicos.networkmonitor", qos: .utility)
    private let subject: CurrentValueSubject<NetworkStatus, Never>
    private let lock = NSLock()
    private var isSimulated: Bool = false

    public static let shared = NetworkMonitor()

    public var currentStatus: NetworkStatus {
        subject.value
    }

    public var isConnected: Bool {
        subject.value.isOnline
    }

    public var statusPublisher: AnyPublisher<NetworkStatus, Never> {
        subject.eraseToAnyPublisher()
    }

    public init(initialStatus: NetworkStatus = .online) {
        self.subject = CurrentValueSubject<NetworkStatus, Never>(initialStatus)
        self.monitor = NWPathMonitor()
        setupMonitor()
    }

    private func setupMonitor() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            self.lock.lock()
            defer { self.lock.unlock() }

            if self.isSimulated { return }

            let newStatus: NetworkStatus
            if path.status == .satisfied {
                if path.isExpensive {
                    newStatus = .limited(reason: "Cellular / Metered Data")
                } else if path.isConstrained {
                    newStatus = .limited(reason: "Low Data Mode Active")
                } else {
                    newStatus = .online
                }
            } else {
                newStatus = .offline
            }

            if self.subject.value != newStatus {
                self.subject.send(newStatus)
            }
        }
    }

    public func startMonitoring() {
        monitor.start(queue: monitorQueue)
    }

    public func stopMonitoring() {
        monitor.cancel()
    }

    public func simulateStatusChange(to status: NetworkStatus) {
        lock.lock()
        isSimulated = true
        lock.unlock()
        subject.send(status)
    }

    public func resetSimulation() {
        lock.lock()
        isSimulated = false
        lock.unlock()
    }
}
