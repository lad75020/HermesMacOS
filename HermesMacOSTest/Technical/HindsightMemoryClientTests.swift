import XCTest
@testable import HermesMacOS

final class HindsightMemoryClientTests: XCTestCase {
    func testListJSONDecodingAcceptsOptionalMetadata() throws {
        let request = MemoryListRequest(filterText: "", pageIndex: 0, pageSize: 10)
        let page = try HermesHindsightMemoryClient.decodeListOutput(HindsightMemoryFixtures.listJSON(), request: request)
        XCTAssertEqual(page.entries.count, 2)
        XCTAssertEqual(page.entries[0].id, "h-1")
        XCTAssertEqual(page.entries[0].kind, "experience")
        XCTAssertEqual(page.entries[0].profile, "bank-default")
        XCTAssertEqual(page.entries[0].metadata["context"], "test")
        XCTAssertEqual(page.entries[0].metadata["proof_count"], "2")
        XCTAssertEqual(page.pageIndex, 0)
        XCTAssertEqual(page.pageSize, 10)
        XCTAssertEqual(page.offset, 0)
        XCTAssertEqual(page.totalCount, 2)
        XCTAssertEqual(page.providerBank, "bank-default")
        XCTAssertFalse(page.hasMore)
    }

    func testInventoryDecodingUsesExactProviderPaginationMetadata() throws {
        let request = MemoryListRequest(filterText: "Hermes", pageIndex: 0, pageSize: 10)
        let output = Data(#"{"success":true,"items":[{"id":"h-11","text":"Provider page row","fact_type":"world"}],"total":13,"limit":5,"offset":10,"bank_id":"bank-research","profile":"research"}"#.utf8)

        let page = try HermesHindsightMemoryClient.decodeListOutput(output, request: request)

        XCTAssertEqual(page.entries.map(\.id), ["h-11"])
        XCTAssertEqual(page.pageIndex, 2)
        XCTAssertEqual(page.pageSize, 5)
        XCTAssertEqual(page.offset, 10)
        XCTAssertEqual(page.totalCount, 13)
        XCTAssertEqual(page.providerBank, "bank-research")
        XCTAssertEqual(page.profile, "research")
        XCTAssertTrue(page.hasMore)
    }

    func testInventoryHelperUsesProviderSideSearchLimitAndOffset() {
        let source = HermesHindsightMemoryClient.pythonHelperContract

        XCTAssertTrue(source.contains("client.memories.list("))
        XCTAssertTrue(source.contains("client.list_memories("))
        XCTAssertTrue(source.contains("search_query=search_query"))
        XCTAssertTrue(source.contains("limit=limit"))
        XCTAssertTrue(source.contains("offset=offset"))
        XCTAssertFalse(source.contains("client.arecall("))
        XCTAssertFalse(source.contains("all_records[start:end]"))
    }

    func testListHelperArgumentsKeepProfilesHomesAndBanksIsolated() {
        let request = MemoryListRequest(filterText: "  project notes  ", pageIndex: 2, pageSize: 5)
        let alpha = HindsightMemoryContext.active(
            rootHermesHome: "/private/tmp/hermes-memory-context",
            profile: "alpha",
            providerBank: "bank-alpha"
        )
        let beta = HindsightMemoryContext.active(
            rootHermesHome: "/private/tmp/hermes-memory-context",
            profile: "beta",
            providerBank: "bank-beta"
        )

        XCTAssertEqual(alpha.hermesHome, "/private/tmp/hermes-memory-context/profiles/alpha")
        XCTAssertEqual(beta.hermesHome, "/private/tmp/hermes-memory-context/profiles/beta")
        XCTAssertEqual(
            HermesHindsightMemoryClient.listHelperArguments(request: request, context: alpha),
            ["list", alpha.hermesHome, "alpha", "bank-alpha", "project notes", "5", "10"]
        )
        XCTAssertEqual(
            HermesHindsightMemoryClient.listHelperArguments(request: request, context: beta),
            ["list", beta.hermesHome, "beta", "bank-beta", "project notes", "5", "10"]
        )
    }

    func testListDecodingToleratesDiagnosticsAroundFramedHelperPayload() throws {
        let request = MemoryListRequest(filterText: "", pageIndex: 0, pageSize: 10)
        let payload = String(decoding: HindsightMemoryFixtures.listJSON(), as: UTF8.self)
        let output = Data("""
        Hindsight diagnostic before payload
        HERMES_MEMORY_JSON:\(payload)
        Hindsight diagnostic after payload
        """.utf8)

        let page = try HermesHindsightMemoryClient.decodeListOutput(output, request: request)

        XCTAssertEqual(page.entries.map(\.id), ["h-1", "h-2"])
        XCTAssertEqual(page.totalCount, 2)
        XCTAssertFalse(page.hasMore)
    }

    func testMalformedRowsAreRejected() {
        let request = MemoryListRequest(filterText: "", pageIndex: 0, pageSize: 10)
        XCTAssertThrowsError(try HermesHindsightMemoryClient.decodeListOutput(HindsightMemoryFixtures.malformedListJSON(), request: request))
    }

    func testMalformedResultDoesNotHideValidResults() throws {
        let request = MemoryListRequest(filterText: "Hermes", pageIndex: 0, pageSize: 10)
        let output = Data(#"{"success":true,"items":[{"id":"valid-1","text":"First valid memory"},{"id":"malformed-missing-content"},{"id":"valid-2","text":"Second valid memory"}],"total":3,"limit":10,"offset":0}"#.utf8)

        let page = try HermesHindsightMemoryClient.decodeListOutput(output, request: request)

        XCTAssertEqual(page.entries.map(\.id), ["valid-1", "valid-2"])
        XCTAssertEqual(page.totalCount, 3)
        XCTAssertFalse(page.hasMore)
    }

    func testNonFiniteConfidenceDoesNotHideValidResults() throws {
        let request = MemoryListRequest(filterText: "Hermes", pageIndex: 0, pageSize: 10)
        for token in ["NaN", "Infinity", "-Infinity"] {
            let output = Data("{\"success\":true,\"items\":[{\"id\":\"valid-1\",\"text\":\"First valid memory\"},{\"id\":\"invalid-confidence\",\"text\":\"Memory with invalid confidence\",\"confidence\":\(token)},{\"id\":\"valid-2\",\"text\":\"Second valid memory\"}],\"total\":3,\"limit\":10,\"offset\":0}".utf8)

            let page = try HermesHindsightMemoryClient.decodeListOutput(output, request: request)

            XCTAssertEqual(page.entries.map(\.id), ["valid-1", "invalid-confidence", "valid-2"], token)
            XCTAssertNil(page.entries[1].confidence, token)
            XCTAssertEqual(page.totalCount, 3, token)
            XCTAssertFalse(page.hasMore, token)
        }
    }

    func testNonFiniteStructuralFieldsRemainMalformed() {
        let request = MemoryListRequest(filterText: "Hermes", pageIndex: 0, pageSize: 10)
        let output = Data(#"{"success":true,"items":[{"id":"valid-1","text":"First valid memory"}],"total":NaN,"limit":10,"offset":0}"#.utf8)

        XCTAssertThrowsError(try HermesHindsightMemoryClient.decodeListOutput(output, request: request))
    }

    @MainActor
    func testClientCancellationReachesHelperExecutor() async {
        let probe = CancellableMemoryHelperProbe()
        let client = HermesHindsightMemoryClient(helperExecutor: { invocation in
            try await probe.execute(invocation)
        })
        let request = MemoryListRequest(filterText: "", pageIndex: 0, pageSize: 10)
        let context = HindsightMemoryContext.active(
            rootHermesHome: "/private/tmp/hermes-memory-context",
            profile: "alpha",
            providerBank: "bank-alpha"
        )

        let task = Task {
            try await client.listMemories(request: request, context: context)
        }
        await probe.waitUntilStarted()
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("A cancelled helper request must throw CancellationError.")
        } catch is CancellationError {
            // Expected.
        } catch {
            XCTFail("Expected CancellationError, got \(error)")
        }
        let observedCancellation = await probe.observedCancellation
        XCTAssertTrue(observedCancellation)
    }

    func testDeleteDecodingToleratesDiagnosticsAroundFramedHelperPayload() throws {
        let payload = String(decoding: HindsightMemoryFixtures.deleteJSON(id: "h-1"), as: UTF8.self)
        let output = Data("""
        Hindsight diagnostic before payload
        HERMES_MEMORY_JSON:\(payload)
        Hindsight diagnostic after payload
        """.utf8)

        let result = try HermesHindsightMemoryClient.decodeDeleteOutput(output, requestedID: "h-1")

        XCTAssertTrue(result.deleted)
        XCTAssertEqual(result.entryID, "h-1")
    }

    func testDeleteJSONDecodingAndSecretRedaction() throws {
        let result = try HermesHindsightMemoryClient.decodeDeleteOutput(HindsightMemoryFixtures.deleteJSON(id: "h-1"), requestedID: "h-1")
        XCTAssertTrue(result.deleted)
        XCTAssertEqual(result.entryID, "h-1")

        XCTAssertThrowsError(try HermesHindsightMemoryClient.decodeDeleteOutput(HindsightMemoryFixtures.failedDeleteJSON(), requestedID: "h-1")) { error in
            let text = error.localizedDescription
            XCTAssertFalse(text.contains("Authorization"))
            XCTAssertFalse(text.contains("api_key="))
            XCTAssertFalse(text.contains("Traceback"))
        }
    }
}

private actor CancellableMemoryHelperProbe {
    private(set) var observedCancellation = false
    private var didStart = false
    private var startWaiters: [CheckedContinuation<Void, Never>] = []

    func waitUntilStarted() async {
        if didStart { return }
        await withCheckedContinuation { continuation in
            startWaiters.append(continuation)
        }
    }

    func execute(_ invocation: HermesHindsightMemoryHelperInvocation) async throws -> String {
        _ = invocation
        didStart = true
        let waiters = startWaiters
        startWaiters.removeAll()
        waiters.forEach { $0.resume() }

        do {
            while true {
                try Task.checkCancellation()
                await Task.yield()
            }
        } catch is CancellationError {
            observedCancellation = true
            throw CancellationError()
        }
    }
}
