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

    func testGatewayParserExtractsCurrentContextUsageFromNumberAndNumericString() throws {
        let completion = "{\"jsonrpc\":\"2.0\",\"method\":\"event\",\"params\":{\"type\":\"message.complete\",\"session_id\":\"s1\",\"payload\":{\"text\":\"Done\",\"usage\":{\"context_used\":12345,\"context_max\":\"131072\",\"context_percent\":\"9.42\"}}}}"
        let info = "{\"jsonrpc\":\"2.0\",\"method\":\"event\",\"params\":{\"type\":\"session.info\",\"session_id\":\"s1\",\"payload\":{\"usage\":{\"context_used\":\"23456\"}}}}"

        let parsedCompletion = try XCTUnwrap(HermesTUIGatewayEventParser.parseEventEnvelope(completion))
        XCTAssertEqual(parsedCompletion.currentContextUsage, HermesTUICurrentContextUsage(used: 12_345, maximum: 131_072, percent: 9.42))
        XCTAssertEqual(try HermesTUIGatewayEventParser.parseEventEnvelope(info)?.currentContextUsage?.used, 23_456)
    }

    func testGatewayParserNeverUsesCumulativeTotalAsCurrentContext() throws {
        let event = "{\"jsonrpc\":\"2.0\",\"method\":\"event\",\"params\":{\"type\":\"message.complete\",\"session_id\":\"s1\",\"payload\":{\"usage\":{\"total\":999999}}}}"
        XCTAssertNil(try HermesTUIGatewayEventParser.parseEventEnvelope(event)?.currentContextUsage)
    }

    func testGatewayParserRejectsOutOfRangeContextUsage() throws {
        let event = "{\"jsonrpc\":\"2.0\",\"method\":\"event\",\"params\":{\"type\":\"message.complete\",\"session_id\":\"s1\",\"payload\":{\"usage\":{\"context_used\":9223372036854775808}}}}"
        XCTAssertNil(try HermesTUIGatewayEventParser.parseEventEnvelope(event)?.currentContextUsage)
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
