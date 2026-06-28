import XCTest
@testable import HermesMacOS

@MainActor
final class MemoryTabWorkflowTests: XCTestCase {
    func testFirstPageEmptyAndProviderErrorStates() async {
        let provider = FixtureMemoryProvider(entries: HindsightMemoryFixtures.entries(count: 12))
        let store = HermesMemoryStore(provider: provider, pageSize: 5)
        await store.load()
        XCTAssertEqual(store.entries.map(\.id), ["mem-1", "mem-2", "mem-3", "mem-4", "mem-5"])
        XCTAssertEqual(store.rangeText, "1–5 of 12")
        XCTAssertTrue(store.canGoNext)
        XCTAssertNil(store.errorMessage)

        let empty = HermesMemoryStore(provider: FixtureMemoryProvider(entries: []), pageSize: 5)
        await empty.load()
        XCTAssertEqual(empty.emptyStateTitle, "No memories found")
        XCTAssertEqual(empty.rangeText, "No memories shown")

        let failing = HermesMemoryStore(provider: FixtureMemoryProvider(error: HermesHindsightMemoryClientError.providerUnavailable(HindsightMemoryFixtures.providerError)), pageSize: 5)
        await failing.load()
        XCTAssertEqual(failing.emptyStateTitle, "Memory provider unavailable")
        XCTAssertFalse(failing.errorMessage?.contains("sk-AAAAAAAAAAAAAAAAAAAAAAAA") ?? true)
        XCTAssertFalse(failing.errorMessage?.contains("Traceback") ?? true)
    }

    func testPaginationRangePreviousNextAndClamping() async {
        let store = HermesMemoryStore(provider: FixtureMemoryProvider(entries: HindsightMemoryFixtures.entries(count: 11)), pageSize: 5)
        await store.load()
        XCTAssertTrue(store.canGoNext)
        await store.nextPage()
        XCTAssertEqual(store.entries.first?.id, "mem-6")
        XCTAssertEqual(store.rangeText, "6–10 of 11")
        await store.nextPage()
        XCTAssertEqual(store.entries.map(\.id), ["mem-11"])
        XCTAssertFalse(store.canGoNext)
        await store.previousPage()
        XCTAssertEqual(store.entries.first?.id, "mem-6")
    }

    func testFilterTextFilteredEmptyAndPageReset() async {
        let store = HermesMemoryStore(provider: FixtureMemoryProvider(entries: HindsightMemoryFixtures.entries(count: 8)), pageSize: 3)
        await store.load()
        await store.nextPage()
        XCTAssertEqual(store.pageIndex, 1)
        store.filterText = "row 8"
        store.applyFilterChange()
        try? await Task.sleep(nanoseconds: 80_000_000)
        XCTAssertEqual(store.pageIndex, 0)
        XCTAssertEqual(store.entries.map(\.id), ["mem-8"])
        store.filterText = "not-present"
        store.applyFilterChange()
        try? await Task.sleep(nanoseconds: 80_000_000)
        XCTAssertTrue(store.entries.isEmpty)
        XCTAssertEqual(store.emptyStateTitle, "No memories match this filter")
    }

    func testSuccessfulDeleteFailedDeleteAndPaginationAfterDelete() async {
        let provider = FixtureMemoryProvider(entries: HindsightMemoryFixtures.entries(count: 6))
        let store = HermesMemoryStore(provider: provider, pageSize: 5)
        await store.load()
        await store.nextPage()
        XCTAssertEqual(store.entries.map(\.id), ["mem-6"])
        await store.deleteMemory(id: "mem-6")
        XCTAssertEqual(store.pageIndex, 0)
        XCTAssertFalse(store.entries.contains { $0.id == "mem-6" })
        XCTAssertEqual(store.totalCount, 5)

        provider.deleteError = HermesHindsightMemoryClientError.deletionFailed(HindsightMemoryFixtures.providerError)
        await store.deleteMemory(id: "mem-1")
        XCTAssertTrue(store.entries.contains { $0.id == "mem-1" })
        XCTAssertFalse(store.errorMessage?.contains("sk-AAAAAAAAAAAAAAAAAAAAAAAA") ?? true)
    }
}

@MainActor
private final class FixtureMemoryProvider: HindsightMemoryProviding {
    var entries: [MemoryEntry]
    var error: Error?
    var deleteError: Error?

    init(entries: [MemoryEntry] = [], error: Error? = nil) {
        self.entries = entries
        self.error = error
    }

    func listMemories(request: MemoryListRequest) async throws -> MemoryPage {
        if let error { throw error }
        let filtered: [MemoryEntry]
        if request.filterText.isEmpty {
            filtered = entries
        } else {
            let needle = request.filterText.lowercased()
            filtered = entries.filter { entry in
                entry.content.lowercased().contains(needle) || entry.metadataSummary.lowercased().contains(needle)
            }
        }
        let start = min(request.offset, filtered.count)
        let end = min(start + request.pageSize, filtered.count)
        let pageEntries = Array(filtered[start..<end])
        return MemoryPage(entries: pageEntries, pageIndex: request.pageIndex, pageSize: request.pageSize, totalCount: filtered.count, hasMore: end < filtered.count)
    }

    func deleteMemory(id: String) async throws -> MemoryDeletionResult {
        if let deleteError { throw deleteError }
        entries.removeAll { $0.id == id }
        return MemoryDeletionResult(entryID: id, deleted: true, message: nil)
    }
}
