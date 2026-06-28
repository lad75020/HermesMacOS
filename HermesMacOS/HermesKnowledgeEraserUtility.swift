//
//  HermesKnowledgeEraserUtility.swift
//  HermesMacOS
//

import Foundation
import Observation
import SwiftUI

enum HermesKnowledgeEraserItemKind: String, Codable, Equatable {
    case memoryEntry
    case localMemoryEntry
    case hindsightMemoryEntry
    case userProfileBlock
    case skillBlock

    var label: String {
        switch self {
        case .memoryEntry: "Memory"
        case .localMemoryEntry: "Local memory"
        case .hindsightMemoryEntry: "Hindsight memory"
        case .userProfileBlock: "User profile"
        case .skillBlock: "Skill"
        }
    }
}

struct HermesKnowledgeEraserItem: Codable, Identifiable, Equatable {
    let id: String
    let kind: HermesKnowledgeEraserItemKind
    let title: String
    let path: String
    let location: String
    let preview: String
    let content: String
    let confidence: Double
}

struct HermesKnowledgeEraserScanResult: Codable, Equatable {
    let workspacePath: String
    let resolvedWorkspacePath: String
    let topic: String
    let scannedAt: Date
    let items: [HermesKnowledgeEraserItem]
}

struct HermesKnowledgeEraserEraseResult: Codable, Equatable {
    let workspacePath: String
    let resolvedWorkspacePath: String
    let topic: String
    let erasedAt: Date
    let archivePath: String
    let erasedItemIDs: [String]
    let skippedItemIDs: [String]
    let remainingItems: [HermesKnowledgeEraserItem]
}

private enum HermesKnowledgeEraserError: LocalizedError {
    case invalidWorkspace(String)
    case emptyTopic
    case noSelectedItems
    case localMemoryProvider(String)
    case hindsightProvider(String)

    var errorDescription: String? {
        switch self {
        case .invalidWorkspace(let path): "The Hermes workspace path '\(path)' is invalid."
        case .emptyTopic: "Enter a topic description before scanning."
        case .noSelectedItems: "Select at least one item to erase."
        case .localMemoryProvider(let message): "local_memory provider operation failed: \(message)"
        case .hindsightProvider(let message): "Hindsight provider operation failed: \(message)"
        }
    }
}

@MainActor
@Observable
final class HermesKnowledgeEraserStore {
    var topic = ""
    var items: [HermesKnowledgeEraserItem] = []
    var selectedItemIDs: Set<String> = []
    var operationOutput = ""
    var isBusy = false
    var resolvedWorkspacePath = ""
    var lastScanDate: Date?

    private let workspacePath = HermesRuntimePaths.defaultHermesHome
    private let registry = HermesKnowledgeEraserRegistry()

    var selectedCount: Int { selectedItemIDs.count }
    var workspaceSummary: String { resolvedWorkspacePath.isEmpty ? workspacePath : resolvedWorkspacePath }

    func scan() {
        let requestedTopic = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !requestedTopic.isEmpty else {
            operationOutput = HermesKnowledgeEraserError.emptyTopic.localizedDescription
            return
        }
        isBusy = true
        operationOutput = "Scanning local Hermes knowledge for \"\(requestedTopic)\"…"
        Task {
            do {
                try await HermesFilesystemAccessPolicy.requireAccess(to: workspacePath, operation: "Scan Hermes knowledge")
                let result = try await Task.detached(priority: .userInitiated) { [registry, workspacePath] in
                    try registry.scan(workspacePath: workspacePath, topic: requestedTopic)
                }.value
                await MainActor.run {
                    self.items = result.items
                    self.selectedItemIDs = Set(result.items.map(\.id))
                    self.resolvedWorkspacePath = result.resolvedWorkspacePath
                    self.lastScanDate = result.scannedAt
                    self.operationOutput = result.items.isEmpty
                        ? "No candidates found for \"\(result.topic)\"."
                        : "Found \(result.items.count) candidate item\(result.items.count == 1 ? "" : "s") for \"\(result.topic)\". Review checked items before erasing."
                    self.isBusy = false
                }
            } catch {
                await MainActor.run {
                    self.operationOutput = error.localizedDescription
                    self.isBusy = false
                }
            }
        }
    }

    func eraseSelected() {
        let requestedTopic = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        let selectedIDs = Array(selectedItemIDs)
        guard !selectedIDs.isEmpty else {
            operationOutput = HermesKnowledgeEraserError.noSelectedItems.localizedDescription
            return
        }
        isBusy = true
        operationOutput = "Archiving and erasing \(selectedIDs.count) selected item\(selectedIDs.count == 1 ? "" : "s")…"
        Task {
            do {
                try await HermesFilesystemAccessPolicy.requireAccess(to: workspacePath, operation: "Erase Hermes knowledge")
                let result = try await Task.detached(priority: .userInitiated) { [registry, workspacePath] in
                    try registry.erase(workspacePath: workspacePath, topic: requestedTopic, selectedItemIDs: selectedIDs)
                }.value
                await MainActor.run {
                    self.items = result.remainingItems
                    self.selectedItemIDs = []
                    self.resolvedWorkspacePath = result.resolvedWorkspacePath
                    self.lastScanDate = result.erasedAt
                    let skipped = result.skippedItemIDs.isEmpty ? "" : "\nSkipped \(result.skippedItemIDs.count) items that no longer matched."
                    self.operationOutput = "Archived \(result.erasedItemIDs.count) erased item\(result.erasedItemIDs.count == 1 ? "" : "s") to \(result.archivePath)" + skipped
                    self.isBusy = false
                }
            } catch {
                await MainActor.run {
                    self.operationOutput = error.localizedDescription
                    self.isBusy = false
                }
            }
        }
    }

    func setSelection(_ id: String, isSelected: Bool) {
        if isSelected { selectedItemIDs.insert(id) } else { selectedItemIDs.remove(id) }
    }
}

struct HermesKnowledgeEraserUtilityPanel: View {
    @Bindable var store: HermesKnowledgeEraserStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Two-step cleanup for memories, user profile blocks, and skill files. Scan first, review every candidate, then archive and erase only checked items.")
                .font(.subheadline)
                .foregroundStyle(Color.hermesSecondaryText)

            VStack(alignment: .leading, spacing: 8) {
                Text("Topic to erase")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.hermesSecondaryText)
                TextField("Describe the topic, project, person, or workflow to forget", text: $store.topic, axis: .vertical)
                    .lineLimit(2...4)
                    .textFieldStyle(.roundedBorder)
                    .disabled(store.isBusy)
            }

            HStack(spacing: 12) {
                Button {
                    store.scan()
                } label: {
                    Label("Find Items", systemImage: "magnifyingglass")
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.isBusy || store.topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button(role: .destructive) {
                    store.eraseSelected()
                } label: {
                    Label("Erase & Archive", systemImage: "archivebox.fill")
                }
                .buttonStyle(.bordered)
                .disabled(store.isBusy || store.selectedCount == 0)

                if store.isBusy {
                    ProgressView().controlSize(.small)
                }
            }

            Text("Workspace: \(store.workspaceSummary)")
                .font(.caption.monospaced())
                .foregroundStyle(Color.hermesSecondaryText)
                .textSelection(.enabled)

            if !store.operationOutput.isEmpty {
                Text(store.operationOutput)
                    .font(.caption.monospaced())
                    .foregroundStyle(Color.hermesSecondaryText)
                    .textSelection(.enabled)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .hermesGlassPanel(tint: Color.white.opacity(0.04), cornerRadius: 14)
            }

            if !store.items.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Review candidates")
                            .font(.headline)
                        Spacer()
                        Text("\(store.selectedCount)/\(store.items.count) selected")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.hermesSecondaryText)
                    }

                    LazyVStack(spacing: 10) {
                        ForEach(store.items) { item in
                            HermesKnowledgeEraserItemRow(
                                item: item,
                                isSelected: Binding(
                                    get: { store.selectedItemIDs.contains(item.id) },
                                    set: { store.setSelection(item.id, isSelected: $0) }
                                )
                            )
                        }
                    }
                }
            }
        }
        .padding(.top, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct HermesKnowledgeEraserItemRow: View {
    let item: HermesKnowledgeEraserItem
    @Binding var isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Toggle("", isOn: $isSelected)
                .labelsHidden()

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    Text(item.kind.label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.hermesActionBlue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.hermesActionBlue.opacity(0.12), in: Capsule())
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                    Spacer(minLength: 8)
                    Text("\(Int(item.confidence * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Color.hermesSecondaryText)
                }

                Text(item.preview)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("\(item.path) · \(item.location)")
                    .font(.caption2.monospaced())
                    .foregroundStyle(Color.hermesSecondaryText)
                    .lineLimit(2)
                    .textSelection(.enabled)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .hermesGlassPanel(tint: isSelected ? Color.hermesDestructive.opacity(0.08) : Color.white.opacity(0.03), cornerRadius: 16)
    }
}

private final class HermesKnowledgeEraserRegistry: @unchecked Sendable {
    private let fileManager = FileManager.default
    private let entryDelimiter = "\n§\n"

    func scan(workspacePath: String, topic: String) throws -> HermesKnowledgeEraserScanResult {
        let workspaceURL = try resolvedWorkspaceURL(from: workspacePath)
        let normalizedTopic = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedTopic.isEmpty else { throw HermesKnowledgeEraserError.emptyTopic }
        let matcher = HermesKnowledgeTopicMatcher(topic: normalizedTopic)
        var items: [HermesKnowledgeEraserItem] = []
        items.append(contentsOf: scanMemoryEntries(workspaceURL: workspaceURL, matcher: matcher))
        items.append(contentsOf: scanHindsightMemoryEntries(workspaceURL: workspaceURL, topic: normalizedTopic))
        items.append(contentsOf: scanUserProfile(workspaceURL: workspaceURL, matcher: matcher))
        items.append(contentsOf: scanSkills(workspaceURL: workspaceURL, matcher: matcher))
        items.sort { lhs, rhs in
            if lhs.confidence == rhs.confidence { return lhs.path < rhs.path }
            return lhs.confidence > rhs.confidence
        }
        return HermesKnowledgeEraserScanResult(
            workspacePath: workspacePath,
            resolvedWorkspacePath: workspaceURL.path,
            topic: normalizedTopic,
            scannedAt: Date(),
            items: items
        )
    }

    func erase(workspacePath: String, topic: String, selectedItemIDs: [String]) throws -> HermesKnowledgeEraserEraseResult {
        let workspaceURL = try resolvedWorkspaceURL(from: workspacePath)
        let selectedIDs = Set(selectedItemIDs)
        guard !selectedIDs.isEmpty else { throw HermesKnowledgeEraserError.noSelectedItems }
        let scanResult = try scan(workspacePath: workspacePath, topic: topic)
        let selectedItems = scanResult.items.filter { selectedIDs.contains($0.id) }
        guard !selectedItems.isEmpty else { throw HermesKnowledgeEraserError.noSelectedItems }

        let archiveURL = try archive(items: selectedItems, topic: scanResult.topic, workspaceURL: workspaceURL)
        var erasedIDs: [String] = []
        var skippedIDs: [String] = []

        let memoryIDs = selectedItems.filter { $0.kind == .memoryEntry }.map(\.id)
        if !memoryIDs.isEmpty {
            erasedIDs.append(contentsOf: try eraseMemoryEntries(workspaceURL: workspaceURL, selectedIDs: Set(memoryIDs)))
        }

        let localMemoryIDs = selectedItems.filter { $0.kind == .localMemoryEntry }.map(\.id)
        if !localMemoryIDs.isEmpty {
            let result = try eraseLocalMemoryEntries(workspaceURL: workspaceURL, selectedIDs: Set(localMemoryIDs))
            erasedIDs.append(contentsOf: result.erased)
            skippedIDs.append(contentsOf: result.skipped)
        }

        let hindsightMemoryIDs = selectedItems.filter { $0.kind == .hindsightMemoryEntry }.map(\.id)
        if !hindsightMemoryIDs.isEmpty {
            let result = try eraseHindsightMemoryEntries(workspaceURL: workspaceURL, selectedIDs: Set(hindsightMemoryIDs))
            erasedIDs.append(contentsOf: result.erased)
            skippedIDs.append(contentsOf: result.skipped)
        }

        let fileItems = selectedItems.filter { $0.kind == .userProfileBlock || $0.kind == .skillBlock }
        let groupedByPath = Dictionary(grouping: fileItems, by: \.path)
        for (path, items) in groupedByPath {
            let result = try eraseBlocks(path: path, items: items)
            erasedIDs.append(contentsOf: result.erased)
            skippedIDs.append(contentsOf: result.skipped)
        }

        let erasedSet = Set(erasedIDs)
        skippedIDs.append(contentsOf: selectedItems.map(\.id).filter { !erasedSet.contains($0) && !skippedIDs.contains($0) })

        return HermesKnowledgeEraserEraseResult(
            workspacePath: workspacePath,
            resolvedWorkspacePath: workspaceURL.path,
            topic: scanResult.topic,
            erasedAt: Date(),
            archivePath: archiveURL.path,
            erasedItemIDs: erasedIDs,
            skippedItemIDs: skippedIDs,
            remainingItems: try scan(workspacePath: workspacePath, topic: topic).items
        )
    }

    private func scanMemoryEntries(workspaceURL: URL, matcher: HermesKnowledgeTopicMatcher) -> [HermesKnowledgeEraserItem] {
        let url = memoryURL(for: workspaceURL)
        let content = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        let entries = content.components(separatedBy: entryDelimiter).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        return entries.enumerated().compactMap { index, entry in
            guard let confidence = matcher.confidence(in: entry) else { return nil }
            return HermesKnowledgeEraserItem(
                id: "memory:\(index)",
                kind: .memoryEntry,
                title: "Memory entry #\(index + 1)",
                path: url.path,
                location: "Entry \(index + 1)",
                preview: Self.preview(entry),
                content: entry,
                confidence: confidence
            )
        }
    }

    private func scanLocalMemoryEntries(workspaceURL: URL, topic: String) -> [HermesKnowledgeEraserItem] {
        guard let response = try? runLocalMemoryScan(workspaceURL: workspaceURL, topic: topic), response.success else { return [] }
        return response.results.map { record in
            let sources = [record.mongo_match == true ? "MongoDB" : nil, record.chroma_match == true ? "ChromaDB" : nil]
                .compactMap { $0 }
                .joined(separator: " + ")
            let scope = record.scopeSummary
            let location = [sources.isEmpty ? nil : sources, scope.isEmpty ? nil : scope]
                .compactMap { $0 }
                .joined(separator: " · ")
            return HermesKnowledgeEraserItem(
                id: Self.localMemoryItemID(for: record.memory_id),
                kind: .localMemoryEntry,
                title: "Local memory \(record.memory_id)",
                path: "local_memory://durable_memories/\(record.memory_id)",
                location: location.isEmpty ? "durable_memories + ChromaDB" : location,
                preview: Self.preview(record.content),
                content: record.content,
                confidence: record.confidence ?? 0.8
            )
        }
    }

    private func scanHindsightMemoryEntries(workspaceURL: URL, topic: String) -> [HermesKnowledgeEraserItem] {
        guard let response = try? runHindsightScan(workspaceURL: workspaceURL, topic: topic), response.success else { return [] }
        return response.results.map { record in
            let type = record.fact_type.trimmingCharacters(in: .whitespacesAndNewlines)
            let context = record.context?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let document = record.document_id?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let location = [type.isEmpty ? nil : type, context.isEmpty ? nil : context, document.isEmpty ? nil : document]
                .compactMap { $0 }
                .joined(separator: " · ")
            return HermesKnowledgeEraserItem(
                id: Self.hindsightMemoryItemID(for: record.memory_id),
                kind: .hindsightMemoryEntry,
                title: "Hindsight memory \(record.memory_id)",
                path: "hindsight://\(type.isEmpty ? "memory" : type)/\(record.memory_id)",
                location: location.isEmpty ? "Hindsight memory provider" : location,
                preview: Self.preview(record.text),
                content: record.text,
                confidence: record.confidence ?? 0.82
            )
        }
    }

    private func scanUserProfile(workspaceURL: URL, matcher: HermesKnowledgeTopicMatcher) -> [HermesKnowledgeEraserItem] {
        scanTextBlocks(url: userURL(for: workspaceURL), kind: .userProfileBlock, titlePrefix: "User profile") { text in
            matcher.confidence(in: text)
        }
    }

    private func scanSkills(workspaceURL: URL, matcher: HermesKnowledgeTopicMatcher) -> [HermesKnowledgeEraserItem] {
        let skillsURL = workspaceURL.appendingPathComponent("skills", isDirectory: true)
        guard let enumerator = fileManager.enumerator(
            at: skillsURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        var items: [HermesKnowledgeEraserItem] = []
        for case let url as URL in enumerator {
            guard ["md", "txt", "yaml", "yml", "json"].contains(url.pathExtension.lowercased()) else { continue }
            items.append(contentsOf: scanTextBlocks(url: url, kind: .skillBlock, titlePrefix: "Skill file") { text in
                matcher.confidence(in: text)
            })
        }
        return items
    }

    private func scanTextBlocks(url: URL, kind: HermesKnowledgeEraserItemKind, titlePrefix: String, confidence: (String) -> Double?) -> [HermesKnowledgeEraserItem] {
        guard let content = try? String(contentsOf: url, encoding: .utf8), !content.isEmpty else { return [] }
        let lines = content.components(separatedBy: .newlines)
        let blocks = Self.blocks(from: lines)
        return blocks.compactMap { block in
            let text = block.lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty, let score = confidence(text) else { return nil }
            return HermesKnowledgeEraserItem(
                id: "block:\(url.path):\(block.startLine):\(block.endLine)",
                kind: kind,
                title: "\(titlePrefix) lines \(block.startLine)-\(block.endLine)",
                path: url.path,
                location: "Lines \(block.startLine)-\(block.endLine)",
                preview: Self.preview(text),
                content: text,
                confidence: score
            )
        }
    }

    private func eraseMemoryEntries(workspaceURL: URL, selectedIDs: Set<String>) throws -> [String] {
        let url = memoryURL(for: workspaceURL)
        let content = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        let entries = content.components(separatedBy: entryDelimiter).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        var erased: [String] = []
        var kept: [String] = []
        for (index, entry) in entries.enumerated() {
            let id = "memory:\(index)"
            if selectedIDs.contains(id) { erased.append(id) } else { kept.append(entry) }
        }
        try kept.joined(separator: entryDelimiter).write(to: url, atomically: true, encoding: .utf8)
        return erased
    }

    private func eraseLocalMemoryEntries(workspaceURL: URL, selectedIDs: Set<String>) throws -> (erased: [String], skipped: [String]) {
        let memoryIDs = selectedIDs.compactMap(Self.localMemoryRecordID(from:))
        guard !memoryIDs.isEmpty else { return ([], Array(selectedIDs)) }
        let response = try runLocalMemoryErase(workspaceURL: workspaceURL, memoryIDs: memoryIDs)
        guard response.success else {
            throw HermesKnowledgeEraserError.localMemoryProvider(response.error ?? response.message ?? "unknown error")
        }
        return (
            erased: response.erased.map { Self.localMemoryItemID(for: $0) },
            skipped: response.skipped.map { Self.localMemoryItemID(for: $0) }
        )
    }

    private func eraseHindsightMemoryEntries(workspaceURL: URL, selectedIDs: Set<String>) throws -> (erased: [String], skipped: [String]) {
        let memoryIDs = selectedIDs.compactMap(Self.hindsightMemoryRecordID(from:))
        guard !memoryIDs.isEmpty else { return ([], Array(selectedIDs)) }
        let response = try runHindsightErase(workspaceURL: workspaceURL, memoryIDs: memoryIDs)
        guard response.success else {
            throw HermesKnowledgeEraserError.hindsightProvider(response.error ?? response.message ?? "unknown error")
        }
        return (
            erased: response.erased.map { Self.hindsightMemoryItemID(for: $0) },
            skipped: response.skipped.map { Self.hindsightMemoryItemID(for: $0) }
        )
    }

    private func eraseBlocks(path: String, items: [HermesKnowledgeEraserItem]) throws -> (erased: [String], skipped: [String]) {
        let url = URL(fileURLWithPath: path)
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return ([], items.map(\.id)) }
        let lines = content.components(separatedBy: .newlines)
        let selected = Set(items.map(\.id))
        var eraseLineNumbers = Set<Int>()
        for block in Self.blocks(from: lines) {
            let id = "block:\(path):\(block.startLine):\(block.endLine)"
            if selected.contains(id) {
                for line in block.startLine...block.endLine { eraseLineNumbers.insert(line) }
            }
        }
        guard !eraseLineNumbers.isEmpty else { return ([], items.map(\.id)) }
        var newLines: [String] = []
        for (offset, line) in lines.enumerated() where !eraseLineNumbers.contains(offset + 1) {
            newLines.append(line)
        }
        try newLines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
        return (items.map(\.id), [])
    }

    private func archive(items: [HermesKnowledgeEraserItem], topic: String, workspaceURL: URL) throws -> URL {
        let folder = workspaceURL.appendingPathComponent("knowledge-erasure-archive", isDirectory: true)
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        let fileName = "\(Self.slug(topic))-\(Self.archiveDateFormatter.string(from: Date())).md"
        let url = folder.appendingPathComponent(fileName)
        var markdown = "# Knowledge Eraser Archive\n\n"
        markdown += "Topic: \(topic)\n\n"
        markdown += "Created: \(ISO8601DateFormatter().string(from: Date()))\n\n"
        markdown += "Selected items: \(items.count)\n\n"
        for item in items {
            markdown += "## \(item.title)\n\n"
            markdown += "- Kind: \(item.kind.rawValue)\n"
            markdown += "- Path: \(item.path)\n"
            markdown += "- Location: \(item.location)\n"
            markdown += "- Confidence: \(String(format: "%.2f", item.confidence))\n\n"
            markdown += "```text\n\(item.content)\n```\n\n"
        }
        try markdown.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func runLocalMemoryScan(workspaceURL: URL, topic: String) throws -> HermesLocalMemoryEraserScanResponse {
        let data = try runLocalMemoryOperation(workspaceURL: workspaceURL, operation: "scan", topic: topic, memoryIDs: [])
        return try JSONDecoder().decode(HermesLocalMemoryEraserScanResponse.self, from: data)
    }

    private func runLocalMemoryErase(workspaceURL: URL, memoryIDs: [String]) throws -> HermesLocalMemoryEraserEraseResponse {
        let data = try runLocalMemoryOperation(workspaceURL: workspaceURL, operation: "erase", topic: "", memoryIDs: memoryIDs)
        return try JSONDecoder().decode(HermesLocalMemoryEraserEraseResponse.self, from: data)
    }

    private func runHindsightScan(workspaceURL: URL, topic: String) throws -> HermesHindsightEraserScanResponse {
        let data = try runHindsightOperation(workspaceURL: workspaceURL, operation: "scan", topic: topic, memoryIDs: [])
        return try JSONDecoder().decode(HermesHindsightEraserScanResponse.self, from: data)
    }

    private func runHindsightErase(workspaceURL: URL, memoryIDs: [String]) throws -> HermesHindsightEraserEraseResponse {
        let data = try runHindsightOperation(workspaceURL: workspaceURL, operation: "erase", topic: "", memoryIDs: memoryIDs)
        return try JSONDecoder().decode(HermesHindsightEraserEraseResponse.self, from: data)
    }

    private func runLocalMemoryOperation(workspaceURL: URL, operation: String, topic: String, memoryIDs: [String]) throws -> Data {
        let script = Self.localMemoryPythonScript
        let arguments = ["-c", script, operation, workspaceURL.path, topic] + memoryIDs
        let result = try HermesProcessRunner.run(
            executable: HermesRuntimePaths.defaultPythonExecutable,
            arguments: arguments,
            environment: Self.normalizedPythonEnvironment(hermesHome: workspaceURL.path),
            currentDirectory: HermesRuntimePaths.defaultHermesAgentRoot,
            timeout: 45
        )
        guard !result.timedOut else { throw HermesKnowledgeEraserError.localMemoryProvider("python helper timed out") }
        guard result.exitCode == 0 else {
            throw HermesKnowledgeEraserError.localMemoryProvider(result.output.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        guard let data = result.output.data(using: .utf8) else {
            throw HermesKnowledgeEraserError.localMemoryProvider("python helper returned non-UTF-8 output")
        }
        return data
    }

    private func runHindsightOperation(workspaceURL: URL, operation: String, topic: String, memoryIDs: [String]) throws -> Data {
        let script = Self.hindsightPythonScript
        let arguments = ["-c", script, operation, workspaceURL.path, topic] + memoryIDs
        let result = try HermesProcessRunner.run(
            executable: HermesRuntimePaths.defaultPythonExecutable,
            arguments: arguments,
            environment: Self.normalizedPythonEnvironment(hermesHome: workspaceURL.path),
            currentDirectory: HermesRuntimePaths.defaultHermesAgentRoot,
            timeout: 45
        )
        guard !result.timedOut else { throw HermesKnowledgeEraserError.hindsightProvider("python helper timed out") }
        guard result.exitCode == 0 else {
            throw HermesKnowledgeEraserError.hindsightProvider(result.output.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        guard let data = result.output.data(using: .utf8) else {
            throw HermesKnowledgeEraserError.hindsightProvider("python helper returned non-UTF-8 output")
        }
        return data
    }

    private static func normalizedPythonEnvironment(hermesHome: String) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        environment["HERMES_HOME"] = hermesHome
        environment["TERM"] = environment["TERM"] ?? "xterm-256color"
        let agentRoot = HermesRuntimePaths.defaultHermesAgentRoot
        let existingPythonPath = environment["PYTHONPATH"] ?? ""
        environment["PYTHONPATH"] = existingPythonPath.isEmpty ? agentRoot : agentRoot + ":" + existingPythonPath
        environment["PATH"] = normalizedPATH(existing: environment["PATH"], hermesHome: hermesHome)
        return environment
    }

    private static func normalizedPATH(existing: String?, hermesHome: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let preferredPaths = [
            URL(fileURLWithPath: hermesHome).appendingPathComponent("node/bin").path,
            "/opt/homebrew/bin",
            "/opt/homebrew/sbin",
            "/usr/local/bin",
            "/usr/local/sbin",
            URL(fileURLWithPath: home).appendingPathComponent(".local/bin").path
        ]
        let fallbackPaths = ["/usr/bin", "/bin", "/usr/sbin", "/sbin"]
        let currentPaths = (existing ?? "")
            .split(separator: ":", omittingEmptySubsequences: true)
            .map(String.init)
        var seen = Set<String>()
        return (preferredPaths + currentPaths + fallbackPaths).filter { path in
            let standardized = URL(fileURLWithPath: path).standardizedFileURL.path
            guard FileManager.default.fileExists(atPath: standardized), !seen.contains(standardized) else { return false }
            seen.insert(standardized)
            return true
        }.joined(separator: ":")
    }

    private static func localMemoryItemID(for memoryID: String) -> String { "local_memory:\(memoryID)" }

    private static func hindsightMemoryItemID(for memoryID: String) -> String { "hindsight:\(memoryID)" }

    private static func localMemoryRecordID(from itemID: String) -> String? {
        let prefix = "local_memory:"
        guard itemID.hasPrefix(prefix) else { return nil }
        return String(itemID.dropFirst(prefix.count))
    }

    private static func hindsightMemoryRecordID(from itemID: String) -> String? {
        let prefix = "hindsight:"
        guard itemID.hasPrefix(prefix) else { return nil }
        return String(itemID.dropFirst(prefix.count))
    }

    private func resolvedWorkspaceURL(from path: String) throws -> URL {
        let expanded = (path as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expanded, isDirectory: true)
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw HermesKnowledgeEraserError.invalidWorkspace(path)
        }
        return url
    }

    private func memoryURL(for workspaceURL: URL) -> URL { workspaceURL.appendingPathComponent("memory.md") }
    private func userURL(for workspaceURL: URL) -> URL { workspaceURL.appendingPathComponent("USER.md") }

    private static func blocks(from lines: [String]) -> [(startLine: Int, endLine: Int, lines: [String])] {
        var result: [(Int, Int, [String])] = []
        var start: Int?
        var current: [String] = []
        for (offset, line) in lines.enumerated() {
            let lineNumber = offset + 1
            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if let startLine = start, !current.isEmpty { result.append((startLine, lineNumber - 1, current)) }
                start = nil
                current = []
            } else {
                if start == nil { start = lineNumber }
                current.append(line)
            }
        }
        if let startLine = start, !current.isEmpty { result.append((startLine, lines.count, current)) }
        return result
    }

    private static func preview(_ text: String) -> String {
        let collapsed = text.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        return collapsed.count > 240 ? String(collapsed.prefix(240)) + "…" : collapsed
    }

    private static func slug(_ text: String) -> String {
        let lowered = text.lowercased()
        let scalars = lowered.unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) ? Character(scalar) : "-"
        }
        let collapsed = String(scalars).split(separator: "-").joined(separator: "-")
        return collapsed.isEmpty ? "topic" : String(collapsed.prefix(80))
    }

    private static let localMemoryPythonScript = #"""
import json
import sys

operation = sys.argv[1]
hermes_home = sys.argv[2]
topic = sys.argv[3]
memory_ids = sys.argv[4:]

try:
    from plugins.memory.local_memory import LocalMemoryProvider

    provider = LocalMemoryProvider()
    provider.initialize(
        "hermes-macos-knowledge-eraser",
        hermes_home=hermes_home,
        platform="macos",
        agent_identity="default",
        agent_workspace="hermes",
        agent_context="primary",
    )
    if operation == "scan":
        payload = {
            "success": True,
            "results": provider.find_eraser_keyword_matches(topic, limit=200, scoped=False),
        }
    elif operation == "erase":
        payload = provider.erase_eraser_memories(memory_ids, reason="knowledge_eraser")
        payload["success"] = True
    else:
        raise ValueError(f"Unsupported local_memory operation: {operation}")
    print(json.dumps(payload, sort_keys=True))
except Exception as exc:  # noqa: BLE001 - returned to the Swift UI as a user-visible operation failure
    print(json.dumps({"success": False, "error": str(exc), "results": [], "erased": [], "skipped": memory_ids}, sort_keys=True))
    sys.exit(1)
"""#

    private static let hindsightPythonScript = #"""
import asyncio
import json
import sys
import urllib.error
import urllib.parse
import urllib.request

operation = sys.argv[1]
hermes_home = sys.argv[2]
topic = sys.argv[3]
memory_ids = sys.argv[4:]


def value(record, *names):
    for name in names:
        if isinstance(record, dict) and name in record:
            return record.get(name)
        candidate = getattr(record, name, None)
        if candidate is not None:
            return candidate
    return None


def as_list(candidate):
    if candidate is None:
        return []
    if isinstance(candidate, (list, tuple, set)):
        return [str(item) for item in candidate if str(item).strip()]
    return [str(candidate)] if str(candidate).strip() else []


async def invalidate_memories(client, provider, ids):
    base_url = str(getattr(client, "_base_url", "") or provider._probe_url() or provider._api_url or "").rstrip("/")
    if not base_url:
        raise RuntimeError("Hindsight API URL is unavailable")
    bank_id = str(getattr(provider, "_bank_id", "") or "").strip()
    if not bank_id:
        raise RuntimeError("Hindsight bank ID is unavailable")
    api_key = str(getattr(client, "_api_key", "") or getattr(provider, "_api_key", "") or "").strip()
    erased = []
    skipped = []
    errors = []
    for memory_id in ids:
        memory_id = str(memory_id or "").strip()
        if not memory_id:
            continue
        endpoint = (
            f"{base_url}/v1/default/banks/"
            f"{urllib.parse.quote(bank_id, safe='')}/memories/"
            f"{urllib.parse.quote(memory_id, safe='')}"
        )
        body = json.dumps({"state": "invalidated", "reason": "knowledge_eraser"}).encode("utf-8")
        headers = {"Content-Type": "application/json"}
        if api_key:
            headers["Authorization"] = f"Bearer {api_key}"
        request = urllib.request.Request(endpoint, data=body, headers=headers, method="PATCH")
        try:
            await asyncio.to_thread(urllib.request.urlopen, request, timeout=30)
            erased.append(memory_id)
        except urllib.error.HTTPError as exc:
            skipped.append(memory_id)
            detail = exc.read().decode("utf-8", errors="replace")[:400]
            errors.append(f"{memory_id}: HTTP {exc.code} {detail}")
        except Exception as exc:  # noqa: BLE001 - reported to Swift as skipped detail
            skipped.append(memory_id)
            errors.append(f"{memory_id}: {exc}")
    return {"success": True, "erased": erased, "skipped": skipped, "message": "; ".join(errors)}


provider = None
try:
    from plugins.memory.hindsight import HindsightMemoryProvider

    provider = HindsightMemoryProvider()
    provider.initialize(
        "hermes-macos-knowledge-eraser",
        hermes_home=hermes_home,
        platform="macos",
        agent_identity="default",
        agent_workspace="hermes",
        agent_context="primary",
    )
    if getattr(provider, "_mode", "") == "disabled":
        raise RuntimeError("Hindsight memory provider is disabled or unavailable for this Hermes profile")
    if operation == "scan":
        recall_kwargs = {
            "bank_id": provider._bank_id,
            "query": topic,
            "budget": provider._budget,
            "max_tokens": 4096,
            "types": ["world", "experience"],
        }
        if provider._recall_tags:
            recall_kwargs["tags"] = provider._recall_tags
            recall_kwargs["tags_match"] = provider._recall_tags_match
        response = provider._run_hindsight_operation(lambda client: client.arecall(**recall_kwargs))
        records = []
        seen = set()
        for item in response.results or []:
            memory_id = str(value(item, "id", "memory_id") or "").strip()
            text = str(value(item, "text", "content") or "").strip()
            fact_type = str(value(item, "type", "fact_type") or "").strip()
            if not memory_id or not text or fact_type == "observation" or memory_id in seen:
                continue
            seen.add(memory_id)
            score = value(item, "score", "confidence", "relevance")
            try:
                confidence = float(score) if score is not None else 0.82
            except Exception:
                confidence = 0.82
            records.append({
                "memory_id": memory_id,
                "text": text,
                "fact_type": fact_type,
                "context": value(item, "context"),
                "confidence": confidence,
                "document_id": value(item, "document_id"),
                "chunk_id": value(item, "chunk_id"),
                "tags": as_list(value(item, "tags")),
                "entities": as_list(value(item, "entities")),
            })
        payload = {"success": True, "results": records}
    elif operation == "erase":
        payload = provider._run_hindsight_operation(lambda client: invalidate_memories(client, provider, memory_ids))
    else:
        raise ValueError(f"Unsupported Hindsight operation: {operation}")
    print(json.dumps(payload, sort_keys=True))
except Exception as exc:  # noqa: BLE001 - returned to the Swift UI as a user-visible operation failure
    print(json.dumps({"success": False, "error": str(exc), "results": [], "erased": [], "skipped": memory_ids}, sort_keys=True))
    sys.exit(1)
finally:
    if provider is not None:
        try:
            provider.shutdown()
        except Exception:
            pass
"""#

    private static let archiveDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter
    }()
}

private struct HermesLocalMemoryEraserScanResponse: Decodable {
    let success: Bool
    let error: String?
    let results: [HermesLocalMemoryEraserRecord]
}

private struct HermesLocalMemoryEraserEraseResponse: Decodable {
    let success: Bool
    let error: String?
    let message: String?
    let erased: [String]
    let skipped: [String]
}

private struct HermesHindsightEraserScanResponse: Decodable {
    let success: Bool
    let error: String?
    let results: [HermesHindsightEraserRecord]
}

private struct HermesHindsightEraserEraseResponse: Decodable {
    let success: Bool
    let error: String?
    let message: String?
    let erased: [String]
    let skipped: [String]
}

private struct HermesHindsightEraserRecord: Decodable {
    let memory_id: String
    let text: String
    let fact_type: String
    let context: String?
    let confidence: Double?
    let document_id: String?
    let chunk_id: String?
    let tags: [String]?
    let entities: [String]?
}

private struct HermesLocalMemoryEraserRecord: Decodable {
    let memory_id: String
    let content: String
    let memory_type: String?
    let confidence: Double?
    let updated_at: String?
    let scope: [String: String]?
    let source_session_ids: [String]?
    let mongo_match: Bool?
    let chroma_match: Bool?

    var scopeSummary: String {
        guard let scope else { return "" }
        let values = [scope["agent_identity"], scope["agent_workspace"], scope["user_id"]]
            .compactMap { value -> String? in
                guard let value, !value.isEmpty else { return nil }
                return value
            }
        return values.joined(separator: "/")
    }
}

private struct HermesKnowledgeTopicMatcher {
    let topic: String
    let tokens: [String]

    init(topic: String) {
        self.topic = topic.lowercased()
        self.tokens = topic.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 3 }
    }

    func confidence(in text: String) -> Double? {
        let haystack = text.lowercased()
        if haystack.contains(topic), topic.count >= 3 { return 1.0 }
        guard !tokens.isEmpty else { return nil }
        let matched = tokens.filter { haystack.contains($0) }
        if matched.count >= max(1, min(2, tokens.count)) {
            return min(0.95, 0.45 + Double(matched.count) / Double(tokens.count) * 0.5)
        }
        return nil
    }
}
