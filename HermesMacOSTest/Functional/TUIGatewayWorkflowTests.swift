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


    func testTUIGatewaySubcategoryCoverageMatchesFR007() throws {
        let subcategories = HermesMacOSTestCoverageMap.subcategories(for: "tui-gateway")
        XCTAssertTrue(subcategories.isSuperset(of: Set(["WebSocket authentication", "workspace create", "workspace activate", "workspace resume", "workspace close", "prompt submission", "attachment flow", "interrupt", "request-response bubbles", "event grouping", "background completion", "malformed events", "unknown events"])))
        let stream = try HermesFixtureLoader.string(named: "stream-fixtures", extension: "ndjson", subdirectory: "Streams")
        XCTAssertTrue(stream.contains("gateway.ready"))
        XCTAssertTrue(stream.contains("unknown.fixture"))
        XCTAssertTrue(HermesMacOSTestCoverageMap.category("tui-gateway").defaultCoverage.contains { $0.contains("TUIGatewayWorkflowTests") })
    }
}
