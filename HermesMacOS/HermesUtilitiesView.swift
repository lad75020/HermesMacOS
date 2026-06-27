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
    @Bindable var chatSession: HermesChatSession
    @Bindable var installationSession: HermesInstallationSession
    let connectedHostName: String
    let connectedWindowID: UUID
    var onReviewInstallationWithHermes: (String) -> Void

    @AppStorage("hermes.macOS.utilities.clipboardHistoryExpanded") private var isClipboardHistoryExpanded = false
    @AppStorage("hermes.macOS.utilities.messagesHistoryExpanded") private var isMessagesHistoryExpanded = false
    @AppStorage("hermes.macOS.utilities.debuggingExpanded") private var isDebuggingExpanded = false
    @AppStorage("hermes.macOS.utilities.installationExpanded") private var isInstallationExpanded = false
    @AppStorage("hermes.macOS.utilities.knowledgeEraserExpanded") private var isKnowledgeEraserExpanded = false
    @AppStorage(HermesClipboardHistoryStore.monitoringEnabledKey) private var clipboardMonitoringEnabled = false
    @AppStorage(HermesPromptHistoryStore.persistenceEnabledKey) private var messageHistoryPersistenceEnabled = true
    @State private var statusMessage = String(localized: "Clipboard monitoring is off by default. Enable it here when you want HermesMacOS to retain recent clipboard items.")
    @State private var historyStatusMessage = String(localized: "Capturing prompts and responses sent from Ask Hermes and Chat with Hermes.")
    @State private var messagesHistoryMode: HermesMessagesHistoryMode = .prompt
    @State private var knowledgeEraser = HermesKnowledgeEraserStore()

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
                        .hermesWebsiteTitleFont(size: 22, weight: .bold)
                    Spacer()
                    HermesConnectedHostLabel(hostName: connectedHostName, windowID: connectedWindowID)
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
                        HermesResponsesDebugPanel(workspaces: workspaces, selectedWorkspaceID: $selectedWorkspaceID, chatSession: chatSession)
                    } label: {
                        utilityDisclosureLabel(title: String(localized: "Debugging"), subtitle: String(localized: "Inspect streamed Responses and Chat JSON"), systemImage: "ladybug")
                    }
                    .tint(.hermesActionBlue)

                    Divider().padding(.vertical, 8)

                    DisclosureGroup(isExpanded: $isKnowledgeEraserExpanded) {
                        HermesKnowledgeEraserUtilityPanel(store: knowledgeEraser)
                    } label: {
                        utilityDisclosureLabel(
                            title: String(localized: "Knowledge Eraser"),
                            subtitle: knowledgeEraser.items.isEmpty ? String(localized: "Find, review, archive, and erase topic-related knowledge") : String(localized: "\(knowledgeEraser.items.count) candidates • \(knowledgeEraser.selectedCount) selected"),
                            systemImage: "eraser.line.dashed.fill"
                        )
                    }
                    .tint(.hermesActionBlue)

                    Divider().padding(.vertical, 8)

                    DisclosureGroup(isExpanded: $isInstallationExpanded) {
                        HermesInstallationView(
                            session: installationSession,
                            onReviewWithHermes: onReviewInstallationWithHermes,
                            presentation: .utilitySection
                        )
                    } label: {
                        utilityDisclosureLabel(title: String(localized: "Hermes Installation"), subtitle: installationSubtitle, systemImage: "arrow.triangle.2.circlepath")
                    }
                    .tint(.hermesActionBlue)
                }
                .padding(18)
                .hermesGlassPanel(tint: Color.hermesSurface.opacity(0.68), cornerRadius: 24)
            }
            .padding(24)
            .frame(maxWidth: 980, alignment: .leading)
        }
        .background(HermesLiquidGlassCanvas().ignoresSafeArea())
        .onAppear {
            if clipboardMonitoringEnabled { clipboardHistory.captureCurrentPasteboardIfNeeded(force: true) }
            installationSession.remoteHostName = connectedHostName
        }
        .onChange(of: connectedHostName) { _, newValue in
            installationSession.remoteHostName = newValue
        }
        .onDisappear { collapseAllUtilitySections() }
    }

    private var messagesHistorySubtitle: String {
        switch messagesHistoryMode {
        case .prompt: String(localized: "Last \(promptHistory.entries.count) of 10 prompts sent to Hermes")
        case .response: String(localized: "Last \(promptHistory.responseEntries.count) of 10 Hermes responses")
        }
    }

    private var installationSubtitle: String {
        if installationSession.isRefreshing || installationSession.isPreviewingMerge || installationSession.isMerging {
            return String(localized: "Checking or updating the local Hermes agent repository")
        }
        if let lastChecked = installationSession.status.lastChecked {
            return String(localized: "\(installationSession.status.lagSummary) • checked \(lastChecked.formatted(date: .omitted, time: .shortened))")
        }
        return String(localized: "Check lag, review conflicts, and stage local update branches")
    }

    private func collapseAllUtilitySections() {
        isClipboardHistoryExpanded = false
        isMessagesHistoryExpanded = false
        isDebuggingExpanded = false
        isInstallationExpanded = false
        isKnowledgeEraserExpanded = false
    }

    private func utilityDisclosureLabel(title: String, subtitle: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.hermesActionBlue)
                .frame(width: 34, height: 34)
                .hermesGlassPanel(tint: Color.hermesActionBlue.opacity(0.10), cornerRadius: 11)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).hermesWebsiteTitleFont(size: 15, weight: .bold)
                Text(subtitle).font(.caption).foregroundStyle(Color.hermesSecondaryText)
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }

    private var clipboardHistoryContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Toggle("Monitor clipboard", isOn: $clipboardMonitoringEnabled)
                    .tint(.hermesActionBlue)
                Spacer()
                Button { clipboardHistory.captureCurrentPasteboardIfNeeded(force: true); statusMessage = String(localized: "Clipboard checked.") } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(!clipboardMonitoringEnabled)
                Button(role: .destructive) { clipboardHistory.clear(); statusMessage = String(localized: "Clipboard history cleared.") } label: {
                    Label("Clear", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .disabled(clipboardHistory.entries.isEmpty)
            }
            Text(statusMessage).font(.caption).foregroundStyle(Color.hermesSecondaryText)
            if clipboardHistory.entries.isEmpty {
                ContentUnavailableView("No clipboard history yet", systemImage: "clipboard", description: Text(clipboardMonitoringEnabled ? "Copy text, images, or files while HermesMacOS is active, then open this utility to paste them back later." : "Clipboard monitoring is off. Enable it above to retain recent clipboard items while HermesMacOS is active."))
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
            Toggle("Save prompt and response history", isOn: $messageHistoryPersistenceEnabled)
                .tint(.hermesActionBlue)
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
            ContentUnavailableView("No prompt history yet", systemImage: "text.quote", description: Text("Send prompts from Ask Hermes or Chat with Hermes, then open this utility to copy them back later."))
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
            ContentUnavailableView("No response history yet", systemImage: "text.bubble", description: Text("Hermes responses from Ask Hermes and Chat with Hermes will appear here after requests complete."))
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
            .hermesGlassPanel(tint: Color.hermesDestructive.opacity(0.10), cornerRadius: 12)
    }
}

private struct HermesResponsesDebugPanel: View {
    enum DebugSource: String, CaseIterable, Identifiable {
        case ask
        case chat
        var id: String { rawValue }
        var title: String { self == .ask ? String(localized: "Ask Hermes") : String(localized: "Chat with Hermes") }
    }

    let workspaces: [HermesAskWorkspace]
    @Binding var selectedWorkspaceID: HermesAskWorkspace.ID
    @Bindable var chatSession: HermesChatSession
    @State private var debugSource: DebugSource = .ask
    private let visibleDebugLineCount: CGFloat = 16
    private let debugLineHeight: CGFloat = 18

    private var selectedWorkspace: HermesAskWorkspace {
        workspaces.first(where: { $0.id == selectedWorkspaceID }) ?? workspaces[0]
    }

    private var debugText: String {
        switch debugSource {
        case .ask:
            return selectedWorkspace.session.rawStreamedJSON.isEmpty ? String(localized: "No Responses API JSON has been streamed yet in workspace \(selectedWorkspace.number). Send an Ask Hermes request with streaming enabled to populate this debug view.") : selectedWorkspace.session.rawStreamedJSON
        case .chat:
            return chatSession.rawStreamedJSON.isEmpty ? String(localized: "No Chat Completions JSON has been streamed yet. Send a Chat with Hermes request with streaming enabled to populate this debug view.") : chatSession.rawStreamedJSON
        }
    }

    private var eventCount: Int {
        switch debugSource {
        case .ask: selectedWorkspace.session.eventCount
        case .chat: chatSession.eventCount
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Debug source", selection: $debugSource) {
                ForEach(DebugSource.allCases) { source in Text(source.title).tag(source) }
            }
            .pickerStyle(.segmented)

            if debugSource == .ask && workspaces.count > 1 {
                Picker("Workspace", selection: $selectedWorkspaceID) {
                    ForEach(workspaces) { workspace in Text("Workspace \(workspace.number)").tag(workspace.id) }
                }
                .pickerStyle(.segmented)
            }
            HStack(spacing: 12) {
                Label("\(eventCount) events", systemImage: "timeline.selection")
                    .hermesWebsiteLabelFont(size: 11, weight: .bold)
                    .foregroundStyle(Color.hermesSecondaryText)
                Spacer()
                Button { clearDebugText() } label: { Label("Clear", systemImage: "trash") }
                    .buttonStyle(.bordered)
                    .disabled(isClearDisabled)
            }
            TextEditor(text: .constant(debugText))
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .scrollContentBackground(.hidden)
                .frame(height: visibleDebugLineCount * debugLineHeight)
                .padding(8)
                .hermesGlassInput(tint: Color.hermesSurfaceInput.opacity(0.70), cornerRadius: 14)
        }
        .padding(.top, 12)
    }

    private var isClearDisabled: Bool {
        switch debugSource {
        case .ask: selectedWorkspace.session.rawStreamedJSON.isEmpty
        case .chat: chatSession.rawStreamedJSON.isEmpty
        }
    }

    private func clearDebugText() {
        switch debugSource {
        case .ask: selectedWorkspace.session.rawStreamedJSON = ""
        case .chat: chatSession.rawStreamedJSON = ""
        }
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

@MainActor
private func historyRow(systemImage: String, badge: String, title: String, subtitle: String, badgeIcon: String) -> some View {
    HStack(alignment: .center, spacing: 14) {
        Image(systemName: systemImage)
            .font(.system(size: 28, weight: .semibold))
            .foregroundStyle(Color.hermesActionBlue)
            .frame(width: 72, height: 72)
            .hermesGlassPanel(tint: Color.hermesSurfaceInput.opacity(0.66), cornerRadius: 16)
        VStack(alignment: .leading, spacing: 6) {
            Label(badge, systemImage: badgeIcon).hermesWebsiteLabelFont(size: 11, weight: .bold).foregroundStyle(Color.hermesSecondaryText)
            Text(title).hermesWebsiteTitleFont(size: 15, weight: .bold).lineLimit(3).multilineTextAlignment(.leading)
            Text(subtitle).font(.caption).foregroundStyle(Color.hermesSecondaryText).lineLimit(1)
        }
        Spacer(minLength: 0)
        Image(systemName: "doc.on.clipboard").foregroundStyle(Color.hermesActionBlue)
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .hermesGlassPanel(tint: Color.hermesActionBlue.opacity(0.05), cornerRadius: 18)
}

private struct HermesClipboardHistoryRow: View {
    let entry: HermesClipboardHistoryEntry
    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            preview.frame(width: 72, height: 72)
                .hermesGlassPanel(tint: Color.hermesSurfaceInput.opacity(0.66), cornerRadius: 16)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            VStack(alignment: .leading, spacing: 6) {
                Label(entry.kind.localizedDisplayName, systemImage: entry.kind.systemImage).hermesWebsiteLabelFont(size: 11, weight: .bold).foregroundStyle(Color.hermesSecondaryText)
                Text(entry.title).hermesWebsiteTitleFont(size: 15, weight: .bold).lineLimit(2).multilineTextAlignment(.leading)
                if let subtitle = entry.subtitle { Text(subtitle).font(.caption).foregroundStyle(Color.hermesSecondaryText).lineLimit(1) }
            }
            Spacer(minLength: 0)
            Image(systemName: "doc.on.clipboard").foregroundStyle(Color.hermesActionBlue)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .hermesGlassPanel(tint: Color.hermesActionBlue.opacity(0.05), cornerRadius: 18)
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
    static let monitoringEnabledKey = "hermes.macOS.utilities.clipboardHistory.monitoringEnabled"
    private let defaultsKey = "hermes.macOS.utilities.clipboardHistory.entries"
    private let maxEntries = 10
    private let maxStoredBytes = 25 * 1024 * 1024
    private var lastObservedChangeCount = NSPasteboard.general.changeCount
    private var didLoadPersistedEntries = false
    var entries: [HermesClipboardHistoryEntry] = []

    func loadPersistedEntriesIfNeeded() async {
        guard !didLoadPersistedEntries else { return }
        didLoadPersistedEntries = true
        let loadedEntries = await Task.detached(priority: .utility) { [defaultsKey, maxEntries] () -> [HermesClipboardHistoryEntry] in
            guard let decoded = HermesEncryptedRetentionStore.load([HermesClipboardHistoryEntry].self, forKey: defaultsKey) else { return [] }
            return Array(decoded.map(\.redactedForRetention).prefix(maxEntries))
        }.value
        entries = loadedEntries
    }

    func runMonitoringLoop() async {
        await loadPersistedEntriesIfNeeded()
        while !Task.isCancelled {
            if UserDefaults.standard.bool(forKey: Self.monitoringEnabledKey) {
                captureCurrentPasteboardIfNeeded()
            }
            try? await Task.sleep(for: .seconds(1))
        }
    }

    func captureCurrentPasteboardIfNeeded(force: Bool = false) {
        guard force || UserDefaults.standard.bool(forKey: Self.monitoringEnabledKey) else { return }
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
        guard let decoded = UserDefaults.standard.data(forKey: defaultsKey),
              let entries = try? JSONDecoder().decode([HermesClipboardHistoryEntry].self, from: decoded)
        else { self.entries = []; return }
        self.entries = Array(entries.map(\.redactedForRetention).prefix(maxEntries))
    }

    private func persist() {
        _ = HermesEncryptedRetentionStore.save(entries.map(\.redactedForRetention), forKey: defaultsKey)
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }

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

struct HermesClipboardHistoryEntry: Identifiable, Codable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable {
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

    var redactedForRetention: HermesClipboardHistoryEntry {
        guard kind == .text, let textValue, let data = HermesSecretRedactor.redact(textValue).data(using: .utf8) else { return self }
        return HermesClipboardHistoryEntry(kind: kind, typeIdentifier: typeIdentifier, payload: data, displayName: displayName)
    }
}

@MainActor
@Observable
final class HermesPromptHistoryStore {
    static let persistenceEnabledKey = "hermes.macOS.utilities.messageHistory.persistenceEnabled"
    private let promptDefaultsKey = "hermes.macOS.utilities.promptHistory.entries"
    private let responseDefaultsKey = "hermes.macOS.utilities.responseHistory.entries"
    private let maxEntries = 10
    private var didLoadPersistedEntries = false
    var entries: [HermesPromptHistoryEntry] = []
    var responseEntries: [HermesResponseHistoryEntry] = []
    init() {
        UserDefaults.standard.register(defaults: [Self.persistenceEnabledKey: true])
    }
    func loadPersistedEntriesIfNeeded() async {
        guard !didLoadPersistedEntries else { return }
        didLoadPersistedEntries = true
        let loaded = await Task.detached(priority: .utility) { [promptDefaultsKey, responseDefaultsKey, maxEntries] () -> ([HermesPromptHistoryEntry], [HermesResponseHistoryEntry]) in
            let prompts = HermesEncryptedRetentionStore.load([HermesPromptHistoryEntry].self, forKey: promptDefaultsKey) ?? []
            let responses = HermesEncryptedRetentionStore.load([HermesResponseHistoryEntry].self, forKey: responseDefaultsKey) ?? []
            return (
                Array(prompts.map(\.redactedForRetention).prefix(maxEntries)),
                Array(responses.map(\.redactedForRetention).prefix(maxEntries))
            )
        }.value
        entries = loaded.0
        responseEntries = loaded.1
    }
    func record(_ prompt: String, source: HermesPromptHistoryEntry.Source = .askHermes) {
        guard UserDefaults.standard.bool(forKey: Self.persistenceEnabledKey) else { return }
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines); guard !trimmed.isEmpty else { return }
        let entry = HermesPromptHistoryEntry(prompt: trimmed, source: source)
        if entries.first?.fingerprint == entry.fingerprint { return }
        entries.removeAll { $0.fingerprint == entry.fingerprint }; entries.insert(entry, at: 0)
        if entries.count > maxEntries { entries = Array(entries.prefix(maxEntries)) }
        persistPrompts()
    }
    func recordResponse(_ response: String, source: HermesPromptHistoryEntry.Source = .askHermes) {
        guard UserDefaults.standard.bool(forKey: Self.persistenceEnabledKey) else { return }
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
        if let data = UserDefaults.standard.data(forKey: promptDefaultsKey),
           let decoded = try? JSONDecoder().decode([HermesPromptHistoryEntry].self, from: data) {
            entries = Array(decoded.map(\.redactedForRetention).prefix(maxEntries))
        }
        if let data = UserDefaults.standard.data(forKey: responseDefaultsKey),
           let decoded = try? JSONDecoder().decode([HermesResponseHistoryEntry].self, from: data) {
            responseEntries = Array(decoded.map(\.redactedForRetention).prefix(maxEntries))
        }
    }
    private func persistPrompts() {
        _ = HermesEncryptedRetentionStore.save(entries.map(\.redactedForRetention), forKey: promptDefaultsKey)
        UserDefaults.standard.removeObject(forKey: promptDefaultsKey)
    }
    private func persistResponses() {
        _ = HermesEncryptedRetentionStore.save(responseEntries.map(\.redactedForRetention), forKey: responseDefaultsKey)
        UserDefaults.standard.removeObject(forKey: responseDefaultsKey)
    }
}

struct HermesPromptHistoryEntry: Identifiable, Codable, Equatable, Sendable {
    enum Source: String, Codable, Sendable {
        case askHermes
        case chatWithHermes
        var displayName: String {
            switch self {
            case .askHermes: String(localized: "Ask Hermes")
            case .chatWithHermes: String(localized: "Chat with Hermes")
            }
        }
        var systemImage: String {
            switch self {
            case .askHermes: "dot.radiowaves.left.and.right"
            case .chatWithHermes: "text.bubble"
            }
        }
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

    var redactedForRetention: HermesPromptHistoryEntry {
        HermesPromptHistoryEntry(prompt: HermesSecretRedactor.redact(prompt), source: source)
    }
}

struct HermesResponseHistoryEntry: Identifiable, Codable, Equatable, Sendable {
    let id: UUID; let response: String; let source: HermesPromptHistoryEntry.Source; let createdAt: Date; let fingerprint: String
    init(response: String, source: HermesPromptHistoryEntry.Source) { self.id = UUID(); self.response = response; self.source = source; self.createdAt = Date(); self.fingerprint = Self.makeFingerprint(response: response, source: source) }
    private static func makeFingerprint(response: String, source: HermesPromptHistoryEntry.Source) -> String { source.rawValue + ":response:" + SHA256.hash(data: Data((source.rawValue + ":response:" + response).utf8)).map { String(format: "%02x", $0) }.joined() }
    var title: String { HermesPromptHistoryEntry.normalizedTitle(from: response, fallback: String(localized: "Response")) }
    var subtitle: String { String(localized: "\(response.count) characters") }
    var redactedForRetention: HermesResponseHistoryEntry {
        HermesResponseHistoryEntry(response: HermesSecretRedactor.redact(response), source: source)
    }
}
