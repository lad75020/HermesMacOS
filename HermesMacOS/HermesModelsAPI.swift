//
//  HermesModelsAPI.swift
//  HermesMacOS
//

import Foundation
import Observation
import UniformTypeIdentifiers

let defaultHermesMacHost = "mac-studio.tail4d2ab4.ts.net"
let defaultHermesAPIPort = "8642"

enum HermesHostEndpoints {
    static func httpURLString(host: String, port: String, path: String = "") -> String {
        let normalizedHost = normalizedHost(host)
        let normalizedPort = tcpPort(from: port, fallback: defaultHermesAPIPort)
        let normalizedPath = path.isEmpty ? "" : (path.hasPrefix("/") ? path : "/\(path)")
        return "https://\(normalizedHost):\(normalizedPort)\(normalizedPath)"
    }

    static func normalizedHost(_ host: String) -> String {
        let trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return defaultHermesMacHost }
        if let components = URLComponents(string: trimmed), components.scheme != nil, let host = components.host, !host.isEmpty { return host }
        let withoutPath = trimmed.split(separator: "/", maxSplits: 1).first.map(String.init) ?? trimmed
        if withoutPath.filter({ $0 == ":" }).count == 1, let colon = withoutPath.lastIndex(of: ":") {
            return String(withoutPath[..<colon])
        }
        return withoutPath
    }

    static func tcpPort(from value: String, fallback: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return fallback }
        if let components = URLComponents(string: trimmed), let port = components.port { return String(port) }
        let digits = trimmed.filter(\.isNumber)
        return digits.isEmpty ? fallback : String(digits.prefix(5))
    }
}

struct HermesAPISettings: Codable, Equatable {
    var baseURL = HermesHostEndpoints.httpURLString(host: defaultHermesMacHost, port: defaultHermesAPIPort, path: "/v1")
    var apiKey = ""
    var allowSelfSignedCertificates = false

    static func responseURL(from baseURL: String) -> URL? { endpointURL(from: baseURL, suffix: "responses") }
    static func profilesURL(from baseURL: String) -> URL? { endpointURL(from: baseURL, suffix: "profiles") }

    private static func endpointURL(from baseURL: String, suffix: String) -> URL? {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.hasSuffix("/\(suffix)") { return URL(string: trimmed) }
        guard var components = URLComponents(string: trimmed) else { return nil }
        let normalizedPath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if normalizedPath.isEmpty {
            components.path = "/v1/\(suffix)"
            return components.url
        }
        return URL(string: trimmed.hasSuffix("/") ? trimmed + suffix : trimmed + "/" + suffix)
    }
}

struct HermesRequestDraft: Codable, Equatable {
    var profile = "default"
    var userPrompt = "Summarize the current project layout and recommend the next integration step."
    var stream = true

    func locked(toProfile profile: String) -> HermesRequestDraft {
        var copy = self
        let trimmed = profile.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.profile = trimmed.isEmpty ? "default" : trimmed
        return copy
    }
}

enum HermesSettingsStore {
    private static let apiSettingsKey = "hermes.macOS.apiSettings"
    private static let requestDraftKey = "hermes.macOS.responsesDraft"
    private static let lastResponseIDKey = "hermes.macOS.lastResponsesSessionID"
    private static let lastResponseTitleKey = "hermes.macOS.lastResponsesSessionTitle"

    static func loadAPISettings() -> HermesAPISettings { load(HermesAPISettings.self, forKey: apiSettingsKey) ?? HermesAPISettings() }
    static func saveAPISettings(_ value: HermesAPISettings) { save(value, forKey: apiSettingsKey) }
    static func loadDraft() -> HermesRequestDraft { load(HermesRequestDraft.self, forKey: requestDraftKey) ?? HermesRequestDraft() }
    static func saveDraft(_ value: HermesRequestDraft) { save(value, forKey: requestDraftKey) }
    static func loadLastResponsesSessionID() -> String { UserDefaults.standard.string(forKey: lastResponseIDKey) ?? "" }
    static func saveLastResponsesSessionID(_ value: String) { UserDefaults.standard.set(value, forKey: lastResponseIDKey) }
    static func loadLastResponsesSessionTitle() -> String { UserDefaults.standard.string(forKey: lastResponseTitleKey) ?? "" }
    static func saveLastResponsesSessionTitle(_ value: String) { UserDefaults.standard.set(value, forKey: lastResponseTitleKey) }

    private static func load<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private static func save<T: Encodable>(_ value: T, forKey key: String) {
        if let data = try? JSONEncoder().encode(value) { UserDefaults.standard.set(data, forKey: key) }
    }
}

struct HermesAPIProfile: Decodable, Identifiable, Equatable {
    let id: String
    let name: String
    let isDefault: Bool
    let model: String?
    let provider: String?

    enum CodingKeys: String, CodingKey {
        case id, name, model, provider
        case isDefault = "is_default"
    }
}

private struct HermesAPIProfilesEnvelope: Decodable { let data: [HermesAPIProfile] }

enum HermesAPIProfilesClient {
    static func fetchProfiles(apiSettings: HermesAPISettings) async throws -> [HermesAPIProfile] {
        guard let url = HermesAPISettings.profilesURL(from: apiSettings.baseURL) else { throw HermesResponsesError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if !apiSettings.apiKey.isEmpty { request.setValue("Bearer \(apiSettings.apiKey)", forHTTPHeaderField: "Authorization") }
        let (data, response) = try await HermesNetworkSessionFactory.session(for: apiSettings).data(for: request)
        try HermesNetworkSessionFactory.validate(response: response)
        return try JSONDecoder().decode(HermesAPIProfilesEnvelope.self, from: data).data.filter { !$0.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
}

struct HermesPromptAttachment: Equatable {
    let filename: String
    let mimeType: String
    let data: Data
    let fileExtension: String

    static let supportedFileExtensions: Set<String> = ["png", "jpg", "jpeg", "gif", "webp", "pdf", "docx", "pptx", "xlsx", "txt", "text", "json", "yaml", "yml", "toml", "swift"]
    static let imageFileExtensions: Set<String> = ["png", "jpg", "jpeg", "gif", "webp"]
    static let utf8FileExtensions: Set<String> = ["txt", "text", "json", "yaml", "yml", "toml", "swift"]

    static var supportedContentTypes: [UTType] {
        var types: [UTType] = [.pdf, .plainText, .text, .json, .sourceCode, .swiftSource]
        ["public.png", "public.jpeg", "com.compuserve.gif", "org.webmproject.webp", "public.yaml", "public.toml", "org.openxmlformats.wordprocessingml.document", "org.openxmlformats.presentationml.presentation", "org.openxmlformats.spreadsheetml.sheet"].forEach { if let type = UTType($0) { types.append(type) } }
        supportedFileExtensions.forEach { if let type = UTType(filenameExtension: $0) { types.append(type) } }
        return Array(Set(types))
    }

    static func load(from url: URL) throws -> HermesPromptAttachment {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
        let values = try url.resourceValues(forKeys: [.contentTypeKey, .nameKey])
        let data = try Data(contentsOf: url)
        return try HermesPromptAttachment(filename: values.name ?? url.lastPathComponent, contentType: values.contentType, data: data)
    }

    init(filename: String, contentType: UTType?, data: Data) throws {
        let normalized = filename.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "attachment" : filename
        let ext = URL(fileURLWithPath: normalized).pathExtension.lowercased()
        guard Self.supportedFileExtensions.contains(ext) else { throw HermesAttachmentError.unsupportedFileType(ext.isEmpty ? normalized : ".\(ext)") }
        self.filename = normalized
        self.fileExtension = ext
        self.mimeType = Self.mimeType(forExtension: ext, contentType: contentType)
        self.data = data
    }

    var isImage: Bool { Self.imageFileExtensions.contains(fileExtension) }
    var isUTF8Text: Bool { Self.utf8FileExtensions.contains(fileExtension) }
    var formattedByteCount: String { ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file) }
    var base64DataURL: String { "data:\(mimeType);base64,\(data.base64EncodedString())" }
    var textContent: String? { isUTF8Text ? String(data: data, encoding: .utf8) : nil }
    var textAttachmentBlock: String {
        if let textContent {
            return "\n" + String(localized: "Attached file: \(filename) (\(mimeType), \(formattedByteCount))\n```\(fileExtension)\n\(textContent)\n```")
        }
        return "\n" + String(localized: "Attached file: \(filename) (\(mimeType), \(formattedByteCount))\nThe file is provided as a base64 data URL. Decode it if you need to inspect or process the document bytes:\n\(base64DataURL)")
    }

    private static func mimeType(forExtension ext: String, contentType: UTType?) -> String {
        if let preferred = contentType?.preferredMIMEType, !preferred.isEmpty { return preferred }
        switch ext {
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "webp": return "image/webp"
        case "pdf": return "application/pdf"
        case "docx": return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "pptx": return "application/vnd.openxmlformats-officedocument.presentationml.presentation"
        case "xlsx": return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        case "json": return "application/json"
        case "yaml", "yml": return "application/yaml"
        case "toml": return "application/toml"
        case "swift": return "text/x-swift"
        default: return "text/plain"
        }
    }
}

enum HermesAttachmentError: LocalizedError {
    case unsupportedFileType(String)
    var errorDescription: String? { String(localized: "Unsupported attachment type: \(typeDescription). Choose an image, PDF, Office document, text, JSON, YAML, TOML, or Swift file.") }
    private var typeDescription: String { if case .unsupportedFileType(let value) = self { value } else { "file" } }
}

final class HermesNetworkSessionDelegate: NSObject, URLSessionDelegate {
    private let allowSelfSignedCertificates: Bool
    init(allowSelfSignedCertificates: Bool) { self.allowSelfSignedCertificates = allowSelfSignedCertificates }

    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard allowSelfSignedCertificates, challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust, let trust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        completionHandler(.useCredential, URLCredential(trust: trust))
    }
}

enum HermesNetworkSessionFactory {
    static func session(for apiSettings: HermesAPISettings) -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = true
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 3600
        if apiSettings.allowSelfSignedCertificates {
            return URLSession(configuration: configuration, delegate: HermesNetworkSessionDelegate(allowSelfSignedCertificates: true), delegateQueue: nil)
        }
        return URLSession(configuration: configuration)
    }

    static func validate(response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else { throw HermesResponsesError.invalidResponse }
        guard 200 ..< 300 ~= httpResponse.statusCode else { throw HermesResponsesError.httpError(httpResponse.statusCode) }
    }
}

enum HermesRequestFailureClassifier {
    static func isTimeoutOrNetworkLoss(_ error: Error) -> Bool {
        if let urlError = error as? URLError { return isTimeoutOrNetworkLoss(urlError.code) }
        if case HermesResponsesError.httpError(let statusCode) = error { return statusCode == 408 || statusCode == 504 }
        return isTimeoutOrNetworkLoss(error.localizedDescription)
    }
    static func isTimeoutOrNetworkLoss(_ message: String) -> Bool {
        let value = message.lowercased()
        return ["timed out", "timeout", "network connection was lost", "not connected to the internet", "cannot connect", "cannot find host", "dns"].contains { value.contains($0) }
    }
    private static func isTimeoutOrNetworkLoss(_ code: URLError.Code) -> Bool {
        [.timedOut, .networkConnectionLost, .notConnectedToInternet, .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed, .dataNotAllowed].contains(code)
    }
}

@MainActor
@Observable
final class HermesResponsesSession {
    var entries: [HermesResponseMessage] = []
    var streamedText = ""
    var isSending = false
    var isStreaming = false
    var activeProfile = ""
    var connectionStatus = "Idle"
    var latestResponseID = ""
    var previousResponseID = ""
    var activeHermesSessionID = ""
    var lastKnownResponseID = ""
    var lastKnownResponseTitle = ""
    var lastErrorMessage = ""
    var lastErrorWasTimeoutOrNetworkLoss = false
    var latestMessageType = ""
    var eventCount = 0
    var rawStreamedJSON = ""
    var sessionTitle = ""

    private var requestTask: Task<Void, Never>?
    private var activeAssistantEntryID: UUID?
    private var activeHistoryStore: HermesPromptHistoryStore?

    init() {
        lastKnownResponseID = HermesSettingsStore.loadLastResponsesSessionID()
        lastKnownResponseTitle = HermesSettingsStore.loadLastResponsesSessionTitle()
    }

    var displaySessionTitle: String {
        let title = sessionTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty { return title }
        return previousResponseID.isEmpty && activeHermesSessionID.isEmpty ? String(localized: "New response") : String(localized: "Continuing response")
    }

    var localizedConnectionStatus: String {
        String(localized: String.LocalizationValue(connectionStatus))
    }

    var hasActiveConversation: Bool { !previousResponseID.isEmpty || !latestResponseID.isEmpty || !activeHermesSessionID.isEmpty || !entries.isEmpty || isSending }

    func submit(apiSettings: HermesAPISettings, draft: HermesRequestDraft, attachment: HermesPromptAttachment? = nil, historyStore: HermesPromptHistoryStore? = nil) {
        requestTask?.cancel()
        activeHistoryStore = historyStore
        historyStore?.record(draft.userPrompt, source: .askHermes)
        let requestedProfile = draft.profile.trimmingCharacters(in: .whitespacesAndNewlines)
        if activeProfile.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { activeProfile = requestedProfile.isEmpty ? "default" : requestedProfile }
        let lockedDraft = draft.locked(toProfile: activeProfile)
        requestTask = Task { await runRequest(apiSettings: apiSettings, draft: lockedDraft, attachment: attachment) }
    }

    func cancel() {
        requestTask?.cancel()
        requestTask = nil
        isSending = false
        isStreaming = false
        connectionStatus = "Cancelled"
    }

    func terminateAndStartNewSession() {
        requestTask?.cancel()
        entries = []
        streamedText = ""
        activeAssistantEntryID = nil
        isSending = false
        isStreaming = false
        activeProfile = ""
        connectionStatus = "New session ready"
        latestResponseID = ""
        previousResponseID = ""
        activeHermesSessionID = ""
        lastErrorMessage = ""
        latestMessageType = ""
        eventCount = 0
        rawStreamedJSON = ""
        sessionTitle = ""
    }

    func resumeLastKnownResponseSession() {
        let sessionID = lastKnownResponseID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sessionID.isEmpty else { connectionStatus = "No previous session"; return }
        requestTask?.cancel()
        entries = [HermesResponseMessage(role: "assistant", content: String(localized: "Resumed last Responses session \(Self.shortResponseID(sessionID)). Send a new prompt to continue."))]
        streamedText = ""
        activeAssistantEntryID = nil
        isSending = false
        isStreaming = false
        latestResponseID = ""
        previousResponseID = sessionID
        activeHermesSessionID = ""
        lastErrorMessage = ""
        latestMessageType = "resumed response"
        eventCount = 0
        rawStreamedJSON = ""
        sessionTitle = Self.userFriendlySessionTitle(from: lastKnownResponseTitle, fallback: String(localized: "Last response"))
        connectionStatus = "Resumed last response"
    }

    func resumeConversation(from result: HermesDashboardConversationResult) {
        requestTask?.cancel()
        requestTask = nil
        streamedText = ""
        activeAssistantEntryID = nil
        isSending = false
        isStreaming = false
        latestResponseID = ""
        activeProfile = ""
        activeHermesSessionID = Self.hermesSessionID(from: result)
        let continuationID = Self.responseContinuationID(from: result)
        previousResponseID = continuationID
        persistLastResponseID(continuationID)
        lastErrorMessage = ""
        lastErrorWasTimeoutOrNetworkLoss = false
        latestMessageType = continuationID.isEmpty ? (activeHermesSessionID.isEmpty ? "loaded history" : "resumed session") : "resumed response"
        eventCount = 0
        rawStreamedJSON = ""
        let displayTitle = result.sessionFriendlyName
        sessionTitle = Self.userFriendlySessionTitle(from: displayTitle, fallback: continuationID.isEmpty ? (activeHermesSessionID.isEmpty ? "Loaded history" : activeHermesSessionID) : continuationID)
        if !continuationID.isEmpty { persistLastResponseTitle(sessionTitle) }
        let restoredEntries = result.messages
            .filter { message in
                let role = message.role.lowercased()
                return (role == "user" || role == "assistant") && !message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            .map { HermesResponseMessage(role: $0.role.lowercased(), content: $0.content) }
        entries = restoredEntries.isEmpty
            ? [HermesResponseMessage(role: "assistant", content: String(localized: "Loaded session \(displayTitle). Send a new prompt to start a new Responses API turn."))]
            : restoredEntries
        connectionStatus = continuationID.isEmpty ? (activeHermesSessionID.isEmpty ? "Loaded history" : "Resumed session") : "Resumed response"
    }

    private static func hermesSessionID(from result: HermesDashboardConversationResult) -> String {
        [result.sessionID, result.session.id]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? ""
    }

    private static func responseContinuationID(from result: HermesDashboardConversationResult) -> String {
        [result.sessionID, result.session.id]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { $0.hasPrefix("resp_") } ?? ""
    }

    private func runRequest(apiSettings: HermesAPISettings, draft: HermesRequestDraft, attachment: HermesPromptAttachment?) async {
        let continuationID = previousResponseID
        let hermesSessionID = activeHermesSessionID
        let prompt = draft.userPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if sessionTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { sessionTitle = Self.userFriendlySessionTitle(from: prompt, fallback: attachment?.filename ?? String(localized: "New response")) }
        persistLastResponseTitle(sessionTitle)
        resetForRequest()
        appendExchange(prompt: displayPrompt(prompt, attachment: attachment))
        isSending = true
        isStreaming = draft.stream
        connectionStatus = continuationID.isEmpty ? (draft.stream ? "Connecting to SSE stream" : "Sending request") : (draft.stream ? "Continuing SSE stream" : "Continuing request")
        do {
            if draft.stream {
                try await streamResponse(apiSettings: apiSettings, draft: draft, attachment: attachment, previousResponseID: continuationID, hermesSessionID: hermesSessionID)
            } else {
                try await fetchResponse(apiSettings: apiSettings, draft: draft, attachment: attachment, previousResponseID: continuationID, hermesSessionID: hermesSessionID)
            }
            if !latestResponseID.isEmpty { previousResponseID = latestResponseID; persistLastResponseID(latestResponseID) }
            activeHistoryStore?.recordResponse(streamedText, source: .askHermes)
            if !Task.isCancelled { connectionStatus = "Completed" }
        } catch is CancellationError {
            connectionStatus = "Cancelled"
            updateActiveAssistantEntry(with: streamedText.isEmpty ? String(localized: "Cancelled.") : streamedText)
        } catch {
            lastErrorMessage = error.localizedDescription
            lastErrorWasTimeoutOrNetworkLoss = HermesRequestFailureClassifier.isTimeoutOrNetworkLoss(error)
            connectionStatus = "Failed"
            updateActiveAssistantEntry(with: streamedText.isEmpty ? String(localized: "Request failed: \(error.localizedDescription)") : streamedText)
        }
        isSending = false
        isStreaming = false
    }

    private func resetForRequest() {
        streamedText = ""; latestResponseID = ""; lastErrorMessage = ""; lastErrorWasTimeoutOrNetworkLoss = false; latestMessageType = ""; eventCount = 0; rawStreamedJSON = ""; activeAssistantEntryID = nil
    }

    private func appendExchange(prompt: String) {
        guard !prompt.isEmpty else { return }
        entries.append(HermesResponseMessage(role: "user", content: prompt))
        let assistant = HermesResponseMessage(role: "assistant", content: "")
        activeAssistantEntryID = assistant.id
        entries.append(assistant)
    }

    private func displayPrompt(_ prompt: String, attachment: HermesPromptAttachment?) -> String {
        guard let attachment else { return prompt }
        let label = String(localized: "Attached: \(attachment.filename) (\(attachment.mimeType), \(attachment.formattedByteCount))")
        return prompt.isEmpty ? label : "\(prompt)\n\n\(label)"
    }

    private func updateActiveAssistantEntry(with content: String) {
        guard let activeAssistantEntryID, let index = entries.firstIndex(where: { $0.id == activeAssistantEntryID }) else { return }
        entries[index].content = HermesStreamTextFormatter.lineBreakAfterStatementDots(content)
    }

    private func streamResponse(apiSettings: HermesAPISettings, draft: HermesRequestDraft, attachment: HermesPromptAttachment?, previousResponseID: String, hermesSessionID: String) async throws {
        let request = try buildRequest(apiSettings: apiSettings, draft: draft, attachment: attachment, stream: true, previousResponseID: previousResponseID, hermesSessionID: hermesSessionID)
        let (bytes, response) = try await HermesNetworkSessionFactory.session(for: apiSettings).bytes(for: request)
        try HermesNetworkSessionFactory.validate(response: response)
        persistHermesSessionID(from: response)
        var parser = HermesSSEParser()
        for try await line in bytes.lines {
            try Task.checkCancellation()
            if let event = parser.consume(line: line) { handle(event: event) }
        }
        if let event = parser.finish() { handle(event: event) }
    }

    private func fetchResponse(apiSettings: HermesAPISettings, draft: HermesRequestDraft, attachment: HermesPromptAttachment?, previousResponseID: String, hermesSessionID: String) async throws {
        let request = try buildRequest(apiSettings: apiSettings, draft: draft, attachment: attachment, stream: false, previousResponseID: previousResponseID, hermesSessionID: hermesSessionID)
        let (data, response) = try await HermesNetworkSessionFactory.session(for: apiSettings).data(for: request)
        try HermesNetworkSessionFactory.validate(response: response)
        persistHermesSessionID(from: response)
        let envelope = try JSONDecoder().decode(HermesResponseEnvelope.self, from: data)
        rawStreamedJSON = Self.prettyPrintedJSON(from: data)
        latestResponseID = envelope.id ?? ""
        persistLastResponseID(latestResponseID)
        streamedText = envelope.assistantText
        updateActiveAssistantEntry(with: streamedText)
        latestMessageType = envelope.outputMessageType
        eventCount = 1
    }

    private func buildRequest(apiSettings: HermesAPISettings, draft: HermesRequestDraft, attachment: HermesPromptAttachment?, stream: Bool, previousResponseID: String, hermesSessionID: String) throws -> URLRequest {
        guard let url = HermesAPISettings.responseURL(from: apiSettings.baseURL) else { throw HermesResponsesError.invalidURL }
        let payload = HermesResponsesRequestBody(model: "hermes-agent", input: HermesResponsesInput(prompt: draft.userPrompt, attachment: attachment), stream: stream, store: true, previousResponseID: previousResponseID.isEmpty ? nil : previousResponseID)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(stream ? "text/event-stream" : "application/json", forHTTPHeaderField: "Accept")
        if stream { request.timeoutInterval = 0 }
        let profile = draft.profile.trimmingCharacters(in: .whitespacesAndNewlines)
        request.setValue(profile.isEmpty ? "default" : profile, forHTTPHeaderField: "X-Hermes-Profile")
        if !hermesSessionID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            request.setValue(hermesSessionID, forHTTPHeaderField: "X-Hermes-Session-Id")
            request.setValue(hermesSessionID, forHTTPHeaderField: "x-openclaw-session-key")
        }
        if !apiSettings.apiKey.isEmpty { request.setValue("Bearer \(apiSettings.apiKey)", forHTTPHeaderField: "Authorization") }
        request.httpBody = try JSONEncoder().encode(payload)
        return request
    }

    private func handle(event: HermesSSEEvent) {
        appendRawStreamedJSON(event)
        if event.data == "[DONE]" { connectionStatus = "Completed"; return }
        eventCount += 1
        let summary = HermesEventSummaryBuilder.summary(for: event)
        latestMessageType = summary.messageType
        if let responseID = summary.responseID, !responseID.isEmpty { latestResponseID = responseID; persistLastResponseID(responseID) }
        if let delta = summary.outputDelta, !delta.isEmpty {
            if streamedText.isEmpty { streamedText = delta }
            else if summary.title == "response.completed" && streamedText.count >= delta.count { }
            else if delta.hasPrefix(streamedText) { streamedText = delta }
            else if !streamedText.hasSuffix(delta) { streamedText += delta }
            updateActiveAssistantEntry(with: streamedText)
            connectionStatus = "Streaming output"
        } else if summary.title.hasPrefix("response.output_item.") { connectionStatus = summary.status }
        else { connectionStatus = String(localized: "Processing \(summary.title)") }
    }

    private func persistHermesSessionID(from response: URLResponse) {
        guard let http = response as? HTTPURLResponse else { return }
        [http.value(forHTTPHeaderField: "X-Hermes-Session-Id"), http.value(forHTTPHeaderField: "x-openclaw-session-key")]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
            .map { activeHermesSessionID = $0 }
    }

    private func appendRawStreamedJSON(_ event: HermesSSEEvent) {
        let eventName = event.event ?? "message"
        let payload = event.data == "[DONE]" ? "[DONE]" : Self.prettyPrintedJSON(from: event.data)
        rawStreamedJSON = rawStreamedJSON.isEmpty ? "event: \(eventName)\n\(payload)" : rawStreamedJSON + "\n\nevent: \(eventName)\n\(payload)"
    }

    private func persistLastResponseID(_ value: String) { let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines); if !trimmed.isEmpty { lastKnownResponseID = trimmed; HermesSettingsStore.saveLastResponsesSessionID(trimmed) } }
    private func persistLastResponseTitle(_ value: String) { let normalized = Self.userFriendlySessionTitle(from: value, fallback: ""); if !normalized.isEmpty { lastKnownResponseTitle = normalized; HermesSettingsStore.saveLastResponsesSessionTitle(normalized) } }
    private static func shortResponseID(_ responseID: String) -> String { responseID.count > 18 ? String(responseID.prefix(18)) + "…" : responseID }
    private static func userFriendlySessionTitle(from title: String, fallback: String) -> String { let normalized = title.split(whereSeparator: { $0.isWhitespace }).joined(separator: " "); return normalized.isEmpty ? (fallback.isEmpty ? String(localized: "New response") : fallback) : normalized }
    private static func prettyPrintedJSON(from string: String) -> String { string.data(using: .utf8).map(prettyPrintedJSON(from:)) ?? string }
    private static func prettyPrintedJSON(from data: Data) -> String { guard let object = try? JSONSerialization.jsonObject(with: data), let prettyData = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]), let pretty = String(data: prettyData, encoding: .utf8) else { return String(data: data, encoding: .utf8) ?? "" }; return pretty }
}

struct HermesResponseMessage: Identifiable, Equatable {
    let id = UUID()
    let role: String
    var content: String
}

private enum HermesResponsesInput: Encodable {
    case text(String)
    case message([HermesResponsesInputMessage])

    init(prompt: String, attachment: HermesPromptAttachment?) {
        guard let attachment else { self = .text(prompt); return }
        if attachment.isImage {
            self = .message([HermesResponsesInputMessage(role: "user", content: [.inputText(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? String(localized: "Please inspect the attached image.") : prompt), .inputImage(attachment.base64DataURL)])])
        } else {
            let base = prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? String(localized: "Please inspect the attached file.") : prompt
            self = .text(base + attachment.textAttachmentBlock)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self { case .text(let text): try container.encode(text); case .message(let messages): try container.encode(messages) }
    }
}

private struct HermesResponsesInputMessage: Encodable { let role: String; let content: [HermesResponsesInputContentPart] }
private enum HermesResponsesInputContentPart: Encodable {
    case inputText(String), inputImage(String)
    enum CodingKeys: String, CodingKey { case type, text; case imageURL = "image_url" }
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self { case .inputText(let text): try container.encode("input_text", forKey: .type); try container.encode(text, forKey: .text); case .inputImage(let url): try container.encode("input_image", forKey: .type); try container.encode(url, forKey: .imageURL) }
    }
}
private struct HermesResponsesRequestBody: Encodable { let model: String; let input: HermesResponsesInput; let stream: Bool; let store: Bool; let previousResponseID: String?; enum CodingKeys: String, CodingKey { case model, input, stream, store; case previousResponseID = "previous_response_id" } }

private struct HermesResponseEnvelope: Decodable {
    let id: String?
    let output: [HermesResponseOutputItem]?
    var assistantText: String { (output ?? []).compactMap(\.assistantText).joined(separator: "\n\n") }
    var outputMessageType: String { output?.first(where: { $0.assistantText?.isEmpty == false })?.type ?? "message" }
}
private struct HermesResponseOutputItem: Decodable { let type: String; let content: [HermesResponseContent]?; let output: [HermesResponseContent]?; var assistantText: String? { guard type == "message" else { return nil }; let text = (content ?? output ?? []).compactMap(\.displayValue).joined(); return text.isEmpty ? nil : text } }
private struct HermesResponseContent: Decodable {
    let type: String; let text: String?; let imageURL: HermesImageURLPayload?; let url: String?; let b64JSON: String?; let imageBase64: String?; let mimeType: String?; let originalMimeType: String?
    enum CodingKeys: String, CodingKey { case type, text, url; case imageURL = "image_url"; case b64JSON = "b64_json"; case imageBase64 = "image_base64"; case mimeType = "mime_type"; case originalMimeType = "original_mime_type" }
    var displayValue: String? { if type == "output_text" || type == "text" || type == "message" { return text.flatMap { HermesImageJSONFormatter.renderableImageMarkdown(from: $0) ?? $0 } }; return imageMarkdown }
    var imageMarkdown: String? { let base64 = b64JSON ?? imageBase64; let mime = (mimeType ?? originalMimeType)?.trimmingCharacters(in: .whitespacesAndNewlines); let source = imageURL?.url ?? url ?? base64.map { "data:\((mime?.isEmpty == false) ? mime! : "image/png");base64,\($0)" }; return source.map { "\n\n![Hermes image](\($0))" } }
}
private struct HermesImageURLPayload: Decodable { let url: String? }

private struct HermesSSEEvent { let event: String?; let data: String }
private struct HermesSSEParser {
    private var eventName: String?; private var dataLines: [String] = []
    mutating func consume(line: String) -> HermesSSEEvent? {
        if line.isEmpty { return flush() }
        if line.hasPrefix("event:") { if !dataLines.isEmpty || eventName != nil { let pending = flush(); eventName = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces); return pending }; eventName = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces) }
        else if line.hasPrefix("data:") { dataLines.append(String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)) }
        return nil
    }
    mutating func finish() -> HermesSSEEvent? { flush() }
    private mutating func flush() -> HermesSSEEvent? { guard !dataLines.isEmpty || eventName != nil else { return nil }; let event = HermesSSEEvent(event: eventName, data: dataLines.joined(separator: "\n")); eventName = nil; dataLines.removeAll(keepingCapacity: true); return event }
}

private struct HermesEventSummary { let title: String; let messageType: String; let status: String; let responseID: String?; let outputDelta: String? }
private enum HermesEventSummaryBuilder {
    static func summary(for event: HermesSSEEvent) -> HermesEventSummary {
        let title = event.event ?? "message"; let payload = HermesLooseJSON(json: event.data)
        switch title {
        case "response.created": return HermesEventSummary(title: title, messageType: "response", status: (payload.string(at: ["response", "status"]) ?? "Created").capitalized, responseID: payload.string(at: ["response", "id"]) ?? payload.string(at: ["id"]), outputDelta: nil)
        case "response.output_text.delta": return HermesEventSummary(title: title, messageType: "message", status: "Streaming", responseID: payload.string(at: ["response_id"]), outputDelta: payload.string(at: ["delta"]) ?? "")
        case "response.output_text.done": return HermesEventSummary(title: title, messageType: "message", status: "Completed", responseID: payload.string(at: ["response_id"]), outputDelta: payload.string(at: ["text"]) ?? "")
        case let name where name.hasPrefix("response.output_item."):
            let itemType = payload.string(at: ["item", "type"]) ?? payload.string(at: ["type"]) ?? "item"
            let itemStatus = payload.string(at: ["item", "status"]) ?? String(name.dropFirst("response.output_item.".count))
            return HermesEventSummary(title: title, messageType: itemType, status: "\(itemType): \(itemStatus)", responseID: payload.string(at: ["response_id"]), outputDelta: nil)
        case "response.completed": return HermesEventSummary(title: title, messageType: "response", status: "Completed", responseID: payload.string(at: ["response", "id"]) ?? payload.string(at: ["id"]), outputDelta: payload.messageOutputTexts(at: ["response", "output"]).joined(separator: "\n\n"))
        default: return HermesEventSummary(title: title, messageType: title, status: "Event", responseID: payload.string(at: ["response_id"]), outputDelta: nil)
        }
    }
}

struct HermesLooseJSON {
    private let object: Any?
    init(json: String) { object = json.data(using: .utf8).flatMap { try? JSONSerialization.jsonObject(with: $0) } }
    func string(at path: [String]) -> String? { guard let value = value(at: path) else { return nil }; if let string = value as? String { return string }; if let number = value as? NSNumber { return number.stringValue }; return nil }
    func messageOutputTexts(at path: [String]) -> [String] { value(at: path).map(extractMessageOutputTexts(from:)) ?? [] }
    private func value(at path: [String]) -> Any? { var current = object; for key in path { if let index = Int(key), let array = current as? [Any], array.indices.contains(index) { current = array[index] } else if let dict = current as? [String: Any] { current = dict[key] } else { return nil } }; return current }
    private func extractMessageOutputTexts(from value: Any) -> [String] { if let array = value as? [Any] { return array.flatMap(extractMessageOutputTexts) }; guard let dict = value as? [String: Any] else { return [] }; if let type = dict["type"] as? String, type != "message" { return [] }; return extractTexts(from: dict["content"] ?? dict["output"] ?? dict) }
    private func extractTexts(from value: Any) -> [String] { if let string = value as? String { return [string] }; if let array = value as? [Any] { return array.flatMap(extractTexts) }; if let dict = value as? [String: Any] { if let text = dict["text"] as? String { return [text] }; if let outputText = dict["output_text"] as? String { return [outputText] }; return dict.values.flatMap(extractTexts) }; return [] }
}

enum HermesImageJSONFormatter {
    static func renderableImageMarkdown(from text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.contains("image_base64") || trimmed.contains("b64_json") else { return nil }
        let mime = firstJSONStringValue(for: "mime_type", in: trimmed) ?? firstJSONStringValue(for: "original_mime_type", in: trimmed) ?? "image/png"
        guard let base64 = firstJSONStringValue(for: "image_base64", in: trimmed) ?? firstJSONStringValue(for: "b64_json", in: trimmed), !base64.isEmpty else { return nil }
        return "\n\n![Hermes image](data:\(mime);base64,\(base64.filter { !$0.isWhitespace }))"
    }
    private static func firstJSONStringValue(for key: String, in text: String) -> String? { let pattern = #""# + NSRegularExpression.escapedPattern(for: key) + #""\s*:\s*"((?:\\.|[^"\\])*)""#; guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]), let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text)), let range = Range(match.range(at: 1), in: text) else { return nil }; let value = String(text[range]); let wrapped = "\"\(value)\""; return wrapped.data(using: .utf8).flatMap { try? JSONSerialization.jsonObject(with: $0) as? String } ?? value }
}

enum HermesStreamTextFormatter {
    static func lineBreakAfterStatementDots(_ text: String) -> String {
        if let imageMarkdown = HermesImageJSONFormatter.renderableImageMarkdown(from: text) { return imageMarkdown }
        guard text.contains("."), !text.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("{") else { return text }
        var output = ""
        for (idx, char) in text.enumerated() {
            output.append(char)
            if char == "." {
                let next = text.dropFirst(idx + 1).first
                if next != "." && next != "\n" && next != "\r" { output.append("\n") }
            }
        }
        return output
    }
}

enum HermesResponsesError: LocalizedError {
    case invalidURL, invalidResponse, httpError(Int)
    var errorDescription: String? { switch self { case .invalidURL: String(localized: "The Hermes gateway URL is invalid."); case .invalidResponse: String(localized: "The Hermes gateway returned an invalid response."); case .httpError(let code): String(localized: "The Hermes gateway returned HTTP \(code).") } }
}
