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

    init(number: Int, draft: HermesRequestDraft = HermesRequestDraft()) {
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
    let approvalsAttention: HermesTopTabAttention?
    let onSelectTab: (HermesMacOSTab) -> Void
    @State private var reachabilityMonitor = HermesReachabilityMonitor()
    @State private var isAskBlinking = false
    @State private var isChatBlinking = false
    @State private var isHistoryBlinking = false
    @State private var isApprovalsBlinking = false

    private var activeAskAttention: HermesAskWorkspaceAttention? {
        switch askAttention {
        case .failed:
            return .failed
        case .completed:
            return .completed
        case .streaming:
            return .streaming
        case nil:
            return nil
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            HermesReachabilityLEDRow(monitor: reachabilityMonitor)
                .padding(.bottom, 2)

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
        .task {
            await reachabilityMonitor.runAgentAPILoop()
        }
        .task {
            await reachabilityMonitor.runDashboardLoop()
        }
        .task(id: activeAskAttention) {
            await runAskBlinkLoop(for: activeAskAttention)
        }
        .task(id: chatAttention) {
            await runChatBlinkLoop(for: chatAttention)
        }
        .task(id: historyAttention) {
            await runHistoryBlinkLoop(for: historyAttention)
        }
        .task(id: approvalsAttention) {
            await runApprovalsBlinkLoop(for: approvalsAttention)
        }
    }

    private func foregroundColor(for tab: HermesMacOSTab) -> Color {
        if tab == .ask, activeAskAttention != nil { return .white }
        if tab == .chat, chatAttention != nil { return .white }
        if tab == .history, historyAttention != nil { return .white }
        if tab == .approvals, approvalsAttention != nil { return .white }
        return selectedTab == tab ? .white : .primary
    }

    private func backgroundColor(for tab: HermesMacOSTab) -> Color {
        if tab == .ask {
            switch activeAskAttention {
            case .failed:
                return .hermesDestructive
            case .completed:
                return .green
            case .streaming:
                return .hermesOrange
            case nil:
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
        if tab == .approvals {
            switch approvalsAttention {
            case .streaming:
                return .hermesOrange
            case .completed:
                return .green
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
        if tab == .approvals && approvalsAttention == .streaming && isApprovalsBlinking { return 0.45 }
        return 1.0
    }

    private func shadowColor(for tab: HermesMacOSTab) -> Color {
        if tab == .ask {
            switch activeAskAttention {
            case .failed:
                return .hermesDestructive.opacity(0.24)
            case .completed:
                return .green.opacity(0.24)
            case .streaming:
                return .hermesOrange.opacity(0.24)
            case nil:
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
        if tab == .approvals {
            switch approvalsAttention {
            case .streaming:
                return .hermesOrange.opacity(0.24)
            case .completed:
                return .green.opacity(0.24)
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
    private func runApprovalsBlinkLoop(for attention: HermesTopTabAttention?) async {
        await runBlinkLoop(isStreaming: attention == .streaming) { isApprovalsBlinking = $0 }
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

private struct HermesReachabilityLEDRow: View {
    let monitor: HermesReachabilityMonitor

    var body: some View {
        HStack(spacing: 8) {
            HermesReachabilityLED(title: "Hermes agent API", isReachable: monitor.agentAPIIsReachable)
            HermesReachabilityLED(title: "Hermes dashboard", isReachable: monitor.dashboardIsReachable)
        }
        .frame(width: 44, height: 16)
        .accessibilityElement(children: .contain)
    }
}

private struct HermesReachabilityLED: View {
    let title: String
    let isReachable: Bool

    private var statusText: String {
        isReachable ? "reachable" : "unreachable"
    }

    var body: some View {
        Circle()
            .fill(isReachable ? Color.green : Color.hermesDestructive)
            .frame(width: 10, height: 10)
            .overlay(Circle().strokeBorder(Color.white.opacity(0.34), lineWidth: 1))
            .shadow(color: (isReachable ? Color.green : Color.hermesDestructive).opacity(0.36), radius: 4)
            .help("\(title) is \(statusText)")
            .accessibilityLabel("\(title) \(statusText)")
    }
}

private struct HermesContentPersistedStartupValues: Sendable {
    var apiSettings: HermesAPISettings
    var dashboardURL: String
    var requestDraft: HermesRequestDraft
    var chatDraft: HermesChatDraft
    var lastResponseID: String
    var lastResponseTitle: String
    var lastChatSessionID: String
    var lastChatSessionTitle: String

    static func load() -> HermesContentPersistedStartupValues {
        HermesContentPersistedStartupValues(
            apiSettings: HermesSettingsStore.loadAPISettings(),
            dashboardURL: UserDefaults.standard.string(forKey: hermesDashboardURLStorageKey) ?? defaultHermesDashboardURL,
            requestDraft: HermesSettingsStore.loadDraft(),
            chatDraft: HermesSettingsStore.loadChatDraft(),
            lastResponseID: HermesSettingsStore.loadLastResponsesSessionID(),
            lastResponseTitle: HermesSettingsStore.loadLastResponsesSessionTitle(),
            lastChatSessionID: HermesSettingsStore.loadLastChatSessionID(),
            lastChatSessionTitle: HermesSettingsStore.loadLastChatSessionTitle()
        )
    }
}

struct ContentView: View {
    @Environment(\.colorScheme) private var systemColorScheme
    @AppStorage("hermes.appTheme") private var appTheme: HermesAppTheme = .system
    @State private var apiSettings = HermesSettingsStore.loadAPISettings()
    @State private var dashboardURL = UserDefaults.standard.string(forKey: hermesDashboardURLStorageKey) ?? defaultHermesDashboardURL
    @State private var windowID = UUID()
    @State private var connectionCenter = HermesWindowConnectionCenter.shared
    @State private var askWorkspaces = [HermesAskWorkspace(number: 1, draft: HermesRequestDraft())]
    @State private var selectedAskWorkspaceID: HermesAskWorkspace.ID?
    @State private var chatDraft = HermesChatDraft()
    @State private var chatSession = HermesChatSession()
    @State private var clipboardHistory = HermesClipboardHistoryStore()
    @State private var promptHistory = HermesPromptHistoryStore()
    @State private var historySearchSession = HermesDashboardHistorySearchSession()
    @State private var sessionsStore = HermesSessionsStore()
    @State private var approvalsInboxStore = HermesApprovalsInboxStore()
    @State private var kanbanStore = HermesKanbanStore()
    @State private var tuiWorkspaces = [HermesTUIWorkspace(number: 1)]
    @State private var selectedTUIWorkspaceID: HermesTUIWorkspace.ID?
    @State private var installationSession = HermesInstallationSession()
    @State private var configurationWebViewStore = HermesDashboardWebViewStore()
    @State private var selectedTab = HermesMacOSTab.ask
    @State private var acknowledgedChatCompletionToken = ""
    @State private var acknowledgedChatFailureToken = ""
    @State private var didLoadPersistedStartupValues = false

    private var selectedAskWorkspace: HermesAskWorkspace {
        if let selectedAskWorkspaceID,
           let workspace = askWorkspaces.first(where: { $0.id == selectedAskWorkspaceID }) {
            return workspace
        }
        return askWorkspaces[0]
    }

    private var selectedTUIWorkspace: HermesTUIWorkspace {
        if let selectedTUIWorkspaceID,
           let workspace = tuiWorkspaces.first(where: { $0.id == selectedTUIWorkspaceID }) {
            return workspace
        }
        return tuiWorkspaces[0]
    }

    private var askTabAttention: HermesAskWorkspaceAttention? {
        if askWorkspaces.contains(where: { $0.attention == .failed }) { return .failed }
        if askWorkspaces.contains(where: { $0.attention == .completed }) { return .completed }
        if askWorkspaces.contains(where: { $0.attention == .streaming }) { return .streaming }
        return nil
    }

    private var historyTabAttention: HermesTopTabAttention? {
        historySearchSession.tabAttention
    }

    private var approvalsTabAttention: HermesTopTabAttention? {
        approvalsInboxStore.pendingCount > 0 ? .streaming : nil
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

    private var connectedHostName: String {
        HermesHostEndpoints.displayHost(from: apiSettings.baseURL)
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
                approvalsAttention: approvalsTabAttention,
                onSelectTab: handleTopTabSelection
            )
            activeTabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(HermesLiquidGlassCanvas().ignoresSafeArea())
        .preferredColorScheme(appTheme.colorScheme)
        .tint(.hermesActionBlue)
        .onAppear {
            _ = connectionCenter.registerWindow(id: windowID, apiSettings: apiSettings, dashboardURL: dashboardURL)
            if selectedAskWorkspaceID == nil { selectedAskWorkspaceID = askWorkspaces.first?.id }
            if selectedTUIWorkspaceID == nil { selectedTUIWorkspaceID = tuiWorkspaces.first?.id }
        }
        .onDisappear {
            connectionCenter.unregisterWindow(id: windowID)
        }
        .task {
            await loadPersistedStartupValuesIfNeeded()
        }
        .task {
            await promptHistory.loadPersistedEntriesIfNeeded()
        }
        .task {
            await clipboardHistory.runMonitoringLoop()
        }
        .task(id: dashboardURL + apiSettings.baseURL) {
            await approvalsInboxStore.runAutoRefreshLoop(dashboardBaseURL: dashboardURL, apiSettings: apiSettings)
        }
        .onChange(of: apiSettings) { _, newValue in
            HermesSettingsStore.saveAPISettings(newValue)
            connectionCenter.updateWindow(id: windowID, apiSettings: newValue, dashboardURL: dashboardURL)
        }
        .onChange(of: dashboardURL) { _, newValue in
            UserDefaults.standard.set(newValue, forKey: hermesDashboardURLStorageKey)
            connectionCenter.updateWindow(id: windowID, apiSettings: apiSettings, dashboardURL: newValue)
        }
        .onChange(of: chatDraft) { _, newValue in HermesSettingsStore.saveChatDraft(newValue) }
        .onReceive(NotificationCenter.default.publisher(for: .hermesWindowConnectionDidChange)) { notification in
            guard let changedWindowID = notification.object as? UUID, changedWindowID == windowID,
                  let connection = connectionCenter.connection(id: windowID)
            else { return }
            apiSettings = connection.apiSettings
            dashboardURL = connection.dashboardURL
        }
    }

    @ViewBuilder
    private var activeTabContent: some View {
        switch selectedTab {
        case .ask:
            HermesAskWorkspacesView(
                apiSettings: $apiSettings,
                dashboardURL: dashboardURL,
                workspaces: askWorkspaces,
                selectedWorkspaceID: selectedWorkspaceBinding,
                promptHistory: promptHistory,
                connectedHostName: connectedHostName,
                connectedWindowID: windowID,
                onSelectWorkspace: selectAskWorkspace,
                onAddWorkspace: addAskWorkspace,
                onDeleteWorkspace: deleteAskWorkspace
            )
        case .chat:
            HermesChatConsoleView(
                apiSettings: $apiSettings,
                chatDraft: $chatDraft,
                chatSession: chatSession,
                promptHistoryStore: promptHistory,
                dashboardURL: dashboardURL,
                connectedHostName: connectedHostName,
                connectedWindowID: windowID
            )
        case .tuiGateway:
            HermesTUIGatewayWorkspacesView(
                apiSettings: apiSettings,
                dashboardURL: dashboardURL,
                workspaces: tuiWorkspaces,
                selectedWorkspaceID: selectedTUIWorkspaceBinding,
                connectedHostName: connectedHostName,
                connectedWindowID: windowID,
                onSelectWorkspace: selectTUIWorkspace,
                onAddWorkspace: addTUIWorkspace,
                onDeleteWorkspace: deleteTUIWorkspace
            )
        case .history:
            HermesHistoryView(
                apiSettings: $apiSettings,
                dashboardURL: dashboardURL,
                searchSession: historySearchSession,
                isResponsesStreaming: askWorkspaces.contains(where: { $0.session.isSending }),
                isChatStreaming: chatSession.isSending,
                connectedHostName: connectedHostName,
                connectedWindowID: windowID,
                onResumeResponses: resumeConversationInResponses,
                onResumeChat: resumeConversationInChat
            )
        case .sessions:
            HermesSessionsView(
                apiSettings: apiSettings,
                dashboardURL: dashboardURL,
                store: sessionsStore,
                isResponsesStreaming: askWorkspaces.contains(where: { $0.session.isSending }),
                isTUIGatewayBusy: selectedTUIWorkspace.store.isStreaming || selectedTUIWorkspace.store.isConnecting || selectedTUIWorkspace.store.isResumingSession,
                connectedHostName: connectedHostName,
                connectedWindowID: windowID,
                onResumeResponses: resumeConversationInResponses,
                onResumeTUI: resumeSessionInTUIGateway
            )
        case .approvals:
            HermesApprovalsInboxView(
                apiSettings: apiSettings,
                dashboardURL: dashboardURL,
                store: approvalsInboxStore,
                connectedHostName: connectedHostName,
                connectedWindowID: windowID
            )
        case .kanban:
            HermesKanbanView(
                apiSettings: apiSettings,
                dashboardURL: dashboardURL,
                store: kanbanStore,
                connectedHostName: connectedHostName,
                connectedWindowID: windowID
            )
        case .dashboard:
            HermesDashboardView(dashboardURL: dashboardURL, webViewStore: configurationWebViewStore, colorScheme: effectiveColorScheme, connectedHostName: connectedHostName, connectedWindowID: windowID)
        case .configuration:
            HermesConfigurationView(apiSettings: apiSettings, dashboardURL: dashboardURL, connectedHostName: connectedHostName, connectedWindowID: windowID)
        case .utilities:
            HermesUtilitiesView(
                clipboardHistory: clipboardHistory,
                promptHistory: promptHistory,
                workspaces: askWorkspaces,
                selectedWorkspaceID: selectedWorkspaceBinding,
                chatSession: chatSession,
                installationSession: installationSession,
                connectedHostName: connectedHostName,
                connectedWindowID: windowID,
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

    private var selectedTUIWorkspaceBinding: Binding<HermesTUIWorkspace.ID> {
        Binding(
            get: { selectedTUIWorkspaceID ?? tuiWorkspaces[0].id },
            set: { selectedTUIWorkspaceID = $0 }
        )
    }

    private func loadPersistedStartupValuesIfNeeded() async {
        guard !didLoadPersistedStartupValues else { return }
        do {
            try await HermesSecretUnlockGate.shared.unlockIfNeeded()
        } catch {
            return
        }
        didLoadPersistedStartupValues = true
        let values = await Task.detached(priority: .userInitiated) {
            HermesContentPersistedStartupValues.load()
        }.value
        apiSettings = values.apiSettings
        dashboardURL = values.dashboardURL
        chatDraft = values.chatDraft
        if let firstWorkspace = askWorkspaces.first {
            firstWorkspace.draft = values.requestDraft
            firstWorkspace.session.lastKnownResponseID = values.lastResponseID
            firstWorkspace.session.lastKnownResponseTitle = values.lastResponseTitle
        }
        chatSession.lastKnownChatSessionID = values.lastChatSessionID
        chatSession.lastKnownChatSessionTitle = values.lastChatSessionTitle
        connectionCenter.updateWindow(id: windowID, apiSettings: values.apiSettings, dashboardURL: values.dashboardURL)
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

    private func addTUIWorkspace() {
        let nextNumber = (tuiWorkspaces.map(\.number).max() ?? 0) + 1
        let workspace = HermesTUIWorkspace(number: nextNumber)
        tuiWorkspaces.append(workspace)
        selectedTUIWorkspaceID = workspace.id
    }

    private func selectTUIWorkspace(_ workspace: HermesTUIWorkspace) {
        workspace.acknowledgeCurrentStatus()
        selectedTUIWorkspaceID = workspace.id
    }

    private func deleteTUIWorkspace(_ workspace: HermesTUIWorkspace) {
        guard !workspace.store.isStreaming,
              !workspace.store.isConnecting,
              !workspace.store.isResumingSession,
              let deletedIndex = tuiWorkspaces.firstIndex(where: { $0.id == workspace.id }) else { return }

        let wasSelected = selectedTUIWorkspaceID == workspace.id
        workspace.store.disconnect()
        tuiWorkspaces.remove(at: deletedIndex)

        if tuiWorkspaces.isEmpty {
            let replacement = HermesTUIWorkspace(number: 1)
            tuiWorkspaces = [replacement]
            selectedTUIWorkspaceID = replacement.id
        } else if wasSelected {
            let replacementIndex = min(deletedIndex, tuiWorkspaces.count - 1)
            selectedTUIWorkspaceID = tuiWorkspaces[replacementIndex].id
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

    private func resumeSessionInTUIGateway(_ session: HermesAgentSessionSummary) {
        selectedTUIWorkspace.store.resumeStoredSession(session.id, title: session.displayTitle, dashboardBaseURL: dashboardURL, apiSettings: apiSettings)
        selectedTab = .tuiGateway
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
    case tuiGateway
    case history
    case sessions
    case approvals
    case kanban
    case dashboard
    case configuration
    case utilities

    var id: Self { self }

    var title: String {
        switch self {
        case .ask: "Ask Hermes"
        case .chat: "Chat with Hermes"
        case .tuiGateway: "TUI Gateway"
        case .history: "History"
        case .sessions: "Sessions"
        case .approvals: "Approvals Inbox"
        case .kanban: "Kanban"
        case .dashboard: "Hermes Dashboard"
        case .configuration: "Configuration"
        case .utilities: "Utilities"
        }
    }

    var systemImage: String {
        switch self {
        case .ask: "dot.radiowaves.left.and.right"
        case .chat: "text.bubble"
        case .tuiGateway: "terminal.fill"
        case .history: "clock.arrow.circlepath"
        case .sessions: "rectangle.stack"
        case .approvals: "tray.full"
        case .kanban: "rectangle.3.group.bubble.left"
        case .dashboard: "speedometer"
        case .configuration: "gearshape.2"
        case .utilities: "wrench.and.screwdriver"
        }
    }
}
