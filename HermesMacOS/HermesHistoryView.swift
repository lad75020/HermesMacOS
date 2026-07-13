//
//  HermesHistoryView.swift
//  HermesMacOS
//
import Foundation
import SwiftUI

struct HermesHistoryView: View {
    @Binding var apiSettings: HermesAPISettings
    let dashboardURL: String
    @Bindable var searchSession: HermesDashboardHistorySearchSession
    let isResponsesStreaming: Bool
    let isChatStreaming: Bool
    let isTUIGatewayBusy: Bool
    let connectedHostName: String
    let connectedWindowID: UUID
    let onResumeResponses: (HermesDashboardConversationResult) -> Void
    let onResumeChat: (HermesDashboardConversationResult) -> Void
    let onResumeTUI: (HermesDashboardConversationResult) -> Void

    @State private var expandedConversationIDs: Set<String> = []
    @State private var apiProfiles: [HermesAPIProfile] = []
    @State private var selectedProfileFilter = "all"

    var body: some View {
        VStack(spacing: 0) {
            header
            List {
                searchSection
                if searchSession.hasActiveSearch {
                    resultsSection
                } else {
                    ContentUnavailableView(
                        "Search Hermes History",
                        systemImage: "text.magnifyingglass",
                        description: Text("Search the Mac dashboard history to query conversations across all Hermes channels.")
                    )
                }
            }
            .scrollContentBackground(.hidden)
        }
        .background(HermesLiquidGlassCanvas().ignoresSafeArea())
        .task(id: apiSettings.baseURL) { await refreshProfileOptions() }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Label("History", systemImage: "clock.arrow.circlepath")
                .hermesWebsiteTitleFont(size: 22, weight: .bold)
            Spacer()
            HermesConnectedHostLabel(hostName: connectedHostName, windowID: connectedWindowID)
            if searchSession.isDashboardHTTPActive {
                ProgressView().controlSize(.small)
                Text("Dashboard HTTP")
                    .hermesWebsiteLabelFont(size: 11, weight: .bold)
                    .foregroundStyle(Color.hermesSecondaryText)
            }
        }
        .padding(18)
        .hermesGlassPanel(cornerRadius: 0)
    }

    private var searchSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Search all Hermes conversations", text: $searchSession.query, axis: .vertical)
                    .lineLimit(1...3)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(runDashboardSearch)

                HStack(spacing: 10) {
                    HStack(spacing: 6) {
                        Text("Profile")
                            .font(.subheadline)
                        Picker("Profile", selection: $selectedProfileFilter) {
                            ForEach(profileFilterOptions, id: \.value) { option in
                                Text(option.title).tag(option.value)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .controlSize(.small)
                        .disabled(searchSession.isSearching)
                    }
                    .fixedSize()

                    Button(action: runDashboardSearch) {
                        Label(searchSession.isSearching ? String(localized: "Searching…") : String(localized: "Search"), systemImage: "magnifyingglass")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(searchSession.isSearching || searchSession.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .keyboardShortcut(.return, modifiers: [.command])

                    if searchSession.isSearching {
                        Button("Cancel") { searchSession.cancel() }
                            .buttonStyle(.bordered)
                            .keyboardShortcut(.cancelAction)
                    }

                    Spacer()

                    if searchSession.hasActiveSearch {
                        Button("Clear") {
                            searchSession.clear()
                            expandedConversationIDs.removeAll()
                        }
                        .buttonStyle(.bordered)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: String.LocalizationValue(searchSession.status)))
                        .font(.caption)
                        .foregroundStyle(Color.hermesSecondaryText)

                    if searchSession.matchedMessages > 0 || searchSession.matchedSessions > 0 {
                        Text("\(searchSession.matchedMessages) matching messages across \(searchSession.matchedSessions) conversations")
                            .font(.caption2)
                            .foregroundStyle(Color.hermesSecondaryText)
                    }

                    if !searchSession.lastErrorMessage.isEmpty {
                        Text(searchSession.lastErrorMessage)
                            .font(.caption)
                            .foregroundStyle(Color.hermesDestructive)
                    }
                }
            }
            .padding(14)
            .hermesGlassPanel(tint: Color.hermesSurface.opacity(0.58), cornerRadius: 18)
            .padding(.vertical, 4)
        } header: {
            Label("Full-text search", systemImage: "text.magnifyingglass")
        } footer: {
            Text("Searches the Mac dashboard server through /api/sessions/search/conversations. Natural words and SQLite FTS-style queries are accepted; matching sessions are returned as full conversations.")
        }
    }

    private var resultsSection: some View {
        Section {
            if searchSession.isSearching && searchSession.results.isEmpty {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Searching conversations…")
                        .foregroundStyle(Color.hermesSecondaryText)
                }
                .padding(.vertical, 8)
            } else if searchSession.results.isEmpty {
                ContentUnavailableView(
                    "No Matching Conversations",
                    systemImage: "magnifyingglass",
                    description: Text("Try fewer words, a quoted phrase, or a broader FTS query.")
                )
            } else {
                ForEach(searchSession.results) { result in
                    HermesDashboardConversationDisclosure(
                        result: result,
                        isExpanded: bindingForConversation(result.id),
                        isResumeResponsesDisabled: isResponsesStreaming,
                        isResumeChatDisabled: isChatStreaming,
                        isResumeTUIDisabled: isTUIGatewayBusy,
                        onResumeResponses: onResumeResponses,
                        onResumeChat: onResumeChat,
                        onResumeTUI: onResumeTUI
                    )
                }
            }
        } header: {
            Label("Search results", systemImage: "bubble.left.and.text.bubble.right")
        }
    }

    private func runDashboardSearch() {
        expandedConversationIDs.removeAll()
        let limit = selectedProfileFilter == "all" ? 25 : 100
        searchSession.search(dashboardBaseURL: dashboardURL, apiSettings: apiSettings, profileFilter: selectedProfileFilter, limit: limit)
    }

    private var profileFilterOptions: [HermesHistoryProfileFilterOption] {
        var seen = Set(["all", "default"])
        var options = [HermesHistoryProfileFilterOption(title: String(localized: "All"), value: "all"), HermesHistoryProfileFilterOption(title: String(localized: "Default"), value: "default")]
        let namedProfiles = apiProfiles.filter { !$0.isDefault }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        for profile in namedProfiles {
            let value = profile.id.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { continue }
            let key = value.lowercased()
            guard !seen.contains(key) else { continue }
            let title = profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? value : profile.name
            options.append(HermesHistoryProfileFilterOption(title: title, value: value))
            seen.insert(key)
        }
        return options
    }

    private func refreshProfileOptions() async {
        do {
            apiProfiles = try await HermesAPIProfilesClient.fetchProfiles(apiSettings: apiSettings)
            let available = Set(profileFilterOptions.map { $0.value.lowercased() })
            if !available.contains(selectedProfileFilter.lowercased()) { selectedProfileFilter = "all" }
        } catch {
            apiProfiles = []
            if selectedProfileFilter != "all" && selectedProfileFilter != "default" { selectedProfileFilter = "all" }
        }
    }

    private func bindingForConversation(_ id: String) -> Binding<Bool> {
        Binding(
            get: { expandedConversationIDs.contains(id) },
            set: { isExpanded in
                if isExpanded { expandedConversationIDs.insert(id) } else { expandedConversationIDs.remove(id) }
            }
        )
    }
}

private struct HermesHistoryProfileFilterOption: Hashable {
    let title: String
    let value: String
}

private struct HermesDashboardConversationDisclosure: View {
    let result: HermesDashboardConversationResult
    @Binding var isExpanded: Bool
    let isResumeResponsesDisabled: Bool
    let isResumeChatDisabled: Bool
    let isResumeTUIDisabled: Bool
    let onResumeResponses: (HermesDashboardConversationResult) -> Void
    let onResumeChat: (HermesDashboardConversationResult) -> Void
    let onResumeTUI: (HermesDashboardConversationResult) -> Void

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Button {
                        onResumeResponses(result)
                    } label: {
                        Label("Resume in Ask Hermes", systemImage: "arrow.uturn.forward.circle")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isResumeResponsesDisabled)
                    .help(isResumeResponsesDisabled ? "Ask Hermes is streaming a response" : "Resume this conversation in Ask Hermes")

                    Button {
                        onResumeChat(result)
                    } label: {
                        Label("Resume in Chat with Hermes", systemImage: "text.bubble")
                    }
                    .buttonStyle(.bordered)
                    .disabled(isResumeChatDisabled)
                    .help(isResumeChatDisabled ? "Chat with Hermes is streaming a response" : "Resume this conversation in Chat with Hermes")
                }

                ForEach(result.displayMessages) { message in
                    HermesDashboardConversationMessageRow(message: message)
                }
            }
            .padding(.top, 10)
        } label: {
            HStack(alignment: .center, spacing: 12) {
                HermesDashboardConversationSummary(result: result)
                Spacer(minLength: 8)
                Menu {
                    Button {
                        onResumeResponses(result)
                    } label: {
                        Label("Ask Hermes", systemImage: "dot.radiowaves.left.and.right")
                    }
                    .disabled(isResumeResponsesDisabled)

                    Button {
                        onResumeChat(result)
                    } label: {
                        Label("Chat with Hermes", systemImage: "text.bubble")
                    }
                    .disabled(isResumeChatDisabled)

                    Button {
                        onResumeTUI(result)
                    } label: {
                        Label("Resume to TUI Gateway", systemImage: "terminal.fill")
                    }
                    .disabled(isResumeTUIDisabled)
                } label: {
                    Label("Resume", systemImage: "arrow.uturn.forward")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }
}

private struct HermesDashboardConversationSummary: View {
    let result: HermesDashboardConversationResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label(result.session.displayTitle, systemImage: result.session.sourceIconName)
                    .hermesWebsiteTitleFont(size: 15, weight: .bold)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer()
                Text(String.localizedStringWithFormat(String(localized: "%lld hit%@"), result.matches.count, result.matches.count == 1 ? "" : "s"))
                    .hermesWebsiteLabelFont(size: 11, weight: .bold)
                    .foregroundStyle(Color.hermesActionBlue)
            }

            HStack(spacing: 8) {
                Text(result.session.source?.uppercased() ?? "HERMES")
                if let profile = result.session.profile, !profile.isEmpty { Text(profile) }
                if let model = result.session.model, !model.isEmpty { Text(model) }
                Text("\(result.displayMessages.count) shown")
            }
            .font(.caption)
            .foregroundStyle(Color.hermesSecondaryText)
            .lineLimit(1)

            if let startedAt = result.session.startedAtDate {
                Text(startedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(Color.hermesSecondaryText)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct HermesDashboardConversationMessageRow: View {
    let message: HermesDashboardConversationMessage

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(displayRoleTitle)
                    .hermesWebsiteLabelFont(size: 11, weight: .bold)
                    .foregroundStyle(roleColor)
                if let timestamp = message.timestampDate {
                    Text(timestamp.formatted(date: .omitted, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(Color.hermesSecondaryText)
                }
                if let toolName = message.toolName, !toolName.isEmpty {
                    Text(toolName)
                        .font(.caption2.monospaced())
                        .foregroundStyle(Color.hermesSecondaryText)
                }
            }

            Text(message.content.isEmpty ? "—" : message.content)
                .font(.callout)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .hermesGlassPanel(tint: Color.hermesSurfaceInput.opacity(0.58), cornerRadius: 14)
    }

    private var displayRoleTitle: String {
        switch message.role.lowercased() {
        case "user": String(localized: "Initial prompt")
        case "assistant": String(localized: "Final response")
        default: message.role.capitalized
        }
    }

    private var roleColor: Color {
        switch message.role.lowercased() {
        case "user": .hermesActionBlue
        case "assistant": .green
        case "tool": .hermesOrange
        default: .hermesSecondaryText
        }
    }
}

private extension HermesDashboardConversationResult {
    var displayMessages: [HermesDashboardConversationMessage] {
        let nonEmptyMessages = messages.filter { !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let initialUserPrompt = nonEmptyMessages.first { $0.role.lowercased() == "user" }
        let finalAgentResponse = nonEmptyMessages.last { $0.role.lowercased() == "assistant" }
        switch (initialUserPrompt, finalAgentResponse) {
        case let (user?, assistant?) where user.id != assistant.id: return [user, assistant]
        case let (user?, nil): return [user]
        case let (nil, assistant?): return [assistant]
        case let (user?, assistant?): return [user, assistant]
        case (nil, nil): return []
        }
    }
}

private extension HermesDashboardSessionInfo {
    var displayTitle: String {
        if let title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return title }
        return id
    }

    var startedAtDate: Date? {
        guard let startedAt else { return nil }
        return Date(timeIntervalSince1970: startedAt)
    }

    var sourceIconName: String {
        switch source?.lowercased() {
        case "telegram", "whatsapp", "signal", "discord", "slack", "matrix": "message"
        case "cli": "terminal"
        case "cron": "calendar.badge.clock"
        case "api", "api_server": "network"
        default: "bubble.left.and.text.bubble.right"
        }
    }
}

private extension HermesDashboardConversationMessage {
    var timestampDate: Date? {
        guard let timestamp else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }
}

struct HermesSessionsResponse: Decodable {
    let sessions: [HermesAgentSessionSummary]
    let total: Int
    let limit: Int
    let offset: Int
}

struct HermesSessionMessagesResponse: Decodable {
    let sessionID: String
    let messages: [HermesDashboardConversationMessage]

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case messages
    }
}

enum HermesSessionDisplayOrder: String, CaseIterable, Identifiable {
    case chronological
    case reverseChronological

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chronological: "Oldest first"
        case .reverseChronological: "Newest first"
        }
    }

    var statusDescription: String {
        switch self {
        case .chronological: "oldest first"
        case .reverseChronological: "newest first"
        }
    }
}

private struct HermesHindsightSessionPersistMessage: Encodable, Sendable {
    let role: String
    let content: String
    let timestamp: Double?
}

private struct HermesHindsightSessionPersistPayload: Encodable, Sendable {
    let sessionID: String
    let title: String
    let source: String
    let profile: String
    let model: String
    let startedAt: Double?
    let endedAt: Double?
    let messages: [HermesHindsightSessionPersistMessage]

    enum CodingKeys: String, CodingKey {
        case title, source, profile, model, messages
        case sessionID = "session_id"
        case startedAt = "started_at"
        case endedAt = "ended_at"
    }
}

private struct HermesHindsightSessionPersistResponse: Decodable, Sendable {
    let success: Bool
    let inserted: Bool
    let alreadyStored: Bool
    let rawTurnID: String?
    let message: String?
    let error: String?
    let userMessages: Int
    let assistantMessages: Int

    enum CodingKeys: String, CodingKey {
        case success, inserted, message, error
        case alreadyStored = "already_stored"
        case rawTurnID = "raw_turn_id"
        case userMessages = "user_messages"
        case assistantMessages = "assistant_messages"
    }
}

struct HermesAgentSessionSummary: Identifiable, Decodable, Equatable {
    let id: String
    let source: String?
    let model: String?
    let title: String?
    let startedAt: Double?
    let endedAt: Double?
    let lastActive: Double?
    let messageCount: Int?
    let preview: String?
    let isActive: Bool?
    let profile: String?
    let endReason: String?

    enum CodingKeys: String, CodingKey {
        case id, source, model, title, preview, profile
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case lastActive = "last_active"
        case messageCount = "message_count"
        case isActive = "is_active"
        case endReason = "end_reason"
    }

    var displayTitle: String {
        for candidate in [title, preview, id] {
            let trimmed = (candidate ?? "").replacingOccurrences(of: "\n", with: " ").split(whereSeparator: { $0.isWhitespace }).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return "Untitled session"
    }

    var startedAtDate: Date? { startedAt.map { Date(timeIntervalSince1970: $0) } }
    var lastActiveDate: Date? { lastActive.map { Date(timeIntervalSince1970: $0) } }

    var sourceIconName: String {
        switch source?.lowercased() {
        case "telegram", "whatsapp", "signal", "discord", "slack", "matrix": "message"
        case "cli": "terminal"
        case "cron": "calendar.badge.clock"
        case "api", "api_server": "network"
        case "tui": "rectangle.and.pencil.and.ellipsis"
        case "tool": "hammer"
        default: "bubble.left.and.text.bubble.right"
        }
    }

    var isCronInitiated: Bool {
        switch source?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "cron", "cronjob", "scheduled", "scheduler": true
        default: false
        }
    }
}

@MainActor
@Observable
final class HermesSessionsStore {
    let pageSize = 10
    var sessions: [HermesAgentSessionSummary] = []
    var total = 0
    var pageIndex = 0
    var displayOrder: HermesSessionDisplayOrder = .chronological
    var isLoading = false
    var status = "Loading sessions"
    var lastErrorMessage = ""
    var isDashboardHTTPActive = false
    var conversationResultsBySessionID: [String: HermesDashboardConversationResult] = [:]
    var loadingConversationIDs: Set<String> = []
    var conversationErrorBySessionID: [String: String] = [:]
    var hindsightPersistingSessionIDs: Set<String> = []
    var hindsightStoredSessionIDs: Set<String> = []
    var hindsightPersistenceMessageBySessionID: [String: String] = [:]

    private var requestTask: Task<Void, Never>?
    private var conversationTasks: [String: Task<Void, Never>] = [:]
    private var hindsightPersistenceTasks: [String: Task<Void, Never>] = [:]
    private var activeRequestID: UUID?

    var pageCount: Int { max(1, Int(ceil(Double(total) / Double(pageSize)))) }
    var canGoPrevious: Bool { !isLoading && pageIndex > 0 }
    var canGoNext: Bool { !isLoading && pageIndex + 1 < pageCount }
    var displayRangeText: String {
        guard total > 0 else { return "No sessions" }
        let start = pageIndex * pageSize + 1
        let end = min(total, start + sessions.count - 1)
        return "\(start)–\(end) of \(total)"
    }

    func refresh(dashboardURL: String, apiSettings: HermesAPISettings) {
        load(page: pageIndex, dashboardURL: dashboardURL, apiSettings: apiSettings)
    }

    func loadFirstPage(dashboardURL: String, apiSettings: HermesAPISettings) {
        load(page: 0, dashboardURL: dashboardURL, apiSettings: apiSettings)
    }

    func nextPage(dashboardURL: String, apiSettings: HermesAPISettings) {
        guard canGoNext else { return }
        load(page: pageIndex + 1, dashboardURL: dashboardURL, apiSettings: apiSettings)
    }

    func previousPage(dashboardURL: String, apiSettings: HermesAPISettings) {
        guard canGoPrevious else { return }
        load(page: pageIndex - 1, dashboardURL: dashboardURL, apiSettings: apiSettings)
    }

    func setDisplayOrder(_ order: HermesSessionDisplayOrder, dashboardURL: String, apiSettings: HermesAPISettings) {
        guard displayOrder != order else { return }
        displayOrder = order
        load(page: 0, dashboardURL: dashboardURL, apiSettings: apiSettings)
    }

    func cancel() {
        requestTask?.cancel()
        conversationTasks.values.forEach { $0.cancel() }
        hindsightPersistenceTasks.values.forEach { $0.cancel() }
        conversationTasks.removeAll()
        hindsightPersistenceTasks.removeAll()
        loadingConversationIDs.removeAll()
        hindsightPersistingSessionIDs.removeAll()
        requestTask = nil
        activeRequestID = nil
        isLoading = false
        status = "Cancelled"
    }

    func loadConversation(for session: HermesAgentSessionSummary, dashboardURL: String, apiSettings: HermesAPISettings, onLoaded: ((HermesDashboardConversationResult) -> Void)? = nil) {
        if let cached = conversationResultsBySessionID[session.id] {
            onLoaded?(cached)
            return
        }
        conversationTasks[session.id]?.cancel()
        loadingConversationIDs.insert(session.id)
        conversationErrorBySessionID[session.id] = nil
        status = "Loading session details"

        conversationTasks[session.id] = Task {
            do {
                let baseURL = try await HermesDashboardClient.shared.resolvedBaseURL(dashboardBaseURL: dashboardURL, apiBaseURL: apiSettings.baseURL)
                isDashboardHTTPActive = true
                var token = try await HermesDashboardClient.shared.sessionToken(baseURL: baseURL, apiSettings: apiSettings)
                isDashboardHTTPActive = false
                let response: HermesSessionMessagesResponse
                do {
                    response = try await Self.fetchSessionMessages(baseURL: baseURL, token: token, apiSettings: apiSettings, sessionID: session.id)
                } catch HermesResponsesError.httpError(401) {
                    isDashboardHTTPActive = true
                    token = try await HermesDashboardClient.shared.sessionToken(baseURL: baseURL, apiSettings: apiSettings, refresh: true)
                    isDashboardHTTPActive = false
                    response = try await Self.fetchSessionMessages(baseURL: baseURL, token: token, apiSettings: apiSettings, sessionID: session.id)
                }
                try Task.checkCancellation()
                let result = Self.conversationResult(for: session, resolvedSessionID: response.sessionID, messages: response.messages)
                conversationResultsBySessionID[session.id] = result
                conversationErrorBySessionID[session.id] = nil
                loadingConversationIDs.remove(session.id)
                conversationTasks[session.id] = nil
                status = "Session details loaded"
                onLoaded?(result)
            } catch is CancellationError {
                isDashboardHTTPActive = false
                if loadingConversationIDs.contains(session.id) {
                    loadingConversationIDs.remove(session.id)
                    conversationTasks[session.id] = nil
                }
            } catch {
                isDashboardHTTPActive = false
                loadingConversationIDs.remove(session.id)
                conversationTasks[session.id] = nil
                conversationErrorBySessionID[session.id] = error.localizedDescription
                status = "Could not load session details"
            }
        }
    }

    func persistSessionToHindsight(for session: HermesAgentSessionSummary, dashboardURL: String, apiSettings: HermesAPISettings) {
        guard !hindsightPersistingSessionIDs.contains(session.id) else { return }
        if hindsightStoredSessionIDs.contains(session.id) {
            hindsightPersistenceMessageBySessionID[session.id] = "Already stored in Hindsight."
            return
        }

        hindsightPersistenceTasks[session.id]?.cancel()
        hindsightPersistingSessionIDs.insert(session.id)
        hindsightPersistenceMessageBySessionID[session.id] = "Preparing Hindsight import…"

        hindsightPersistenceTasks[session.id] = Task {
            do {
                let conversation: HermesDashboardConversationResult
                if let cached = conversationResultsBySessionID[session.id] {
                    conversation = cached
                } else {
                    let baseURL = try await HermesDashboardClient.shared.resolvedBaseURL(dashboardBaseURL: dashboardURL, apiBaseURL: apiSettings.baseURL)
                    isDashboardHTTPActive = true
                    var token = try await HermesDashboardClient.shared.sessionToken(baseURL: baseURL, apiSettings: apiSettings)
                    isDashboardHTTPActive = false
                    let response: HermesSessionMessagesResponse
                    do {
                        response = try await Self.fetchSessionMessages(baseURL: baseURL, token: token, apiSettings: apiSettings, sessionID: session.id)
                    } catch HermesResponsesError.httpError(401) {
                        isDashboardHTTPActive = true
                        token = try await HermesDashboardClient.shared.sessionToken(baseURL: baseURL, apiSettings: apiSettings, refresh: true)
                        isDashboardHTTPActive = false
                        response = try await Self.fetchSessionMessages(baseURL: baseURL, token: token, apiSettings: apiSettings, sessionID: session.id)
                    }
                    try Task.checkCancellation()
                    conversation = Self.conversationResult(for: session, resolvedSessionID: response.sessionID, messages: response.messages)
                    conversationResultsBySessionID[session.id] = conversation
                    conversationErrorBySessionID[session.id] = nil
                }

                let payload = try Self.hindsightPersistencePayload(for: conversation)
                hindsightPersistenceMessageBySessionID[session.id] = "Writing to Hindsight…"
                let outcome = try await Task.detached(priority: .userInitiated) {
                    try Self.runHindsightPersistence(payload: payload, hermesHome: HermesRuntimePaths.defaultHermesHome)
                }.value
                try Task.checkCancellation()
                if outcome.success {
                    hindsightStoredSessionIDs.insert(session.id)
                    hindsightPersistenceMessageBySessionID[session.id] = outcome.message ?? (outcome.alreadyStored ? "Already stored in Hindsight." : "Stored in Hindsight.")
                    status = outcome.alreadyStored ? "Session already stored in Hindsight" : "Session stored in Hindsight"
                } else {
                    let message = outcome.error ?? outcome.message ?? "Hindsight import failed"
                    hindsightPersistenceMessageBySessionID[session.id] = message
                    status = "Could not store session in Hindsight"
                }
            } catch is CancellationError {
                if hindsightPersistingSessionIDs.contains(session.id) {
                    hindsightPersistenceMessageBySessionID[session.id] = "Hindsight import cancelled."
                }
            } catch {
                isDashboardHTTPActive = false
                hindsightPersistenceMessageBySessionID[session.id] = error.localizedDescription
                status = "Could not store session in Hindsight"
            }
            hindsightPersistingSessionIDs.remove(session.id)
            hindsightPersistenceTasks[session.id] = nil
        }
    }

    private func load(page requestedPage: Int, dashboardURL: String, apiSettings: HermesAPISettings) {
        requestTask?.cancel()
        let requestID = UUID()
        activeRequestID = requestID
        isLoading = true
        lastErrorMessage = ""
        status = "Loading sessions"
        let requestedDisplayOrder = displayOrder

        requestTask = Task {
            do {
                let baseURL = try await HermesDashboardClient.shared.resolvedBaseURL(dashboardBaseURL: dashboardURL, apiBaseURL: apiSettings.baseURL)
                isDashboardHTTPActive = true
                var token = try await HermesDashboardClient.shared.sessionToken(baseURL: baseURL, apiSettings: apiSettings)
                isDashboardHTTPActive = false
                let firstResponse: HermesSessionsResponse
                do {
                    firstResponse = try await Self.fetchSessions(baseURL: baseURL, token: token, apiSettings: apiSettings, limit: 1, offset: 0)
                } catch HermesResponsesError.httpError(401) {
                    isDashboardHTTPActive = true
                    token = try await HermesDashboardClient.shared.sessionToken(baseURL: baseURL, apiSettings: apiSettings, refresh: true)
                    isDashboardHTTPActive = false
                    firstResponse = try await Self.fetchSessions(baseURL: baseURL, token: token, apiSettings: apiSettings, limit: 1, offset: 0)
                }
                try Task.checkCancellation()
                guard activeRequestID == requestID else { return }

                let visibleTotal = try await Self.discoverVisibleSessionTotal(
                    baseURL: baseURL,
                    token: token,
                    apiSettings: apiSettings,
                    reportedTotal: firstResponse.total,
                    firstPage: firstResponse
                )
                try Task.checkCancellation()
                guard activeRequestID == requestID else { return }

                let nonCronPage = try await Self.nonCronSessionPage(
                    baseURL: baseURL,
                    token: token,
                    apiSettings: apiSettings,
                    visibleTotal: visibleTotal,
                    requestedPage: requestedPage,
                    pageSize: pageSize,
                    displayOrder: requestedDisplayOrder
                )
                try Task.checkCancellation()
                guard activeRequestID == requestID else { return }

                total = nonCronPage.total
                pageIndex = nonCronPage.pageIndex
                sessions = nonCronPage.sessions
                status = nonCronPage.total == 0 ? "No non-cron sessions found" : "Showing non-cron sessions \(requestedDisplayOrder.statusDescription)"
            } catch is CancellationError {
                isDashboardHTTPActive = false
                if activeRequestID == requestID { status = "Cancelled" }
            } catch {
                isDashboardHTTPActive = false
                if activeRequestID == requestID {
                    sessions = []
                    lastErrorMessage = error.localizedDescription
                    status = "Could not load sessions"
                }
            }
            if activeRequestID == requestID {
                isLoading = false
                activeRequestID = nil
            }
        }
    }

    nonisolated private static func discoverVisibleSessionTotal(
        baseURL: URL,
        token: String,
        apiSettings: HermesAPISettings,
        reportedTotal: Int,
        firstPage: HermesSessionsResponse
    ) async throws -> Int {
        guard reportedTotal > 0, !firstPage.sessions.isEmpty else { return 0 }

        let highestReportedOffset = max(reportedTotal - 1, 0)
        let lastReportedPage = try await fetchSessions(baseURL: baseURL, token: token, apiSettings: apiSettings, limit: 1, offset: highestReportedOffset)
        if !lastReportedPage.sessions.isEmpty { return reportedTotal }

        var low = 0
        var high = highestReportedOffset
        var highestNonEmptyOffset = 0

        while low <= high {
            let midpoint = low + (high - low) / 2
            let response = try await fetchSessions(baseURL: baseURL, token: token, apiSettings: apiSettings, limit: 1, offset: midpoint)
            if response.sessions.isEmpty {
                high = midpoint - 1
            } else {
                highestNonEmptyOffset = midpoint
                low = midpoint + 1
            }
        }

        return highestNonEmptyOffset + 1
    }

    nonisolated private static func nonCronSessionPage(
        baseURL: URL,
        token: String,
        apiSettings: HermesAPISettings,
        visibleTotal: Int,
        requestedPage: Int,
        pageSize: Int,
        displayOrder: HermesSessionDisplayOrder
    ) async throws -> (sessions: [HermesAgentSessionSummary], total: Int, pageIndex: Int) {
        guard visibleTotal > 0 else { return ([], 0, 0) }

        let batchSize = 100
        let offsets = stride(from: 0, to: visibleTotal, by: batchSize)
        let batches = try await withThrowingTaskGroup(of: (Int, [HermesAgentSessionSummary]).self) { group in
            for offset in offsets {
                let limit = min(batchSize, visibleTotal - offset)
                group.addTask {
                    let response = try await fetchSessions(
                        baseURL: baseURL,
                        token: token,
                        apiSettings: apiSettings,
                        limit: limit,
                        offset: offset
                    )
                    return (offset, response.sessions)
                }
            }

            var fetched: [(Int, [HermesAgentSessionSummary])] = []
            for try await batch in group {
                fetched.append(batch)
            }
            return fetched.sorted { $0.0 < $1.0 }
        }
        let newestFirstNonCron = batches
            .flatMap(\.1)
            .filter { !$0.isCronInitiated }

        let filteredTotal = newestFirstNonCron.count
        guard filteredTotal > 0 else { return ([], 0, 0) }

        let orderedSessions = Self.orderedSessions(newestFirstNonCron, displayOrder: displayOrder)
        let lastPage = max(0, Int(ceil(Double(filteredTotal) / Double(pageSize))) - 1)
        let effectivePage = min(max(0, requestedPage), lastPage)
        let pageStart = effectivePage * pageSize
        let pageEnd = min(filteredTotal, pageStart + pageSize)
        return (Array(orderedSessions[pageStart..<pageEnd]), filteredTotal, effectivePage)
    }

    nonisolated private static func orderedSessions(_ newestFirstSessions: [HermesAgentSessionSummary], displayOrder: HermesSessionDisplayOrder) -> [HermesAgentSessionSummary] {
        switch displayOrder {
        case .chronological:
            return Array(newestFirstSessions.reversed())
        case .reverseChronological:
            return newestFirstSessions
        }
    }

    nonisolated private static func fetchSessions(baseURL: URL, token: String, apiSettings: HermesAPISettings, limit: Int, offset: Int) async throws -> HermesSessionsResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("api/sessions"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset))
        ]
        guard let url = components?.url else { throw HermesDashboardHistorySearchError.invalidDashboardURL }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(token, forHTTPHeaderField: "X-Hermes-Session-Token")
        let (data, response) = try await HermesNetworkSessionFactory.session(for: apiSettings).data(for: request)
        try HermesNetworkSessionFactory.validate(response: response)
        return try JSONDecoder().decode(HermesSessionsResponse.self, from: data)
    }

    nonisolated private static func fetchSessionMessages(baseURL: URL, token: String, apiSettings: HermesAPISettings, sessionID: String) async throws -> HermesSessionMessagesResponse {
        let url = baseURL.appendingPathComponent("api/sessions").appendingPathComponent(sessionID).appendingPathComponent("messages")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(token, forHTTPHeaderField: "X-Hermes-Session-Token")
        let (data, response) = try await HermesNetworkSessionFactory.session(for: apiSettings).data(for: request)
        try HermesNetworkSessionFactory.validate(response: response)
        return try JSONDecoder().decode(HermesSessionMessagesResponse.self, from: data)
    }

    nonisolated private static func conversationResult(for session: HermesAgentSessionSummary, resolvedSessionID: String, messages: [HermesDashboardConversationMessage]) -> HermesDashboardConversationResult {
        let sessionInfo = HermesDashboardSessionInfo(
            id: resolvedSessionID,
            source: session.source,
            profile: session.profile,
            model: session.model,
            title: session.title ?? session.preview,
            startedAt: session.startedAt,
            endedAt: session.endedAt,
            messageCount: session.messageCount
        )
        return HermesDashboardConversationResult(
            sessionID: resolvedSessionID,
            session: sessionInfo,
            messages: messages,
            title: session.title ?? session.preview
        )
    }

    nonisolated private static func hindsightPersistencePayload(for conversation: HermesDashboardConversationResult) throws -> HermesHindsightSessionPersistPayload {
        let messages = conversation.messages.compactMap { message -> HermesHindsightSessionPersistMessage? in
            let normalizedRole = message.role.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard normalizedRole == "user" || normalizedRole == "assistant" else { return nil }
            let content = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !content.isEmpty else { return nil }
            return HermesHindsightSessionPersistMessage(role: normalizedRole, content: content, timestamp: message.timestamp)
        }
        guard messages.contains(where: { $0.role == "user" }) || messages.contains(where: { $0.role == "assistant" }) else {
            throw NSError(domain: "HermesHindsight", code: 1, userInfo: [NSLocalizedDescriptionKey: "This session has no user prompts or assistant answers to store."])
        }
        return HermesHindsightSessionPersistPayload(
            sessionID: conversation.sessionID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? conversation.session.id : conversation.sessionID,
            title: conversation.sessionFriendlyName,
            source: conversation.session.source ?? "macos",
            profile: conversation.session.profile ?? "default",
            model: conversation.session.model ?? "",
            startedAt: conversation.session.startedAt,
            endedAt: conversation.session.endedAt,
            messages: messages
        )
    }

    nonisolated private static func runHindsightPersistence(payload: HermesHindsightSessionPersistPayload, hermesHome: String) throws -> HermesHindsightSessionPersistResponse {
        let fileManager = FileManager.default
        let payloadURL = fileManager.temporaryDirectory.appendingPathComponent("hermes-session-hindsight-\(UUID().uuidString).json")
        let payloadData = try JSONEncoder().encode(payload)
        try payloadData.write(to: payloadURL, options: .atomic)
        defer { try? fileManager.removeItem(at: payloadURL) }

        let result = try HermesProcessRunner.run(
            executable: HermesRuntimePaths.defaultPythonExecutable,
            arguments: ["-c", hindsightPersistencePythonScript, payloadURL.path, hermesHome],
            environment: normalizedPythonEnvironment(hermesHome: hermesHome),
            currentDirectory: HermesRuntimePaths.defaultHermesAgentRoot,
            timeout: 180
        )
        guard !result.timedOut else {
            throw NSError(domain: "HermesHindsight", code: 2, userInfo: [NSLocalizedDescriptionKey: "Hindsight import timed out"])
        }
        guard result.output.data(using: .utf8) != nil else {
            throw NSError(domain: "HermesHindsight", code: 3, userInfo: [NSLocalizedDescriptionKey: "Hindsight helper returned non-UTF-8 output"])
        }
        if let response = decodeHindsightPersistenceResponse(from: result.output) {
            if result.exitCode != 0 || !response.success {
                throw NSError(domain: "HermesHindsight", code: Int(result.exitCode), userInfo: [NSLocalizedDescriptionKey: response.error ?? response.message ?? "Hindsight import failed"])
            }
            return response
        }
        guard result.exitCode == 0 else {
            throw NSError(domain: "HermesHindsight", code: Int(result.exitCode), userInfo: [NSLocalizedDescriptionKey: result.output.trimmingCharacters(in: .whitespacesAndNewlines)])
        }
        throw NSError(domain: "HermesHindsight", code: 4, userInfo: [NSLocalizedDescriptionKey: "Hindsight helper returned an unreadable response"])
    }

    nonisolated private static func decodeHindsightPersistenceResponse(from output: String) -> HermesHindsightSessionPersistResponse? {
        let decoder = JSONDecoder()
        if let data = output.data(using: .utf8), let response = try? decoder.decode(HermesHindsightSessionPersistResponse.self, from: data) {
            return response
        }
        for line in output.split(whereSeparator: \.isNewline).reversed() {
            let candidate = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard candidate.hasPrefix("{"), candidate.hasSuffix("}"), let data = candidate.data(using: .utf8) else { continue }
            if let response = try? decoder.decode(HermesHindsightSessionPersistResponse.self, from: data) {
                return response
            }
        }
        return nil
    }

    nonisolated private static func normalizedPythonEnvironment(hermesHome: String) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        environment["HERMES_HOME"] = hermesHome
        environment["TERM"] = environment["TERM"] ?? "xterm-256color"
        let agentRoot = HermesRuntimePaths.defaultHermesAgentRoot
        let existingPythonPath = environment["PYTHONPATH"] ?? ""
        environment["PYTHONPATH"] = existingPythonPath.isEmpty ? agentRoot : agentRoot + ":" + existingPythonPath
        environment["PATH"] = normalizedPATH(existing: environment["PATH"], hermesHome: hermesHome)
        return environment
    }

    nonisolated private static func normalizedPATH(existing: String?, hermesHome: String) -> String {
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

    nonisolated private static let hindsightPersistencePythonScript = #"""
import json
import re
import sys
from datetime import datetime, timezone

payload_path = sys.argv[1]
hermes_home = sys.argv[2]


def iso_timestamp(value):
    if value is None:
        return None
    try:
        return datetime.fromtimestamp(float(value), timezone.utc).isoformat(timespec="milliseconds").replace("+00:00", "Z")
    except Exception:
        return None


def tag_segment(value, fallback):
    text = str(value or "").strip() or fallback
    text = re.sub(r"[^A-Za-z0-9_-]+", "-", text).strip("-_")
    return text or fallback


provider = None
try:
    from plugins.memory.hindsight import HindsightMemoryProvider

    with open(payload_path, "r", encoding="utf-8") as handle:
        payload = json.load(handle)

    session_id = str(payload.get("session_id") or "").strip() or "hermes-macos-session"
    profile = str(payload.get("profile") or "default").strip() or "default"
    source = str(payload.get("source") or "macos").strip() or "macos"
    title = str(payload.get("title") or "Hermes session").strip() or "Hermes session"
    model = str(payload.get("model") or "").strip()
    raw_messages = payload.get("messages") or []
    messages = []
    user_count = 0
    assistant_count = 0
    for item in raw_messages:
        if not isinstance(item, dict):
            continue
        role = str(item.get("role") or "").strip().lower()
        content = str(item.get("content") or "").strip()
        if role not in {"user", "assistant"} or not content:
            continue
        message = {"role": role, "content": content}
        timestamp = iso_timestamp(item.get("timestamp"))
        if timestamp:
            message["timestamp"] = timestamp
        messages.append(message)
        if role == "user":
            user_count += 1
        elif role == "assistant":
            assistant_count += 1

    if not messages:
        raise ValueError("No user prompts or assistant answers were present in this session.")

    provider = HindsightMemoryProvider()
    provider.initialize(
        session_id,
        hermes_home=hermes_home,
        platform=source,
        agent_identity=profile,
        agent_workspace="hermes",
        agent_context="primary",
    )
    if getattr(provider, "_mode", "") == "disabled":
        raise RuntimeError("Hindsight memory provider is disabled or unavailable for this Hermes profile")

    content = json.dumps(messages, ensure_ascii=False)
    document_id = f"hermes-macos-session-{tag_segment(profile, 'default')}-{tag_segment(session_id, 'session')}"
    metadata = provider._build_metadata(message_count=len(messages), turn_index=1)
    metadata.update({
        "source": "hermes_macos_sessions_tab",
        "session_id": session_id,
        "profile": profile,
        "title": title,
        "message_count": str(len(messages)),
        "user_messages": str(user_count),
        "assistant_messages": str(assistant_count),
    })
    if model:
        metadata["model"] = model
    if payload.get("started_at") is not None:
        metadata["started_at"] = str(payload.get("started_at"))
    if payload.get("ended_at") is not None:
        metadata["ended_at"] = str(payload.get("ended_at"))

    tags = [
        "source:hermes_macos_sessions_tab",
        f"profile:{tag_segment(profile, 'default')}",
        f"session:{tag_segment(session_id, 'session')}",
    ]
    item = provider._build_retain_kwargs(
        content,
        context=f"HermesMacOS Sessions tab transcript: {title}",
        metadata=metadata,
        tags=tags,
    )
    item.pop("bank_id", None)
    item.pop("retain_async", None)

    provider._run_hindsight_operation(
        lambda client: client.aretain_batch(
            bank_id=provider._bank_id,
            items=[item],
            document_id=document_id,
            retain_async=provider._retain_async,
        )
    )
    print(json.dumps({
        "success": True,
        "inserted": True,
        "already_stored": False,
        "raw_turn_id": document_id,
        "message": "Stored in Hindsight.",
        "user_messages": user_count,
        "assistant_messages": assistant_count,
    }, sort_keys=True))
except Exception as exc:  # noqa: BLE001 - surfaced to the Swift UI
    print(json.dumps({
        "success": False,
        "inserted": False,
        "already_stored": False,
        "raw_turn_id": "",
        "message": "Hindsight import failed",
        "error": str(exc),
        "user_messages": 0,
        "assistant_messages": 0,
    }, sort_keys=True))
    sys.exit(1)
finally:
    if provider is not None:
        try:
            provider.shutdown()
        except Exception:
            pass
"""#

}

struct HermesSessionsView: View {
    let apiSettings: HermesAPISettings
    let dashboardURL: String
    @Bindable var store: HermesSessionsStore
    let isResponsesStreaming: Bool
    let isTUIGatewayBusy: Bool
    let connectedHostName: String
    let connectedWindowID: UUID
    let onResumeResponses: (HermesDashboardConversationResult) -> Void
    let onResumeTUI: (HermesAgentSessionSummary) -> Void

    @State private var expandedSessionIDs: Set<String> = []
    var body: some View {
        VStack(spacing: 0) {
            header
            List {
                paginationSection
                sessionsSection
            }
            .scrollContentBackground(.hidden)
        }
        .background(HermesLiquidGlassCanvas().ignoresSafeArea())
        .task(id: dashboardURL + apiSettings.baseURL) {
            store.loadFirstPage(dashboardURL: dashboardURL, apiSettings: apiSettings)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Label("Sessions", systemImage: "rectangle.stack")
                .hermesWebsiteTitleFont(size: 22, weight: .bold)
            Spacer()
            HermesConnectedHostLabel(hostName: connectedHostName, windowID: connectedWindowID)
            if store.isLoading {
                ProgressView().controlSize(.small)
                Text("Dashboard HTTP")
                    .hermesWebsiteLabelFont(size: 11, weight: .bold)
                    .foregroundStyle(Color.hermesSecondaryText)
            }
        }
        .padding(18)
        .hermesGlassPanel(cornerRadius: 0)
    }

    private var paginationSection: some View {
        Section {
            HStack(spacing: 12) {
                Button {
                    store.previousPage(dashboardURL: dashboardURL, apiSettings: apiSettings)
                } label: {
                    Label("Previous 10", systemImage: "chevron.left")
                }
                .buttonStyle(.bordered)
                .disabled(!store.canGoPrevious)

                Button {
                    store.nextPage(dashboardURL: dashboardURL, apiSettings: apiSettings)
                } label: {
                    Label("Next 10", systemImage: "chevron.right")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!store.canGoNext)

                Button {
                    store.refresh(dashboardURL: dashboardURL, apiSettings: apiSettings)
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(store.isLoading)

                Toggle(isOn: displayOrderToggleBinding) {
                    Label("Newest first", systemImage: "arrow.down.circle")
                }
                .toggleStyle(.switch)
                .controlSize(.small)
                .help("Switch session display between chronological and anti-chronological order.")
                .accessibilityLabel("Display newest sessions first")

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text(store.displayRangeText)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.primary)
                    Text("Page \(min(store.pageIndex + 1, store.pageCount)) of \(store.pageCount)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(Color.hermesSecondaryText)
                }
            }
            .padding(14)
            .hermesGlassPanel(tint: Color.hermesSurface.opacity(0.58), cornerRadius: 18)
            .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(store.status)
                    .font(.caption)
                    .foregroundStyle(Color.hermesSecondaryText)
                if !store.lastErrorMessage.isEmpty {
                    Text(store.lastErrorMessage)
                        .font(.caption)
                        .foregroundStyle(Color.hermesDestructive)
                }
            }
        } header: {
            Label("Pagination", systemImage: "list.number")
        } footer: {
            Text("Use the toggle to switch between chronological (oldest first) and anti-chronological (newest first) display. Each page shows up to 10 non-cron sessions from the Hermes dashboard /api/sessions endpoint.")
        }
    }

    private var displayOrderToggleBinding: Binding<Bool> {
        Binding(
            get: { store.displayOrder == .reverseChronological },
            set: { isNewestFirst in
                store.setDisplayOrder(isNewestFirst ? .reverseChronological : .chronological, dashboardURL: dashboardURL, apiSettings: apiSettings)
            }
        )
    }

    private var sessionsSection: some View {
        Section {
            if store.isLoading && store.sessions.isEmpty {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Loading sessions…")
                        .foregroundStyle(Color.hermesSecondaryText)
                }
                .padding(.vertical, 8)
            } else if store.sessions.isEmpty {
                ContentUnavailableView(
                    "No Sessions",
                    systemImage: "rectangle.stack.badge.person.crop",
                    description: Text("Hermes has not reported any saved sessions yet.")
                )
            } else {
                ForEach(store.sessions) { session in
                    HermesSessionSummaryRow(
                        session: session,
                        conversationResult: store.conversationResultsBySessionID[session.id],
                        isConversationLoading: store.loadingConversationIDs.contains(session.id),
                        conversationError: store.conversationErrorBySessionID[session.id],
                        isExpanded: bindingForSessionDetails(session.id),
                        isResumeDisabled: isResponsesStreaming,
                        isResumeTUIDisabled: isTUIGatewayBusy,
                        isHindsightPersisting: store.hindsightPersistingSessionIDs.contains(session.id),
                        isHindsightStored: store.hindsightStoredSessionIDs.contains(session.id),
                        hindsightMessage: store.hindsightPersistenceMessageBySessionID[session.id],
                        onResume: { resumeSessionInAskHermes(session) },
                        onResumeTUI: { onResumeTUI(session) },
                        onPersistHindsight: { store.persistSessionToHindsight(for: session, dashboardURL: dashboardURL, apiSettings: apiSettings) },
                        onToggleDetails: { toggleDetails(for: session) }
                    )
                }
            }
        } header: {
            Label("Known sessions", systemImage: "rectangle.stack")
        }
    }

    private func bindingForSessionDetails(_ sessionID: String) -> Binding<Bool> {
        Binding(
            get: { expandedSessionIDs.contains(sessionID) },
            set: { isExpanded in
                if isExpanded { expandedSessionIDs.insert(sessionID) } else { expandedSessionIDs.remove(sessionID) }
            }
        )
    }

    private func toggleDetails(for session: HermesAgentSessionSummary) {
        if expandedSessionIDs.contains(session.id) {
            expandedSessionIDs.remove(session.id)
            return
        }
        expandedSessionIDs.insert(session.id)
        store.loadConversation(for: session, dashboardURL: dashboardURL, apiSettings: apiSettings)
    }

    private func resumeSessionInAskHermes(_ session: HermesAgentSessionSummary) {
        store.loadConversation(for: session, dashboardURL: dashboardURL, apiSettings: apiSettings) { result in
            onResumeResponses(result)
        }
    }
}

private struct HermesSessionSummaryRow: View {
    let session: HermesAgentSessionSummary
    let conversationResult: HermesDashboardConversationResult?
    let isConversationLoading: Bool
    let conversationError: String?
    @Binding var isExpanded: Bool
    let isResumeDisabled: Bool
    let isResumeTUIDisabled: Bool
    let isHindsightPersisting: Bool
    let isHindsightStored: Bool
    let hindsightMessage: String?
    let onResume: () -> Void
    let onResumeTUI: () -> Void
    let onPersistHindsight: () -> Void
    let onToggleDetails: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: session.sourceIconName)
                    .foregroundStyle(session.isActive == true ? Color.green : Color.hermesActionBlue)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(session.displayTitle)
                            .font(.headline)
                            .lineLimit(2)
                        if session.isActive == true {
                            Text("Active")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color.green.opacity(0.16), in: Capsule())
                                .foregroundStyle(Color.green)
                        }
                    }

                    Text(session.id)
                        .font(.caption.monospaced())
                        .foregroundStyle(Color.hermesSecondaryText)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    if let startedAtDate = session.startedAtDate {
                        Text(startedAtDate, formatter: Self.dateFormatter)
                            .font(.caption.monospacedDigit())
                    }
                    if let messageCount = session.messageCount {
                        Text("\(messageCount) messages")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(Color.hermesSecondaryText)
                    }
                }
            }

            if let preview = session.preview?.trimmingCharacters(in: .whitespacesAndNewlines), !preview.isEmpty, preview != session.displayTitle {
                Text(preview)
                    .font(.subheadline)
                    .foregroundStyle(Color.hermesSecondaryText)
                    .lineLimit(3)
            }

            HStack(spacing: 10) {
                Button {
                    onResume()
                } label: {
                    Label("Resume to Ask Hermes", systemImage: "arrow.uturn.forward.circle")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(isResumeDisabled || isConversationLoading)
                .help(isResumeDisabled ? "Ask Hermes is streaming a response" : "Load this session and resume it in Ask Hermes")

                Button {
                    onResumeTUI()
                } label: {
                    Label("Resume to TUI Gateway", systemImage: "terminal.fill")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isResumeTUIDisabled)
                .help(isResumeTUIDisabled ? "TUI Gateway is busy" : "Resume this stored session in the TUI Gateway tab")

                Button {
                    onPersistHindsight()
                } label: {
                    Label(hindsightButtonTitle, systemImage: hindsightButtonIcon)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isHindsightPersisting || isHindsightStored)
                .help(isHindsightStored ? "This session is already stored in Hindsight" : "Store this session's user prompts and assistant answers in Hindsight")

                Button {
                    onToggleDetails()
                } label: {
                    Label(isExpanded ? "Hide details" : "Details", systemImage: isExpanded ? "chevron.up.circle" : "text.bubble")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isConversationLoading && !isExpanded)

                if isConversationLoading {
                    ProgressView()
                        .controlSize(.small)
                    Text("Loading details…")
                        .font(.caption)
                        .foregroundStyle(Color.hermesSecondaryText)
                }
                Spacer()
            }

            if let hindsightMessage, !hindsightMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Label(hindsightMessage, systemImage: isHindsightStored ? "checkmark.circle.fill" : "brain.head.profile")
                    .font(.caption)
                    .foregroundStyle(isHindsightStored ? Color.green : Color.hermesSecondaryText)
            }

            if let conversationError, !conversationError.isEmpty {
                Text(conversationError)
                    .font(.caption)
                    .foregroundStyle(Color.hermesDestructive)
            }

            if isExpanded {
                detailsContent
            }

            HStack(spacing: 8) {
                sessionPill(label: session.source ?? "unknown", systemImage: "tray")
                if let profile = session.profile?.trimmingCharacters(in: .whitespacesAndNewlines), !profile.isEmpty {
                    sessionPill(label: profile, systemImage: "person.crop.circle")
                }
                if let model = session.model?.trimmingCharacters(in: .whitespacesAndNewlines), !model.isEmpty {
                    sessionPill(label: model, systemImage: "cpu")
                }
                if let lastActiveDate = session.lastActiveDate {
                    sessionPill(label: "Last active \(Self.relativeFormatter.localizedString(for: lastActiveDate, relativeTo: Date()))", systemImage: "clock")
                }
            }
            .lineLimit(1)
        }
        .padding(14)
        .hermesGlassPanel(tint: Color.hermesSurface.opacity(0.54), cornerRadius: 18)
        .padding(.vertical, 4)
    }

    private var hindsightButtonTitle: String {
        if isHindsightPersisting { return "Storing…" }
        if isHindsightStored { return "Stored in Hindsight" }
        return "Store in Hindsight"
    }

    private var hindsightButtonIcon: String {
        if isHindsightPersisting { return "arrow.triangle.2.circlepath" }
        if isHindsightStored { return "checkmark.circle.fill" }
        return "brain.head.profile"
    }

    private var detailsContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let conversationResult {
                if conversationResult.messages.isEmpty {
                    Text("No conversation messages were stored for this session.")
                        .font(.caption)
                        .foregroundStyle(Color.hermesSecondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(conversationResult.messages) { message in
                        HermesDashboardConversationMessageRow(message: message)
                    }
                }
            } else if !isConversationLoading {
                Text("Click Details to load this session conversation.")
                    .font(.caption)
                    .foregroundStyle(Color.hermesSecondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.top, 4)
    }

    private func sessionPill(label: String, systemImage: String) -> some View {
        Label(label, systemImage: systemImage)
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.hermesSurfaceInput.opacity(0.7), in: Capsule())
            .foregroundStyle(Color.hermesSecondaryText)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()
}
