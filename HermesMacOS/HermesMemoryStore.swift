//
//  HermesMemoryStore.swift
//  HermesMacOS
//

import Foundation
import Observation

@MainActor
@Observable
final class HermesMemoryStore {
    typealias FilterDebounce = @Sendable () async throws -> Void

    var filterText = ""
    var pageIndex = 0
    var pageSize: Int
    var totalCount: Int?
    var entries: [MemoryEntry] = []
    var isLoading = false
    var deleteInFlightID: String?
    var statusMessage: String?
    var errorMessage: String?
    var hasMore = false
    private(set) var context: HindsightMemoryContext
    private(set) var providerBank: String?

    @ObservationIgnored private let provider: HindsightMemoryProviding
    @ObservationIgnored private let filterDebounce: FilterDebounce
    @ObservationIgnored private var activeRequestID = UUID()
    @ObservationIgnored private var activeLoadTask: Task<MemoryPage, Error>?

    init(
        provider: HindsightMemoryProviding = HermesHindsightMemoryClient(),
        context: HindsightMemoryContext = .active(
            rootHermesHome: HermesRuntimePaths.defaultHermesHome,
            profile: "default"
        ),
        pageSize: Int = MemoryTabState.defaultPageSize,
        filterDebounce: @escaping FilterDebounce = {
            try await Task.sleep(for: .milliseconds(300))
        }
    ) {
        self.provider = provider
        self.context = context
        self.providerBank = context.providerBank
        self.pageSize = MemoryTabState.boundedPageSize(pageSize)
        self.filterDebounce = filterDebounce
    }

    var canGoPrevious: Bool { pageIndex > 0 && !isLoading }
    var canGoNext: Bool { hasMore && !isLoading }

    var rangeText: String {
        guard !entries.isEmpty else {
            if filterText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return String(localized: "No memories shown")
            }
            return String(localized: "No matching memories")
        }
        let start = pageIndex * pageSize + 1
        let end = start + entries.count - 1
        if let totalCount {
            return String(localized: "\(start)–\(end) of \(totalCount)")
        }
        return String(localized: "\(start)–\(end) shown")
    }

    var emptyStateTitle: String {
        if errorMessage != nil { return String(localized: "Memory provider unavailable") }
        if filterText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return String(localized: "No memories found")
        }
        return String(localized: "No memories match this filter")
    }

    func refresh() {
        Task { await load() }
    }

    func activate(context newContext: HindsightMemoryContext) async {
        guard newContext != context else {
            if entries.isEmpty, !isLoading { await load() }
            return
        }
        activeLoadTask?.cancel()
        activeRequestID = UUID()
        context = newContext
        providerBank = newContext.providerBank
        pageIndex = 0
        totalCount = nil
        entries = []
        hasMore = false
        statusMessage = nil
        errorMessage = nil
        isLoading = false
        await load()
    }

    func load() async {
        let request = MemoryListRequest(filterText: filterText, pageIndex: pageIndex, pageSize: pageSize)
        let requestContext = context
        let requestID = UUID()

        activeLoadTask?.cancel()
        activeRequestID = requestID
        isLoading = true
        errorMessage = nil
        statusMessage = String(localized: "Loading memories…")

        let loadTask = Task { try await provider.listMemories(request: request, context: requestContext) }
        activeLoadTask = loadTask

        do {
            let page = try await withTaskCancellationHandler {
                try await loadTask.value
            } onCancel: {
                loadTask.cancel()
            }
            guard activeRequestID == requestID, context == requestContext else { return }
            entries = page.entries
            totalCount = page.totalCount
            hasMore = page.hasMore
            pageIndex = page.pageIndex
            pageSize = page.pageSize
            providerBank = page.providerBank ?? requestContext.providerBank
            if page.entries.isEmpty {
                statusMessage = nil
            } else if page.entries.count == 1 {
                statusMessage = String(localized: "Loaded one memory.")
            } else {
                statusMessage = String(localized: "Loaded \(page.entries.count) memories.")
            }
            errorMessage = nil
            isLoading = false
            activeLoadTask = nil
        } catch is CancellationError {
            guard activeRequestID == requestID else { return }
            isLoading = false
            statusMessage = nil
            activeLoadTask = nil
        } catch {
            guard activeRequestID == requestID, context == requestContext else { return }
            entries = []
            totalCount = 0
            hasMore = false
            statusMessage = nil
            errorMessage = HermesHindsightMemoryClientError.sanitized(error.localizedDescription)
            isLoading = false
            activeLoadTask = nil
        }
    }

    func applyFilterChange(_ value: String) async {
        filterText = value
        pageIndex = 0
        do {
            try await filterDebounce()
            try Task.checkCancellation()
            guard filterText == value else { return }
            await load()
        } catch is CancellationError {
            return
        } catch {
            guard filterText == value else { return }
            errorMessage = HermesHindsightMemoryClientError.sanitized(error.localizedDescription)
        }
    }

    func applyFilterChange() {
        let value = filterText
        Task { await applyFilterChange(value) }
    }

    func previousPage() async {
        guard pageIndex > 0 else { return }
        pageIndex -= 1
        await load()
    }

    func nextPage() async {
        guard hasMore else { return }
        pageIndex += 1
        await load()
    }

    func delete(_ entry: MemoryEntry) async {
        await deleteMemory(id: entry.id)
    }

    func deleteMemory(id: String) async {
        guard deleteInFlightID == nil else { return }
        deleteInFlightID = id
        errorMessage = nil
        statusMessage = String(localized: "Deleting memory…")
        do {
            let result = try await provider.deleteMemory(id: id, context: context)
            guard result.deleted else {
                throw HermesHindsightMemoryClientError.deletionFailed(result.message ?? "provider skipped deletion")
            }
            if entries.count == 1, pageIndex > 0 { pageIndex -= 1 }
            deleteInFlightID = nil
            statusMessage = String(localized: "Memory deleted.")
            await load()
        } catch is CancellationError {
            deleteInFlightID = nil
            statusMessage = nil
        } catch {
            deleteInFlightID = nil
            statusMessage = nil
            errorMessage = HermesHindsightMemoryClientError.sanitized(error.localizedDescription)
        }
    }
}
