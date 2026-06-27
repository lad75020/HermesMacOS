import XCTest
@testable import HermesMacOS

final class ChatHermesWorkflowTests: XCTestCase {
    func testChatWorkflowUsesChatCompletionsRoute() {
        let base = "http://localhost:8642/v1"
        XCTAssertEqual(HermesAPISettings.chatCompletionsURL(from: base)?.absoluteString, "http://localhost:8642/v1/chat/completions")
    }

    func testChatDraftRedactionRemovesSecretLikePromptContent() {
        let token = String(repeating: "t", count: 30)
        let secretPrompt = "api_key=" + token
        let redacted = HermesSecretRedactor.redact(secretPrompt)
        XCTAssertFalse(redacted.contains(token))
        XCTAssertTrue(redacted.contains("[REDACTED]"))
    }

    func testChatFixtureIncludesAssistantMessageShape() throws {
        let fixture = try HermesFixtureLoader.string(named: "api-fixtures", extension: "json", subdirectory: "HermesAPI")
        XCTAssertTrue(fixture.contains("chatCompletion"))
        XCTAssertTrue(fixture.contains("assistant"))
    }
}
