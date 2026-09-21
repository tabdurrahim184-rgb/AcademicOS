import XCTest
import Combine
@testable import AcademicOSKit

final class NetworkMonitorTests: XCTestCase {
    var monitor: NetworkMonitor!
    var cancellables = Set<AnyCancellable>()

    override func setUp() {
        super.setUp()
        monitor = NetworkMonitor(initialStatus: .online)
        cancellables.removeAll()
    }

    func testNetworkStatusTransitions() {
        let expectation = XCTestExpectation(description: "Network switches to offline")

        monitor.statusPublisher
            .dropFirst()
            .sink { status in
                if status == .offline {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        monitor.simulateStatusChange(to: .offline)
        wait(for: [expectation], timeout: 1.0)
        XCTAssertFalse(monitor.isConnected)
    }

    func testLimitedNetworkStatus() {
        monitor.simulateStatusChange(to: .limited(reason: "Cellular Roaming"))
        XCTAssertFalse(monitor.isConnected)
        if case .limited(let reason) = monitor.currentStatus {
            XCTAssertEqual(reason, "Cellular Roaming")
        } else {
            XCTFail("Expected limited status")
        }
    }
}
