import XCTest
@testable import AcademicOSKit

final class KeychainServiceTests: XCTestCase {
    var keychain: KeychainStorage!

    override func setUp() {
        super.setUp()
        // Use memory fallback for headless testing harness
        keychain = KeychainStorage(useMemoryFallbackOnly: true)
    }

    func testSaveAndRetrieveCredential() throws {
        let fakeApiKey = "AIzaSyAcademicOSSecureTestKey123"
        try keychain.set(fakeApiKey, for: .geminiApiKey)

        let retrieved = try keychain.get(.geminiApiKey)
        XCTAssertEqual(retrieved, fakeApiKey)
        XCTAssertTrue(keychain.contains(.geminiApiKey))
    }

    func testDeleteCredential() throws {
        let password = "SuperSecretLmsPassword"
        try keychain.set(password, for: .lmsPassword)
        XCTAssertTrue(keychain.contains(.lmsPassword))

        try keychain.delete(.lmsPassword)
        let retrieved = try keychain.get(.lmsPassword)
        XCTAssertNil(retrieved)
        XCTAssertFalse(keychain.contains(.lmsPassword))
    }
}
