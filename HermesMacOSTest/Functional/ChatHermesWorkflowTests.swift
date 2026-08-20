import XCTest
@testable import HermesMacOS

final class ChatHermesWorkflowTests: XCTestCase {
    func testChatWorkflowUsesChatCompletionsRoute() {
        let base = "http://localhost:8642/v1"
        XCTAssertEqual(HermesAPISettings.chatCompletionsURL(from: base)?.absoluteString, "http://localhost:8642/v1/chat/completions")
    }

    @MainActor
    func testChatTranslationReplacesOnlySelectedRangeAndPreservesBubbleIdentity() {
        let session = HermesChatSession()
        let first = HermesChatMessage(role: "assistant", content: "Bonjour, Laurent")
        let second = HermesChatMessage(role: "user", content: "Keep this message")
        session.entries = [first, second]

        let didReplace = session.replaceSelectedText(
            in: first.id,
            originalContent: first.content,
            selectedRange: NSRange(location: 0, length: 7),
            with: "Hello"
        )

        XCTAssertTrue(didReplace)
        XCTAssertEqual(session.entries.map(\.id), [first.id, second.id])
        XCTAssertEqual(session.entries.map(\.content), ["Hello, Laurent", "Keep this message"])
    }

    @MainActor
    func testChatTranslationRejectsInvalidSelectionWithoutChangingHistory() {
        let session = HermesChatSession()
        let message = HermesChatMessage(role: "assistant", content: "Bonjour")
        session.entries = [message]

        let didReplace = session.replaceSelectedText(
            in: message.id,
            originalContent: "Changed before translation finished",
            selectedRange: NSRange(location: 0, length: 7),
            with: "Hello"
        )

        XCTAssertFalse(didReplace)
        XCTAssertEqual(session.entries.first?.id, message.id)
        XCTAssertEqual(session.entries.first?.content, "Bonjour")
    }

    @MainActor
    func testNativeTranslationServiceRejectsEmptySelection() {
        let service = HermesNativeTranslationService()
        let messageID = UUID()

        service.requestTranslation(
            messageID: messageID,
            content: "Bonjour",
            selectedRange: NSRange(location: 0, length: 0),
            isMessageComplete: true
        )

        XCTAssertFalse(service.isTranslating)
        XCTAssertNil(service.selection)
        XCTAssertFalse(service.errorMessage.isEmpty)
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


    func testChatHermesSubcategoryCoverageMatchesFR006() throws {
        let subcategories = HermesMacOSTestCoverageMap.subcategories(for: "chat-hermes")
        XCTAssertTrue(subcategories.isSuperset(of: Set(["system prompt", "streaming responses", "non-streaming responses", "attachments", "cancellation", "session continuation headers", "retained history", "user-visible errors"])))
        XCTAssertEqual(HermesAPISettings.chatCompletionsURL(from: "http://localhost:8642/v1")?.path, "/v1/chat/completions")
        let fixture = try HermesFixtureLoader.string(named: "api-fixtures", extension: "json", subdirectory: "HermesAPI")
        XCTAssertTrue(fixture.contains("chatCompletion"))
        XCTAssertTrue(HermesMacOSTestCoverageMap.category("chat-hermes").defaultCoverage.contains { $0.contains("ChatHermesWorkflowTests") })
    }
}
