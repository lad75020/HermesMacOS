//
//  HermesMemoryStore.swift
//  HermesMacOS
//

import Foundation
import Observation

@MainActor
@Observable
final class HermesMemoryStore {
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

    @ObservationIgnored private let provider: HindsightMemoryProviding
    @ObservationIgnored private var activeRequestID = UUID()

    init(provider: HindsightMemoryProviding = HermesHindsightMemoryClient(), pageSize: Int = MemoryTabState.defaultPageSize) {
        self.provider = provider
        self.pageSize = MemoryTabState.boundedPageSize(pageSize)
    }

    var canGoPrevious: Bool { pageIndex > 0 && !isLoading }
    var canGoNext: Bool { hasMore && !isLoading }

    var rangeText: String {
        guard !entries.isEmpty else {
            if filterText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "No memories shown" }
            return "No matching memories"
        }
        let start = pageIndex * pageSize + 1
        let end = start + entries.count - 1
        if let totalCount {
            return "\(start)–\(end) of \(totalCount)"
        }
        return "\(start)–\(end) shown"
    }

    var emptyStateTitle: String {
        if errorMessage != nil { return "Memory provider unavailable" }
        if filterText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "No memories found" }
        return "No memories match this filter"
    }

    func refresh() {
        Task { await load() }
    }

    func load() async {
        let request = MemoryListRequest(filterText: filterText, pageIndex: pageIndex, pageSize: pageSize)
        let requestID = UUID()
        activeRequestID = requestID
        isLoading = true
        errorMessage = nil
        statusMessage = "Loading memories…"
        do {
            let page = try await provider.listMemories(request: request)
            guard activeRequestID == requestID else { return }
            entries = page.entries
            totalCount = page.totalCount
            hasMore = page.hasMore
            pageIndex = page.pageIndex
            statusMessage = page.entries.isEmpty ? nil : "Loaded \(page.entries.count) memor\(page.entries.count == 1 ? "y" : "ies")."
            errorMessage = nil
            isLoading = false
        } catch {
            guard activeRequestID == requestID else { return }
            entries = []
            totalCount = 0
            hasMore = false
            statusMessage = nil
            errorMessage = HermesHindsightMemoryClientError.sanitized(error.localizedDescription)
            isLoading = false
        }
    }

    func applyFilterChange() {
        pageIndex = 0
        refresh()
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
        statusMessage = "Deleting memory…"
        do {
            let result = try await provider.deleteMemory(id: id)
            guard result.deleted else {
                throw HermesHindsightMemoryClientError.deletionFailed(result.message ?? "provider skipped deletion")
            }
            if entries.count == 1, pageIndex > 0 { pageIndex -= 1 }
            deleteInFlightID = nil
            statusMessage = "Memory deleted."
            await load()
        } catch {
            deleteInFlightID = nil
            statusMessage = nil
            errorMessage = HermesHindsightMemoryClientError.sanitized(error.localizedDescription)
        }
    }
}
