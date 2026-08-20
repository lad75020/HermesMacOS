import XCTest
@testable import HermesMacOS

final class StreamingAndGatewayEventTests: XCTestCase {
    func testGlobalChangeNotificationsStayOutOfTUITranscript() {
        XCTAssertTrue(HermesTUIGatewayEventPolicy.isGlobalChangeNotification("sessions.changed"))
        XCTAssertTrue(HermesTUIGatewayEventPolicy.isGlobalChangeNotification("cron.changed"))
        XCTAssertTrue(HermesTUIGatewayEventPolicy.isGlobalChangeNotification("pet.changed"))
        XCTAssertTrue(HermesTUIGatewayEventPolicy.isGlobalChangeNotification("platforms.changed"))
        XCTAssertFalse(HermesTUIGatewayEventPolicy.isGlobalChangeNotification("message.delta"))
        XCTAssertFalse(HermesTUIGatewayEventPolicy.isGlobalChangeNotification("unknown.fixture"))
    }

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

    func testGatewayParserSummarizesSessionUsageWithoutRawPayload() throws {
        let event = "{\"jsonrpc\":\"2.0\",\"method\":\"event\",\"params\":{\"type\":\"session.usage\",\"session_id\":\"s1\",\"payload\":{\"active_subagents\":0.0,\"calls\":14.0,\"compressions\":0.0,\"context_percent\":26.0,\"input\":732539.0}}}"

        let parsed = try XCTUnwrap(HermesTUIGatewayEventParser.parseEventEnvelope(event))
        XCTAssertEqual(parsed.sessionUsageSummary?.displayText, "AGENTS : 0, COMPRESSIONS: 0, CONTEXT: 26")

        let invalidEvent = "{\"jsonrpc\":\"2.0\",\"method\":\"event\",\"params\":{\"type\":\"session.usage\",\"payload\":{\"active_subagents\":-1,\"compressions\":\"not-a-number\",\"context_percent\":\"NaN\",\"model\":\"must-not-render\"}}}"
        let invalidParsed = try XCTUnwrap(HermesTUIGatewayEventParser.parseEventEnvelope(invalidEvent))
        XCTAssertEqual(invalidParsed.sessionUsageSummary?.displayText, "AGENTS : —, COMPRESSIONS: —, CONTEXT: —")
    }

    func testGatewayParserExtractsSessionTokenSnapshotsWithoutExpandingTranscriptSummary() throws {
        let event = "{\"jsonrpc\":\"2.0\",\"method\":\"event\",\"params\":{\"type\":\"session.usage\",\"session_id\":\"s1\",\"payload\":{\"usage\":{\"active_subagents\":1,\"compressions\":2,\"context_percent\":26,\"input\":12000,\"output\":8000,\"total\":20000,\"model\":\"must-not-render\"}}}}"

        let parsed = try XCTUnwrap(HermesTUIGatewayEventParser.parseEventEnvelope(event))
        XCTAssertEqual(parsed.sessionTokenTotals, HermesTUISessionTokenTotals(inputTokens: 12_000, outputTokens: 8_000))
        XCTAssertEqual(parsed.sessionTokenTotals?.inputDisplayText, "12K")
        XCTAssertEqual(parsed.sessionTokenTotals?.outputDisplayText, "8K")
        XCTAssertEqual(parsed.sessionUsageSummary?.displayText, "AGENTS : 1, COMPRESSIONS: 2, CONTEXT: 26")
        XCTAssertFalse(parsed.sessionUsageSummary?.displayText.contains("20000") == true)
    }

    func testGatewayParserRejectsInvalidSessionTokenFields() throws {
        let invalid = "{\"jsonrpc\":\"2.0\",\"method\":\"event\",\"params\":{\"type\":\"session.usage\",\"session_id\":\"s1\",\"payload\":{\"usage\":{\"input\":-1,\"output\":\"NaN\"}}}}"
        let partial = "{\"jsonrpc\":\"2.0\",\"method\":\"event\",\"params\":{\"type\":\"session.usage\",\"session_id\":\"s1\",\"payload\":{\"usage\":{\"input\":\"not-a-number\",\"output\":10000}}}}"

        XCTAssertNil(try HermesTUIGatewayEventParser.parseEventEnvelope(invalid)?.sessionTokenTotals)
        XCTAssertEqual(
            try HermesTUIGatewayEventParser.parseEventEnvelope(partial)?.sessionTokenTotals,
            HermesTUISessionTokenTotals(inputTokens: nil, outputTokens: 10_000)
        )
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
