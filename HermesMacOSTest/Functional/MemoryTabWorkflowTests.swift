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
        let debouncer = ManualMemoryFilterDebouncer()
        let provider = FixtureMemoryProvider(entries: HindsightMemoryFixtures.entries(count: 8))
        let store = HermesMemoryStore(
            provider: provider,
            pageSize: 3,
            filterDebounce: { try await debouncer.wait() }
        )
        await store.load()
        await store.nextPage()
        XCTAssertEqual(store.pageIndex, 1)

        store.filterText = "row 7"
        let superseded = Task { await store.applyFilterChange("row 7") }
        await debouncer.waitForCalls(1)
        store.filterText = "row 8"
        superseded.cancel()
        let current = Task { await store.applyFilterChange("row 8") }
        await debouncer.waitForCalls(2)
        await debouncer.resumeLatest()
        await superseded.value
        await current.value

        XCTAssertEqual(store.pageIndex, 0)
        XCTAssertEqual(store.entries.map(\.id), ["mem-8"])
        XCTAssertFalse(provider.listRequests.contains { $0.filterText == "row 7" })
        XCTAssertEqual(provider.listRequests.last?.filterText, "row 8")

        store.filterText = "not-present"
        let emptyFilter = Task { await store.applyFilterChange("not-present") }
        await debouncer.waitForCalls(3)
        await debouncer.resumeLatest()
        await emptyFilter.value
        XCTAssertTrue(store.entries.isEmpty)
        XCTAssertEqual(store.emptyStateTitle, "No memories match this filter")
    }

    func testContextChangeClearsOldProfileAndReloadsActiveProfile() async {
        let provider = MultiProfileMemoryProvider()
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
        let store = HermesMemoryStore(provider: provider, context: alpha, pageSize: 5)

        await store.load()
        XCTAssertEqual(store.entries.map(\.id), ["alpha-memory"])
        XCTAssertEqual(store.providerBank, "bank-alpha")

        await store.activate(context: beta)

        XCTAssertEqual(store.context, beta)
        XCTAssertEqual(store.pageIndex, 0)
        XCTAssertEqual(store.entries.map(\.id), ["beta-memory"])
        XCTAssertEqual(store.providerBank, "bank-beta")
        XCTAssertEqual(provider.contexts.map(\.profile), ["alpha", "beta"])
    }

    func testSupersededListCancelsProviderAndStaleResultCannotWin() async {
        let provider = SupersedingMemoryProvider()
        let store = HermesMemoryStore(provider: provider, pageSize: 5)

        let superseded = Task { await store.load() }
        await provider.waitUntilFirstRequestStarts()
        let current = Task { await store.load() }
        await current.value
        await superseded.value

        XCTAssertTrue(provider.observedCancellation)
        XCTAssertEqual(store.entries.map(\.id), ["fresh-memory"])
        XCTAssertFalse(store.isLoading)
        XCTAssertNil(store.errorMessage)
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
    var listRequests: [MemoryListRequest] = []
    var contexts: [HindsightMemoryContext] = []

    init(entries: [MemoryEntry] = [], error: Error? = nil) {
        self.entries = entries
        self.error = error
    }

    func listMemories(request: MemoryListRequest, context: HindsightMemoryContext) async throws -> MemoryPage {
        if let error { throw error }
        listRequests.append(request)
        contexts.append(context)
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
        return MemoryPage(
            entries: pageEntries,
            pageIndex: request.pageIndex,
            pageSize: request.pageSize,
            offset: request.offset,
            totalCount: filtered.count,
            hasMore: end < filtered.count,
            providerBank: context.providerBank,
            profile: context.profile
        )
    }

    func deleteMemory(id: String, context: HindsightMemoryContext) async throws -> MemoryDeletionResult {
        _ = context
        if let deleteError { throw deleteError }
        entries.removeAll { $0.id == id }
        return MemoryDeletionResult(entryID: id, deleted: true, message: nil)
    }
}

@MainActor
private final class MultiProfileMemoryProvider: HindsightMemoryProviding {
    var contexts: [HindsightMemoryContext] = []

    func listMemories(request: MemoryListRequest, context: HindsightMemoryContext) async throws -> MemoryPage {
        contexts.append(context)
        let entry = MemoryEntry(
            id: "\(context.profile)-memory",
            content: "Memory for \(context.profile)",
            kind: "world",
            source: "fixture",
            profile: context.providerBank,
            createdAt: nil,
            updatedAt: nil,
            confidence: nil,
            metadata: [:]
        )
        return MemoryPage(
            entries: [entry],
            pageIndex: request.pageIndex,
            pageSize: request.pageSize,
            offset: request.offset,
            totalCount: 1,
            hasMore: false,
            providerBank: context.providerBank,
            profile: context.profile
        )
    }

    func deleteMemory(id: String, context: HindsightMemoryContext) async throws -> MemoryDeletionResult {
        MemoryDeletionResult(entryID: id, deleted: true, message: context.profile)
    }
}

@MainActor
private final class SupersedingMemoryProvider: HindsightMemoryProviding {
    private(set) var observedCancellation = false
    private var requestCount = 0
    private var firstRequestStarted = false
    private var startWaiters: [CheckedContinuation<Void, Never>] = []

    func waitUntilFirstRequestStarts() async {
        if firstRequestStarted { return }
        await withCheckedContinuation { continuation in
            startWaiters.append(continuation)
        }
    }

    func listMemories(request: MemoryListRequest, context: HindsightMemoryContext) async throws -> MemoryPage {
        requestCount += 1
        if requestCount == 1 {
            firstRequestStarted = true
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

        let entry = MemoryEntry(
            id: "fresh-memory",
            content: "Fresh provider result",
            kind: "world",
            source: "fixture",
            profile: context.profile,
            createdAt: nil,
            updatedAt: nil,
            confidence: nil,
            metadata: [:]
        )
        return MemoryPage(
            entries: [entry],
            pageIndex: request.pageIndex,
            pageSize: request.pageSize,
            offset: request.offset,
            totalCount: 1,
            hasMore: false,
            providerBank: context.providerBank,
            profile: context.profile
        )
    }

    func deleteMemory(id: String, context: HindsightMemoryContext) async throws -> MemoryDeletionResult {
        MemoryDeletionResult(entryID: id, deleted: true, message: context.profile)
    }
}

private actor ManualMemoryFilterDebouncer {
    private var callCount = 0
    private var pending: [(id: UUID, continuation: CheckedContinuation<Void, Error>)] = []
    private var callWaiters: [(target: Int, continuation: CheckedContinuation<Void, Never>)] = []

    func wait() async throws {
        try Task.checkCancellation()
        let id = UUID()
        callCount += 1
        resumeSatisfiedCallWaiters()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                pending.append((id, continuation))
            }
        } onCancel: {
            Task { await self.cancel(id: id) }
        }
    }

    func waitForCalls(_ target: Int) async {
        if callCount >= target { return }
        await withCheckedContinuation { continuation in
            callWaiters.append((target, continuation))
        }
    }

    func resumeLatest() {
        guard let waiter = pending.popLast() else { return }
        waiter.continuation.resume()
    }

    private func cancel(id: UUID) {
        guard let index = pending.firstIndex(where: { $0.id == id }) else { return }
        let waiter = pending.remove(at: index)
        waiter.continuation.resume(throwing: CancellationError())
    }

    private func resumeSatisfiedCallWaiters() {
        let satisfied = callWaiters.filter { callCount >= $0.target }
        callWaiters.removeAll { callCount >= $0.target }
        satisfied.forEach { $0.continuation.resume() }
    }
}
