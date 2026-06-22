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
final class HermesTUIWorkspace: Identifiable {
    let id = UUID()
    let number: Int
    let store = HermesTUIGatewayStore()
    var selectedProfile: String
    var fastModeEnabled: Bool
    var promptText = ""
    var requestResponses: [UUID: String] = [:]
    var selectedAttachment: HermesPromptAttachment?
    var selectedAttachmentPath = ""
    private var acknowledgedCompletionToken = ""
    private var acknowledgedFailureToken = ""

    init(number: Int, selectedProfile: String = "default", fastModeEnabled: Bool = false) {
        self.number = number
        let trimmedProfile = selectedProfile.trimmingCharacters(in: .whitespacesAndNewlines)
        self.selectedProfile = trimmedProfile.isEmpty ? "default" : trimmedProfile
        self.fastModeEnabled = fastModeEnabled
    }

    var attention: HermesTopTabAttention? {
        if store.isStreaming || store.isConnecting || store.isResumingSession { return .streaming }
        if let token = failureToken, token != acknowledgedFailureToken { return .failed }
        if let token = completionToken, token != acknowledgedCompletionToken { return .completed }
        return nil
    }

    func acknowledgeCurrentStatus() {
        if let token = completionToken { acknowledgedCompletionToken = token }
        if let token = failureToken { acknowledgedFailureToken = token }
    }

    private var completionToken: String? {
        guard store.connectionStatus == "Completed", !store.messages.isEmpty else { return nil }
        let sessionPart = store.sessionID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "tui" : store.sessionID
        return "completed-\(sessionPart)-\(store.messages.count)-\(store.eventCount)"
    }

    private var failureToken: String? {
        let error = store.lastErrorMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        if !error.isEmpty { return error }
        guard store.connectionStatus == "Error" || store.connectionStatus == "Connection failed" || store.connectionStatus == "Prompt failed" || store.connectionStatus == "Resume failed" else { return nil }
        return "failed-\(store.messages.count)-\(store.eventCount)-\(store.connectionStatus)"
    }
}

@MainActor
@Observable
final class HermesTUIGatewayStore {
    var messages: [HermesTUIGatewayMessage] = []
    var activeSessions: [HermesTUILiveSession] = []
    var sessionID = ""
    var storedSessionID = ""
    var sessionTitle = "New TUI session"
    var activeProfile = ""
    var connectionStatus = "Idle"
    var eventCount = 0
    var lastErrorMessage = ""
    var isConnecting = false
    var isConnected = false
    var isStreaming = false
    var isResumingSession = false
    var isRefreshingSessions = false

    private var webSocketTask: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var requestCounter = 0
    private var pendingResponses: [String: CheckedContinuation<JSONValue, Error>] = [:]
    private var activeAssistantMessageID: UUID?
    private var activeStreamMessageID: UUID?
    private var activeStreamContentType: String?
    private var currentTurnReceivedMessageDelta = false
    private var currentTurnMessageDeltaSegmentCount = 0

    var canSendPrompt: Bool {
        isConnected && !isStreaming && !sessionID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func normalizedProfile(_ profile: String) -> String {
        let trimmed = profile.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "default" : trimmed
    }

    func connect(dashboardBaseURL: String, apiSettings: HermesAPISettings, profile: String, fast: Bool) {
        guard !isConnecting, !isStreaming else { return }
        let selectedProfile = normalizedProfile(profile)
        Task { await connectGateway(dashboardBaseURL: dashboardBaseURL, apiSettings: apiSettings, createSessionIfMissing: true, selectedProfile: selectedProfile, fast: fast) }
    }

    func disconnect() {
        receiveTask?.cancel()
        receiveTask = nil
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        isConnected = false
        isConnecting = false
        isStreaming = false
        isResumingSession = false
        connectionStatus = "Disconnected"
        failPending(HermesTUIGatewayError.notConnected)
    }

    func createSession(profile: String, fast: Bool) {
        guard !isStreaming else { return }
        let selectedProfile = normalizedProfile(profile)
        Task { await createGatewaySession(profile: selectedProfile, fast: fast) }
    }

    func submitPrompt(_ prompt: String, attachment: HermesPromptAttachment? = nil, attachmentPath: String = "", fast: Bool = false) {
        let text = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let path = attachmentPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || attachment != nil || !path.isEmpty else { return }
        Task { await submit(text, attachment: attachment, attachmentPath: path, fast: fast) }
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
        guard !isStreaming, !sessionID.isEmpty else { return }
        Task {
            do {
                _ = try await request("session.close", params: ["session_id": .string(sessionID)], timeoutSeconds: 20)
                appendEvent(title: "Session closed", content: shortSessionID(sessionID), eventType: "session.close")
                sessionID = ""
                storedSessionID = ""
                activeProfile = ""
                sessionTitle = "New TUI session"
                isStreaming = false
                await refreshActiveSessions()
            } catch {
                lastErrorMessage = error.localizedDescription
            }
        }
    }

    func refreshSessions() {
        guard !isStreaming else { return }
        Task { await refreshActiveSessions() }
    }

    func activateSession(_ liveSession: HermesTUILiveSession) {
        guard !isStreaming else { return }
        Task { await activate(sessionID: liveSession.id) }
    }

    func resumeStoredSession(_ storedSessionID: String, title: String = "", profile: String, dashboardBaseURL: String, apiSettings: HermesAPISettings) {
        let target = storedSessionID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !target.isEmpty else { return }
        let selectedProfile = normalizedProfile(profile)
        Task { await resumeStoredSession(target, title: title, profile: selectedProfile, dashboardBaseURL: dashboardBaseURL, apiSettings: apiSettings) }
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

    private func connectGateway(dashboardBaseURL: String, apiSettings: HermesAPISettings, createSessionIfMissing: Bool, selectedProfile: String, fast: Bool) async {
        guard !isConnecting else { return }
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
            if createSessionIfMissing && sessionID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                await createGatewaySession(profile: selectedProfile, fast: fast)
            }
            await refreshActiveSessions()
        } catch {
            isConnecting = false
            isConnected = false
            lastErrorMessage = error.localizedDescription
            connectionStatus = "Connection failed"
        }
    }

    private func resumeStoredSession(_ target: String, title: String, profile: String, dashboardBaseURL: String, apiSettings: HermesAPISettings) async {
        guard !isStreaming else {
            lastErrorMessage = "Wait for the active TUI Gateway turn to finish before resuming another session."
            return
        }
        let selectedProfile = normalizedProfile(profile)
        if !isConnected {
            await connectGateway(dashboardBaseURL: dashboardBaseURL, apiSettings: apiSettings, createSessionIfMissing: false, selectedProfile: selectedProfile, fast: false)
        }
        guard isConnected else { return }

        isResumingSession = true
        lastErrorMessage = ""
        connectionStatus = "Resuming session"
        defer { isResumingSession = false }

        do {
            let result = try await request(
                "session.resume",
                params: [
                    "session_id": .string(target),
                    "profile": .string(selectedProfile)
                ],
                timeoutSeconds: 180
            )
            let object = result.objectValue
            sessionID = object["session_id"]?.stringValue ?? sessionID
            storedSessionID = object["resumed"]?.stringValue ?? object["stored_session_id"]?.stringValue ?? object["session_key"]?.stringValue ?? target
            activeProfile = selectedProfile
            let displayTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            sessionTitle = displayTitle.isEmpty ? "TUI session \(shortSessionID(storedSessionID.isEmpty ? sessionID : storedSessionID))" : displayTitle
            resetStreamGrouping(resetTurn: false)
            isStreaming = object["running"]?.boolValue ?? false
            restoreMessages(from: object["messages"]?.arrayValue ?? [])
            connectionStatus = isStreaming ? "Streaming" : "Session resumed"
            await refreshActiveSessions()
        } catch {
            lastErrorMessage = error.localizedDescription
            connectionStatus = "Resume failed"
        }
    }

    private func createGatewaySession(profile: String, fast: Bool) async {
        do {
            let selectedProfile = normalizedProfile(profile)
            var params: [String: JSONValue] = ["profile": .string(selectedProfile)]
            if fast { params["fast"] = .bool(true) }
            let result = try await request("session.create", params: params, timeoutSeconds: 120)
            let object = result.objectValue
            sessionID = object["session_id"]?.stringValue ?? ""
            storedSessionID = object["stored_session_id"]?.stringValue ?? ""
            activeProfile = selectedProfile
            sessionTitle = "TUI session \(shortSessionID(sessionID))"
            messages.removeAll()
            resetStreamGrouping()
            isStreaming = false
            connectionStatus = sessionID.isEmpty ? "Session create failed" : "Session ready"
            appendEvent(title: "Session ready", content: "Created live TUI session \(shortSessionID(sessionID)).", eventType: "session.create")
            await refreshActiveSessions()
        } catch {
            lastErrorMessage = error.localizedDescription
            connectionStatus = "Session create failed"
        }
    }

    private func submit(_ text: String, attachment: HermesPromptAttachment? = nil, attachmentPath: String = "", fast: Bool = false) async {
        guard canSendPrompt else {
            lastErrorMessage = HermesTUIGatewayError.missingSession.localizedDescription
            return
        }
        let prepared: (text: String, activity: String?)
        do {
            prepared = try await promptPayload(text: text, attachment: attachment, attachmentPath: attachmentPath)
        } catch {
            lastErrorMessage = error.localizedDescription
            connectionStatus = "Attachment failed"
            return
        }
        let finalText = prepared.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !finalText.isEmpty else { return }
        if let activity = prepared.activity, !activity.isEmpty {
            appendEvent(title: "Attachment", content: activity, eventType: "input.attachment")
        }
        resetStreamGrouping()
        messages.append(HermesTUIGatewayMessage(role: .user, title: "You", content: finalText))
        isStreaming = true
        connectionStatus = "Sending prompt"
        do {
            var params: [String: JSONValue] = ["session_id": .string(sessionID), "text": .string(finalText)]
            if fast { params["fast"] = .bool(true) }
            _ = try await request("prompt.submit", params: params, timeoutSeconds: 60)
            connectionStatus = "Streaming"
        } catch {
            isStreaming = false
            lastErrorMessage = error.localizedDescription
            connectionStatus = "Prompt failed"
            updateAssistantMessage(text: "Request failed: \(error.localizedDescription)")
        }
    }

    private func promptPayload(text: String, attachment: HermesPromptAttachment?, attachmentPath: String) async throws -> (text: String, activity: String?) {
        guard let attachment else { return (text, nil) }
        if attachment.isImage {
            return try await promptPayloadWithNativeImage(text: text, attachment: attachment, attachmentPath: attachmentPath)
        }

        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let path = attachmentPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let pathLine = path.isEmpty ? "" : "\nLocal path: \(path)"
        let block: String
        if attachment.isUTF8Text {
            block = attachment.textAttachmentBlock + pathLine
        } else {
            block = "\nAttached file: \(attachment.filename) (\(attachment.mimeType), \(attachment.formattedByteCount))\(pathLine)\nUse the local path with file-aware tools if you need to inspect this document."
        }
        let finalText = [trimmedText, block.trimmingCharacters(in: .whitespacesAndNewlines)]
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
        return (finalText, "Attached file: \(attachment.filename) (\(attachment.formattedByteCount))")
    }

    private func promptPayloadWithNativeImage(text: String, attachment: HermesPromptAttachment, attachmentPath: String) async throws -> (text: String, activity: String?) {
        let path = attachmentPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else {
            let fallback = [text.trimmingCharacters(in: .whitespacesAndNewlines), "Attached image: \(attachment.filename)\n\(attachment.base64DataURL)"]
                .filter { !$0.isEmpty }
                .joined(separator: "\n\n")
            return (fallback, "Attached image inline: \(attachment.filename) (\(attachment.formattedByteCount))")
        }
        let dropText = [Self.quotedAttachmentPath(path), text.trimmingCharacters(in: .whitespacesAndNewlines)]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let result = try await request("input.detect_drop", params: ["session_id": .string(sessionID), "text": .string(dropText)], timeoutSeconds: 30)
        let object = result.objectValue
        guard object["matched"]?.boolValue == true else {
            throw HermesTUIGatewayError.requestFailed("Could not attach image at \(path).")
        }
        let finalText = object["text"]?.stringValue ?? text
        let name = object["name"]?.stringValue ?? attachment.filename
        let tokenEstimate = object["token_estimate"]?.stringValue.map { " • ~\($0) image tokens" } ?? ""
        return (finalText, "Attached image: \(name) (\(attachment.formattedByteCount))\(tokenEstimate)")
    }

    private nonisolated static func quotedAttachmentPath(_ path: String) -> String {
        let escaped = path
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    private func activate(sessionID target: String) async {
        do {
            let result = try await request("session.activate", params: ["session_id": .string(target)], timeoutSeconds: 60)
            let object = result.objectValue
            sessionID = object["session_id"]?.stringValue ?? target
            storedSessionID = object["stored_session_id"]?.stringValue ?? object["session_key"]?.stringValue ?? storedSessionID
            sessionTitle = activeSessions.first(where: { $0.id == target })?.title ?? "TUI session \(shortSessionID(target))"
            resetStreamGrouping(resetTurn: false)
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
            resetStreamGrouping()
        case "message.delta":
            let delta = payload["text"]?.stringValue ?? ""
            if !delta.isEmpty { appendAssistantDelta(delta) }
            connectionStatus = shortStatus("Receiving message")
        case "message.complete":
            let final = payload["text"]?.stringValue ?? ""
            let status = payload["status"]?.stringValue ?? "complete"
            if !final.isEmpty { completeAssistantMessage(text: final) }
            isStreaming = false
            resetStreamGrouping(resetTurn: true)
            connectionStatus = status == "complete" ? "Completed" : status.capitalized
        case "reasoning.delta", "thinking.delta":
            let text = payload["text"]?.stringValue ?? ""
            if !text.isEmpty {
                appendStreamContent(
                    type: event.type,
                    title: event.type == "thinking.delta" ? "Thinking" : "Reasoning",
                    content: text,
                    role: .event,
                    eventType: event.type
                )
            }
            connectionStatus = shortStatus(event.type == "thinking.delta" ? "Thinking" : "Reasoning")
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
            resetStreamGrouping(resetTurn: true)
            let message = payload["message"]?.stringValue ?? eventSummary(payload: payload)
            lastErrorMessage = message
            connectionStatus = "Error"
            appendEvent(title: "Gateway error", content: message, eventType: event.type)
        case let deltaType where deltaType.hasSuffix(".delta"):
            let text = payload["text"]?.stringValue ?? eventSummary(payload: payload)
            if !text.isEmpty {
                appendStreamContent(type: deltaType, title: streamTitle(for: deltaType), content: text, role: .event, eventType: deltaType)
            }
            connectionStatus = shortStatus(deltaType)
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
        currentTurnReceivedMessageDelta = true
        let result = appendStreamContent(type: "message.delta", title: "Hermes", content: delta, role: .assistant)
        if result.created {
            currentTurnMessageDeltaSegmentCount += 1
        }
        activeAssistantMessageID = result.id
    }

    private func updateAssistantMessage(text: String) {
        let result = appendStreamContent(type: "message.delta", title: "Hermes", content: text, role: .assistant)
        activeAssistantMessageID = result.id
    }

    private func completeAssistantMessage(text: String) {
        if !currentTurnReceivedMessageDelta {
            updateAssistantMessage(text: text)
            return
        }
        guard currentTurnMessageDeltaSegmentCount <= 1,
              let activeAssistantMessageID,
              let index = messages.firstIndex(where: { $0.id == activeAssistantMessageID })
        else { return }
        messages[index].content = text
    }

    @discardableResult
    private func appendStreamContent(type: String, title: String, content: String, role: HermesTUIGatewayMessage.Role, eventType: String? = nil) -> (id: UUID?, created: Bool) {
        guard !content.isEmpty else { return (nil, false) }
        if activeStreamContentType == type,
           let activeStreamMessageID,
           let index = messages.firstIndex(where: { $0.id == activeStreamMessageID }) {
            messages[index].content += content
            return (messages[index].id, false)
        }
        let message = HermesTUIGatewayMessage(role: role, title: title, content: content, eventType: eventType)
        activeStreamContentType = type
        activeStreamMessageID = message.id
        if role == .assistant {
            activeAssistantMessageID = message.id
        }
        messages.append(message)
        return (message.id, true)
    }

    private func resetStreamGrouping(resetTurn: Bool = true) {
        activeAssistantMessageID = nil
        activeStreamMessageID = nil
        activeStreamContentType = nil
        if resetTurn {
            currentTurnReceivedMessageDelta = false
            currentTurnMessageDeltaSegmentCount = 0
        }
    }

    private func appendEvent(title: String, content: String, eventType: String) {
        resetStreamGrouping(resetTurn: false)
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        messages.append(HermesTUIGatewayMessage(role: .event, title: title, content: trimmed.isEmpty ? eventType : trimmed, eventType: eventType))
    }

    private func appendRequest(kind: HermesTUIGatewayMessage.RequestKind, title: String, payload: [String: JSONValue]) {
        resetStreamGrouping(resetTurn: false)
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
        resetStreamGrouping()
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

    private func streamTitle(for eventType: String) -> String {
        eventType
            .replacingOccurrences(of: ".delta", with: "")
            .split(separator: ".")
            .map { $0.capitalized }
            .joined(separator: " ")
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

struct HermesTUIGatewayWorkspacesView: View {
    let apiSettings: HermesAPISettings
    let dashboardURL: String
    let workspaces: [HermesTUIWorkspace]
    @Binding var selectedWorkspaceID: HermesTUIWorkspace.ID
    let connectedHostName: String
    let connectedWindowID: UUID
    let onSelectWorkspace: (HermesTUIWorkspace) -> Void
    let onAddWorkspace: () -> Void
    let onDeleteWorkspace: (HermesTUIWorkspace) -> Void

    private var selectedWorkspace: HermesTUIWorkspace {
        workspaces.first(where: { $0.id == selectedWorkspaceID }) ?? workspaces[0]
    }

    var body: some View {
        HermesTUIGatewayWorkspaceHost(
            apiSettings: apiSettings,
            dashboardURL: dashboardURL,
            workspace: selectedWorkspace,
            connectedHostName: connectedHostName,
            connectedWindowID: connectedWindowID,
            workspaceControls: workspaceControls
        )
        .id(selectedWorkspace.id)
    }

    private var workspaceControls: AnyView {
        AnyView(
            HStack(spacing: 6) {
                Button(action: onAddWorkspace) {
                    HermesComposerCircleButtonLabel(systemImage: "plus", foreground: Color.hermesActionBlue, size: 24)
                }
                .buttonStyle(.plain)
                .help("Open a new TUI Gateway workspace")
                .accessibilityLabel("Open a new TUI Gateway workspace")

                ForEach(workspaces) { workspace in
                    Button {
                        onSelectWorkspace(workspace)
                    } label: {
                        HermesTUIWorkspaceButtonLabel(
                            number: workspace.number,
                            isSelected: workspace.id == selectedWorkspaceID,
                            attention: workspace.attention
                        )
                    }
                    .buttonStyle(.plain)
                    .controlSize(.small)
                    .contextMenu {
                        Button(role: .destructive) {
                            onDeleteWorkspace(workspace)
                        } label: {
                            Label("Delete Workspace", systemImage: "trash")
                        }
                        .disabled(workspace.store.isStreaming || workspace.store.isConnecting || workspace.store.isResumingSession)
                    }
                    .help("Switch to TUI Gateway workspace \(workspace.number)")
                    .accessibilityLabel("TUI Gateway workspace \(workspace.number)")
                }
            }
        )
    }
}

private struct HermesTUIGatewayWorkspaceHost: View {
    let apiSettings: HermesAPISettings
    let dashboardURL: String
    @Bindable var workspace: HermesTUIWorkspace
    let connectedHostName: String
    let connectedWindowID: UUID
    let workspaceControls: AnyView

    var body: some View {
        HermesTUIGatewayView(
            apiSettings: apiSettings,
            dashboardURL: dashboardURL,
            store: workspace.store,
            promptText: $workspace.promptText,
            requestResponses: $workspace.requestResponses,
            selectedAttachment: $workspace.selectedAttachment,
            selectedAttachmentPath: $workspace.selectedAttachmentPath,
            selectedProfile: $workspace.selectedProfile,
            fastModeEnabled: $workspace.fastModeEnabled,
            connectedHostName: connectedHostName,
            connectedWindowID: connectedWindowID,
            workspaceControls: workspaceControls
        )
    }
}

private struct HermesTUIWorkspaceButtonLabel: View {
    let number: Int
    let isSelected: Bool
    let attention: HermesTopTabAttention?
    @State private var isBlinking = false

    private var backgroundColor: Color {
        switch attention {
        case .streaming:
            return .hermesOrange
        case .completed:
            return .green
        case .failed:
            return .hermesDestructive
        case nil:
            return isSelected ? .hermesActionBlue : .hermesSurface
        }
    }

    private var foregroundColor: Color {
        (attention != nil || isSelected) ? .white : .primary
    }

    private var blinkOpacity: Double {
        attention == .streaming && isBlinking ? 0.45 : 1.0
    }

    var body: some View {
        Text("\(number)")
            .font(.caption.weight(.bold))
            .monospacedDigit()
            .foregroundStyle(foregroundColor)
            .frame(width: 24, height: 24)
            .background(backgroundColor.opacity(blinkOpacity), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).stroke(Color.white.opacity(0.14), lineWidth: 1))
            .task(id: attention) {
                await runBlinkLoop(for: attention)
            }
    }

    @MainActor
    private func runBlinkLoop(for attention: HermesTopTabAttention?) async {
        guard attention == .streaming else {
            isBlinking = false
            return
        }

        isBlinking = false
        while !Task.isCancelled {
            withAnimation(.easeInOut(duration: 0.45)) {
                isBlinking = true
            }
            do { try await Task.sleep(nanoseconds: 450_000_000) } catch { break }
            if Task.isCancelled { break }
            withAnimation(.easeInOut(duration: 0.45)) {
                isBlinking = false
            }
            do { try await Task.sleep(nanoseconds: 450_000_000) } catch { break }
        }
        isBlinking = false
    }
}

struct HermesTUIGatewayView: View {
    let apiSettings: HermesAPISettings
    let dashboardURL: String
    @Bindable var store: HermesTUIGatewayStore
    @Binding var promptText: String
    @Binding var requestResponses: [UUID: String]
    @Binding var selectedAttachment: HermesPromptAttachment?
    @Binding var selectedAttachmentPath: String
    @Binding var selectedProfile: String
    @Binding var fastModeEnabled: Bool
    let connectedHostName: String
    let connectedWindowID: UUID
    let workspaceControls: AnyView

    @State private var isImportingAttachment = false
    @State private var apiProfiles: [HermesAPIProfile] = []
    @State private var profileRefreshError = ""
    @State private var dashboardSkills = HermesDashboardSkillsStore()
    @State private var localPathSuggestions = HermesLocalPathSuggestionsStore()
    @State private var selectedSkillIndex = 0
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
        .task(id: apiSettings.baseURL) {
            await refreshAPIProfiles()
        }
        .onChange(of: apiSettings) { _, _ in Task { await refreshAPIProfiles() } }
        .onChange(of: apiProfiles) { _, _ in clampFastModeIfNeeded() }
        .onChange(of: selectedProfile) { _, _ in clampFastModeIfNeeded() }
        .onChange(of: promptText) { _, _ in handlePromptSkillQueryChange() }
        .onDisappear { }
        .fileImporter(isPresented: $isImportingAttachment, allowedContentTypes: HermesPromptAttachment.supportedContentTypes, allowsMultipleSelection: false) { result in
            handleAttachmentImport(result)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Label("TUI Gateway", systemImage: "terminal.fill")
                    .hermesWebsiteTitleFont(size: 22, weight: .bold)
                workspaceControls
                Spacer()
                HermesConnectedHostLabel(hostName: connectedHostName, windowID: connectedWindowID)
                if store.isConnecting || store.isStreaming || store.isResumingSession || store.isRefreshingSessions {
                    ProgressView().controlSize(.small)
                }
            }

            HStack(alignment: .top, spacing: 12) {
                HermesProfileSelector(
                    selectedProfile: $selectedProfile,
                    apiProfiles: apiProfiles,
                    lockedProfile: store.activeProfile,
                    isDisabled: store.isConnecting || store.isStreaming || store.isResumingSession
                ) { newProfile in
                    handleProfileSelection(newProfile)
                }
                HermesTUIFastTogglePill(
                    isOn: $fastModeEnabled,
                    isSupported: selectedProfileSupportsFastMode,
                    isDisabled: store.isConnecting || store.isStreaming || store.isResumingSession
                ) { isEnabled in
                    handleFastModeSelection(isEnabled)
                }
                HermesStatusCard(title: "Session", value: store.sessionTitle, tint: .hermesActionBlue, minimumWidth: 210, maximumWidth: .infinity)
                HermesStatusCard(title: "Status", value: store.connectionStatus, tint: .hermesOrange, minimumWidth: 210, maximumWidth: 300)
                HermesStatusCard(title: "Events", value: "\(store.eventCount)", tint: .hermesPurple, minimumWidth: 100, maximumWidth: 120)
            }

            if !profileRefreshError.isEmpty {
                Label(profileRefreshError, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(Color.hermesDestructive)
            }

            HStack(spacing: 10) {
                Button(store.isConnected ? "Reconnect" : "Connect") {
                    guard !store.isStreaming else { return }
                    store.disconnect()
                    store.connect(dashboardBaseURL: dashboardURL, apiSettings: apiSettings, profile: selectedProfile, fast: fastModeEnabled && selectedProfileSupportsFastMode)
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.isConnecting || store.isStreaming)

                Button("New session") { store.createSession(profile: selectedProfile, fast: fastModeEnabled && selectedProfileSupportsFastMode) }
                    .buttonStyle(.bordered)
                    .disabled(!store.isConnected || store.isStreaming || store.isResumingSession)

                Button("Interrupt") { store.interruptSession() }
                    .buttonStyle(.bordered)
                    .disabled(!store.isStreaming)

                Button("Close session") { store.closeSession() }
                    .buttonStyle(.bordered)
                    .disabled(!store.isConnected || store.sessionID.isEmpty || store.isStreaming)

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
                .disabled(!store.isConnected || store.isStreaming)
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
            if let selectedAttachment {
                HermesAttachmentChip(attachment: selectedAttachment) {
                    self.selectedAttachment = nil
                    selectedAttachmentPath = ""
                }
                .disabled(store.isStreaming)
            }

            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    if shouldShowSkillPicker {
                        HermesSkillSlashPicker(
                            skills: filteredSkillSuggestions,
                            selectedIndex: selectedSkillIndex,
                            isLoading: dashboardSkills.isLoading,
                            errorMessage: dashboardSkills.lastErrorMessage,
                            onSelect: selectSkillSuggestion
                        )
                    } else if shouldShowPathPicker, let activePathToken {
                        HermesPathSlashPicker(
                            pathToken: activePathToken,
                            paths: localPathSuggestions.suggestions,
                            selectedIndex: selectedSkillIndex,
                            errorMessage: localPathSuggestions.lastErrorMessage,
                            onSelect: selectPathSuggestion
                        )
                    }

                    TextEditor(text: $promptText)
                        .font(.system(size: promptFontSize))
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 78, maxHeight: 150)
                        .padding(8)
                        .hermesGlassInput(tint: Color.hermesSurfaceInput.opacity(store.isStreaming ? 0.42 : 0.70))
                        .disabled(!store.isConnected || store.isStreaming)
                        .onKeyPress(.upArrow) {
                            guard shouldShowCompletionPicker else { return .ignored }
                            moveSkillSelection(delta: -1)
                            return .handled
                        }
                        .onKeyPress(.downArrow) {
                            guard shouldShowCompletionPicker else { return .ignored }
                            moveSkillSelection(delta: 1)
                            return .handled
                        }
                        .onKeyPress(.return) {
                            guard shouldShowCompletionPicker else { return .ignored }
                            if shouldShowSkillPicker, let skill = selectedSkillSuggestion {
                                selectSkillSuggestion(skill)
                                return .handled
                            }
                            if shouldShowPathPicker, let path = selectedPathSuggestion {
                                selectPathSuggestion(path)
                                return .handled
                            }
                            return .ignored
                        }
                        .onKeyPress(.tab) {
                            guard shouldShowPathPicker,
                                  let path = selectedPathSuggestion,
                                  path.isDirectory
                            else { return .ignored }
                            selectPathSuggestion(path)
                            return .handled
                        }
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
                }

                VStack(spacing: 8) {
                    Button { isImportingAttachment = true } label: {
                        HermesComposerCircleButtonLabel(systemImage: selectedAttachment == nil ? "paperclip" : "paperclip.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .disabled(!store.isConnected || store.isStreaming)
                    .help(selectedAttachment == nil ? "Attach file" : "Change attached file")

                    Button { submitPrompt() } label: {
                        HermesComposerSendButtonLabel()
                    }
                    .buttonStyle(.plain)
                    .disabled(!store.canSendPrompt || (promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedAttachment == nil))
                    .keyboardShortcut(.return, modifiers: [.command])
                    .help("Send through TUI Gateway (⌘↩)")
                }
            }
        }
        .padding(16)
        .hermesGlassPanel(cornerRadius: 0)
    }

    private var activeSlashToken: String? { promptText.hermesActiveSlashCompletionToken }
    private var activeSkillQuery: String? { promptText.hermesActiveSlashSkillQuery }

    private var filteredSkillSuggestions: [HermesDashboardSkill] {
        guard let query = activeSkillQuery else { return [] }
        if query.isEmpty { return dashboardSkills.skills }
        return dashboardSkills.skills.filter { $0.name.range(of: query, options: [.caseInsensitive, .anchored]) != nil }
    }

    private var activePathToken: String? {
        guard let token = activeSlashToken else { return nil }
        let pathText = token.dropFirst()
        guard !pathText.isEmpty, !dashboardSkills.isLoading, filteredSkillSuggestions.isEmpty else { return nil }
        return token
    }

    private var shouldShowSkillPicker: Bool {
        activeSkillQuery != nil && (dashboardSkills.isLoading || (!dashboardSkills.lastErrorMessage.isEmpty && activePathToken == nil) || !filteredSkillSuggestions.isEmpty)
    }

    private var shouldShowPathPicker: Bool { activePathToken != nil }

    private var shouldShowCompletionPicker: Bool { shouldShowSkillPicker || shouldShowPathPicker }

    private var selectedAPIProfile: HermesAPIProfile? {
        let active = normalizedProfile(selectedProfile)
        return apiProfiles.first(where: { $0.id == active })
    }

    private var selectedProfileSupportsFastMode: Bool {
        selectedAPIProfile?.supportsFastMode ?? false
    }

    private var activeFastMode: Bool {
        fastModeEnabled && selectedProfileSupportsFastMode
    }

    private func clampFastModeIfNeeded() {
        if fastModeEnabled && !selectedProfileSupportsFastMode {
            fastModeEnabled = false
        }
    }

    private func handleFastModeSelection(_ isEnabled: Bool) {
        guard selectedProfileSupportsFastMode else {
            fastModeEnabled = false
            return
        }
        fastModeEnabled = isEnabled
    }

    private func handleProfileSelection(_ newProfile: String) {
        selectedProfile = normalizedProfile(newProfile)
        clampFastModeIfNeeded()
        let active = normalizedProfile(store.activeProfile)
        guard store.isConnected,
              !store.sessionID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !store.isStreaming,
              !store.isConnecting,
              !store.isResumingSession,
              active != selectedProfile
        else { return }
        store.createSession(profile: selectedProfile, fast: activeFastMode)
    }

    private func refreshAPIProfiles() async {
        do {
            let profiles = try await HermesAPIProfilesClient.fetchProfiles(apiSettings: apiSettings)
            apiProfiles = profiles
            profileRefreshError = ""
            syncSelectedProfileWithAPIProfiles(profiles)
        } catch {
            apiProfiles = []
            profileRefreshError = String(localized: "Profiles unavailable: \(error.localizedDescription)")
        }
    }

    private func syncSelectedProfileWithAPIProfiles(_ profiles: [HermesAPIProfile]) {
        let current = selectedProfile.trimmingCharacters(in: .whitespacesAndNewlines)
        if current.isEmpty { selectedProfile = profiles.first?.id ?? "default" }
        else if !profiles.isEmpty && !profiles.contains(where: { $0.id == current }) { selectedProfile = profiles.first?.id ?? "default" }
        clampFastModeIfNeeded()
    }

    private func normalizedProfile(_ profile: String) -> String {
        let trimmed = profile.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "default" : trimmed
    }

    private var selectedSkillSuggestion: HermesDashboardSkill? {
        let suggestions = filteredSkillSuggestions
        guard suggestions.indices.contains(selectedSkillIndex) else { return suggestions.first }
        return suggestions[selectedSkillIndex]
    }

    private var selectedPathSuggestion: HermesLocalPathSuggestion? {
        let suggestions = localPathSuggestions.suggestions
        guard suggestions.indices.contains(selectedSkillIndex) else { return suggestions.first }
        return suggestions[selectedSkillIndex]
    }

    private func handlePromptSkillQueryChange() {
        guard activeSlashToken != nil else {
            localPathSuggestions.clear()
            selectedSkillIndex = 0
            return
        }
        dashboardSkills.refreshIfNeeded(dashboardBaseURL: dashboardURL, apiSettings: apiSettings)
        if let activePathToken {
            localPathSuggestions.refresh(pathToken: activePathToken)
        } else {
            localPathSuggestions.clear()
        }
        let count = shouldShowSkillPicker ? filteredSkillSuggestions.count : localPathSuggestions.suggestions.count
        if count == 0 || selectedSkillIndex >= count { selectedSkillIndex = 0 }
    }

    private func moveSkillSelection(delta: Int) {
        let count = shouldShowSkillPicker ? filteredSkillSuggestions.count : localPathSuggestions.suggestions.count
        guard count > 0 else { return }
        selectedSkillIndex = (selectedSkillIndex + delta + count) % count
    }

    private func selectSkillSuggestion(_ skill: HermesDashboardSkill) {
        promptText = promptText.replacingActiveSlashSkillQuery(with: skill.name)
        localPathSuggestions.clear()
        selectedSkillIndex = 0
    }

    private func selectPathSuggestion(_ path: HermesLocalPathSuggestion) {
        promptText = promptText.replacingActiveSlashCompletionToken(with: path.insertedPath)
        selectedSkillIndex = 0
    }

    private func submitPrompt() {
        let text = promptText
        store.submitPrompt(text, attachment: selectedAttachment, attachmentPath: selectedAttachmentPath, fast: activeFastMode)
        promptText = ""
        selectedAttachment = nil
        selectedAttachmentPath = ""
    }

    private func handleAttachmentImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                selectedAttachment = try HermesPromptAttachment.load(from: url)
                selectedAttachmentPath = url.path
                store.lastErrorMessage = ""
            } catch {
                store.lastErrorMessage = error.localizedDescription
            }
        case .failure(let error):
            store.lastErrorMessage = error.localizedDescription
        }
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

private struct HermesTUIFastTogglePill: View {
    @Binding var isOn: Bool
    let isSupported: Bool
    let isDisabled: Bool
    let onChange: (Bool) -> Void

    private var isControlDisabled: Bool { isDisabled || !isSupported }
    private var effectiveIsOn: Bool { isSupported && isOn }

    var body: some View {
        Button {
            guard !isControlDisabled else { return }
            let nextValue = !effectiveIsOn
            isOn = nextValue
            onChange(nextValue)
        } label: {
            HStack(spacing: 6) {
                Text(verbatim: "FAST")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(labelColor)
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(toggleFill)
                    .frame(width: 28, height: 16)
                    .overlay(alignment: effectiveIsOn ? .trailing : .leading) {
                        Circle()
                            .fill(Color.white.opacity(isControlDisabled ? 0.72 : 0.95))
                            .frame(width: 12, height: 12)
                            .padding(2)
                    }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(backgroundFill, in: Capsule())
            .overlay(Capsule().stroke(borderColor, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(isControlDisabled)
        .opacity(isControlDisabled ? 0.48 : 1.0)
        .help(helpText)
        .accessibilityLabel("Fast mode")
        .accessibilityValue(effectiveIsOn ? "On" : "Off")
    }

    private var labelColor: Color {
        if !isSupported { return .hermesSecondaryText }
        return effectiveIsOn ? .white : .primary
    }

    private var toggleFill: Color {
        if !isSupported { return .hermesSecondaryText }
        return effectiveIsOn ? .hermesActionBlue : .hermesSecondaryText.opacity(0.8)
    }

    private var backgroundFill: Color {
        if !isSupported { return .hermesSurface.opacity(0.45) }
        return effectiveIsOn ? .hermesActionBlue.opacity(0.22) : .hermesSurface.opacity(0.74)
    }

    private var borderColor: Color {
        if !isSupported { return .hermesSecondaryText.opacity(0.55) }
        return effectiveIsOn ? .hermesActionBlue.opacity(0.7) : .hermesSecondaryText.opacity(0.8)
    }

    private var helpText: String {
        isSupported ? "Send prompts with Hermes FAST mode" : "The selected profile model does not support FAST mode"
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
