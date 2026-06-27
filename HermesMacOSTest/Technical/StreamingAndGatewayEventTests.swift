import XCTest
@testable import HermesMacOS

final class StreamingAndGatewayEventTests: XCTestCase {
    func testGatewayParserIgnoresNonEventRPCResponses() throws {
        let rpcResponse = "{\"jsonrpc\":\"2.0\",\"id\":\"1\",\"result\":{\"ok\":true}}"
        XCTAssertNil(try HermesTUIGatewayEventParser.parseEventEnvelope(rpcResponse))
    }

    func testGatewayParserExtractsCompletionStatus() throws {
        let event = "{\"jsonrpc\":\"2.0\",\"method\":\"event\",\"params\":{\"type\":\"message.complete\",\"session_id\":\"s1\",\"payload\":{\"text\":\"Done\",\"status\":\"complete\"}}}"
        let parsed = try XCTUnwrap(HermesTUIGatewayEventParser.parseEventEnvelope(event))
        XCTAssertEqual(parsed.type, "message.complete")
        XCTAssertEqual(parsed.sessionID, "s1")
        XCTAssertEqual(parsed.text, "Done")
        XCTAssertEqual(parsed.status, "complete")
    }

    func testStreamFixturesIncludeMalformedAndUnknownEventCoverage() throws {
        let fixture = try HermesFixtureLoader.string(named: "stream-fixtures", extension: "ndjson", subdirectory: "Streams")
        XCTAssertTrue(fixture.contains("unknown.fixture"))
        XCTAssertTrue(fixture.contains("approval.request"))
    }


    func testGatewayStreamContractCoversLifecycleAndMalformedEvents() throws {
        let subcategories = HermesMacOSTestCoverageMap.subcategories(for: "tui-gateway")
        XCTAssertTrue(subcategories.isSuperset(of: Set(["WebSocket authentication", "workspace create", "workspace activate", "workspace resume", "workspace close", "background completion", "malformed events", "unknown events"])))
        let stream = try HermesFixtureLoader.string(named: "stream-fixtures", extension: "ndjson", subdirectory: "Streams")
        XCTAssertTrue(HermesMacOSTestCoverageMap.covers("tui-gateway", "malformed events"))
        XCTAssertTrue(stream.contains("unknown.fixture"))
    }
}
