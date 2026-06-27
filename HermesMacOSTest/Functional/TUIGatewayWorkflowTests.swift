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
}
