import XCTest
@testable import HermesMacOS

final class TUIGatewayWorkflowTests: XCTestCase {
    func testGatewayEventParserHandlesMessageAndRequestEvents() throws {
        let stream = try HermesFixtureLoader.string(named: "stream-fixtures", extension: "ndjson", subdirectory: "Streams")
        let parsed = try stream.split(separator: "\n").compactMap { try HermesTUIGatewayEventParser.parseEventEnvelope(String($0)) }
        XCTAssertTrue(parsed.contains { $0.type == "gateway.ready" && $0.sessionID == "sess-test" })
        XCTAssertTrue(parsed.contains { $0.type == "message.delta" && $0.text == "Hello" })
        XCTAssertTrue(parsed.contains { $0.type == "approval.request" && $0.requestID == "approval-test" })
        XCTAssertTrue(parsed.contains { $0.type == "unknown.fixture" })
    }

    func testGatewayMessageRequestMetadataIsStable() {
        var message = HermesTUIGatewayMessage(role: .request, title: "Approval required", content: "Approve fake action", eventType: "approval.request", requestKind: .approval, requestID: "approval-test")
        XCTAssertEqual(message.role, .request)
        XCTAssertEqual(message.requestKind, .approval)
        XCTAssertFalse(message.isResolved)
        message.isResolved = true
        XCTAssertTrue(message.isResolved)
    }

    @MainActor
    func testCurrentContextUsageFormatsAndUpdatesOnlyAssistantBubble() {
        let usage = HermesTUICurrentContextUsage(used: 12_345, maximum: 131_072, percent: 9.42)
        XCTAssertEqual(usage.displayText, "Context 12.3K")
        XCTAssertEqual(usage.accessibilityText, "12,345 of 131,072 context tokens, 9.42 percent used")

        let store = HermesTUIGatewayStore()
        store.sessionID = "live-session"
        store.isStreaming = true
        store.messages = [
            HermesTUIGatewayMessage(role: .user, title: "You", content: "Question"),
            HermesTUIGatewayMessage(role: .assistant, title: "Hermes", content: "Answer")
        ]

        store.applyCurrentContextUsage(usage, eventSessionID: "live-session", allowLatestAssistant: true)

        XCTAssertNil(store.messages[0].currentContextUsage)
        XCTAssertEqual(store.messages[1].currentContextUsage, usage)
        XCTAssertEqual(store.messages.count, 2)

        store.messages[1].currentContextUsage = nil
        store.isStreaming = false
        store.applyCurrentContextUsage(usage, eventSessionID: "live-session", allowLatestAssistant: true)
        XCTAssertNil(store.messages[1].currentContextUsage)

        store.connectionStatus = "Completed"
        store.applyCurrentContextUsage(usage, eventSessionID: "live-session", allowLatestAssistant: true)
        XCTAssertEqual(store.messages[1].currentContextUsage, usage)
    }

    @MainActor
    func testCurrentContextUsageDoesNotCrossSessionOrUserTurn() {
        let store = HermesTUIGatewayStore()
        store.sessionID = "current"
        store.isStreaming = true
        store.messages = [
            HermesTUIGatewayMessage(role: .assistant, title: "Hermes", content: "Old answer"),
            HermesTUIGatewayMessage(role: .user, title: "You", content: "New question")
        ]

        store.applyCurrentContextUsage(HermesTUICurrentContextUsage(used: 500), eventSessionID: "other", allowLatestAssistant: true)
        store.applyCurrentContextUsage(HermesTUICurrentContextUsage(used: 600), eventSessionID: "current", allowLatestAssistant: true)

        XCTAssertNil(store.messages[0].currentContextUsage)
        XCTAssertNil(store.messages[1].currentContextUsage)
    }

    func testTUIGatewayRegistersPendingResponseBeforeSendingRequest() throws {
        let source = try HermesTestAssertions.readRepositoryFile("HermesMacOS/HermesTUIGatewayView.swift")
        let requestStart = try XCTUnwrap(source.range(of: "private func request(_ method:"))
        let requestEnd = try XCTUnwrap(source.range(of: "private func webSocketURL(", range: requestStart.upperBound..<source.endIndex))
        let requestSource = source[requestStart.lowerBound..<requestEnd.lowerBound]
        let registration = try XCTUnwrap(requestSource.range(of: "pendingResponses[id] = continuation"))
        let send = try XCTUnwrap(requestSource.range(of: "try await task.send(.string(text))"))

        XCTAssertLessThan(
            requestSource.distance(from: requestSource.startIndex, to: registration.lowerBound),
            requestSource.distance(from: requestSource.startIndex, to: send.lowerBound),
            "A fast JSON-RPC response can be dropped unless its continuation is registered before WebSocket send."
        )
    }


    func testTUIGatewaySubcategoryCoverageMatchesFR007() throws {
        let subcategories = HermesMacOSTestCoverageMap.subcategories(for: "tui-gateway")
        XCTAssertTrue(subcategories.isSuperset(of: Set(["WebSocket authentication", "workspace create", "workspace activate", "workspace resume", "workspace close", "prompt submission", "attachment flow", "interrupt", "request-response bubbles", "event grouping", "background completion", "malformed events", "unknown events"])))
        let stream = try HermesFixtureLoader.string(named: "stream-fixtures", extension: "ndjson", subdirectory: "Streams")
        XCTAssertTrue(stream.contains("gateway.ready"))
        XCTAssertTrue(stream.contains("unknown.fixture"))
        XCTAssertTrue(HermesMacOSTestCoverageMap.category("tui-gateway").defaultCoverage.contains { $0.contains("TUIGatewayWorkflowTests") })
    }
}
