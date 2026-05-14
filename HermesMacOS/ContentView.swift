//
//  ContentView.swift
//  HermesMacOS
//

import SwiftUI

enum HermesAskWorkspaceAttention {
    case streaming
    case completed
    case failed
}

enum HermesTopTabAttention {
    case streaming
    case completed
    case failed
}

enum HermesAppTheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

@MainActor
@Observable
final class HermesAskWorkspace: Identifiable {
    let id = UUID()
    let number: Int
    var draft: HermesRequestDraft
    let session = HermesResponsesSession()
    private var acknowledgedCompletionToken = ""
    private var acknowledgedFailureToken = ""

    init(number: Int, draft: HermesRequestDraft = HermesSettingsStore.loadDraft()) {
        self.number = number
        self.draft = draft
    }

    var attention: HermesAskWorkspaceAttention? {
        if session.isStreaming { return .streaming }
        if let token = failureToken, token != acknowledgedFailureToken { return .failed }
        if let token = completionToken, token != acknowledgedCompletionToken { return .completed }
        return nil
    }

    func acknowledgeCurrentStatus() {
        if let token = completionToken { acknowledgedCompletionToken = token }
        if let token = failureToken { acknowledgedFailureToken = token }
    }

    private var completionToken: String? {
        guard session.connectionStatus == "Completed", session.hasActiveConversation else { return nil }
        let responseID = session.latestResponseID.trimmingCharacters(in: .whitespacesAndNewlines)
        if !responseID.isEmpty { return responseID }
        return "completed-\(session.entries.count)-\(session.eventCount)"
    }

    private var failureToken: String? {
        guard session.connectionStatus == "Failed" || !session.lastErrorMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let error = session.lastErrorMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        if !error.isEmpty { return error }
        return "failed-\(session.entries.count)-\(session.eventCount)"
    }
}

struct HermesSideTabButton: View {
    let tab: HermesMacOSTab
    let isSelected: Bool
    let foregroundColor: Color
    let backgroundColor: Color
    let backgroundOpacity: Double
    let shadowColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: tab.systemImage)
                .font(.system(size: 23, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .frame(width: 44, height: 44)
                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(foregroundColor)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(backgroundColor.opacity(backgroundOpacity))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(isSelected ? Color.white.opacity(0.24) : Color.white.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: shadowColor, radius: 8, y: 3)
        .help(tab.title)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

struct HermesSideTabSwitcher: View {
    @Binding var selectedTab: HermesMacOSTab
    let askAttention: HermesAskWorkspaceAttention?
    let chatAttention: HermesTopTabAttention?
    let historyAttention: HermesTopTabAttention?
    let onSelectTab: (HermesMacOSTab) -> Void
    @State private var isAskBlinking = false
    @State private var isChatBlinking = false
    @State private var isHistoryBlinking = false

    private var activeAskAttention: HermesAskWorkspaceAttention? {
        switch askAttention {
        case .completed:
            return .completed
        case .streaming:
            return .streaming
        case .failed, nil:
            return nil
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            ForEach(HermesMacOSTab.allCases) { tab in
                HermesSideTabButton(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    foregroundColor: foregroundColor(for: tab),
                    backgroundColor: backgroundColor(for: tab),
                    backgroundOpacity: backgroundOpacity(for: tab),
                    shadowColor: shadowColor(for: tab)
                ) {
                    selectedTab = tab
                    onSelectTab(tab)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 16)
        .frame(width: 66)
        .frame(maxHeight: .infinity)
        .hermesGlassPanel(tint: Color.hermesSurface.opacity(0.56), cornerRadius: 0)
        .task(id: activeAskAttention) {
            await runAskBlinkLoop(for: activeAskAttention)
        }
        .task(id: chatAttention) {
            await runChatBlinkLoop(for: chatAttention)
        }
        .task(id: historyAttention) {
            await runHistoryBlinkLoop(for: historyAttention)
        }
    }

    private func foregroundColor(for tab: HermesMacOSTab) -> Color {
        if tab == .ask, activeAskAttention != nil { return .white }
        if tab == .chat, chatAttention != nil { return .white }
        if tab == .history, historyAttention != nil { return .white }
        return selectedTab == tab ? .white : .primary
    }

    private func backgroundColor(for tab: HermesMacOSTab) -> Color {
        if tab == .ask {
            switch activeAskAttention {
            case .completed:
                return .green
            case .streaming:
                return .hermesOrange
            case .failed, nil:
                break
            }
        }
        if tab == .chat {
            switch chatAttention {
            case .completed:
                return .green
            case .streaming:
                return .hermesOrange
            case .failed:
                return .hermesDestructive
            case nil:
                break
            }
        }
        if tab == .history {
            switch historyAttention {
            case .completed:
                return .green
            case .streaming:
                return .hermesOrange
            case .failed:
                return .hermesDestructive
            case nil:
                break
            }
        }
        return selectedTab == tab ? .hermesActionBlue : .hermesSurface.opacity(0.58)
    }

    private func backgroundOpacity(for tab: HermesMacOSTab) -> Double {
        if tab == .ask && activeAskAttention == .streaming && isAskBlinking { return 0.45 }
        if tab == .chat && chatAttention == .streaming && isChatBlinking { return 0.45 }
        if tab == .history && historyAttention == .streaming && isHistoryBlinking { return 0.45 }
        return 1.0
    }

    private func shadowColor(for tab: HermesMacOSTab) -> Color {
        if tab == .ask {
            switch activeAskAttention {
            case .completed:
                return .green.opacity(0.24)
            case .streaming:
                return .hermesOrange.opacity(0.24)
            case .failed, nil:
                break
            }
        }
        if tab == .chat {
            switch chatAttention {
            case .completed:
                return .green.opacity(0.24)
            case .streaming:
                return .hermesOrange.opacity(0.24)
            case .failed:
                return .hermesDestructive.opacity(0.24)
            case nil:
                break
            }
        }
        if tab == .history {
            switch historyAttention {
            case .completed:
                return .green.opacity(0.24)
            case .streaming:
                return .hermesOrange.opacity(0.24)
            case .failed:
                return .hermesDestructive.opacity(0.24)
            case nil:
                break
            }
        }
        return selectedTab == tab ? .hermesActionBlue.opacity(0.24) : .clear
    }

    @MainActor
    private func runAskBlinkLoop(for attention: HermesAskWorkspaceAttention?) async {
        await runBlinkLoop(isStreaming: attention == .streaming) { isAskBlinking = $0 }
    }

    @MainActor
    private func runChatBlinkLoop(for attention: HermesTopTabAttention?) async {
        await runBlinkLoop(isStreaming: attention == .streaming) { isChatBlinking = $0 }
    }

    @MainActor
    private func runHistoryBlinkLoop(for attention: HermesTopTabAttention?) async {
        await runBlinkLoop(isStreaming: attention == .streaming) { isHistoryBlinking = $0 }
    }

    @MainActor
    private func runBlinkLoop(isStreaming: Bool, setPhase: @escaping (Bool) -> Void) async {
        guard isStreaming else {
            setPhase(false)
            return
        }

        setPhase(false)
        while !Task.isCancelled {
            withAnimation(.easeInOut(duration: 0.7)) {
                setPhase(true)
            }
            do { try await Task.sleep(nanoseconds: 700_000_000) } catch { break }
            if Task.isCancelled { break }
            withAnimation(.easeInOut(duration: 0.7)) {
                setPhase(false)
            }
            do { try await Task.sleep(nanoseconds: 700_000_000) } catch { break }
        }
        setPhase(false)
    }
}

struct ContentView: View {
    @Environment(\.colorScheme) private var systemColorScheme
    @AppStorage("hermes.appTheme") private var appTheme: HermesAppTheme = .system
    @State private var apiSettings = HermesSettingsStore.loadAPISettings()
    @State private var askWorkspaces = [HermesAskWorkspace(number: 1)]
    @State private var selectedAskWorkspaceID: HermesAskWorkspace.ID?
    @State private var chatDraft = HermesSettingsStore.loadChatDraft()
    @State private var chatSession = HermesChatSession()
    @State private var clipboardHistory = HermesClipboardHistoryStore()
    @State private var promptHistory = HermesPromptHistoryStore()
    @State private var historySearchSession = HermesDashboardHistorySearchSession()
    @State private var installationSession = HermesInstallationSession()
    @State private var configurationWebViewStore = HermesDashboardWebViewStore()
    @State private var selectedTab = HermesMacOSTab.ask
    @State private var acknowledgedChatCompletionToken = ""
    @State private var acknowledgedChatFailureToken = ""

    private var selectedAskWorkspace: HermesAskWorkspace {
        if let selectedAskWorkspaceID,
           let workspace = askWorkspaces.first(where: { $0.id == selectedAskWorkspaceID }) {
            return workspace
        }
        return askWorkspaces[0]
    }

    private var askTabAttention: HermesAskWorkspaceAttention? {
        if askWorkspaces.contains(where: { $0.attention == .completed }) { return .completed }
        if askWorkspaces.contains(where: { $0.attention == .streaming }) { return .streaming }
        return nil
    }

    private var historyTabAttention: HermesTopTabAttention? {
        historySearchSession.tabAttention
    }

    private var chatTabAttention: HermesTopTabAttention? {
        if chatSession.isStreaming { return .streaming }
        if let token = chatFailureToken, token != acknowledgedChatFailureToken { return .failed }
        if let token = chatCompletionToken, token != acknowledgedChatCompletionToken { return .completed }
        return nil
    }

    private var effectiveColorScheme: ColorScheme {
        appTheme.colorScheme ?? systemColorScheme
    }

    private var chatCompletionToken: String? {
        guard chatSession.connectionStatus == "Completed", !chatSession.entries.isEmpty else { return nil }
        let sessionID = chatSession.activeChatSessionID.trimmingCharacters(in: .whitespacesAndNewlines)
        let sessionPart = sessionID.isEmpty ? "chat" : sessionID
        return "completed-\(sessionPart)-\(chatSession.entries.count)-\(chatSession.eventCount)"
    }

    private var chatFailureToken: String? {
        guard chatSession.connectionStatus == "Failed" || !chatSession.lastErrorMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let error = chatSession.lastErrorMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        if !error.isEmpty { return error }
        return "failed-\(chatSession.entries.count)-\(chatSession.eventCount)"
    }

    var body: some View {
        HStack(spacing: 0) {
            HermesSideTabSwitcher(
                selectedTab: $selectedTab,
                askAttention: askTabAttention,
                chatAttention: chatTabAttention,
                historyAttention: historyTabAttention,
                onSelectTab: handleTopTabSelection
            )
            activeTabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(HermesLiquidGlassCanvas().ignoresSafeArea())
        .preferredColorScheme(appTheme.colorScheme)
        .tint(.hermesActionBlue)
        .onAppear {
            if selectedAskWorkspaceID == nil { selectedAskWorkspaceID = askWorkspaces.first?.id }
        }
        .task {
            await clipboardHistory.runMonitoringLoop()
        }
        .onChange(of: apiSettings) { _, newValue in HermesSettingsStore.saveAPISettings(newValue) }
        .onChange(of: chatDraft) { _, newValue in HermesSettingsStore.saveChatDraft(newValue) }
    }

    @ViewBuilder
    private var activeTabContent: some View {
        switch selectedTab {
        case .ask:
            HermesAskWorkspacesView(
                apiSettings: $apiSettings,
                workspaces: askWorkspaces,
                selectedWorkspaceID: selectedWorkspaceBinding,
                promptHistory: promptHistory,
                onSelectWorkspace: selectAskWorkspace,
                onAddWorkspace: addAskWorkspace,
                onDeleteWorkspace: deleteAskWorkspace
            )
        case .chat:
            HermesChatConsoleView(
                apiSettings: $apiSettings,
                chatDraft: $chatDraft,
                chatSession: chatSession,
                promptHistoryStore: promptHistory
            )
        case .history:
            HermesHistoryView(
                apiSettings: $apiSettings,
                searchSession: historySearchSession,
                isResponsesStreaming: askWorkspaces.contains(where: { $0.session.isSending }),
                isChatStreaming: chatSession.isSending,
                onResumeResponses: resumeConversationInResponses,
                onResumeChat: resumeConversationInChat
            )
        case .configuration:
            HermesConfigurationView(webViewStore: configurationWebViewStore, colorScheme: effectiveColorScheme)
        case .utilities:
            HermesUtilitiesView(
                clipboardHistory: clipboardHistory,
                promptHistory: promptHistory,
                workspaces: askWorkspaces,
                selectedWorkspaceID: selectedWorkspaceBinding,
                chatSession: chatSession,
                installationSession: installationSession,
                onReviewInstallationWithHermes: reviewInstallationWithHermes
            )
        }
    }

    private var selectedWorkspaceBinding: Binding<HermesAskWorkspace.ID> {
        Binding(
            get: { selectedAskWorkspaceID ?? askWorkspaces[0].id },
            set: { selectedAskWorkspaceID = $0 }
        )
    }

    private func addAskWorkspace() {
        let nextNumber = (askWorkspaces.map(\.number).max() ?? 0) + 1
        let workspace = HermesAskWorkspace(number: nextNumber, draft: selectedAskWorkspace.draft)
        askWorkspaces.append(workspace)
        selectedAskWorkspaceID = workspace.id
    }

    private func selectAskWorkspace(_ workspace: HermesAskWorkspace) {
        workspace.acknowledgeCurrentStatus()
        selectedAskWorkspaceID = workspace.id
    }

    private func deleteAskWorkspace(_ workspace: HermesAskWorkspace) {
        guard !workspace.session.isStreaming,
              let deletedIndex = askWorkspaces.firstIndex(where: { $0.id == workspace.id }) else { return }

        let wasSelected = selectedAskWorkspaceID == workspace.id
        askWorkspaces.remove(at: deletedIndex)

        if askWorkspaces.isEmpty {
            let replacement = HermesAskWorkspace(number: 1, draft: workspace.draft)
            askWorkspaces = [replacement]
            selectedAskWorkspaceID = replacement.id
        } else if wasSelected {
            let replacementIndex = min(deletedIndex, askWorkspaces.count - 1)
            selectedAskWorkspaceID = askWorkspaces[replacementIndex].id
        }
    }

    private func resumeConversationInResponses(_ result: HermesDashboardConversationResult) {
        let workspace = selectedAskWorkspace
        guard !workspace.session.isSending else { return }
        workspace.session.resumeConversation(from: result)
        selectedTab = .ask
    }

    private func resumeConversationInChat(_ result: HermesDashboardConversationResult) {
        guard !chatSession.isSending else { return }
        chatSession.resumeConversation(from: result)
        selectedTab = .chat
    }

    private func handleTopTabSelection(_ tab: HermesMacOSTab) {
        if tab == .chat { acknowledgeChatTabAttention() }
        if tab == .history { historySearchSession.acknowledgeTabAttention() }
    }

    private func acknowledgeChatTabAttention() {
        if let token = chatCompletionToken { acknowledgedChatCompletionToken = token }
        if let token = chatFailureToken { acknowledgedChatFailureToken = token }
    }

    private func reviewInstallationWithHermes(_ prompt: String) {
        let nextNumber = (askWorkspaces.map(\.number).max() ?? 0) + 1
        var draft = selectedAskWorkspace.draft
        draft.userPrompt = prompt
        let workspace = HermesAskWorkspace(number: nextNumber, draft: draft)
        askWorkspaces.append(workspace)
        selectedAskWorkspaceID = workspace.id
        selectedTab = .ask
    }
}

enum HermesMacOSTab: String, CaseIterable, Identifiable, Hashable {
    case ask
    case chat
    case history
    case configuration
    case utilities

    var id: Self { self }

    var title: String {
        switch self {
        case .ask: "Ask Hermes"
        case .chat: "Chat with Hermes"
        case .history: "History"
        case .configuration: "Configuration"
        case .utilities: "Utilities"
        }
    }

    var systemImage: String {
        switch self {
        case .ask: "dot.radiowaves.left.and.right"
        case .chat: "text.bubble"
        case .history: "clock.arrow.circlepath"
        case .configuration: "gearshape.2"
        case .utilities: "wrench.and.screwdriver"
        }
    }
}
