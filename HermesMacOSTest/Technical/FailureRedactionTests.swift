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
}
