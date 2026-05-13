//
//  HermesUtilitiesView.swift
//  HermesMacOS
//

import AppKit
import CryptoKit
import Observation
import SwiftUI
import UniformTypeIdentifiers

private enum HermesMessagesHistoryMode: String, CaseIterable, Identifiable {
    case prompt
    case response
    var id: String { rawValue }
    var title: String { self == .prompt ? String(localized: "Prompt") : String(localized: "Response") }
}

struct HermesUtilitiesView: View {
    @Bindable var clipboardHistory: HermesClipboardHistoryStore
    @Bindable var promptHistory: HermesPromptHistoryStore
    let workspaces: [HermesAskWorkspace]
    @Binding var selectedWorkspaceID: HermesAskWorkspace.ID

    @AppStorage("hermes.macOS.utilities.clipboardHistoryExpanded") private var isClipboardHistoryExpanded = false
    @AppStorage("hermes.macOS.utilities.messagesHistoryExpanded") private var isMessagesHistoryExpanded = false
    @AppStorage("hermes.macOS.utilities.debuggingExpanded") private var isDebuggingExpanded = false
    @State private var statusMessage = String(localized: "Monitoring the Mac clipboard while HermesMacOS is active.")
    @State private var historyStatusMessage = String(localized: "Capturing prompts and responses sent from Ask Hermes.")
    @State private var messagesHistoryMode: HermesMessagesHistoryMode = .prompt

    private var selectedWorkspace: HermesAskWorkspace {
        workspaces.first(where: { $0.id == selectedWorkspaceID }) ?? workspaces[0]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 12) {
                    Image(systemName: "wrench.and.screwdriver")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(Color.hermesActionBlue)
                    Text("Utilities")
                        .font(.title2.weight(.semibold))
                }

                VStack(spacing: 0) {
                    DisclosureGroup(isExpanded: $isClipboardHistoryExpanded) {
                        clipboardHistoryContent
                    } label: {
                        utilityDisclosureLabel(title: String(localized: "Clipboard History"), subtitle: String(localized: "Last \(clipboardHistory.entries.count) of 10 copied objects"), systemImage: "clipboard")
                    }
                    .tint(.hermesActionBlue)

                    Divider().padding(.vertical, 8)

                    DisclosureGroup(isExpanded: $isMessagesHistoryExpanded) {
                        messagesHistoryContent
                    } label: {
                        utilityDisclosureLabel(title: String(localized: "Messages History"), subtitle: messagesHistorySubtitle, systemImage: "text.bubble")
                    }
                    .tint(.hermesActionBlue)

                    Divider().padding(.vertical, 8)

                    DisclosureGroup(isExpanded: $isDebuggingExpanded) {
                        HermesResponsesDebugPanel(workspaces: workspaces, selectedWorkspaceID: $selectedWorkspaceID)
                    } label: {
                        utilityDisclosureLabel(title: String(localized: "Debugging"), subtitle: String(localized: "Inspect streamed Responses API JSON"), systemImage: "ladybug")
                    }
                    .tint(.hermesActionBlue)
                }
                .padding(18)
                .hermesCard(tint: Color.hermesSurface.opacity(0.78))
            }
            .padding(24)
            .frame(maxWidth: 980, alignment: .leading)
        }
        .background(HermesLiquidGlassCanvas().ignoresSafeArea())
        .onAppear { clipboardHistory.captureCurrentPasteboardIfNeeded(force: true) }
        .onDisappear { collapseAllUtilitySections() }
    }

    private var messagesHistorySubtitle: String {
        switch messagesHistoryMode {
        case .prompt: String(localized: "Last \(promptHistory.entries.count) of 10 prompts sent to Hermes")
        case .response: String(localized: "Last \(promptHistory.responseEntries.count) of 10 Hermes responses")
        }
    }

    private func collapseAllUtilitySections() {
        isClipboardHistoryExpanded = false
        isMessagesHistoryExpanded = false
        isDebuggingExpanded = false
    }

    private func utilityDisclosureLabel(title: String, subtitle: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.hermesActionBlue)
                .frame(width: 34, height: 34)
                .background(Color.hermesActionBlue.opacity(0.12), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(Color.hermesSecondaryText)
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }

    private var clipboardHistoryContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Button { clipboardHistory.captureCurrentPasteboardIfNeeded(force: true); statusMessage = String(localized: "Clipboard checked.") } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                Button(role: .destructive) { clipboardHistory.clear(); statusMessage = String(localized: "Clipboard history cleared.") } label: {
                    Label("Clear", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .disabled(clipboardHistory.entries.isEmpty)
            }
            Text(statusMessage).font(.caption).foregroundStyle(Color.hermesSecondaryText)
            if clipboardHistory.entries.isEmpty {
                ContentUnavailableView("No clipboard history yet", systemImage: "clipboard", description: Text("Copy text, images, or files while HermesMacOS is active, then open this utility to paste them back later."))
                    .frame(maxWidth: .infinity, minHeight: 220)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(clipboardHistory.entries) { entry in
                        HStack(spacing: 10) {
                            Button { clipboardHistory.copyToPasteboard(entry); statusMessage = String(localized: "Copied \(entry.kind.localizedDisplayName.lowercased()) back to the clipboard.") } label: {
                                HermesClipboardHistoryRow(entry: entry)
                            }
                            .buttonStyle(.plain)
                            Button(role: .destructive) { clipboardHistory.delete(entry); statusMessage = String(localized: "Deleted \(entry.kind.localizedDisplayName.lowercased()) from clipboard history.") } label: { trashIcon }
                                .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(.top, 12)
    }

    private var messagesHistoryContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Messages history mode", selection: $messagesHistoryMode) {
                ForEach(HermesMessagesHistoryMode.allCases) { mode in Text(mode.title).tag(mode) }
            }
            .pickerStyle(.segmented)
            Button(role: .destructive) {
                if messagesHistoryMode == .prompt { promptHistory.clear(); historyStatusMessage = String(localized: "Prompt history cleared.") }
                else { promptHistory.clearResponses(); historyStatusMessage = String(localized: "Response history cleared.") }
            } label: { Label("Clear", systemImage: "trash") }
            .buttonStyle(.bordered)
            .disabled(messagesHistoryMode == .prompt ? promptHistory.entries.isEmpty : promptHistory.responseEntries.isEmpty)
            Text(historyStatusMessage).font(.caption).foregroundStyle(Color.hermesSecondaryText)
            if messagesHistoryMode == .prompt { promptHistoryList } else { responseHistoryList }
        }
        .padding(.top, 12)
    }

    @ViewBuilder private var promptHistoryList: some View {
        if promptHistory.entries.isEmpty {
            ContentUnavailableView("No prompt history yet", systemImage: "text.quote", description: Text("Send prompts from Ask Hermes, then open this utility to copy them back later."))
                .frame(maxWidth: .infinity, minHeight: 220)
        } else {
            LazyVStack(spacing: 10) {
                ForEach(promptHistory.entries) { entry in
                    HStack(spacing: 10) {
                        Button { promptHistory.copyToPasteboard(entry); historyStatusMessage = String(localized: "Copied prompt to the clipboard.") } label: { HermesPromptHistoryRow(entry: entry) }.buttonStyle(.plain)
                        Button(role: .destructive) { promptHistory.delete(entry); historyStatusMessage = String(localized: "Deleted prompt from history.") } label: { trashIcon }.buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder private var responseHistoryList: some View {
        if promptHistory.responseEntries.isEmpty {
            ContentUnavailableView("No response history yet", systemImage: "text.bubble", description: Text("Hermes responses from Ask Hermes will appear here after requests complete."))
                .frame(maxWidth: .infinity, minHeight: 220)
        } else {
            LazyVStack(spacing: 10) {
                ForEach(promptHistory.responseEntries) { entry in
                    HStack(spacing: 10) {
                        Button { promptHistory.copyResponseToPasteboard(entry); historyStatusMessage = String(localized: "Copied response to the clipboard.") } label: { HermesResponseHistoryRow(entry: entry) }.buttonStyle(.plain)
                        Button(role: .destructive) { promptHistory.deleteResponse(entry); historyStatusMessage = String(localized: "Deleted response from history.") } label: { trashIcon }.buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var trashIcon: some View {
        Image(systemName: "trash")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Color.hermesDestructive)
            .frame(width: 38, height: 38)
            .background(Color.hermesDestructive.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct HermesResponsesDebugPanel: View {
    let workspaces: [HermesAskWorkspace]
    @Binding var selectedWorkspaceID: HermesAskWorkspace.ID
    private let visibleDebugLineCount: CGFloat = 16
    private let debugLineHeight: CGFloat = 18

    private var selectedWorkspace: HermesAskWorkspace {
        workspaces.first(where: { $0.id == selectedWorkspaceID }) ?? workspaces[0]
    }

    private var debugText: String {
        selectedWorkspace.session.rawStreamedJSON.isEmpty ? String(localized: "No Responses API JSON has been streamed yet in workspace \(selectedWorkspace.number). Send an Ask Hermes request with streaming enabled to populate this debug view.") : selectedWorkspace.session.rawStreamedJSON
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if workspaces.count > 1 {
                Picker("Workspace", selection: $selectedWorkspaceID) {
                    ForEach(workspaces) { workspace in Text("Workspace \(workspace.number)").tag(workspace.id) }
                }
                .pickerStyle(.segmented)
            }
            HStack(spacing: 12) {
                Label("\(selectedWorkspace.session.eventCount) events", systemImage: "timeline.selection")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.hermesSecondaryText)
                Spacer()
                Button { selectedWorkspace.session.rawStreamedJSON = "" } label: { Label("Clear", systemImage: "trash") }
                    .buttonStyle(.bordered)
                    .disabled(selectedWorkspace.session.rawStreamedJSON.isEmpty)
            }
            TextEditor(text: .constant(debugText))
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .scrollContentBackground(.hidden)
                .frame(height: visibleDebugLineCount * debugLineHeight)
                .padding(8)
                .background(Color.hermesSurfaceInput.opacity(0.84), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(.top, 12)
    }
}

private struct HermesPromptHistoryRow: View {
    let entry: HermesPromptHistoryEntry
    var body: some View { historyRow(systemImage: entry.source.systemImage, badge: entry.source.displayName, title: entry.title, subtitle: entry.subtitle, badgeIcon: "text.quote") }
}

private struct HermesResponseHistoryRow: View {
    let entry: HermesResponseHistoryEntry
    var body: some View { historyRow(systemImage: entry.source.systemImage, badge: entry.source.displayName, title: entry.title, subtitle: entry.subtitle, badgeIcon: "text.bubble") }
}

private func historyRow(systemImage: String, badge: String, title: String, subtitle: String, badgeIcon: String) -> some View {
    HStack(alignment: .center, spacing: 14) {
        Image(systemName: systemImage)
            .font(.system(size: 28, weight: .semibold))
            .foregroundStyle(Color.hermesActionBlue)
            .frame(width: 72, height: 72)
            .background(Color.hermesSurfaceInput, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        VStack(alignment: .leading, spacing: 6) {
            Label(badge, systemImage: badgeIcon).font(.caption.weight(.semibold)).foregroundStyle(Color.hermesSecondaryText)
            Text(title).font(.headline).lineLimit(3).multilineTextAlignment(.leading)
            Text(subtitle).font(.caption).foregroundStyle(Color.hermesSecondaryText).lineLimit(1)
        }
        Spacer(minLength: 0)
        Image(systemName: "doc.on.clipboard").foregroundStyle(Color.hermesActionBlue)
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .hermesCard(tint: Color.hermesActionBlue.opacity(0.06))
}

private struct HermesClipboardHistoryRow: View {
    let entry: HermesClipboardHistoryEntry
    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            preview.frame(width: 72, height: 72)
                .background(Color.hermesSurfaceInput, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            VStack(alignment: .leading, spacing: 6) {
                Label(entry.kind.localizedDisplayName, systemImage: entry.kind.systemImage).font(.caption.weight(.semibold)).foregroundStyle(Color.hermesSecondaryText)
                Text(entry.title).font(.headline).lineLimit(2).multilineTextAlignment(.leading)
                if let subtitle = entry.subtitle { Text(subtitle).font(.caption).foregroundStyle(Color.hermesSecondaryText).lineLimit(1) }
            }
            Spacer(minLength: 0)
            Image(systemName: "doc.on.clipboard").foregroundStyle(Color.hermesActionBlue)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .hermesCard(tint: Color.hermesActionBlue.opacity(0.06))
    }

    @ViewBuilder private var preview: some View {
        switch entry.kind {
        case .text:
            Text(entry.textValue ?? "").font(.caption2.monospaced()).lineLimit(5).padding(8).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        case .image:
            if let image = entry.nsImage { Image(nsImage: image).resizable().scaledToFill() }
            else { Image(systemName: "photo").font(.system(size: 28, weight: .semibold)).foregroundStyle(Color.hermesSecondaryText) }
        case .file:
            Image(systemName: entry.kind.systemImage).font(.system(size: 30, weight: .semibold)).foregroundStyle(Color.hermesActionBlue)
        }
    }
}

@MainActor
@Observable
final class HermesClipboardHistoryStore {
    private let defaultsKey = "hermes.macOS.utilities.clipboardHistory.entries"
    private let maxEntries = 10
    private let maxStoredBytes = 25 * 1024 * 1024
    private var lastObservedChangeCount = NSPasteboard.general.changeCount
    var entries: [HermesClipboardHistoryEntry] = []

    init() { load() }

    func runMonitoringLoop() async {
        captureCurrentPasteboardIfNeeded(force: true)
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1))
            captureCurrentPasteboardIfNeeded()
        }
    }

    func captureCurrentPasteboardIfNeeded(force: Bool = false) {
        let pasteboard = NSPasteboard.general
        guard force || pasteboard.changeCount != lastObservedChangeCount else { return }
        lastObservedChangeCount = pasteboard.changeCount
        guard let entry = Self.entry(from: pasteboard, maxStoredBytes: maxStoredBytes) else { return }
        insert(entry)
    }

    func copyToPasteboard(_ entry: HermesClipboardHistoryEntry) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        switch entry.kind {
        case .text:
            pasteboard.setString(entry.textValue ?? "", forType: .string)
        case .image:
            if let image = entry.nsImage { pasteboard.writeObjects([image]) }
        case .file:
            if let url = entry.fileURL { pasteboard.writeObjects([url as NSURL]) }
            else { pasteboard.setData(entry.payload, forType: NSPasteboard.PasteboardType(entry.typeIdentifier)) }
        }
        lastObservedChangeCount = pasteboard.changeCount
    }

    func clear() { entries.removeAll(); persist() }
    func delete(_ entry: HermesClipboardHistoryEntry) { entries.removeAll { $0.id == entry.id }; persist() }

    private func insert(_ entry: HermesClipboardHistoryEntry) {
        if entries.first?.fingerprint == entry.fingerprint { return }
        entries.removeAll { $0.fingerprint == entry.fingerprint }
        entries.insert(entry, at: 0)
        if entries.count > maxEntries { entries = Array(entries.prefix(maxEntries)) }
        persist()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey), let decoded = try? JSONDecoder().decode([HermesClipboardHistoryEntry].self, from: data) else { entries = []; return }
        entries = Array(decoded.prefix(maxEntries))
    }

    private func persist() { if let data = try? JSONEncoder().encode(entries) { UserDefaults.standard.set(data, forKey: defaultsKey) } }

    private static func entry(from pasteboard: NSPasteboard, maxStoredBytes: Int) -> HermesClipboardHistoryEntry? {
        if let string = pasteboard.string(forType: .string), !string.isEmpty, let data = string.data(using: .utf8), data.count <= maxStoredBytes {
            return HermesClipboardHistoryEntry(kind: .text, typeIdentifier: UTType.utf8PlainText.identifier, payload: data, displayName: nil)
        }
        if let data = pasteboard.data(forType: .tiff), data.count <= maxStoredBytes {
            return HermesClipboardHistoryEntry(kind: .image, typeIdentifier: UTType.tiff.identifier, payload: data, displayName: String(localized: "Clipboard image"))
        }
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL], let url = urls.first, let data = url.path.data(using: .utf8), data.count <= maxStoredBytes {
            return HermesClipboardHistoryEntry(kind: .file, typeIdentifier: UTType.fileURL.identifier, payload: data, displayName: url.lastPathComponent)
        }
        return nil
    }
}

struct HermesClipboardHistoryEntry: Identifiable, Codable, Equatable {
    enum Kind: String, Codable {
        case text, image, file
        var displayName: String { self == .text ? "Text" : (self == .image ? "Image" : "File") }
        var localizedDisplayName: String { String(localized: String.LocalizationValue(displayName)) }
        var systemImage: String { self == .text ? "text.alignleft" : (self == .image ? "photo" : "doc") }
    }
    let id: UUID
    let kind: Kind
    let typeIdentifier: String
    let payload: Data
    let displayName: String?
    let createdAt: Date
    let fingerprint: String

    init(kind: Kind, typeIdentifier: String, payload: Data, displayName: String?) {
        self.id = UUID(); self.kind = kind; self.typeIdentifier = typeIdentifier; self.payload = payload; self.displayName = displayName; self.createdAt = Date()
        self.fingerprint = Self.makeFingerprint(kind: kind, typeIdentifier: typeIdentifier, payload: payload)
    }

    private static func makeFingerprint(kind: Kind, typeIdentifier: String, payload: Data) -> String {
        let digest = SHA256.hash(data: payload).map { String(format: "%02x", $0) }.joined()
        return kind.rawValue + ":" + typeIdentifier + ":" + digest
    }

    var textValue: String? { String(data: payload, encoding: .utf8) }
    var nsImage: NSImage? { NSImage(data: payload) }
    var fileURL: URL? { textValue.map { URL(fileURLWithPath: $0) } }
    var title: String {
        switch kind {
        case .text:
            let trimmed = (textValue ?? "Text").replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "Text" : trimmed
        case .image: return displayName ?? "Image"
        case .file: return displayName ?? fileURL?.lastPathComponent ?? "File"
        }
    }
    var subtitle: String? {
        switch kind {
        case .text: return textValue.map { String(localized: "\($0.count) characters") }
        case .image: return ByteCountFormatter.string(fromByteCount: Int64(payload.count), countStyle: .file)
        case .file: return fileURL?.path
        }
    }
}

@MainActor
@Observable
final class HermesPromptHistoryStore {
    private let promptDefaultsKey = "hermes.macOS.utilities.promptHistory.entries"
    private let responseDefaultsKey = "hermes.macOS.utilities.responseHistory.entries"
    private let maxEntries = 10
    var entries: [HermesPromptHistoryEntry] = []
    var responseEntries: [HermesResponseHistoryEntry] = []
    init() { load() }
    func record(_ prompt: String, source: HermesPromptHistoryEntry.Source = .askHermes) {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines); guard !trimmed.isEmpty else { return }
        let entry = HermesPromptHistoryEntry(prompt: trimmed, source: source)
        if entries.first?.fingerprint == entry.fingerprint { return }
        entries.removeAll { $0.fingerprint == entry.fingerprint }; entries.insert(entry, at: 0)
        if entries.count > maxEntries { entries = Array(entries.prefix(maxEntries)) }
        persistPrompts()
    }
    func recordResponse(_ response: String, source: HermesPromptHistoryEntry.Source = .askHermes) {
        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines); guard !trimmed.isEmpty else { return }
        let entry = HermesResponseHistoryEntry(response: trimmed, source: source)
        if responseEntries.first?.fingerprint == entry.fingerprint { return }
        responseEntries.removeAll { $0.fingerprint == entry.fingerprint }; responseEntries.insert(entry, at: 0)
        if responseEntries.count > maxEntries { responseEntries = Array(responseEntries.prefix(maxEntries)) }
        persistResponses()
    }
    func copyToPasteboard(_ entry: HermesPromptHistoryEntry) { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(entry.prompt, forType: .string) }
    func copyResponseToPasteboard(_ entry: HermesResponseHistoryEntry) { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(entry.response, forType: .string) }
    func delete(_ entry: HermesPromptHistoryEntry) { entries.removeAll { $0.id == entry.id }; persistPrompts() }
    func deleteResponse(_ entry: HermesResponseHistoryEntry) { responseEntries.removeAll { $0.id == entry.id }; persistResponses() }
    func clear() { entries.removeAll(); persistPrompts() }
    func clearResponses() { responseEntries.removeAll(); persistResponses() }
    private func load() {
        if let data = UserDefaults.standard.data(forKey: promptDefaultsKey), let decoded = try? JSONDecoder().decode([HermesPromptHistoryEntry].self, from: data) { entries = Array(decoded.prefix(maxEntries)) }
        if let data = UserDefaults.standard.data(forKey: responseDefaultsKey), let decoded = try? JSONDecoder().decode([HermesResponseHistoryEntry].self, from: data) { responseEntries = Array(decoded.prefix(maxEntries)) }
    }
    private func persistPrompts() { if let data = try? JSONEncoder().encode(entries) { UserDefaults.standard.set(data, forKey: promptDefaultsKey) } }
    private func persistResponses() { if let data = try? JSONEncoder().encode(responseEntries) { UserDefaults.standard.set(data, forKey: responseDefaultsKey) } }
}

struct HermesPromptHistoryEntry: Identifiable, Codable, Equatable {
    enum Source: String, Codable {
        case askHermes
        var displayName: String { String(localized: "Ask Hermes") }
        var systemImage: String { "dot.radiowaves.left.and.right" }
    }
    let id: UUID; let prompt: String; let source: Source; let createdAt: Date; let fingerprint: String
    init(prompt: String, source: Source) { self.id = UUID(); self.prompt = prompt; self.source = source; self.createdAt = Date(); self.fingerprint = Self.makeFingerprint(text: prompt, source: source, kind: "prompt") }
    private static func makeFingerprint(text: String, source: Source, kind: String) -> String { source.rawValue + ":" + kind + ":" + SHA256.hash(data: Data((source.rawValue + ":" + kind + ":" + text).utf8)).map { String(format: "%02x", $0) }.joined() }
    var title: String { Self.normalizedTitle(from: prompt, fallback: String(localized: "Prompt")) }
    var subtitle: String { String(localized: "\(prompt.count) characters") }
    static func normalizedTitle(from text: String, fallback: String) -> String {
        let normalized = text.replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "\r", with: " ").split(whereSeparator: { $0.isWhitespace }).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? fallback : normalized
    }
}

struct HermesResponseHistoryEntry: Identifiable, Codable, Equatable {
    let id: UUID; let response: String; let source: HermesPromptHistoryEntry.Source; let createdAt: Date; let fingerprint: String
    init(response: String, source: HermesPromptHistoryEntry.Source) { self.id = UUID(); self.response = response; self.source = source; self.createdAt = Date(); self.fingerprint = Self.makeFingerprint(response: response, source: source) }
    private static func makeFingerprint(response: String, source: HermesPromptHistoryEntry.Source) -> String { source.rawValue + ":response:" + SHA256.hash(data: Data((source.rawValue + ":response:" + response).utf8)).map { String(format: "%02x", $0) }.joined() }
    var title: String { HermesPromptHistoryEntry.normalizedTitle(from: response, fallback: String(localized: "Response")) }
    var subtitle: String { String(localized: "\(response.count) characters") }
}
