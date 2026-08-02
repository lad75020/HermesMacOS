//
//  HermesTUIConversationHistory.swift
//  HermesMacOS
//
//  Fetches every TUI Gateway conversation from the Hermes dashboard and
//  surfaces the initial user prompt together with the agent's final answer.
//

import Foundation
import Observation

/// A single TUI Gateway conversation reduced to the user's opening prompt and
/// the agent's final answer.
struct HermesTUIConversationSummary: Identifiable, Equatable {
    let id: String
    let title: String
    let profile: String
    let model: String
    let startedAt: Date?
    let endedAt: Date?
    let userPrompt: String
    let finalAnswer: String

    var hasUserPrompt: Bool { !userPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var hasFinalAnswer: Bool { !finalAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var timestampText: String {
        guard let date = endedAt ?? startedAt else { return "" }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    var subtitle: String {
        var parts: [String] = []
        let trimmedProfile = profile.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedProfile.isEmpty { parts.append(trimmedProfile) }
        let stamp = timestampText
        if !stamp.isEmpty { parts.append(stamp) }
        return parts.joined(separator: " • ")
    }
}

@MainActor
@Observable
final class HermesTUIConversationHistoryStore {
    var conversations: [HermesTUIConversationSummary] = []
    var isLoading = false
    var status = String(localized: "Load TUI Gateway conversations to see prompts and final answers.")
    var lastErrorMessage = ""
    var hasLoadedOnce = false

    private var requestTask: Task<Void, Never>?
    private var activeRequestID: UUID?

    /// Maximum number of TUI sessions to surface; keeps the utility responsive.
    private let maxConversations = 50
    /// Sessions are fetched from /api/sessions in batches of this size.
    private let sessionPageSize = 100
    private let sessionScanLimit = 400

    func loadIfNeeded(dashboardURL: String, apiSettings: HermesAPISettings) {
        guard !hasLoadedOnce else { return }
        load(dashboardURL: dashboardURL, apiSettings: apiSettings)
    }

    func load(dashboardURL: String, apiSettings: HermesAPISettings) {
        requestTask?.cancel()
        let requestID = UUID()
        activeRequestID = requestID
        isLoading = true
        lastErrorMessage = ""
        status = String(localized: "Loading TUI Gateway conversations…")
        hasLoadedOnce = true
        requestTask = Task { await run(requestID: requestID, dashboardURL: dashboardURL, apiSettings: apiSettings) }
    }

    func cancel() {
        requestTask?.cancel()
        requestTask = nil
        activeRequestID = nil
        isLoading = false
        status = String(localized: "Cancelled.")
    }

    func clear() {
        requestTask?.cancel()
        requestTask = nil
        activeRequestID = nil
        conversations = []
        isLoading = false
        lastErrorMessage = ""
        hasLoadedOnce = false
        status = String(localized: "Load TUI Gateway conversations to see prompts and final answers.")
    }

    private func run(requestID: UUID, dashboardURL: String, apiSettings: HermesAPISettings) async {
        do {
            let baseURL = try await HermesDashboardClient.shared.resolvedBaseURL(dashboardBaseURL: dashboardURL, apiBaseURL: apiSettings.baseURL)
            var token = try await HermesDashboardClient.shared.sessionToken(baseURL: baseURL, apiSettings: apiSettings)

            let tuiSessions = try await fetchTUISessions(baseURL: baseURL, apiSettings: apiSettings, token: &token)
            try Task.checkCancellation()
            guard activeRequestID == requestID else { return }

            if tuiSessions.isEmpty {
                conversations = []
                status = String(localized: "No TUI Gateway conversations found yet.")
                isLoading = false
                return
            }

            status = String(localized: "Reading \(tuiSessions.count) TUI Gateway conversations…")
            var summaries: [HermesTUIConversationSummary] = []
            for session in tuiSessions {
                try Task.checkCancellation()
                guard activeRequestID == requestID else { return }
                let messages = try await fetchMessages(baseURL: baseURL, apiSettings: apiSettings, token: &token, sessionID: session.id)
                summaries.append(Self.summary(for: session, messages: messages))
                conversations = summaries
            }

            guard activeRequestID == requestID else { return }
            conversations = summaries
            status = String(localized: "Showing \(summaries.count) TUI Gateway conversations.")
            isLoading = false
        } catch is CancellationError {
            if activeRequestID == requestID { status = String(localized: "Cancelled."); isLoading = false }
        } catch {
            if activeRequestID == requestID {
                lastErrorMessage = error.localizedDescription
                status = String(localized: "Could not load TUI Gateway conversations.")
                isLoading = false
            }
        }
        if activeRequestID == requestID { requestTask = nil; activeRequestID = nil }
    }

    /// Scans /api/sessions in batches, keeping only TUI-sourced sessions, newest first.
    private func fetchTUISessions(baseURL: URL, apiSettings: HermesAPISettings, token: inout String) async throws -> [HermesAgentSessionSummary] {
        var collected: [HermesAgentSessionSummary] = []
        var seenIDs = Set<String>()
        var offset = 0
        while offset < sessionScanLimit {
            let batch = try await fetchSessionsPage(baseURL: baseURL, apiSettings: apiSettings, token: &token, offset: offset, limit: sessionPageSize)
            for session in batch.sessions where Self.isTUISession(session) {
                if seenIDs.insert(session.id).inserted { collected.append(session) }
            }
            if collected.count >= maxConversations { break }
            offset += batch.sessions.count
            if batch.sessions.count < sessionPageSize || offset >= batch.total { break }
        }
        return Array(collected.prefix(maxConversations))
    }

    private func fetchSessionsPage(baseURL: URL, apiSettings: HermesAPISettings, token: inout String, offset: Int, limit: Int) async throws -> HermesSessionsResponse {
        do {
            return try await Self.requestSessionsPage(baseURL: baseURL, token: token, apiSettings: apiSettings, offset: offset, limit: limit)
        } catch HermesResponsesError.httpError(401) {
            token = try await HermesDashboardClient.shared.sessionToken(baseURL: baseURL, apiSettings: apiSettings, refresh: true)
            return try await Self.requestSessionsPage(baseURL: baseURL, token: token, apiSettings: apiSettings, offset: offset, limit: limit)
        }
    }

    private func fetchMessages(baseURL: URL, apiSettings: HermesAPISettings, token: inout String, sessionID: String) async throws -> [HermesDashboardConversationMessage] {
        do {
            return try await Self.requestSessionMessages(baseURL: baseURL, token: token, apiSettings: apiSettings, sessionID: sessionID).messages
        } catch HermesResponsesError.httpError(401) {
            token = try await HermesDashboardClient.shared.sessionToken(baseURL: baseURL, apiSettings: apiSettings, refresh: true)
            return try await Self.requestSessionMessages(baseURL: baseURL, token: token, apiSettings: apiSettings, sessionID: sessionID).messages
        }
    }

    nonisolated static func isTUISession(_ session: HermesAgentSessionSummary) -> Bool {
        switch session.source?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "tui", "tui_gateway", "tui-gateway", "gateway": true
        default: false
        }
    }

    nonisolated static func summary(for session: HermesAgentSessionSummary, messages: [HermesDashboardConversationMessage]) -> HermesTUIConversationSummary {
        let nonEmpty = messages.filter { !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let userPrompt = nonEmpty.first { $0.role.lowercased() == "user" }?.content ?? ""
        let finalAnswer = nonEmpty.last { $0.role.lowercased() == "assistant" }?.content ?? ""
        return HermesTUIConversationSummary(
            id: session.id,
            title: session.displayTitle,
            profile: session.profile ?? "default",
            model: session.model ?? "",
            startedAt: session.startedAtDate,
            endedAt: session.endedAt.map { Date(timeIntervalSince1970: $0) },
            userPrompt: userPrompt.trimmingCharacters(in: .whitespacesAndNewlines),
            finalAnswer: finalAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    nonisolated private static func requestSessionsPage(baseURL: URL, token: String, apiSettings: HermesAPISettings, offset: Int, limit: Int) async throws -> HermesSessionsResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("api/sessions"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset))
        ]
        guard let url = components?.url else { throw HermesDashboardHistorySearchError.invalidDashboardURL }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(token, forHTTPHeaderField: "X-Hermes-Session-Token")
        let (data, response) = try await HermesNetworkSessionFactory.session(for: apiSettings).data(for: request)
        try HermesNetworkSessionFactory.validate(response: response)
        return try JSONDecoder().decode(HermesSessionsResponse.self, from: data)
    }

    nonisolated private static func requestSessionMessages(baseURL: URL, token: String, apiSettings: HermesAPISettings, sessionID: String) async throws -> HermesSessionMessagesResponse {
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
}
