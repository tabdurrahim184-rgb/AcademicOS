import Foundation
import Combine

/// Protocol for monitoring device internet connectivity.
public protocol NetworkMonitorProtocol: AnyObject, Sendable {
    var currentStatus: NetworkStatus { get }
    var isConnected: Bool { get }
    var statusPublisher: AnyPublisher<NetworkStatus, Never> { get }

    func startMonitoring()
    func stopMonitoring()
    func simulateStatusChange(to status: NetworkStatus)
}
