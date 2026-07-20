import XCTest
@testable import HermesMacOS

final class HindsightMemoryClientTests: XCTestCase {
    func testListJSONDecodingAcceptsOptionalMetadata() throws {
        let request = MemoryListRequest(filterText: "", pageIndex: 0, pageSize: 10)
        let page = try HermesHindsightMemoryClient.decodeListOutput(HindsightMemoryFixtures.listJSON(), request: request)
        XCTAssertEqual(page.entries.count, 2)
        XCTAssertEqual(page.entries[0].id, "h-1")
        XCTAssertEqual(page.entries[0].kind, "experience")
        XCTAssertEqual(page.entries[0].metadata["bank"], "default")
        XCTAssertEqual(page.totalCount, 2)
        XCTAssertFalse(page.hasMore)
    }

    func testMalformedRowsAreRejected() {
        let request = MemoryListRequest(filterText: "", pageIndex: 0, pageSize: 10)
        XCTAssertThrowsError(try HermesHindsightMemoryClient.decodeListOutput(HindsightMemoryFixtures.malformedListJSON(), request: request))
    }

    func testMalformedResultDoesNotHideValidResults() throws {
        let request = MemoryListRequest(filterText: "Hermes", pageIndex: 0, pageSize: 10)
        let output = Data(#"{"success":true,"total_count":3,"results":[{"id":"valid-1","content":"First valid memory"},{"id":"malformed-missing-content"},{"id":"valid-2","content":"Second valid memory"}]}"#.utf8)

        let page = try HermesHindsightMemoryClient.decodeListOutput(output, request: request)

        XCTAssertEqual(page.entries.map(\.id), ["valid-1", "valid-2"])
        XCTAssertEqual(page.totalCount, 3)
        XCTAssertFalse(page.hasMore)
    }

    func testNonFiniteConfidenceDoesNotHideValidResults() throws {
        let request = MemoryListRequest(filterText: "Hermes", pageIndex: 0, pageSize: 10)
        for token in ["NaN", "Infinity", "-Infinity"] {
            let output = Data("{\"success\":true,\"total_count\":3,\"results\":[{\"id\":\"valid-1\",\"content\":\"First valid memory\"},{\"id\":\"invalid-confidence\",\"content\":\"Memory with invalid confidence\",\"confidence\":\(token)},{\"id\":\"valid-2\",\"content\":\"Second valid memory\"}]}".utf8)

            let page = try HermesHindsightMemoryClient.decodeListOutput(output, request: request)

            XCTAssertEqual(page.entries.map(\.id), ["valid-1", "invalid-confidence", "valid-2"], token)
            XCTAssertNil(page.entries[1].confidence, token)
            XCTAssertEqual(page.totalCount, 3, token)
            XCTAssertFalse(page.hasMore, token)
        }
    }

    func testNonFiniteStructuralFieldsRemainMalformed() {
        let request = MemoryListRequest(filterText: "Hermes", pageIndex: 0, pageSize: 10)
        let output = Data(#"{"success":true,"total_count":NaN,"results":[{"id":"valid-1","content":"First valid memory"}]}"#.utf8)

        XCTAssertThrowsError(try HermesHindsightMemoryClient.decodeListOutput(output, request: request))
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
