import XCTest
@testable import HermesMacOS

final class AskHermesWorkflowTests: XCTestCase {
    func testResponsesWorkflowUsesProfilesResponsesAndCancellationRoutes() throws {
        let base = "http://localhost:8642/v1"
        XCTAssertEqual(HermesAPISettings.profilesURL(from: base)?.path, "/v1/profiles")
        XCTAssertEqual(HermesAPISettings.responseURL(from: base)?.path, "/v1/responses")
        XCTAssertEqual(HermesAPISettings.requestCancelURL(from: base, requestID: "req-ask")?.path, "/v1/requests/req-ask/cancel")
    }

    func testReasoningAndFastModeSupportAreDeterministic() {
        XCTAssertTrue(HermesReasoningModelSupport.supportsReasoningLevel(model: "openai/o4-mini", provider: "openai"))
        XCTAssertTrue(HermesFastModeSupport.supportsFastMode(model: "gpt-5", provider: "openai"))
        XCTAssertFalse(HermesFastModeSupport.supportsFastMode(model: "claude-sonnet", provider: "anthropic"))
    }

    func testAPIFixturesIncludeProfileAndResponsePayloads() throws {
        let fixture = try HermesFixtureLoader.string(named: "api-fixtures", extension: "json", subdirectory: "HermesAPI")
        XCTAssertTrue(fixture.contains("resp-test"))
        XCTAssertTrue(fixture.contains("profiles"))
        HermesTestAssertions.assertNoSecretLeak(fixture)
    }
}
