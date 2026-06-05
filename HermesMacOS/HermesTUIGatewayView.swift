//
//  HermesTUIGatewayView.swift
//  HermesMacOS
//

import Foundation
import Observation
import SwiftUI

private enum HermesTUIGatewayError: LocalizedError {
    case invalidDashboardURL
    case invalidWebSocketURL
    case notConnected
    case requestFailed(String)
    case missingSession

    var errorDescription: String? {
        switch self {
        case .invalidDashboardURL:
            return "The Hermes dashboard URL is invalid."
        case .invalidWebSocketURL:
            return "The TUI Gateway WebSocket URL is invalid."
        case .notConnected:
            return "The TUI Gateway WebSocket is not connected."
        case .requestFailed(let message):
            return message.isEmpty ? "TUI Gateway request failed." : message
        case .missingSession:
            return "Create or activate a TUI Gateway session first."
        }
    }
}

private struct HermesTUIGatewayRPCRequest: Encodable {
    let jsonrpc = "2.0"
    let id: String
    let method: String
    let params: [String: JSONValue]
}

private struct HermesTUIGatewayRPCEnvelope: Decodable {
    let id: String?
    let method: String?
    let params: HermesTUIGatewayEvent?
    let result: JSONValue?
    let error: HermesTUIGatewayRPCError?
}

private struct HermesTUIGatewayRPCError: Decodable {
    let code: Int?
    let message: String?
}

private struct HermesTUIGatewayEvent: Decodable {
    let type: String
    let sessionID: String?
    let payload: JSONValue?

    enum CodingKeys: String, CodingKey {
        case type
        case sessionID = "session_id"
        case payload
    }
}

private struct HermesTUIGatewayWSTicketResponse: Decodable {
    let ticket: String
}

struct HermesTUIGatewayMessage: Identifiable, Equatable {
    enum Role: String, Equatable {
        case user
        case assistant
        case event
        case request
    }

    enum RequestKind: String, Equatable {
        case approval
        case clarify
        case sudo
        case secret
    }

    let id = UUID()
    var role: Role
    var title: String
    var content: String
    var eventType: String?
    var requestKind: RequestKind?
    var requestID: String?
    var isResolved = false
    var createdAt = Date()
}

struct HermesTUILiveSession: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let isCurrent: Bool
}

@MainActor
@Observable
final class HermesTUIGatewayStore {
    var messages: [HermesTUIGatewayMessage] = []
    var activeSessions: [HermesTUILiveSession] = []
    var sessionID = ""
    var storedSessionID = ""
    var sessionTitle = "New TUI session"
    var connectionStatus = "Idle"
    var eventCount = 0
    var lastErrorMessage = ""
    var isConnecting = false
    var isConnected = false
    var isStreaming = false
    var isRefreshingSessions = false

    private var webSocketTask: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var requestCounter = 0
    private var pendingResponses: [String: CheckedContinuation<JSONValue, Error>] = [:]
    private var activeAssistantMessageID: UUID?

    var canSendPrompt: Bool {
        isConnected && !isStreaming && !sessionID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func connect(dashboardBaseURL: String, apiSettings: HermesAPISettings) {
        guard !isConnecting else { return }
        Task { await connectAndCreateSession(dashboardBaseURL: dashboardBaseURL, apiSettings: apiSettings) }
    }

    func disconnect() {
        receiveTask?.cancel()
        receiveTask = nil
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        isConnected = false
        isConnecting = false
        isStreaming = false
        connectionStatus = "Disconnected"
        failPending(HermesTUIGatewayError.notConnected)
    }

    func createSession() {
        Task { await createGatewaySession() }
    }

    func submitPrompt(_ prompt: String) {
        let text = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        Task { await submit(text) }
    }

    func interruptSession() {
        guard !sessionID.isEmpty else { return }
        Task {
            do {
                _ = try await request("session.interrupt", params: ["session_id": .string(sessionID)], timeoutSeconds: 20)
                isStreaming = false
                connectionStatus = "Interrupted"
                appendEvent(title: "Interrupted", content: "The active TUI Gateway turn was interrupted.", eventType: "session.interrupt")
            } catch {
                lastErrorMessage = error.localizedDescription
            }
        }
    }

    func closeSession() {
        guard !sessionID.isEmpty else { return }
        Task {
            do {
                _ = try await request("session.close", params: ["session_id": .string(sessionID)], timeoutSeconds: 20)
                appendEvent(title: "Session closed", content: shortSessionID(sessionID), eventType: "session.close")
                sessionID = ""
                storedSessionID = ""
                sessionTitle = "New TUI session"
                isStreaming = false
                await refreshActiveSessions()
            } catch {
                lastErrorMessage = error.localizedDescription
            }
        }
    }

    func refreshSessions() {
        Task { await refreshActiveSessions() }
    }

    func activateSession(_ liveSession: HermesTUILiveSession) {
        Task { await activate(sessionID: liveSession.id) }
    }

    func respondToApproval(messageID: UUID, choice: String, applyToAll: Bool = false) {
        guard !sessionID.isEmpty else { return }
        Task {
            do {
                _ = try await request(
                    "approval.respond",
                    params: [
                        "session_id": .string(sessionID),
                        "choice": .string(choice),
                        "all": .bool(applyToAll)
                    ],
                    timeoutSeconds: 30
                )
                markRequestResolved(messageID, label: choice == "deny" ? "Denied" : "Approved")
            } catch {
                lastErrorMessage = error.localizedDescription
            }
        }
    }

    func respondToPromptRequest(messageID: UUID, kind: HermesTUIGatewayMessage.RequestKind, requestID: String, value: String) {
        Task {
            do {
                let method: String
                let key: String
                switch kind {
                case .clarify:
                    method = "clarify.respond"
                    key = "answer"
                case .sudo:
                    method = "sudo.respond"
                    key = "password"
                case .secret:
                    method = "secret.respond"
                    key = "value"
                case .approval:
                    return
                }
                _ = try await request(method, params: ["request_id": .string(requestID), key: .string(value)], timeoutSeconds: 30)
                markRequestResolved(messageID, label: value.isEmpty ? "Skipped" : "Responded")
            } catch {
                lastErrorMessage = error.localizedDescription
            }
        }
    }

    private func connectAndCreateSession(dashboardBaseURL: String, apiSettings: HermesAPISettings) async {
        isConnecting = true
        lastErrorMessage = ""
        connectionStatus = "Connecting"
        do {
            let baseURL = try await HermesDashboardClient.shared.resolvedBaseURL(dashboardBaseURL: dashboardBaseURL, apiBaseURL: apiSettings.baseURL)
            let wsURL = try await webSocketURL(baseURL: baseURL, apiSettings: apiSettings)
            let session = HermesNetworkSessionFactory.session(for: apiSettings)
            let task = session.webSocketTask(with: wsURL)
            webSocketTask = task
            task.resume()
            isConnected = true
            isConnecting = false
            connectionStatus = "Connected"
            receiveTask?.cancel()
            receiveTask = Task { await receiveLoop(task) }
            if sessionID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                await createGatewaySession()
            }
            await refreshActiveSessions()
        } catch {
            isConnecting = false
            isConnected = false
            lastErrorMessage = error.localizedDescription
            connectionStatus = "Connection failed"
        }
    }

    private func createGatewaySession() async {
        do {
            let result = try await request("session.create", params: [:], timeoutSeconds: 120)
            let object = result.objectValue
            sessionID = object["session_id"]?.stringValue ?? ""
            storedSessionID = object["stored_session_id"]?.stringValue ?? ""
            sessionTitle = "TUI session \(shortSessionID(sessionID))"
            messages.removeAll()
            activeAssistantMessageID = nil
            isStreaming = false
            connectionStatus = sessionID.isEmpty ? "Session create failed" : "Session ready"
            appendEvent(title: "Session ready", content: "Created live TUI session \(shortSessionID(sessionID)).", eventType: "session.create")
            await refreshActiveSessions()
        } catch {
            lastErrorMessage = error.localizedDescription
            connectionStatus = "Session create failed"
        }
    }

    private func submit(_ text: String) async {
        guard canSendPrompt else {
            lastErrorMessage = HermesTUIGatewayError.missingSession.localizedDescription
            return
        }
        messages.append(HermesTUIGatewayMessage(role: .user, title: "You", content: text))
        let assistant = HermesTUIGatewayMessage(role: .assistant, title: "Hermes", content: "")
        activeAssistantMessageID = assistant.id
        messages.append(assistant)
        isStreaming = true
        connectionStatus = "Sending prompt"
        do {
            _ = try await request("prompt.submit", params: ["session_id": .string(sessionID), "text": .string(text)], timeoutSeconds: 60)
            connectionStatus = "Streaming"
        } catch {
            isStreaming = false
            lastErrorMessage = error.localizedDescription
            connectionStatus = "Prompt failed"
            updateAssistantMessage(text: "Request failed: \(error.localizedDescription)")
        }
    }

    private func activate(sessionID target: String) async {
        do {
            let result = try await request("session.activate", params: ["session_id": .string(target)], timeoutSeconds: 60)
            let object = result.objectValue
            sessionID = object["session_id"]?.stringValue ?? target
            storedSessionID = object["stored_session_id"]?.stringValue ?? object["session_key"]?.stringValue ?? storedSessionID
            sessionTitle = activeSessions.first(where: { $0.id == target })?.title ?? "TUI session \(shortSessionID(target))"
            activeAssistantMessageID = nil
            isStreaming = object["running"]?.boolValue ?? false
            connectionStatus = isStreaming ? "Streaming" : "Session active"
            restoreMessages(from: object["messages"]?.arrayValue ?? [])
            await refreshActiveSessions()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    private func refreshActiveSessions() async {
        guard isConnected else { return }
        isRefreshingSessions = true
        defer { isRefreshingSessions = false }
        do {
            let result = try await request("session.active_list", params: ["current_session_id": .string(sessionID)], timeoutSeconds: 30)
            activeSessions = (result.objectValue["sessions"]?.arrayValue ?? []).compactMap { value in
                let object = value.objectValue
                let id = object["session_id"]?.stringValue ?? object["id"]?.stringValue ?? ""
                guard !id.isEmpty else { return nil }
                let title = object["title"]?.stringValue ?? object["display_title"]?.stringValue ?? object["session_key"]?.stringValue ?? "TUI session \(shortSessionID(id))"
                let model = object["model"]?.stringValue ?? ""
                let running = object["running"]?.boolValue ?? false
                let subtitle = [model, running ? "running" : "idle"].filter { !$0.isEmpty }.joined(separator: " • ")
                return HermesTUILiveSession(id: id, title: title.isEmpty ? "TUI session \(shortSessionID(id))" : title, subtitle: subtitle, isCurrent: id == self.sessionID)
            }
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    private func receiveLoop(_ task: URLSessionWebSocketTask) async {
        while !Task.isCancelled {
            do {
                let message = try await task.receive()
                switch message {
                case .string(let text):
                    await handleWebSocketText(text)
                case .data(let data):
                    await handleWebSocketText(String(decoding: data, as: UTF8.self))
                @unknown default:
                    break
                }
            } catch {
                if Task.isCancelled { return }
                isConnected = false
                isStreaming = false
                connectionStatus = "Disconnected"
                lastErrorMessage = error.localizedDescription
                failPending(error)
                return
            }
        }
    }

    private func handleWebSocketText(_ text: String) async {
        guard let data = text.data(using: .utf8), let envelope = try? JSONDecoder().decode(HermesTUIGatewayRPCEnvelope.self, from: data) else { return }
        if let id = envelope.id, let continuation = pendingResponses.removeValue(forKey: id) {
            if let error = envelope.error {
                continuation.resume(throwing: HermesTUIGatewayError.requestFailed(error.message ?? "JSON-RPC error \(error.code ?? -1)"))
            } else {
                continuation.resume(returning: envelope.result ?? .null)
            }
            return
        }
        guard envelope.method == "event", let event = envelope.params else { return }
        eventCount += 1
        handle(event)
    }

    private func handle(_ event: HermesTUIGatewayEvent) {
        let payload = event.payload?.objectValue ?? [:]
        if let eventSessionID = event.sessionID, !eventSessionID.isEmpty, sessionID.isEmpty {
            sessionID = eventSessionID
        }
        switch event.type {
        case "gateway.ready":
            connectionStatus = "Gateway ready"
        case "session.info":
            if let model = payload["model"]?.stringValue, !model.isEmpty {
                sessionTitle = "\(shortSessionID(event.sessionID ?? sessionID)) • \(model)"
            }
            connectionStatus = "Session info updated"
        case "message.start":
            isStreaming = true
            connectionStatus = "Hermes is responding"
            ensureAssistantMessage()
        case "message.delta":
            let delta = payload["text"]?.stringValue ?? ""
            if !delta.isEmpty { appendAssistantDelta(delta) }
            connectionStatus = shortStatus("Receiving message")
        case "message.complete":
            let final = payload["text"]?.stringValue ?? ""
            let status = payload["status"]?.stringValue ?? "complete"
            if !final.isEmpty { updateAssistantMessage(text: final) }
            isStreaming = false
            connectionStatus = status == "complete" ? "Completed" : status.capitalized
        case "tool.start":
            connectionStatus = shortStatus("Running \(payload["name"]?.stringValue ?? "tool")")
            appendEvent(title: "Tool started", content: toolSummary(payload: payload), eventType: event.type)
        case "tool.progress", "tool.generating":
            connectionStatus = shortStatus(payload["preview"]?.stringValue ?? payload["text"]?.stringValue ?? "Tool progress")
            appendEvent(title: "Tool progress", content: eventSummary(payload: payload), eventType: event.type)
        case "tool.complete":
            connectionStatus = shortStatus("Completed \(payload["name"]?.stringValue ?? "tool")")
            appendEvent(title: "Tool complete", content: toolSummary(payload: payload), eventType: event.type)
        case "approval.request":
            connectionStatus = "Approval requested"
            appendRequest(kind: .approval, title: "Approval required", payload: payload)
        case "clarify.request":
            connectionStatus = "Clarification requested"
            appendRequest(kind: .clarify, title: "Clarification requested", payload: payload)
        case "sudo.request":
            connectionStatus = "Sudo password requested"
            appendRequest(kind: .sudo, title: "Sudo password requested", payload: payload)
        case "secret.request":
            connectionStatus = "Secret requested"
            appendRequest(kind: .secret, title: "Secret requested", payload: payload)
        case "status.update":
            let text = payload["text"]?.stringValue ?? eventSummary(payload: payload)
            connectionStatus = shortStatus(text.isEmpty ? "Status update" : text)
            appendEvent(title: "Status", content: text, eventType: event.type)
        case "background.complete":
            appendEvent(title: "Background task complete", content: payload["text"]?.stringValue ?? eventSummary(payload: payload), eventType: event.type)
        case "error":
            isStreaming = false
            let message = payload["message"]?.stringValue ?? eventSummary(payload: payload)
            lastErrorMessage = message
            connectionStatus = "Error"
            appendEvent(title: "Gateway error", content: message, eventType: event.type)
        default:
            connectionStatus = shortStatus(event.type)
            appendEvent(title: event.type, content: eventSummary(payload: payload), eventType: event.type)
        }
    }

    private func request(_ method: String, params: [String: JSONValue], timeoutSeconds: UInt64) async throws -> JSONValue {
        guard let task = webSocketTask, isConnected else { throw HermesTUIGatewayError.notConnected }
        requestCounter += 1
        let id = "macos-\(requestCounter)"
        let request = HermesTUIGatewayRPCRequest(id: id, method: method, params: params)
        let data = try JSONEncoder().encode(request)
        guard let text = String(data: data, encoding: .utf8) else { throw HermesTUIGatewayError.requestFailed("Could not encode JSON-RPC request.") }
        return try await withTaskCancellationHandler {
            try await withThrowingTaskGroup(of: JSONValue.self) { group in
                group.addTask { [weak self] in
                    guard let self else { throw HermesTUIGatewayError.notConnected }
                    return try await self.waitForResponse(id: id)
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: timeoutSeconds * 1_000_000_000)
                    throw HermesTUIGatewayError.requestFailed("Timed out waiting for \(method).")
                }
                try await task.send(.string(text))
                guard let value = try await group.next() else { throw HermesTUIGatewayError.requestFailed("No response for \(method).") }
                group.cancelAll()
                return value
            }
        } onCancel: {
            Task { @MainActor in
                if let continuation = self.pendingResponses.removeValue(forKey: id) {
                    continuation.resume(throwing: CancellationError())
                }
            }
        }
    }

    private func waitForResponse(id: String) async throws -> JSONValue {
        try await withCheckedThrowingContinuation { continuation in
            pendingResponses[id] = continuation
        }
    }

    private func webSocketURL(baseURL: URL, apiSettings: HermesAPISettings) async throws -> URL {
        try HermesEndpointSecurity.validateSensitiveURL(baseURL)
        let token = try await HermesDashboardClient.shared.sessionToken(baseURL: baseURL, apiSettings: apiSettings)
        let ticket = try? await fetchWebSocketTicket(baseURL: baseURL, token: token, apiSettings: apiSettings)
        var url = baseURL
        url.appendPathComponent("api")
        url.appendPathComponent("ws")
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { throw HermesTUIGatewayError.invalidWebSocketURL }
        switch components.scheme?.lowercased() {
        case "http": components.scheme = "ws"
        case "https": components.scheme = "wss"
        default: throw HermesTUIGatewayError.invalidWebSocketURL
        }
        if let ticket, !ticket.isEmpty {
            components.queryItems = [URLQueryItem(name: "ticket", value: ticket)]
        } else {
            components.queryItems = [URLQueryItem(name: "token", value: token)]
        }
        guard let finalURL = components.url else { throw HermesTUIGatewayError.invalidWebSocketURL }
        return finalURL
    }

    private func fetchWebSocketTicket(baseURL: URL, token: String, apiSettings: HermesAPISettings) async throws -> String {
        var url = baseURL
        url.appendPathComponent("api")
        url.appendPathComponent("auth")
        url.appendPathComponent("ws-ticket")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(token, forHTTPHeaderField: "X-Hermes-Session-Token")
        let (data, response) = try await HermesNetworkSessionFactory.session(for: apiSettings).data(for: request)
        try HermesNetworkSessionFactory.validate(response: response)
        return try JSONDecoder().decode(HermesTUIGatewayWSTicketResponse.self, from: data).ticket
    }

    private func appendAssistantDelta(_ delta: String) {
        ensureAssistantMessage()
        guard let activeAssistantMessageID, let index = messages.firstIndex(where: { $0.id == activeAssistantMessageID }) else { return }
        messages[index].content += delta
    }

    private func updateAssistantMessage(text: String) {
        ensureAssistantMessage()
        guard let activeAssistantMessageID, let index = messages.firstIndex(where: { $0.id == activeAssistantMessageID }) else { return }
        messages[index].content = text
    }

    private func ensureAssistantMessage() {
        if let activeAssistantMessageID, messages.contains(where: { $0.id == activeAssistantMessageID }) { return }
        let assistant = HermesTUIGatewayMessage(role: .assistant, title: "Hermes", content: "")
        activeAssistantMessageID = assistant.id
        messages.append(assistant)
    }

    private func appendEvent(title: String, content: String, eventType: String) {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        messages.append(HermesTUIGatewayMessage(role: .event, title: title, content: trimmed.isEmpty ? eventType : trimmed, eventType: eventType))
    }

    private func appendRequest(kind: HermesTUIGatewayMessage.RequestKind, title: String, payload: [String: JSONValue]) {
        let requestID = payload["request_id"]?.stringValue
        let content = requestText(kind: kind, payload: payload)
        messages.append(HermesTUIGatewayMessage(role: .request, title: title, content: content, eventType: "\(kind.rawValue).request", requestKind: kind, requestID: requestID))
    }

    private func markRequestResolved(_ messageID: UUID, label: String) {
        guard let index = messages.firstIndex(where: { $0.id == messageID }) else { return }
        messages[index].isResolved = true
        messages[index].content += "\n\n\(label)."
        connectionStatus = label
    }

    private func restoreMessages(from values: [JSONValue]) {
        let restored = values.compactMap { value -> HermesTUIGatewayMessage? in
            let object = value.objectValue
            let role = (object["role"]?.stringValue ?? "assistant").lowercased()
            let text = object["content"]?.stringValue ?? object["text"]?.stringValue ?? ""
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return HermesTUIGatewayMessage(role: role == "user" ? .user : .assistant, title: role == "user" ? "You" : "Hermes", content: text)
        }
        messages = restored
    }

    private func failPending(_ error: Error) {
        for continuation in pendingResponses.values {
            continuation.resume(throwing: error)
        }
        pendingResponses.removeAll()
    }

    private func requestText(kind: HermesTUIGatewayMessage.RequestKind, payload: [String: JSONValue]) -> String {
        switch kind {
        case .approval:
            return [
                payload["command"]?.stringValue,
                payload["description"]?.stringValue,
                payload["reason"]?.stringValue,
                payload["risk"]?.stringValue
            ].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }.joined(separator: "\n")
        case .clarify:
            let question = payload["question"]?.stringValue ?? "Hermes needs clarification."
            let choices = payload["choices"]?.arrayValue.map(\.compactDescription).filter { !$0.isEmpty }.joined(separator: ", ") ?? ""
            return choices.isEmpty ? question : "\(question)\nChoices: \(choices)"
        case .sudo:
            return "Hermes needs a sudo password to continue."
        case .secret:
            return [payload["prompt"]?.stringValue, payload["env_var"]?.stringValue.map { "Variable: \($0)" }]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
        }
    }

    private func toolSummary(payload: [String: JSONValue]) -> String {
        let name = payload["name"]?.stringValue ?? "tool"
        if let summary = payload["summary"]?.stringValue, !summary.isEmpty { return "\(name): \(summary)" }
        if let context = payload["context"]?.stringValue, !context.isEmpty { return "\(name): \(context)" }
        return eventSummary(payload: payload)
    }

    private func eventSummary(payload: [String: JSONValue]) -> String {
        let preferredKeys = ["text", "message", "preview", "summary", "label", "status", "name", "kind"]
        let values = preferredKeys.compactMap { payload[$0]?.compactDescription.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        if !values.isEmpty { return values.joined(separator: " • ") }
        return JSONValue.object(payload).compactDescription
    }

    private func shortStatus(_ value: String) -> String {
        let normalized = value.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        guard normalized.count > 40 else { return normalized }
        return String(normalized.prefix(37)) + "…"
    }

    private func shortSessionID(_ value: String) -> String {
        guard value.count > 12 else { return value }
        return String(value.prefix(12)) + "…"
    }
}

struct HermesTUIGatewayView: View {
    let apiSettings: HermesAPISettings
    let dashboardURL: String
    @Bindable var store: HermesTUIGatewayStore
    let connectedHostName: String
    let connectedWindowID: UUID

    @State private var promptText = ""
    @State private var requestResponses: [UUID: String] = [:]
    @AppStorage("hermes.macOS.tuiGatewayBubbleFontSize") private var bubbleFontSize = 14.0
    @AppStorage("hermes.macOS.promptFontSize") private var promptFontSize = 14.0

    var body: some View {
        VStack(spacing: 0) {
            header
            transcript
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            composer
        }
        .background(HermesLiquidGlassCanvas().ignoresSafeArea())
        .onDisappear { }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Label("TUI Gateway", systemImage: "terminal.fill")
                    .hermesWebsiteTitleFont(size: 22, weight: .bold)
                Spacer()
                HermesConnectedHostLabel(hostName: connectedHostName, windowID: connectedWindowID)
                if store.isConnecting || store.isStreaming || store.isRefreshingSessions {
                    ProgressView().controlSize(.small)
                }
            }

            HStack(alignment: .top, spacing: 12) {
                HermesStatusCard(title: "Session", value: store.sessionTitle, tint: .hermesActionBlue, minimumWidth: 210, maximumWidth: .infinity)
                HermesStatusCard(title: "Status", value: store.connectionStatus, tint: .hermesOrange, minimumWidth: 210, maximumWidth: 300)
                HermesStatusCard(title: "Events", value: "\(store.eventCount)", tint: .hermesPurple, minimumWidth: 100, maximumWidth: 120)
            }

            HStack(spacing: 10) {
                Button(store.isConnected ? "Reconnect" : "Connect") {
                    store.disconnect()
                    store.connect(dashboardBaseURL: dashboardURL, apiSettings: apiSettings)
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.isConnecting)

                Button("New session") { store.createSession() }
                    .buttonStyle(.bordered)
                    .disabled(!store.isConnected || store.isStreaming)

                Button("Interrupt") { store.interruptSession() }
                    .buttonStyle(.bordered)
                    .disabled(!store.isStreaming)

                Button("Close session") { store.closeSession() }
                    .buttonStyle(.bordered)
                    .disabled(!store.isConnected || store.sessionID.isEmpty)

                Menu {
                    if store.activeSessions.isEmpty {
                        Text("No live sessions")
                    } else {
                        ForEach(store.activeSessions) { session in
                            Button {
                                store.activateSession(session)
                            } label: {
                                Label(session.title, systemImage: session.isCurrent ? "checkmark.circle.fill" : "circle")
                            }
                        }
                    }
                    Divider()
                    Button("Refresh live sessions") { store.refreshSessions() }
                } label: {
                    Label("Live sessions", systemImage: "rectangle.stack.badge.person.crop")
                }
                .disabled(!store.isConnected)
            }

            if !store.lastErrorMessage.isEmpty {
                Label(store.lastErrorMessage, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(Color.hermesDestructive)
            }
        }
        .padding(18)
        .hermesGlassPanel(cornerRadius: 0)
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    if store.messages.isEmpty {
                        emptyState
                    } else {
                        ForEach(store.messages) { message in
                            HermesTUIGatewayBubble(
                                message: message,
                                responseText: Binding(
                                    get: { requestResponses[message.id, default: ""] },
                                    set: { requestResponses[message.id] = $0 }
                                ),
                                fontSize: bubbleFontSize,
                                onApproval: { choice, all in store.respondToApproval(messageID: message.id, choice: choice, applyToAll: all) },
                                onPromptResponse: { value in
                                    guard let kind = message.requestKind, let requestID = message.requestID else { return }
                                    store.respondToPromptRequest(messageID: message.id, kind: kind, requestID: requestID, value: value)
                                    requestResponses[message.id] = ""
                                }
                            )
                            .id(message.id)
                        }
                    }
                    Color.clear.frame(height: 1).id("tui-gateway-bottom")
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 16)
            }
            .onAppear { scrollToBottom(proxy, animated: false) }
            .onChange(of: store.messages.count) { _, _ in scrollToBottom(proxy) }
            .onChange(of: store.messages.last?.content) { _, _ in scrollToBottom(proxy) }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Talk to Hermes through the TUI Gateway", systemImage: "terminal.fill")
                .hermesWebsiteTitleFont(size: 15, weight: .bold)
            Text("Connect to the dashboard WebSocket, create a live TUI Gateway session, send prompts, and handle streamed messages, events, clarifications, secrets, sudo prompts, and approvals from this native tab.")
                .font(.subheadline)
                .foregroundStyle(Color.hermesSecondaryText)
            Text("Transport: dashboard /api/ws using the same JSON-RPC protocol as hermes --tui.")
                .font(.caption)
                .foregroundStyle(Color.hermesSecondaryText)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .hermesGlassPanel(tint: Color.hermesActionBlue.opacity(0.07))
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .bottom, spacing: 12) {
                TextEditor(text: $promptText)
                    .font(.system(size: promptFontSize))
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 78, maxHeight: 150)
                    .padding(8)
                    .hermesGlassInput(tint: Color.hermesSurfaceInput.opacity(store.isStreaming ? 0.42 : 0.70))
                    .disabled(!store.isConnected || store.isStreaming)
                    .overlay(alignment: .topLeading) {
                        if promptText.isEmpty {
                            Text(store.isConnected ? "Send a prompt through the TUI Gateway…" : "Connect to the TUI Gateway first…")
                                .font(.system(size: promptFontSize))
                                .foregroundStyle(Color.hermesSecondaryText)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 16)
                                .allowsHitTesting(false)
                        }
                    }

                Button { submitPrompt() } label: {
                    HermesComposerSendButtonLabel()
                }
                .buttonStyle(.plain)
                .disabled(!store.canSendPrompt || promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut(.return, modifiers: [.command])
                .help("Send through TUI Gateway (⌘↩)")
            }
        }
        .padding(16)
        .hermesGlassPanel(cornerRadius: 0)
    }

    private func submitPrompt() {
        let text = promptText
        store.submitPrompt(text)
        promptText = ""
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy, animated: Bool = true) {
        DispatchQueue.main.async {
            if animated {
                withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo("tui-gateway-bottom", anchor: .bottom) }
            } else {
                proxy.scrollTo("tui-gateway-bottom", anchor: .bottom)
            }
        }
    }
}

private struct HermesTUIGatewayBubble: View {
    let message: HermesTUIGatewayMessage
    @Binding var responseText: String
    let fontSize: Double
    let onApproval: (String, Bool) -> Void
    let onPromptResponse: (String) -> Void

    var body: some View {
        HStack(alignment: .bottom) {
            if isUser { Spacer(minLength: 80) }
            VStack(alignment: isUser ? .trailing : .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(message.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.hermesSecondaryText)
                    if let eventType = message.eventType {
                        Text(eventType)
                            .font(.caption2.monospaced())
                            .foregroundStyle(Color.hermesSecondaryText.opacity(0.85))
                    }
                    if message.isResolved {
                        Text("Resolved")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.green)
                    }
                }

                HermesCopyableBubbleContent(text: message.content.isEmpty ? "…" : message.content, copyText: message.content, isUser: isUser, rendersMarkdown: !isUser && message.role == .assistant, fontSize: fontSize, isResponding: message.role == .assistant && message.content.isEmpty)

                if message.role == .request && !message.isResolved {
                    requestControls
                }
            }
            .frame(maxWidth: 720, alignment: isUser ? .trailing : .leading)
            if !isUser { Spacer(minLength: 80) }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }

    private var isUser: Bool { message.role == .user }

    @ViewBuilder
    private var requestControls: some View {
        switch message.requestKind {
        case .approval:
            HStack(spacing: 8) {
                Button("Run once") { onApproval("once", false) }
                    .buttonStyle(.borderedProminent)
                Button("Allow all") { onApproval("once", true) }
                    .buttonStyle(.bordered)
                Button("Deny") { onApproval("deny", false) }
                    .buttonStyle(.bordered)
            }
        case .clarify, .sudo, .secret:
            HStack(alignment: .bottom, spacing: 8) {
                SecureOrPlainRequestField(kind: message.requestKind, text: $responseText)
                Button("Respond") { onPromptResponse(responseText) }
                    .buttonStyle(.borderedProminent)
                Button("Skip") { onPromptResponse("") }
                    .buttonStyle(.bordered)
            }
        case .none:
            EmptyView()
        }
    }
}

private struct SecureOrPlainRequestField: View {
    let kind: HermesTUIGatewayMessage.RequestKind?
    @Binding var text: String

    var body: some View {
        if kind == .sudo || kind == .secret {
            SecureField("Response", text: $text)
                .textFieldStyle(.roundedBorder)
                .frame(width: 260)
        } else {
            TextField("Response", text: $text)
                .textFieldStyle(.roundedBorder)
                .frame(width: 320)
        }
    }
}

private extension JSONValue {
    var stringValue: String? {
        switch self {
        case .string(let value): return value
        case .number(let value): return String(value)
        case .bool(let value): return value ? "true" : "false"
        default: return nil
        }
    }

    var boolValue: Bool? {
        switch self {
        case .bool(let value): return value
        case .string(let value): return ["1", "true", "yes", "on"].contains(value.lowercased())
        default: return nil
        }
    }

    var objectValue: [String: JSONValue] {
        if case .object(let value) = self { return value }
        return [:]
    }

    var arrayValue: [JSONValue] {
        if case .array(let value) = self { return value }
        return []
    }
}
