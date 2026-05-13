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

struct ContentView: View {
    @AppStorage("hermes.appTheme") private var appTheme: HermesAppTheme = .system
    @State private var apiSettings = HermesSettingsStore.loadAPISettings()
    @State private var askWorkspaces = [HermesAskWorkspace(number: 1)]
    @State private var selectedAskWorkspaceID: HermesAskWorkspace.ID?
    @State private var clipboardHistory = HermesClipboardHistoryStore()
    @State private var promptHistory = HermesPromptHistoryStore()
    @State private var historySearchSession = HermesDashboardHistorySearchSession()
    @State private var selectedTab = HermesMacOSTab.ask

    private var selectedAskWorkspace: HermesAskWorkspace {
        if let selectedAskWorkspaceID,
           let workspace = askWorkspaces.first(where: { $0.id == selectedAskWorkspaceID }) {
            return workspace
        }
        return askWorkspaces[0]
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HermesAskWorkspacesView(
                apiSettings: $apiSettings,
                workspaces: askWorkspaces,
                selectedWorkspaceID: selectedWorkspaceBinding,
                promptHistory: promptHistory,
                onSelectWorkspace: selectAskWorkspace,
                onAddWorkspace: addAskWorkspace,
                onDeleteWorkspace: deleteAskWorkspace
            )
                .tabItem { Label("Ask Hermes", systemImage: "dot.radiowaves.left.and.right") }
                .tag(HermesMacOSTab.ask)

            HermesHistoryView(
                apiSettings: $apiSettings,
                searchSession: historySearchSession,
                isResponsesStreaming: askWorkspaces.contains(where: { $0.session.isSending }),
                onResumeResponses: resumeConversationInResponses
            )
            .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
            .tag(HermesMacOSTab.history)

            HermesUtilitiesView(
                clipboardHistory: clipboardHistory,
                promptHistory: promptHistory,
                workspaces: askWorkspaces,
                selectedWorkspaceID: selectedWorkspaceBinding
            )
            .tabItem { Label("Utilities", systemImage: "wrench.and.screwdriver") }
            .tag(HermesMacOSTab.utilities)
        }
        .preferredColorScheme(appTheme.colorScheme)
        .tint(.hermesActionBlue)
        .onAppear {
            if selectedAskWorkspaceID == nil { selectedAskWorkspaceID = askWorkspaces.first?.id }
        }
        .task {
            await clipboardHistory.runMonitoringLoop()
        }
        .onChange(of: apiSettings) { _, newValue in HermesSettingsStore.saveAPISettings(newValue) }
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
}

enum HermesMacOSTab: Hashable {
    case ask
    case history
    case utilities
}
