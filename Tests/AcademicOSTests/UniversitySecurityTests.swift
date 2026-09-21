import XCTest
@testable import AcademicOSKit

final class UniversitySecurityTests: XCTestCase {
    var keychain: KeychainStorage!
    var credentialManager: UniversityCredentialManager!

    override func setUp() {
        super.setUp()
        keychain = KeychainStorage(useMemoryFallbackOnly: true)
        credentialManager = UniversityCredentialManager(keychain: keychain)
    }

    func testSaveAndRetrieveCredentials() throws {
        try credentialManager.saveCredential(username: "2026101010", password: "SecureStudentPassword!")
        let stored = try credentialManager.getStoredCredential()
        XCTAssertNotNil(stored)
        XCTAssertEqual(stored?.username, "2026101010")
        XCTAssertTrue(stored?.hasPasswordStored == true)

        let rawPassword = try credentialManager.getRawPassword()
        XCTAssertEqual(rawPassword, "SecureStudentPassword!")
    }

    func testClearAllCredentialsWipesKeychain() throws {
        try credentialManager.saveCredential(username: "student_user", password: "password123")
        XCTAssertNotNil(try credentialManager.getStoredCredential())

        try credentialManager.clearKeychainCredentials()
        XCTAssertNil(try credentialManager.getStoredCredential())
        XCTAssertNil(try credentialManager.getRawPassword())
    }
}
