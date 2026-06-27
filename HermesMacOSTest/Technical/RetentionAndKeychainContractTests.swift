import XCTest
@testable import HermesMacOS

final class RetentionAndKeychainContractTests: XCTestCase {
    func testSecurityFixtureUsesFakeValuesOnly() throws {
        let fixture = try HermesFixtureLoader.string(named: "security-fixtures", extension: "json", subdirectory: "Security")
        XCTAssertTrue(fixture.contains("not-a-real-test-token"))
        XCTAssertTrue(fixture.contains("dashboard-token-test-only"))
        XCTAssertFalse(fixture.contains("/Users/laurent/.hermes"))
    }

    func testRetentionInputsAreRedactedBeforePersistence() {
        let prompt = "API_KEY=not-a-real-test-token-with-enough-length\nplease summarize this"
        let redacted = HermesSecretRedactor.redact(prompt)
        XCTAssertFalse(redacted.contains("not-a-real-test-token-with-enough-length"))
        XCTAssertTrue(redacted.contains("[REDACTED]"))
    }


    func testRetentionAndKeychainCoverageMatchesFR014() {
        let subcategories = HermesMacOSTestCoverageMap.subcategories(for: "security")
        XCTAssertTrue(subcategories.contains("API Keychain storage"))
        XCTAssertTrue(subcategories.contains("SSH Keychain storage"))
        XCTAssertTrue(subcategories.contains("encrypted retention"))
        XCTAssertTrue(subcategories.contains("retention clear paths"))
        HermesTestAssertions.assertRedacts("prompt api_key=\(HermesTestAssertions.fakeAPIKey)")
    }
}
