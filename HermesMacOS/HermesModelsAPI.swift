//
//  HermesModelsAPI.swift
//  HermesMacOS
//

import Foundation
import Observation
import Security
import UniformTypeIdentifiers

let defaultHermesMacHost = "localhost"
let defaultHermesAPIPort = "8642"

enum HermesHostEndpoints {
    static func httpURLString(host: String, port: String, path: String = "") -> String {
        let normalizedHost = normalizedHost(host)
        let normalizedPort = tcpPort(from: port, fallback: defaultHermesAPIPort)
        let normalizedPath = path.isEmpty ? "" : (path.hasPrefix("/") ? path : "/\(path)")
        return "http://\(normalizedHost):\(normalizedPort)\(normalizedPath)"
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

    static func displayHost(from value: String) -> String {
        let normalizedHost = normalizedHost(value).trimmingCharacters(in: .whitespacesAndNewlines)
        return normalizedHost.isEmpty ? defaultHermesMacHost : normalizedHost
    }

    static func tcpPort(from value: String, fallback: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return fallback }
        if let components = URLComponents(string: trimmed), let port = components.port { return String(port) }
        let digits = trimmed.filter(\.isNumber)
        return digits.isEmpty ? fallback : String(digits.prefix(5))
    }
}

struct HermesAPISettings: Codable, Equatable, Sendable {
    var baseURL = HermesHostEndpoints.httpURLString(host: defaultHermesMacHost, port: defaultHermesAPIPort, path: "/v1")
    var apiKey = ""
    var allowSelfSignedCertificates = false

    enum CodingKeys: String, CodingKey { case baseURL, apiKey, allowSelfSignedCertificates }

    init(baseURL: String = HermesHostEndpoints.httpURLString(host: defaultHermesMacHost, port: defaultHermesAPIPort, path: "/v1"), apiKey: String = HermesAPIKeychain.loadAPIKey(), allowSelfSignedCertificates: Bool = false) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.allowSelfSignedCertificates = allowSelfSignedCertificates
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        baseURL = (try? container.decode(String.self, forKey: .baseURL)) ?? HermesHostEndpoints.httpURLString(host: defaultHermesMacHost, port: defaultHermesAPIPort, path: "/v1")
        allowSelfSignedCertificates = (try? container.decode(Bool.self, forKey: .allowSelfSignedCertificates)) ?? false
        let migratedAPIKey = (try? container.decode(String.self, forKey: .apiKey))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !migratedAPIKey.isEmpty {
            apiKey = migratedAPIKey
            HermesAPIKeychain.saveAPIKey(migratedAPIKey)
        } else {
            apiKey = HermesAPIKeychain.loadAPIKey()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(baseURL, forKey: .baseURL)
        try container.encode(allowSelfSignedCertificates, forKey: .allowSelfSignedCertificates)
    }

    var hostName: String { HermesHostEndpoints.displayHost(from: baseURL) }

    static func responseURL(from baseURL: String) -> URL? { endpointURL(from: baseURL, suffix: "responses") }
    static func chatCompletionsURL(from baseURL: String) -> URL? { endpointURL(from: baseURL, suffix: "chat/completions") }
    static func requestCancelURL(from baseURL: String, requestID: String) -> URL? { endpointURL(from: baseURL, suffix: "requests/\(requestID)/cancel") }
    static func profilesURL(from baseURL: String) -> URL? { endpointURL(from: baseURL, suffix: "profiles") }
    static func approvalsURL(from baseURL: String) -> URL? { endpointURL(from: baseURL, suffix: "approvals") }
    static func approvalResolveURL(from baseURL: String) -> URL? { endpointURL(from: baseURL, suffix: "approvals/resolve") }

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
        if ["v1/responses", "v1/chat/completions", "v1/profiles", "v1/approvals", "v1/approvals/resolve"].contains(normalizedPath) {
            components.path = "/v1/\(suffix)"
            return components.url
        }
        return URL(string: trimmed.hasSuffix("/") ? trimmed + suffix : trimmed + "/" + suffix)
    }
}

struct HermesSavedEndpoint: Codable, Equatable, Identifiable, Sendable {
    let id: String
    var apiURL: String
    var dashboardURL: String
    var savedAt: Date
    var sshUsername: String
    var sshKeyDisplayName: String

    init(id: String = UUID().uuidString, apiURL: String, dashboardURL: String, savedAt: Date = Date(), sshUsername: String = "", sshKeyDisplayName: String = "") {
        self.id = id
        self.apiURL = apiURL
        self.dashboardURL = dashboardURL
        self.savedAt = savedAt
        self.sshUsername = sshUsername
        self.sshKeyDisplayName = sshKeyDisplayName
    }

    enum CodingKeys: String, CodingKey { case id, apiURL, dashboardURL, savedAt, sshUsername, sshKeyDisplayName }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(String.self, forKey: .id)) ?? UUID().uuidString
        apiURL = (try? container.decode(String.self, forKey: .apiURL)) ?? ""
        dashboardURL = (try? container.decode(String.self, forKey: .dashboardURL)) ?? ""
        savedAt = (try? container.decode(Date.self, forKey: .savedAt)) ?? Date()
        sshUsername = (try? container.decode(String.self, forKey: .sshUsername)) ?? ""
        sshKeyDisplayName = (try? container.decode(String.self, forKey: .sshKeyDisplayName)) ?? ""
    }

    var title: String {
        let host = Self.hostLabel(apiURL) ?? Self.hostLabel(dashboardURL) ?? "Saved endpoint"
        return host
    }

    var subtitle: String {
        let api = apiURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let dashboard = dashboardURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if api.isEmpty { return dashboard }
        if dashboard.isEmpty { return api }
        return "API: \(api) • Dashboard: \(dashboard)"
    }

    func matches(apiURL candidateAPIURL: String, dashboardURL candidateDashboardURL: String) -> Bool {
        Self.normalizedURLString(apiURL) == Self.normalizedURLString(candidateAPIURL)
        && Self.normalizedURLString(dashboardURL) == Self.normalizedURLString(candidateDashboardURL)
    }

    static func normalizedURLString(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private static func hostLabel(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let components = URLComponents(string: trimmed), let host = components.host, !host.isEmpty {
            if let port = components.port { return "\(host):\(port)" }
            return host
        }
        let normalizedHost = HermesHostEndpoints.normalizedHost(trimmed)
        return normalizedHost.isEmpty ? nil : normalizedHost
    }
}

struct HermesSSHHostCredentials: Codable, Equatable, Sendable {
    var host: String
    var username: String
    var keyDisplayName: String

    var normalizedHost: String { HermesHostEndpoints.normalizedHost(host).lowercased() }
    var isRemoteHost: Bool { !HermesSSHHostCredentials.isLocalHost(host) }
    var hasUsername: Bool { !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var hasPrivateKey: Bool { HermesSSHKeychain.hasPrivateKey(forHost: host) }

    static func isLocalHost(_ host: String) -> Bool {
        let value = HermesHostEndpoints.normalizedHost(host).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return value.isEmpty || value == "localhost" || value == "127.0.0.1" || value == "::1" || value == "[::1]"
    }
}

enum HermesSSHKeychain {
    private static let service = "HermesMacOS.SSHPrivateKeys"
    private static let privateKeyCache = HermesKeyedCachedSecret<String, Data>()
    private static let privateKeyPresenceCache = HermesKeyedCachedSecret<String, Bool>()

    static func hasPrivateKey(forHost host: String) -> Bool {
        let account = accountName(forHost: host)
        let cachedKey = privateKeyCache.value(for: account)
        if cachedKey.isCached { return cachedKey.value != nil }
        let cachedPresence = privateKeyPresenceCache.value(for: account)
        if cachedPresence.isCached { return cachedPresence.value ?? false }
        let hasKey = hasPrivateKey(account: account, dataProtection: true) || hasPrivateKey(account: account, dataProtection: false)
        privateKeyPresenceCache.store(hasKey, for: account)
        return hasKey
    }

    static func savePrivateKey(_ data: Data, displayName: String, forHost host: String) throws {
        let account = accountName(forHost: host)
        HermesKeychainDataProtection.deleteGenericPassword(service: service, account: account)
        var query = baseQuery(account: account)
        query[kSecValueData as String] = data
        query[kSecAttrLabel as String] = displayName
        query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
        privateKeyCache.store(data, for: account)
        privateKeyPresenceCache.store(true, for: account)
    }

    static func deletePrivateKey(forHost host: String) {
        let account = accountName(forHost: host)
        HermesKeychainDataProtection.deleteGenericPassword(service: service, account: account)
        privateKeyCache.store(nil, for: account)
        privateKeyPresenceCache.store(false, for: account)
    }

    static func privateKeyData(forHost host: String) -> Data? {
        let account = accountName(forHost: host)
        let cached = privateKeyCache.value(for: account)
        if cached.isCached { return cached.value }
        if let data = privateKeyData(account: account, dataProtection: true) {
            privateKeyCache.store(data, for: account)
            privateKeyPresenceCache.store(true, for: account)
            return data
        }
        if let legacy = privateKeyData(account: account, dataProtection: false) {
            migratePrivateKeyToDataProtection(legacy, account: account)
            privateKeyCache.store(legacy, for: account)
            privateKeyPresenceCache.store(true, for: account)
            return legacy
        }
        privateKeyCache.store(nil, for: account)
        privateKeyPresenceCache.store(false, for: account)
        return nil
    }

    private static func hasPrivateKey(account: String, dataProtection: Bool) -> Bool {
        var query = baseQuery(account: account, dataProtection: dataProtection)
        query[kSecReturnAttributes as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        return SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess
    }

    private static func privateKeyData(account: String, dataProtection: Bool) -> Data? {
        var query = baseQuery(account: account, dataProtection: dataProtection)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else { return nil }
        return item as? Data
    }

    private static func migratePrivateKeyToDataProtection(_ data: Data, account: String) {
        var query = baseQuery(account: account, dataProtection: true)
        query[kSecValueData as String] = data
        query[kSecAttrLabel as String] = "SSH private key"
        query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecSuccess || status == errSecDuplicateItem {
            SecItemDelete(baseQuery(account: account, dataProtection: false) as CFDictionary)
        }
    }

    static func temporaryIdentityFile(forHost host: String) throws -> URL {
        guard let data = privateKeyData(forHost: host) else {
            throw NSError(domain: "HermesMacOS.SSH", code: 1, userInfo: [NSLocalizedDescriptionKey: "No private SSH key is stored for \(host)."])
        }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("HermesMacOSSSH", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        chmod(folder.path, S_IRWXU)
        cleanupTemporaryIdentityFiles(in: folder)
        let url = folder.appendingPathComponent("key-\(UUID().uuidString)")
        let fd = open(url.path, O_WRONLY | O_CREAT | O_EXCL, S_IRUSR | S_IWUSR)
        guard fd >= 0 else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: [NSLocalizedDescriptionKey: "Could not create temporary SSH identity file."])
        }
        let written = data.withUnsafeBytes { buffer in
            write(fd, buffer.baseAddress, buffer.count)
        }
        close(fd)
        guard written == data.count else {
            try? FileManager.default.removeItem(at: url)
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: [NSLocalizedDescriptionKey: "Could not write temporary SSH identity file."])
        }
        return url
    }

    static func cleanupTemporaryIdentityFiles() {
        cleanupTemporaryIdentityFiles(in: FileManager.default.temporaryDirectory.appendingPathComponent("HermesMacOSSSH", isDirectory: true))
    }

    private static func cleanupTemporaryIdentityFiles(in folder: URL) {
        guard let contents = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey]) else { return }
        let staleCutoff = Date().addingTimeInterval(-3600)
        for url in contents where url.lastPathComponent.hasPrefix("key-") {
            let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            if modified < staleCutoff { try? FileManager.default.removeItem(at: url) }
        }
    }

    private static func accountName(forHost host: String) -> String {
        HermesHostEndpoints.normalizedHost(host).lowercased()
    }

    private static func baseQuery(account: String, dataProtection: Bool = true) -> [String: Any] {
        HermesKeychainDataProtection.genericPasswordQuery(service: service, account: account, dataProtection: dataProtection)
    }
}

enum HermesShellQuoting {
    static func quote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    static func command(_ executable: String, arguments: [String], environment: [String: String] = [:], workingDirectory: String? = nil) -> String {
        var parts: [String] = []
        if let workingDirectory, !workingDirectory.isEmpty {
            parts.append("cd \(quote(workingDirectory))")
        }
        let envParts = environment.map { key, value in "\(key)=\(quote(value))" }.sorted()
        parts.append((envParts + [quote(executable)] + arguments.map(quote)).joined(separator: " "))
        return parts.joined(separator: " && ")
    }
}

extension Notification.Name {
    static let hermesConnectionEndpointDidChange = Notification.Name("hermesConnectionEndpointDidChange")
    static let hermesWindowConnectionDidChange = Notification.Name("hermesWindowConnectionDidChange")
}

struct HermesWindowConnection: Identifiable, Equatable {
    let id: UUID
    var title: String
    var apiSettings: HermesAPISettings
    var dashboardURL: String
}

@MainActor
@Observable
final class HermesWindowConnectionCenter {
    static let shared = HermesWindowConnectionCenter()

    private(set) var windowConnections: [HermesWindowConnection] = []
    private var nextWindowNumber = 1

    private init() {}

    func registerWindow(id: UUID, apiSettings: HermesAPISettings, dashboardURL: String) -> HermesWindowConnection {
        if let existing = windowConnections.first(where: { $0.id == id }) { return existing }
        let connection = HermesWindowConnection(
            id: id,
            title: "Window \(nextWindowNumber)",
            apiSettings: apiSettings,
            dashboardURL: dashboardURL
        )
        nextWindowNumber += 1
        windowConnections.append(connection)
        return connection
    }

    func unregisterWindow(id: UUID) {
        windowConnections.removeAll { $0.id == id }
    }

    func connection(id: UUID) -> HermesWindowConnection? {
        windowConnections.first { $0.id == id }
    }

    func updateWindow(id: UUID, apiSettings: HermesAPISettings, dashboardURL: String, notify: Bool = false) {
        guard let index = windowConnections.firstIndex(where: { $0.id == id }) else { return }
        windowConnections[index].apiSettings = apiSettings
        windowConnections[index].dashboardURL = dashboardURL
        if notify { announceWindowConnectionChange(id: id) }
    }

    func applyEndpoint(to id: UUID, apiSettings: HermesAPISettings, dashboardURL: String) {
        updateWindow(id: id, apiSettings: apiSettings, dashboardURL: dashboardURL, notify: true)
    }

    private func announceWindowConnectionChange(id: UUID) {
        NotificationCenter.default.post(name: .hermesWindowConnectionDidChange, object: id)
        NotificationCenter.default.post(name: .hermesConnectionEndpointDidChange, object: id)
    }
}

enum HermesRequestCancellation {
    static func makeRequestID() -> String {
        "hermes-macos-\(UUID().uuidString.lowercased())"
    }

    static func sendCancel(apiSettings: HermesAPISettings, requestID: String) async {
        let trimmedID = requestID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedID.isEmpty,
              let url = HermesAPISettings.requestCancelURL(from: apiSettings.baseURL, requestID: trimmedID)
        else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if !apiSettings.apiKey.isEmpty {
            guard (try? HermesEndpointSecurity.validateSensitiveURL(url)) != nil else { return }
            request.setValue("Bearer \(apiSettings.apiKey)", forHTTPHeaderField: "Authorization")
        }
        _ = try? await HermesNetworkSessionFactory.session(for: apiSettings).data(for: request)
    }
}

enum HermesReasoningLevel: String, Codable, CaseIterable, Identifiable, Sendable {
    case off
    case low
    case medium
    case high

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off: "Off"
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        }
    }

    var requestEffort: String? { self == .off ? nil : rawValue }
}

struct HermesRequestDraft: Codable, Equatable, Sendable {
    var profile = "default"
    var userPrompt = "Summarize the current project layout and recommend the next integration step."
    var stream = true
    var reasoningLevel: HermesReasoningLevel = .medium

    enum CodingKeys: String, CodingKey { case profile, userPrompt, stream, reasoningLevel }

    init(profile: String = "default", userPrompt: String = "Summarize the current project layout and recommend the next integration step.", stream: Bool = true, reasoningLevel: HermesReasoningLevel = .medium) {
        self.profile = profile
        self.userPrompt = userPrompt
        self.stream = stream
        self.reasoningLevel = reasoningLevel
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        profile = (try? container.decode(String.self, forKey: .profile)) ?? "default"
        userPrompt = (try? container.decode(String.self, forKey: .userPrompt)) ?? "Summarize the current project layout and recommend the next integration step."
        stream = (try? container.decode(Bool.self, forKey: .stream)) ?? true
        reasoningLevel = (try? container.decode(HermesReasoningLevel.self, forKey: .reasoningLevel)) ?? .medium
    }

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
    private static let chatDraftKey = "hermes.macOS.chatDraft"
    private static let lastChatSessionIDKey = "hermes.macOS.lastChatSessionID"
    private static let lastChatSessionTitleKey = "hermes.macOS.lastChatSessionTitle"
    private static let savedEndpointsKey = "hermes.macOS.savedConnectionEndpoints"
    private static let selectedEndpointIDKey = "hermes.macOS.selectedConnectionEndpointID"
    private static let sshCredentialsKey = "hermes.macOS.sshHostCredentials"
    private static let installationRepositoryPathKey = "hermes.macOS.installation.repositoryPath"
    private static let defaultInstallationRepositoryPath = NSString(string: "~/.hermes/hermes-agent").expandingTildeInPath

    static func loadAPISettings() -> HermesAPISettings { load(HermesAPISettings.self, forKey: apiSettingsKey) ?? HermesAPISettings() }
    static func saveAPISettings(_ value: HermesAPISettings) {
        HermesAPIKeychain.saveAPIKey(value.apiKey)
        save(value, forKey: apiSettingsKey)
    }
    static func loadDraft() -> HermesRequestDraft {
        let draft = load(HermesRequestDraft.self, forKey: requestDraftKey) ?? HermesRequestDraft()
        saveDraft(draft)
        return draft
    }
    static func saveDraft(_ value: HermesRequestDraft) {
        var redacted = value
        redacted.userPrompt = HermesSecretRedactor.redact(value.userPrompt)
        saveSecure(redacted, forKey: requestDraftKey)
    }
    static func loadChatDraft() -> HermesChatDraft {
        let draft = load(HermesChatDraft.self, forKey: chatDraftKey) ?? HermesChatDraft()
        saveChatDraft(draft)
        return draft
    }
    static func saveChatDraft(_ value: HermesChatDraft) {
        var redacted = value
        redacted.systemPrompt = HermesSecretRedactor.redact(value.systemPrompt)
        redacted.userPrompt = HermesSecretRedactor.redact(value.userPrompt)
        saveSecure(redacted, forKey: chatDraftKey)
    }
    static func loadLastResponsesSessionID() -> String { HermesEncryptedRetentionStore.loadString(forKey: lastResponseIDKey) }
    static func saveLastResponsesSessionID(_ value: String) { HermesEncryptedRetentionStore.saveString(value, forKey: lastResponseIDKey) }
    static func loadLastResponsesSessionTitle() -> String { HermesEncryptedRetentionStore.loadString(forKey: lastResponseTitleKey) }
    static func saveLastResponsesSessionTitle(_ value: String) { HermesEncryptedRetentionStore.saveString(value, forKey: lastResponseTitleKey) }
    static func loadLastChatSessionID() -> String { HermesEncryptedRetentionStore.loadString(forKey: lastChatSessionIDKey) }
    static func saveLastChatSessionID(_ value: String) { HermesEncryptedRetentionStore.saveString(value, forKey: lastChatSessionIDKey) }
    static func loadLastChatSessionTitle() -> String { HermesEncryptedRetentionStore.loadString(forKey: lastChatSessionTitleKey) }
    static func saveLastChatSessionTitle(_ value: String) { HermesEncryptedRetentionStore.saveString(value, forKey: lastChatSessionTitleKey) }
    static func loadSavedEndpoints() -> [HermesSavedEndpoint] { load([HermesSavedEndpoint].self, forKey: savedEndpointsKey) ?? [] }
    static func saveSavedEndpoints(_ value: [HermesSavedEndpoint]) { save(value, forKey: savedEndpointsKey) }
    static func loadSelectedEndpointID() -> String { UserDefaults.standard.string(forKey: selectedEndpointIDKey) ?? "" }
    static func saveSelectedEndpointID(_ value: String) { UserDefaults.standard.set(value, forKey: selectedEndpointIDKey) }
    static func loadSSHCredentials() -> [String: HermesSSHHostCredentials] { load([String: HermesSSHHostCredentials].self, forKey: sshCredentialsKey) ?? [:] }
    static func saveSSHCredentials(_ value: [String: HermesSSHHostCredentials]) { save(value, forKey: sshCredentialsKey) }
    static func loadInstallationRepositoryPath() -> String { UserDefaults.standard.string(forKey: installationRepositoryPathKey) ?? defaultInstallationRepositoryPath }
    static func saveInstallationRepositoryPath(_ value: String) { UserDefaults.standard.set(value, forKey: installationRepositoryPathKey) }
    static func loadSSHCredentials(forHost host: String) -> HermesSSHHostCredentials {
        let normalizedHost = HermesHostEndpoints.normalizedHost(host).lowercased()
        return loadSSHCredentials()[normalizedHost] ?? HermesSSHHostCredentials(host: normalizedHost, username: "", keyDisplayName: "")
    }
    static func saveSSHCredentials(_ credentials: HermesSSHHostCredentials) {
        let normalizedHost = credentials.normalizedHost
        guard !normalizedHost.isEmpty else { return }
        var values = loadSSHCredentials()
        values[normalizedHost] = HermesSSHHostCredentials(host: normalizedHost, username: credentials.username, keyDisplayName: credentials.keyDisplayName)
        saveSSHCredentials(values)
    }

    private static func load<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        if key == requestDraftKey || key == chatDraftKey {
            return HermesEncryptedRetentionStore.load(type, forKey: key)
        }
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private static func save<T: Encodable>(_ value: T, forKey key: String) {
        if let data = try? JSONEncoder().encode(value) { UserDefaults.standard.set(data, forKey: key) }
    }

    private static func saveSecure<T: Encodable>(_ value: T, forKey key: String) {
        if HermesEncryptedRetentionStore.save(value, forKey: key) {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}

struct HermesAPIProfile: Decodable, Identifiable, Equatable {
    let id: String
    let name: String
    let isDefault: Bool
    let model: String?
    let provider: String?
    let supportedParameters: [String]

    enum CodingKeys: String, CodingKey {
        case id, name, model, provider
        case isDefault = "is_default"
        case supportedParameters = "supported_parameters"
    }

    init(id: String, name: String, isDefault: Bool, model: String?, provider: String?, supportedParameters: [String] = []) {
        self.id = id
        self.name = name
        self.isDefault = isDefault
        self.model = model
        self.provider = provider
        self.supportedParameters = supportedParameters
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = (try? container.decode(String.self, forKey: .name)) ?? id
        isDefault = (try? container.decode(Bool.self, forKey: .isDefault)) ?? false
        model = try? container.decode(String.self, forKey: .model)
        provider = try? container.decode(String.self, forKey: .provider)
        supportedParameters = (try? container.decode([String].self, forKey: .supportedParameters)) ?? []
    }

    var supportsReasoningLevel: Bool {
        if supportedParameters.contains(where: { parameter in
            let value = parameter.lowercased()
            return value == "reasoning" || value == "reasoning_effort" || value == "include_reasoning"
        }) { return true }
        return HermesReasoningModelSupport.supportsReasoningLevel(model: model, provider: provider)
    }
}

enum HermesReasoningModelSupport {
    static func supportsReasoningLevel(model: String?, provider: String?) -> Bool {
        let rawModel = (model ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawModel.isEmpty else { return false }
        let value = rawModel.lowercased()
        if exactReasoningModels.contains(value) { return true }
        if reasoningPrefixes.contains(where: { value.hasPrefix($0) }) { return true }
        if reasoningSubstrings.contains(where: { value.contains($0) }) { return true }
        let providerValue = (provider ?? "").lowercased()
        if providerValue.contains("openai"), value.hasPrefix("o") { return true }
        return false
    }

    private static let exactReasoningModels: Set<String> = [
        "o1", "o1-mini", "o1-preview", "o3", "o3-mini", "o4-mini",
        "gpt-5", "gpt-5-mini", "gpt-5-nano", "gpt-5.1", "gpt-5.1-codex",
        "gpt-5.5", "gpt-5.5-pro"
    ]

    private static let reasoningPrefixes = [
        "openai/o", "openai/gpt-5", "gpt-5",
        "anthropic/claude-3.7", "anthropic/claude-sonnet-4", "anthropic/claude-opus-4", "anthropic/claude-haiku-4",
        "google/gemini-2.5", "google/gemini-3", "gemini-2.5", "gemini-3",
        "x-ai/grok-3", "x-ai/grok-4", "grok-3", "grok-4",
        "deepseek/deepseek-r1", "deepseek/deepseek-v3.1", "deepseek/deepseek-v4",
        "qwen/qwq", "qwen/qwen3", "qwen/qwen-plus", "qwen/qwen-max",
        "moonshotai/kimi", "z-ai/glm-4.5", "z-ai/glm-5",
        "minimax/minimax-m2", "mistralai/mistral-medium",
        "nvidia/nemotron", "arcee-ai/trinity", "perceptron/"
    ]

    private static let reasoningSubstrings = [
        "-thinking", ":thinking", "thinking",
        "reasoning", "deepseek-r1", "qwq", "qwen3", "gemini-2.5", "gemini-3",
        "claude-3.7", "claude-sonnet-4", "claude-opus-4", "grok-3", "grok-4"
    ]
}

private struct HermesAPIProfilesEnvelope: Decodable { let data: [HermesAPIProfile] }

enum HermesAPIProfilesClient {
    static func fetchProfiles(apiSettings: HermesAPISettings) async throws -> [HermesAPIProfile] {
        guard let url = HermesAPISettings.profilesURL(from: apiSettings.baseURL) else { throw HermesResponsesError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if !apiSettings.apiKey.isEmpty {
            try HermesEndpointSecurity.validateSensitiveURL(url)
            request.setValue("Bearer \(apiSettings.apiKey)", forHTTPHeaderField: "Authorization")
        }
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
    let originalByteCount: Int64

    static let supportedFileExtensions: Set<String> = ["png", "jpg", "jpeg", "gif", "webp", "pdf", "docx", "pptx", "xlsx", "txt", "text", "json", "yaml", "yml", "toml", "swift"]
    static let imageFileExtensions: Set<String> = ["png", "jpg", "jpeg", "gif", "webp"]
    static let utf8FileExtensions: Set<String> = ["txt", "text", "json", "yaml", "yml", "toml", "swift"]
    static let maxImageBytes: Int64 = 20 * 1024 * 1024
    static let maxTextBytes: Int64 = 1 * 1024 * 1024
    static let maxDocumentBytes: Int64 = 8 * 1024 * 1024
    static let maxInlineTextCharacters = 120_000

    static var supportedContentTypes: [UTType] {
        var types: [UTType] = [.pdf, .plainText, .text, .json, .sourceCode, .swiftSource]
        ["public.png", "public.jpeg", "com.compuserve.gif", "org.webmproject.webp", "public.yaml", "public.toml", "org.openxmlformats.wordprocessingml.document", "org.openxmlformats.presentationml.presentation", "org.openxmlformats.spreadsheetml.sheet"].forEach { if let type = UTType($0) { types.append(type) } }
        supportedFileExtensions.forEach { if let type = UTType(filenameExtension: $0) { types.append(type) } }
        return Array(Set(types))
    }

    static func load(from url: URL) throws -> HermesPromptAttachment {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
        if !HermesFilesystemAccessPolicy.isAllowed(url.path) {
            Task { @MainActor in
                _ = await HermesLocalApprovalCenter.shared.requestFilesystemAccess(path: url.path, operation: "Import attachment")
            }
            throw HermesSecurityError.localApprovalDenied(url.path)
        }
        let values = try url.resourceValues(forKeys: [.contentTypeKey, .nameKey, .fileSizeKey])
        let name = values.name ?? url.lastPathComponent
        let ext = URL(fileURLWithPath: name).pathExtension.lowercased()
        guard Self.supportedFileExtensions.contains(ext) else { throw HermesAttachmentError.unsupportedFileType(ext.isEmpty ? name : ".\(ext)") }
        let byteCount = Int64(values.fileSize ?? 0)
        let maxBytes = Self.maxStoredBytes(forExtension: ext)
        if byteCount > maxBytes { throw HermesAttachmentError.fileTooLarge(ByteCountFormatter.string(fromByteCount: byteCount, countStyle: .file), ByteCountFormatter.string(fromByteCount: maxBytes, countStyle: .file)) }
        let data = try Data(contentsOf: url)
        return try HermesPromptAttachment(filename: name, contentType: values.contentType, data: data, originalByteCount: byteCount > 0 ? byteCount : Int64(data.count))
    }

    init(filename: String, contentType: UTType?, data: Data, originalByteCount: Int64? = nil) throws {
        let normalized = filename.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "attachment" : filename
        let ext = URL(fileURLWithPath: normalized).pathExtension.lowercased()
        guard Self.supportedFileExtensions.contains(ext) else { throw HermesAttachmentError.unsupportedFileType(ext.isEmpty ? normalized : ".\(ext)") }
        let byteCount = originalByteCount ?? Int64(data.count)
        let maxBytes = Self.maxStoredBytes(forExtension: ext)
        if byteCount > maxBytes { throw HermesAttachmentError.fileTooLarge(ByteCountFormatter.string(fromByteCount: byteCount, countStyle: .file), ByteCountFormatter.string(fromByteCount: maxBytes, countStyle: .file)) }
        self.filename = normalized
        self.fileExtension = ext
        self.mimeType = Self.mimeType(forExtension: ext, contentType: contentType)
        self.data = data
        self.originalByteCount = byteCount
    }

    var isImage: Bool { Self.imageFileExtensions.contains(fileExtension) }
    var isUTF8Text: Bool { Self.utf8FileExtensions.contains(fileExtension) }
    var formattedByteCount: String { ByteCountFormatter.string(fromByteCount: originalByteCount, countStyle: .file) }
    var base64DataURL: String { "data:\(mimeType);base64,\(data.base64EncodedString())" }
    var textContent: String? { isUTF8Text ? String(data: data, encoding: .utf8) : nil }
    var textAttachmentBlock: String {
        if let textContent {
            let limited = String(textContent.prefix(Self.maxInlineTextCharacters))
            let suffix = textContent.count > Self.maxInlineTextCharacters ? "\n\n[Attachment text truncated in HermesMacOS before sending.]" : ""
            return "\n" + String(localized: "Attached file: \(filename) (\(mimeType), \(formattedByteCount))\n```\(fileExtension)\n\(limited)\(suffix)\n```")
        }
        return "\n" + String(localized: "Attached file: \(filename) (\(mimeType), \(formattedByteCount))\nBinary document bytes are not inlined into the prompt by HermesMacOS. Use a file-aware tool or upload workflow if the model needs to inspect this document.")
    }

    private static func maxStoredBytes(forExtension ext: String) -> Int64 {
        if imageFileExtensions.contains(ext) { return maxImageBytes }
        if utf8FileExtensions.contains(ext) { return maxTextBytes }
        return maxDocumentBytes
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
    case fileTooLarge(String, String)

    var errorDescription: String? {
        switch self {
        case .unsupportedFileType:
            return String(localized: "Unsupported attachment type: \(typeDescription). Choose an image, PDF, Office document, text, JSON, YAML, TOML, or Swift file.")
        case .fileTooLarge(let actual, let limit):
            return String(localized: "Attachment is too large (\(actual)). Choose a file up to \(limit).")
        }
    }

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
        let (disposition, credential) = HermesPinnedCertificateTrust.handle(
            trust: trust,
            host: challenge.protectionSpace.host,
            allowSelfSignedCertificates: allowSelfSignedCertificates
        )
        completionHandler(disposition, credential)
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
    var streamOutputBubbles: [HermesStreamOutputBubble] = []
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
    var activeResponseMessageID: UUID?
    var activeResponseElapsedSeconds: Int?
    var activeResponseTokenUsage: HermesTokenUsage?

    private var requestTask: Task<Void, Never>?
    private var activeAssistantEntryID: UUID?
    private var activeStreamOutputBubbleID: UUID?
    private var activeHistoryStore: HermesPromptHistoryStore?
    private var activeCancellationRequestID = ""
    private var activeCancellationAPISettings: HermesAPISettings?
    private var responseTimingStart: Date?
    private var responseTimingTask: Task<Void, Never>?

    var displaySessionTitle: String {
        let title = sessionTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty { return title }
        return previousResponseID.isEmpty && activeHermesSessionID.isEmpty ? String(localized: "New response") : String(localized: "Continuing response")
    }

    var localizedConnectionStatus: String {
        String(localized: String.LocalizationValue(connectionStatus))
    }

    var hasActiveConversation: Bool { !previousResponseID.isEmpty || !latestResponseID.isEmpty || !activeHermesSessionID.isEmpty || !entries.isEmpty || isSending }

    func streamOutputBubble(after userMessageID: UUID) -> HermesStreamOutputBubble? {
        streamOutputBubbles.first { $0.userMessageID == userMessageID }
    }

    func submit(apiSettings: HermesAPISettings, draft: HermesRequestDraft, attachment: HermesPromptAttachment? = nil, historyStore: HermesPromptHistoryStore? = nil, showsStreamOutputBubble: Bool = false) {
        cancelActiveRequest()
        requestTask?.cancel()
        activeHistoryStore = historyStore
        historyStore?.record(draft.userPrompt, source: .askHermes)
        let requestedProfile = draft.profile.trimmingCharacters(in: .whitespacesAndNewlines)
        if activeProfile.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { activeProfile = requestedProfile.isEmpty ? "default" : requestedProfile }
        let lockedDraft = draft.locked(toProfile: activeProfile)
        let cancellationRequestID = HermesRequestCancellation.makeRequestID()
        activeCancellationRequestID = cancellationRequestID
        activeCancellationAPISettings = apiSettings
        requestTask = Task { await runRequest(apiSettings: apiSettings, draft: lockedDraft, attachment: attachment, cancellationRequestID: cancellationRequestID, showsStreamOutputBubble: showsStreamOutputBubble) }
    }

    func cancel() {
        cancelActiveRequest()
        requestTask?.cancel()
        requestTask = nil
        isSending = false
        isStreaming = false
        stopResponseTiming()
        connectionStatus = "Cancelled"
    }

    func terminateAndStartNewSession() {
        cancelActiveRequest()
        requestTask?.cancel()
        entries = []
        streamOutputBubbles = []
        streamedText = ""
        activeAssistantEntryID = nil
        activeStreamOutputBubbleID = nil
        clearResponseTiming()
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
        cancelActiveRequest()
        requestTask?.cancel()
        entries = [HermesResponseMessage(role: "assistant", content: String(localized: "Resumed last Responses session \(Self.shortResponseID(sessionID)). Send a new prompt to continue."))]
        streamedText = ""
        activeAssistantEntryID = nil
        activeStreamOutputBubbleID = nil
        clearResponseTiming()
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
        cancelActiveRequest()
        requestTask?.cancel()
        requestTask = nil
        streamedText = ""
        activeAssistantEntryID = nil
        activeStreamOutputBubbleID = nil
        clearResponseTiming()
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

    private func cancelActiveRequest() {
        let requestID = activeCancellationRequestID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !requestID.isEmpty, let apiSettings = activeCancellationAPISettings else { return }
        activeCancellationRequestID = ""
        activeCancellationAPISettings = nil
        Task {
            await HermesRequestCancellation.sendCancel(apiSettings: apiSettings, requestID: requestID)
        }
    }

    private func clearActiveCancellationRequest(id: String) {
        guard activeCancellationRequestID == id else { return }
        activeCancellationRequestID = ""
        activeCancellationAPISettings = nil
    }

    private func runRequest(apiSettings: HermesAPISettings, draft: HermesRequestDraft, attachment: HermesPromptAttachment?, cancellationRequestID: String, showsStreamOutputBubble: Bool) async {
        defer { clearActiveCancellationRequest(id: cancellationRequestID) }
        let continuationID = previousResponseID
        let hermesSessionID = activeHermesSessionID
        let prompt = draft.userPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if sessionTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { sessionTitle = Self.userFriendlySessionTitle(from: prompt, fallback: attachment?.filename ?? String(localized: "New response")) }
        persistLastResponseTitle(sessionTitle)
        resetForRequest()
        appendExchange(prompt: displayPrompt(prompt, attachment: attachment), includeStreamOutputBubble: showsStreamOutputBubble && draft.stream)
        isSending = true
        isStreaming = draft.stream
        startResponseTiming()
        connectionStatus = continuationID.isEmpty ? (draft.stream ? "Connecting to SSE stream" : "Sending request") : (draft.stream ? "Continuing SSE stream" : "Continuing request")
        do {
            if draft.stream {
                try await streamResponse(apiSettings: apiSettings, draft: draft, attachment: attachment, previousResponseID: continuationID, hermesSessionID: hermesSessionID, cancellationRequestID: cancellationRequestID)
            } else {
                try await fetchResponse(apiSettings: apiSettings, draft: draft, attachment: attachment, previousResponseID: continuationID, hermesSessionID: hermesSessionID, cancellationRequestID: cancellationRequestID)
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
        stopResponseTiming()
        completeActiveStreamOutputBubble()
    }

    private func resetForRequest() {
        streamedText = ""; latestResponseID = ""; lastErrorMessage = ""; lastErrorWasTimeoutOrNetworkLoss = false; latestMessageType = ""; eventCount = 0; rawStreamedJSON = ""; activeAssistantEntryID = nil; activeStreamOutputBubbleID = nil; activeResponseMessageID = nil; activeResponseElapsedSeconds = nil; activeResponseTokenUsage = nil
    }

    private func appendExchange(prompt: String, includeStreamOutputBubble: Bool) {
        guard !prompt.isEmpty else { return }
        let user = HermesResponseMessage(role: "user", content: prompt)
        entries.append(user)
        if includeStreamOutputBubble {
            let bubble = HermesStreamOutputBubble(userMessageID: user.id)
            activeStreamOutputBubbleID = bubble.id
            streamOutputBubbles.append(bubble)
        }
        let assistant = HermesResponseMessage(role: "assistant", content: "")
        activeResponseTokenUsage = nil
        activeAssistantEntryID = assistant.id
        activeResponseMessageID = assistant.id
        entries.append(assistant)
    }

    private func clearResponseTiming() {
        activeResponseMessageID = nil
        activeResponseElapsedSeconds = nil
        activeResponseTokenUsage = nil
        responseTimingTask?.cancel()
        responseTimingTask = nil
        responseTimingStart = nil
    }

    private func startResponseTiming() {
        responseTimingTask?.cancel()
        let start = Date()
        responseTimingStart = start
        activeResponseElapsedSeconds = 0
        responseTimingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard let self, self.isSending, let responseTimingStart = self.responseTimingStart else { return }
                    self.activeResponseElapsedSeconds = max(0, Int(Date().timeIntervalSince(responseTimingStart)))
                }
            }
        }
    }

    private func stopResponseTiming() {
        if let responseTimingStart {
            activeResponseElapsedSeconds = max(0, Int(Date().timeIntervalSince(responseTimingStart)))
        }
        if let activeResponseMessageID,
           let index = entries.firstIndex(where: { $0.id == activeResponseMessageID }) {
            if let activeResponseElapsedSeconds { entries[index].responseElapsedSeconds = activeResponseElapsedSeconds }
            if let activeResponseTokenUsage { entries[index].tokenUsage = activeResponseTokenUsage }
        }
        responseTimingTask?.cancel()
        responseTimingTask = nil
        responseTimingStart = nil
    }

    private func displayPrompt(_ prompt: String, attachment: HermesPromptAttachment?) -> String {
        guard let attachment else { return prompt }
        let label = String(localized: "Attached: \(attachment.filename) (\(attachment.mimeType), \(attachment.formattedByteCount))")
        return prompt.isEmpty ? label : "\(prompt)\n\n\(label)"
    }

    private func updateActiveAssistantEntry(with content: String) {
        guard let activeAssistantEntryID, let index = entries.firstIndex(where: { $0.id == activeAssistantEntryID }) else { return }
        entries[index].content = content
    }

    private func appendActiveStreamOutputBubble(lines: [String]) {
        guard let activeStreamOutputBubbleID, !lines.isEmpty,
              let index = streamOutputBubbles.firstIndex(where: { $0.id == activeStreamOutputBubbleID }) else { return }
        let cleaned = lines.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !cleaned.isEmpty else { return }
        var bubble = streamOutputBubbles[index]
        let addition = cleaned.joined(separator: "\n")
        bubble.text = bubble.text.isEmpty ? addition : bubble.text + "\n" + addition
        streamOutputBubbles[index] = bubble
    }

    private func completeActiveStreamOutputBubble() {
        guard let activeStreamOutputBubbleID,
              let index = streamOutputBubbles.firstIndex(where: { $0.id == activeStreamOutputBubbleID }) else { return }
        streamOutputBubbles[index].isComplete = true
        self.activeStreamOutputBubbleID = nil
    }

    private func streamResponse(apiSettings: HermesAPISettings, draft: HermesRequestDraft, attachment: HermesPromptAttachment?, previousResponseID: String, hermesSessionID: String, cancellationRequestID: String) async throws {
        let request = try buildRequest(apiSettings: apiSettings, draft: draft, attachment: attachment, stream: true, previousResponseID: previousResponseID, hermesSessionID: hermesSessionID, cancellationRequestID: cancellationRequestID)
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

    private func fetchResponse(apiSettings: HermesAPISettings, draft: HermesRequestDraft, attachment: HermesPromptAttachment?, previousResponseID: String, hermesSessionID: String, cancellationRequestID: String) async throws {
        let request = try buildRequest(apiSettings: apiSettings, draft: draft, attachment: attachment, stream: false, previousResponseID: previousResponseID, hermesSessionID: hermesSessionID, cancellationRequestID: cancellationRequestID)
        let (data, response) = try await HermesNetworkSessionFactory.session(for: apiSettings).data(for: request)
        try HermesNetworkSessionFactory.validate(response: response)
        persistHermesSessionID(from: response)
        let envelope = try JSONDecoder().decode(HermesResponseEnvelope.self, from: data)
        rawStreamedJSON = Self.prettyPrintedJSON(from: data)
        latestResponseID = envelope.id ?? ""
        persistLastResponseID(latestResponseID)
        updateTokenUsage(envelope.usage)
        streamedText = envelope.assistantText
        updateActiveAssistantEntry(with: streamedText)
        latestMessageType = envelope.outputMessageType
        eventCount = 1
    }

    private func buildRequest(apiSettings: HermesAPISettings, draft: HermesRequestDraft, attachment: HermesPromptAttachment?, stream: Bool, previousResponseID: String, hermesSessionID: String, cancellationRequestID: String) throws -> URLRequest {
        guard let url = HermesAPISettings.responseURL(from: apiSettings.baseURL) else { throw HermesResponsesError.invalidURL }
        try HermesEndpointSecurity.validateSensitiveURL(url)
        let reasoning = HermesReasoningRequest(level: draft.reasoningLevel)
        let payload = HermesResponsesRequestBody(model: "hermes-agent", input: HermesResponsesInput(prompt: draft.userPrompt, attachment: attachment), stream: stream, store: true, previousResponseID: previousResponseID.isEmpty ? nil : previousResponseID, reasoning: reasoning)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(stream ? "text/event-stream" : "application/json", forHTTPHeaderField: "Accept")
        if stream { request.timeoutInterval = 0 }
        if !cancellationRequestID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { request.setValue(cancellationRequestID, forHTTPHeaderField: "X-Hermes-Request-Id") }
        let profile = draft.profile.trimmingCharacters(in: .whitespacesAndNewlines)
        request.setValue(profile.isEmpty ? "default" : profile, forHTTPHeaderField: "X-Hermes-Profile")
        if !hermesSessionID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            request.setValue(hermesSessionID, forHTTPHeaderField: "X-Hermes-Session-Id")
            request.setValue(hermesSessionID, forHTTPHeaderField: "x-openclaw-session-key")
        }
        if !apiSettings.apiKey.isEmpty {
            try HermesEndpointSecurity.validateSensitiveURL(url)
            request.setValue("Bearer \(apiSettings.apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder().encode(payload)
        return request
    }

    private func handle(event: HermesSSEEvent) {
        appendRawStreamedJSON(event)
        if event.data == "[DONE]" { connectionStatus = "Completed"; return }
        eventCount += 1
        let payload = HermesLooseJSON(json: event.data)
        updateTokenUsage(payload.tokenUsage())
        let summary = HermesEventSummaryBuilder.summary(for: event)
        appendActiveStreamOutputBubble(lines: payload.streamOutputTexts())
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

    private func updateTokenUsage(_ usage: HermesTokenUsage?) {
        guard let usage, !usage.isEmpty else { return }
        activeResponseTokenUsage = usage
        if let activeResponseMessageID, let index = entries.firstIndex(where: { $0.id == activeResponseMessageID }) {
            entries[index].tokenUsage = usage
        }
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
        let block = "event: \(eventName)\n\(payload)"
        rawStreamedJSON = HermesDebugLogBuffer.appending(rawStreamedJSON, block: block)
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
    var responseElapsedSeconds: Int? = nil
    var tokenUsage: HermesTokenUsage? = nil
}

struct HermesTokenUsage: Equatable, Decodable {
    var inputTokens: Int?
    var outputTokens: Int?

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalInputTokens = "total_input_tokens"
        case totalOutputTokens = "total_output_tokens"
    }

    init(inputTokens: Int? = nil, outputTokens: Int? = nil) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        inputTokens = try container.decodeIfPresent(Int.self, forKey: .inputTokens)
            ?? container.decodeIfPresent(Int.self, forKey: .promptTokens)
            ?? container.decodeIfPresent(Int.self, forKey: .totalInputTokens)
        outputTokens = try container.decodeIfPresent(Int.self, forKey: .outputTokens)
            ?? container.decodeIfPresent(Int.self, forKey: .completionTokens)
            ?? container.decodeIfPresent(Int.self, forKey: .totalOutputTokens)
    }

    var isEmpty: Bool { inputTokens == nil && outputTokens == nil }
    var displayText: String { "In \(Self.format(inputTokens)) · Out \(Self.format(outputTokens))" }
    var accessibilityText: String { "input tokens \(Self.format(inputTokens)), output tokens \(Self.format(outputTokens))" }

    private static func format(_ value: Int?) -> String {
        guard let value else { return "—" }
        return value.formatted(.number.notation(.compactName))
    }
}

struct HermesStreamOutputBubble: Identifiable, Equatable {
    let id = UUID()
    let userMessageID: UUID
    var text = ""
    var isComplete = false
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
private struct HermesReasoningRequest: Encodable {
    let effort: String

    init?(level: HermesReasoningLevel) {
        guard let effort = level.requestEffort else { return nil }
        self.effort = effort
    }
}
private struct HermesResponsesRequestBody: Encodable { let model: String; let input: HermesResponsesInput; let stream: Bool; let store: Bool; let previousResponseID: String?; let reasoning: HermesReasoningRequest?; enum CodingKeys: String, CodingKey { case model, input, stream, store, reasoning; case previousResponseID = "previous_response_id" } }

private struct HermesResponseEnvelope: Decodable {
    let id: String?
    let output: [HermesResponseOutputItem]?
    let usage: HermesTokenUsage?
    var assistantText: String { (output ?? []).compactMap(\.assistantText).joined(separator: "\n\n") }
    var outputMessageType: String { output?.first(where: { $0.assistantText?.isEmpty == false })?.type ?? "message" }
}
private struct HermesResponseOutputItem: Decodable { let type: String; let content: [HermesResponseContent]?; let output: [HermesResponseContent]?; var assistantText: String? { guard type == "message" else { return nil }; let text = (content ?? output ?? []).compactMap(\.displayValue).joined(); return text.isEmpty ? nil : text } }
private struct HermesResponseContent: Decodable {
    let type: String?; let text: String?; let imageURL: HermesImageURLPayload?; let url: String?; let b64JSON: String?; let imageBase64: String?; let mimeType: String?; let originalMimeType: String?
    enum CodingKeys: String, CodingKey { case type, text, url; case imageURL = "image_url"; case b64JSON = "b64_json"; case imageBase64 = "image_base64"; case mimeType = "mime_type"; case originalMimeType = "original_mime_type" }
    var displayValue: String? {
        if let imageMarkdown { return imageMarkdown }
        if type == nil || type == "output_text" || type == "text" || type == "message" { return text.flatMap { HermesImageJSONFormatter.renderableImageMarkdown(from: $0) ?? $0 } }
        return nil
    }
    var imageMarkdown: String? {
        let base64 = b64JSON ?? imageBase64
        let source = imageURL?.url ?? url ?? base64.flatMap { base64Value in
            HermesImageJSONFormatter.dataImageSource(from: base64Value, fallbackMIME: mimeType ?? originalMimeType)
        }
        guard let source, HermesImageJSONFormatter.looksLikeImageSource(source) else { return nil }
        return "\n\n![Hermes image](\(source))"
    }
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
    init(data: Data) { object = try? JSONSerialization.jsonObject(with: data) }
    func string(at path: [String]) -> String? { guard let value = value(at: path) else { return nil }; if let string = value as? String { return string }; if let number = value as? NSNumber { return number.stringValue }; return nil }
    func int(at path: [String]) -> Int? { guard let value = value(at: path) else { return nil }; if let int = value as? Int { return int }; if let number = value as? NSNumber { return number.intValue }; if let string = value as? String { return Int(string) }; return nil }
    func tokenUsage() -> HermesTokenUsage? {
        let input = int(at: ["usage", "input_tokens"])
            ?? int(at: ["usage", "prompt_tokens"])
            ?? int(at: ["usage", "total_input_tokens"])
            ?? int(at: ["response", "usage", "input_tokens"])
            ?? int(at: ["response", "usage", "prompt_tokens"])
            ?? int(at: ["response", "usage", "total_input_tokens"])
            ?? int(at: ["input_tokens"])
            ?? int(at: ["prompt_tokens"])
        let output = int(at: ["usage", "output_tokens"])
            ?? int(at: ["usage", "completion_tokens"])
            ?? int(at: ["usage", "total_output_tokens"])
            ?? int(at: ["response", "usage", "output_tokens"])
            ?? int(at: ["response", "usage", "completion_tokens"])
            ?? int(at: ["response", "usage", "total_output_tokens"])
            ?? int(at: ["output_tokens"])
            ?? int(at: ["completion_tokens"])
        let usage = HermesTokenUsage(inputTokens: input, outputTokens: output)
        return usage.isEmpty ? nil : usage
    }
    func texts(at path: [String]) -> [String] { value(at: path).map(extractTexts(from:)) ?? [] }
    func messageOutputTexts(at path: [String]) -> [String] { value(at: path).map(extractMessageOutputTexts(from:)) ?? [] }
    func streamOutputTexts() -> [String] {
        var texts: [String] = []
        texts.append(contentsOf: value(at: ["response", "output", "text"]).map(extractTexts(from:)) ?? [])
        texts.append(contentsOf: value(at: ["response", "output"]).map(extractDirectOutputTexts(from:)) ?? [])
        texts.append(contentsOf: value(at: ["item", "output", "text"]).map(extractTexts(from:)) ?? [])
        texts.append(contentsOf: value(at: ["item", "output"]).map(extractDirectOutputTexts(from:)) ?? [])
        return texts.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
    private func value(at path: [String]) -> Any? { var current = object; for key in path { if let index = Int(key), let array = current as? [Any], array.indices.contains(index) { current = array[index] } else if let dict = current as? [String: Any] { current = dict[key] } else { return nil } }; return current }
    private func extractDirectOutputTexts(from value: Any) -> [String] {
        if let string = value as? String { return [string] }
        if let array = value as? [Any] { return array.flatMap(extractDirectOutputTexts) }
        guard let dict = value as? [String: Any] else { return [] }
        var texts: [String] = []
        if let text = dict["text"] as? String { texts.append(text) }
        if let outputText = dict["output_text"] as? String { texts.append(outputText) }
        if texts.isEmpty, let content = dict["content"] { texts.append(contentsOf: extractDirectOutputTexts(from: content)) }
        return texts
    }
    private func extractMessageOutputTexts(from value: Any) -> [String] {
        if let array = value as? [Any] { return array.flatMap(extractMessageOutputTexts) }
        guard let dict = value as? [String: Any] else { return [] }
        if let type = dict["type"] as? String, type != "message" { return [] }
        return extractTexts(from: dict["content"] ?? dict["output"] ?? dict)
    }
    private func extractTexts(from value: Any) -> [String] { if let string = value as? String { return [string] }; if let array = value as? [Any] { return array.flatMap(extractTexts) }; if let dict = value as? [String: Any] { if let text = dict["text"] as? String { return [text] }; if let outputText = dict["output_text"] as? String { return [outputText] }; return dict.values.flatMap(extractTexts) }; return [] }
}

enum HermesImageJSONFormatter {
    private static let maxEncodedImageCharacters = 32_000_000

    static func renderableImageMarkdown(from text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let fencedJSON = unfencedJSON(from: trimmed), let markdown = imageMarkdown(fromJSONString: fencedJSON) {
            return markdown
        }
        if let markdown = imageMarkdown(fromJSONString: trimmed) {
            return markdown
        }
        if (trimmed.contains("image_base64") || trimmed.contains("b64_json")), let markdown = regexImageMarkdown(from: trimmed) {
            return markdown
        }
        return nil
    }

    static func looksLikeImageSource(_ source: String) -> Bool {
        let lower = source.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if lower.hasPrefix("data:image/") || lower.hasPrefix("file://") { return true }
        if lower.hasPrefix("/") || lower.hasPrefix("~/") { return [".png", ".jpg", ".jpeg", ".gif", ".webp", ".heic"].contains { lower.hasSuffix($0) } }
        return false
    }

    static func normalizedImageMIME(_ value: String?) -> String? {
        guard let value else { return nil }
        let lower = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let allowed = ["image/png", "image/jpeg", "image/jpg", "image/gif", "image/webp", "image/heic"]
        return allowed.contains(lower) ? (lower == "image/jpg" ? "image/jpeg" : lower) : nil
    }

    private static func imageMarkdown(fromJSONString text: String) -> String? {
        guard let data = text.data(using: .utf8), let object = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else { return nil }
        return imageMarkdown(fromJSONObject: object)
    }

    private static func imageMarkdown(fromJSONObject object: Any) -> String? {
        if let array = object as? [Any] {
            let parts = array.compactMap(imageMarkdown(fromJSONObject:))
            return parts.isEmpty ? nil : parts.joined(separator: "\n\n")
        }
        guard let dict = object as? [String: Any] else {
            if let string = object as? String {
                if string.contains("![") { return string }
                return renderableImageMarkdown(from: string)
            }
            return nil
        }

        if let base64 = firstString(in: dict, keys: ["image_base64", "b64_json"]) {
            let mime = normalizedImageMIME(firstString(in: dict, keys: ["mime_type", "original_mime_type"])) ?? "image/png"
            let source = dataImageSource(from: base64, fallbackMIME: mime) ?? "data:\(mime);base64,invalid"
            return "\n\n![Hermes image](\(source))"
        }

        if let source = imageSource(in: dict), looksLikeImageSource(source) {
            return "\n\n![Hermes image](\(source.trimmingCharacters(in: .whitespacesAndNewlines)))"
        }

        for key in ["text", "content", "message", "output_text"] {
            guard let value = dict[key] else { continue }
            if let string = value as? String {
                if string.contains("![") { return string }
                if let markdown = renderableImageMarkdown(from: string) { return markdown }
            } else if let markdown = imageMarkdown(fromJSONObject: value) {
                return markdown
            }
        }

        for key in ["output", "data", "choices", "message", "content"] {
            if let value = dict[key], let markdown = imageMarkdown(fromJSONObject: value) { return markdown }
        }
        return nil
    }

    private static func imageSource(in dict: [String: Any]) -> String? {
        if let source = firstString(in: dict, keys: ["image_url", "url", "file_url", "path", "file"]) { return source }
        if let imageURL = dict["image_url"] as? [String: Any], let url = firstString(in: imageURL, keys: ["url"]) { return url }
        return nil
    }

    private static func firstString(in dict: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let string = dict[key] as? String { return string }
        }
        return nil
    }

    private static func unfencedJSON(from text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("```") else { return nil }
        let lines = trimmed.components(separatedBy: .newlines)
        guard lines.count >= 3, lines.last?.trimmingCharacters(in: .whitespacesAndNewlines) == "```" else { return nil }
        return lines.dropFirst().dropLast().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func regexImageMarkdown(from text: String) -> String? {
        let rawMime = firstJSONStringValue(for: "mime_type", in: text) ?? firstJSONStringValue(for: "original_mime_type", in: text)
        let mime = normalizedImageMIME(rawMime) ?? "image/png"
        guard let base64 = firstJSONStringValue(for: "image_base64", in: text) ?? firstJSONStringValue(for: "b64_json", in: text) else { return nil }
        let source = dataImageSource(from: base64, fallbackMIME: mime) ?? "data:\(mime);base64,invalid"
        return "\n\n![Hermes image](\(source))"
    }

    static func dataImageSource(from value: String, fallbackMIME: String?) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if let separator = trimmed.range(of: ";base64,", options: [.caseInsensitive]) {
            let prefix = String(trimmed[..<separator.lowerBound]).lowercased()
            guard prefix.hasPrefix("data:"), let mime = normalizedImageMIME(String(prefix.dropFirst("data:".count))) else { return nil }
            guard let encoded = normalizedBase64Payload(String(trimmed[separator.upperBound...])) else { return nil }
            return "data:\(mime);base64,\(encoded)"
        }
        guard let encoded = normalizedBase64Payload(value) else { return nil }
        let mime = normalizedImageMIME(fallbackMIME) ?? "image/png"
        return "data:\(mime);base64,\(encoded)"
    }

    private static func normalizedBase64Payload(_ value: String) -> String? {
        var encoded = value.filter { !$0.isWhitespace }
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        guard !encoded.isEmpty, encoded.count <= maxEncodedImageCharacters else { return nil }
        let remainder = encoded.count % 4
        if remainder == 1 { return nil }
        if remainder > 0 { encoded += String(repeating: "=", count: 4 - remainder) }
        guard encoded.range(of: #"^[A-Za-z0-9+/]*={0,2}$"#, options: .regularExpression) != nil else { return nil }
        return encoded
    }

    private static func firstJSONStringValue(for key: String, in text: String) -> String? { let pattern = #""# + NSRegularExpression.escapedPattern(for: key) + #""\s*:\s*"((?:\\.|[^"\\])*)""#; guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]), let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text)), let range = Range(match.range(at: 1), in: text) else { return nil }; let value = String(text[range]); let wrapped = "\"\(value)\""; return wrapped.data(using: .utf8).flatMap { try? JSONSerialization.jsonObject(with: $0) as? String } ?? value }
}

enum HermesResponsesError: LocalizedError {
    case invalidURL, invalidResponse, httpError(Int)
    var errorDescription: String? { switch self { case .invalidURL: String(localized: "The Hermes gateway URL is invalid."); case .invalidResponse: String(localized: "The Hermes gateway returned an invalid response."); case .httpError(let code): String(localized: "The Hermes gateway returned HTTP \(code).") } }
}
