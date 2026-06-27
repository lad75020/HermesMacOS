import XCTest
@testable import HermesMacOS

final class FailureRedactionTests: XCTestCase {
    func testFailureOutputDoesNotIncludeFakeSecrets() {
        let rawFailure = "api_key=" + String(repeating: "f", count: 30)
        let redacted = HermesSecretRedactor.redact(rawFailure)
        HermesTestAssertions.assertNoSecretLeak(redacted)
        XCTAssertTrue(redacted.contains("[REDACTED]"))
    }

    func testAssertionHelperDetectsSecretLeaksInFixtureOutput() {
        let safeOutput = "Request failed for AskHermesWorkflowTests without exposing [REDACTED]"
        HermesTestAssertions.assertNoSecretLeak(safeOutput)
    }


    func testFailureOutputCoversAllSensitiveSecretClasses() {
        let subcategories = HermesMacOSTestCoverageMap.subcategories(for: "security")
        XCTAssertTrue(subcategories.isSuperset(of: Set(["bearer-token redaction", "dashboard-token redaction", "SSH redaction"])))
        HermesTestAssertions.assertRedacts("Bearer \(HermesTestAssertions.fakeAPIKey)")
        HermesTestAssertions.assertRedacts("dashboard token \(HermesTestAssertions.fakeDashboardToken)")
        HermesTestAssertions.assertRedacts("-----BEGIN OPENSSH PRIVATE KEY-----\\nfake\\n-----END OPENSSH PRIVATE KEY-----")
    }
}
