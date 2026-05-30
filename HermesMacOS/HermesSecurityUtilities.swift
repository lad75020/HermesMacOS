//
//  HermesSecurityUtilities.swift
//  HermesMacOS
//

import CryptoKit
import Darwin
import Foundation
import LocalAuthentication
import Observation
import Security

struct HermesProcessResult: Equatable {
    let exitCode: Int32
    let output: String
    let timedOut: Bool

    var statusLine: String {
        timedOut ? "terminated after timeout (exit \(exitCode))" : "exit \(exitCode)"
    }
}

enum HermesSecurityError: LocalizedError {
    case insecureTransport(String)
    case encryptionUnavailable
    case localApprovalDenied(String)
    case authenticationFailed(String)
    case dashboardSessionTokenMissing
    case dashboardURLInvalid
    case dashboardConfigChanged

    var errorDescription: String? {
        switch self {
        case .insecureTransport(let host):
            return String(localized: "Remote HTTP is blocked for sensitive Hermes traffic to \(host). Use HTTPS or localhost.")
        case .encryptionUnavailable:
            return String(localized: "HermesMacOS could not access its local encryption key.")
        case .localApprovalDenied(let path):
            return String(localized: "Local filesystem access was denied for \(path).")
        case .authenticationFailed(let reason):
            return String(localized: "HermesMacOS secrets could not be unlocked: \(reason)")
        case .dashboardSessionTokenMissing:
            return String(localized: "The dashboard session token was not found in the dashboard HTML.")
        case .dashboardURLInvalid:
            return String(localized: "The Hermes dashboard URL is invalid.")
        case .dashboardConfigChanged:
            return String(localized: "The dashboard config changed before HermesMacOS could save it. Refresh and retry.")
        }
    }
}

enum HermesEndpointSecurity {
    static func isLoopbackHost(_ host: String?) -> Bool {
        let value = (host ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return value.isEmpty || value == "localhost" || value == "127.0.0.1" || value == "::1" || value == "[::1]"
    }

    static func isRemotePlaintext(_ url: URL) -> Bool {
        guard (url.scheme ?? "").lowercased() == "http" else { return false }
        return !isLoopbackHost(url.host)
    }

    static func validateSensitiveURL(_ url: URL) throws {
        if isRemotePlaintext(url) { throw HermesSecurityError.insecureTransport(url.host ?? url.absoluteString) }
    }
}

actor HermesSecretUnlockGate {
    static let shared = HermesSecretUnlockGate()

    private var isUnlocked = false
    private var inFlightUnlock: Task<Void, Error>?

    func unlockIfNeeded() async throws {
        if isUnlocked { return }
        if let inFlightUnlock {
            try await inFlightUnlock.value
            return
        }
        let task = Task {
            let context = LAContext()
            context.localizedCancelTitle = String(localized: "Cancel")
            var error: NSError?
            guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
                throw HermesSecurityError.authenticationFailed(error?.localizedDescription ?? String(localized: "local authentication is unavailable"))
            }
            try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: String(localized: "Unlock HermesMacOS secrets for this login session.")
            )
        }
        inFlightUnlock = task
        do {
            try await task.value
            isUnlocked = true
            inFlightUnlock = nil
        } catch {
            inFlightUnlock = nil
            throw error
        }
    }
}

private final class HermesCachedSecret<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var isCached = false
    private var cachedValue: Value?

    func value() -> (isCached: Bool, value: Value?) {
        lock.lock()
        defer { lock.unlock() }
        return (isCached, cachedValue)
    }

    func store(_ value: Value?) {
        lock.lock()
        cachedValue = value
        isCached = true
        lock.unlock()
    }

    func clear() {
        lock.lock()
        cachedValue = nil
        isCached = false
        lock.unlock()
    }
}

final class HermesKeyedCachedSecret<Key: Hashable, Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var cachedValues: [Key: Value?] = [:]
    private var cachedKeys = Set<Key>()

    func value(for key: Key) -> (isCached: Bool, value: Value?) {
        lock.lock()
        defer { lock.unlock() }
        return (cachedKeys.contains(key), cachedValues[key] ?? nil)
    }

    func store(_ value: Value?, for key: Key) {
        lock.lock()
        cachedValues[key] = value
        cachedKeys.insert(key)
        lock.unlock()
    }

    func clear(for key: Key) {
        lock.lock()
        cachedValues.removeValue(forKey: key)
        cachedKeys.remove(key)
        lock.unlock()
    }
}

enum HermesKeychainDataProtection {
    static func genericPasswordQuery(service: String, account: String, dataProtection: Bool = true) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        if dataProtection {
            query[kSecUseDataProtectionKeychain as String] = true
        }
        return query
    }

    static func deleteGenericPassword(service: String, account: String) {
        SecItemDelete(genericPasswordQuery(service: service, account: account, dataProtection: true) as CFDictionary)
        SecItemDelete(genericPasswordQuery(service: service, account: account, dataProtection: false) as CFDictionary)
    }
}

enum HermesAPIKeychain {
    private static let service = "HermesMacOS.APIKeys"
    private static let account = "default"
    private static let cache = HermesCachedSecret<String>()

    static func loadAPIKey() -> String {
        let cached = cache.value()
        if cached.isCached { return cached.value ?? "" }
        if let key = loadAPIKey(dataProtection: true) {
            cache.store(key)
            return key
        }
        if let legacyKey = loadAPIKey(dataProtection: false) {
            migrateAPIKeyToDataProtection(legacyKey)
            cache.store(legacyKey)
            return legacyKey
        }
        cache.store("")
        return ""
    }

    static func saveAPIKey(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        HermesKeychainDataProtection.deleteGenericPassword(service: service, account: account)
        cache.store(trimmed)
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else { return }
        var query = baseQuery()
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        SecItemAdd(query as CFDictionary, nil)
    }

    private static func loadAPIKey(dataProtection: Bool) -> String? {
        var query = baseQuery(dataProtection: dataProtection)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8) ?? ""
    }

    private static func migrateAPIKeyToDataProtection(_ key: String) {
        guard !key.isEmpty, let data = key.data(using: .utf8) else { return }
        var query = baseQuery(dataProtection: true)
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecSuccess || status == errSecDuplicateItem {
            SecItemDelete(baseQuery(dataProtection: false) as CFDictionary)
        }
    }

    private static func baseQuery(dataProtection: Bool = true) -> [String: Any] {
        HermesKeychainDataProtection.genericPasswordQuery(service: service, account: account, dataProtection: dataProtection)
    }
}

enum HermesSecretRedactor {
    static func redact(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        var result = text
        let replacements: [(String, String)] = [
            (#"-----BEGIN [A-Z ]*PRIVATE KEY-----[\s\S]*?-----END [A-Z ]*PRIVATE KEY-----"#, "[PRIVATE KEY REDACTED]"),
            (#"data:[A-Za-z0-9.+-]+/[A-Za-z0-9.+-]+(?:;[A-Za-z0-9=.+-]+)*;base64,[A-Za-z0-9+/=\r\n]{32,}"#, "[DATA URL REDACTED]"),
            (#"(?i)\b(authorization\s*[:=]\s*bearer\s+)[^\s"'`]+"#, "$1[REDACTED]"),
            (#"(?im)^(\s*(?:api[_-]?key|secret|password|passwd|token|access[_-]?token|refresh[_-]?token|client[_-]?secret)\s*[:=]\s*).+$"#, "$1[REDACTED]"),
            (#"\bsk-[A-Za-z0-9_-]{20,}\b"#, "[OPENAI KEY REDACTED]"),
            (#"\bgh[pousr]_[A-Za-z0-9_]{20,}\b"#, "[GITHUB TOKEN REDACTED]"),
            (#"\bxox[baprs]-[A-Za-z0-9-]{20,}\b"#, "[SLACK TOKEN REDACTED]"),
            (#"\b[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\b"#, "[JWT REDACTED]"),
            (#"\b(?:bearer|token)\s+[A-Za-z0-9._~+/=-]{24,}\b"#, "[TOKEN REDACTED]")
        ]
        for (pattern, replacement) in replacements {
            result = result.replacingOccurrences(of: pattern, with: replacement, options: [.regularExpression])
        }
        return result
    }
}

enum HermesEncryptedRetentionStore {
    private static let keyService = "HermesMacOS.LocalRetentionKey"
    private static let keyAccount = "AES-GCM"
    private static let encryptedPrefix = "hermes.macOS.encrypted."
    private static let version: UInt8 = 1
    private static let keyCache = HermesCachedSecret<Data>()

    static func load<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        if let encrypted = UserDefaults.standard.data(forKey: encryptedKey(key)),
           let plaintext = try? decrypt(encrypted) {
            return try? JSONDecoder().decode(type, from: plaintext)
        }
        guard let plaintext = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode(type, from: plaintext)
        else { return nil }
        if saveData(plaintext, forKey: key) {
            UserDefaults.standard.removeObject(forKey: key)
        }
        return decoded
    }

    @discardableResult
    static func save<T: Encodable>(_ value: T, forKey key: String) -> Bool {
        guard let data = try? JSONEncoder().encode(value) else { return false }
        return saveData(data, forKey: key)
    }

    static func loadString(forKey key: String) -> String {
        if let encrypted = UserDefaults.standard.data(forKey: encryptedKey(key)),
           let plaintext = try? decrypt(encrypted),
           let string = String(data: plaintext, encoding: .utf8) {
            return string
        }
        guard let value = UserDefaults.standard.string(forKey: key) else { return "" }
        if saveString(value, forKey: key) {
            UserDefaults.standard.removeObject(forKey: key)
        }
        return value
    }

    @discardableResult
    static func saveString(_ value: String, forKey key: String) -> Bool {
        saveData(Data(HermesSecretRedactor.redact(value).utf8), forKey: key)
    }

    static func removeValue(forKey key: String) {
        UserDefaults.standard.removeObject(forKey: encryptedKey(key))
        UserDefaults.standard.removeObject(forKey: key)
    }

    @discardableResult
    private static func saveData(_ data: Data, forKey key: String) -> Bool {
        do {
            let encrypted = try encrypt(data)
            UserDefaults.standard.set(encrypted, forKey: encryptedKey(key))
            return true
        } catch {
            return false
        }
    }

    private static func encryptedKey(_ key: String) -> String { encryptedPrefix + key }

    private static func encrypt(_ data: Data) throws -> Data {
        let sealedBox = try AES.GCM.seal(data, using: key())
        guard let combined = sealedBox.combined else { throw HermesSecurityError.encryptionUnavailable }
        return Data([version]) + combined
    }

    private static func decrypt(_ data: Data) throws -> Data {
        guard data.first == version else { throw HermesSecurityError.encryptionUnavailable }
        let combined = Data(data.dropFirst())
        return try AES.GCM.open(AES.GCM.SealedBox(combined: combined), using: key())
    }

    private static func key() throws -> SymmetricKey {
        if let existing = keyData() { return SymmetricKey(data: existing) }
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            throw HermesSecurityError.encryptionUnavailable
        }
        let data = Data(bytes)
        var query = keyQuery()
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess || status == errSecDuplicateItem else { throw HermesSecurityError.encryptionUnavailable }
        keyCache.store(data)
        return SymmetricKey(data: data)
    }

    private static func keyData() -> Data? {
        let cached = keyCache.value()
        if cached.isCached { return cached.value }
        if let existing = keyData(dataProtection: true) {
            keyCache.store(existing)
            return existing
        }
        if let legacy = keyData(dataProtection: false) {
            migrateKeyToDataProtection(legacy)
            keyCache.store(legacy)
            return legacy
        }
        keyCache.store(nil)
        return nil
    }

    private static func keyData(dataProtection: Bool) -> Data? {
        var query = keyQuery(dataProtection: dataProtection)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else { return nil }
        return item as? Data
    }

    private static func migrateKeyToDataProtection(_ data: Data) {
        var query = keyQuery(dataProtection: true)
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecSuccess || status == errSecDuplicateItem {
            SecItemDelete(keyQuery(dataProtection: false) as CFDictionary)
        }
    }

    private static func keyQuery(dataProtection: Bool = true) -> [String: Any] {
        HermesKeychainDataProtection.genericPasswordQuery(service: keyService, account: keyAccount, dataProtection: dataProtection)
    }
}

struct HermesDashboardRawConfig {
    let yaml: String
    let eTag: String?
    let lastModified: String?
    let revision: String?
}

private struct HermesDashboardRawConfigUpdate: Encodable {
    let yamlText: String
    enum CodingKeys: String, CodingKey { case yamlText = "yaml_text" }
}

actor HermesDashboardClient {
    static let shared = HermesDashboardClient()
    private var cachedTokenByBaseURL: [String: String] = [:]

    func resolvedBaseURL(dashboardBaseURL: String, apiBaseURL: String) throws -> URL {
        let explicit = dashboardBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !explicit.isEmpty, let url = normalizedBaseURL(from: explicit) { return url }
        var fallback = apiBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if fallback.hasSuffix("/v1") { fallback.removeLast(3) }
        guard let url = normalizedBaseURL(from: fallback) else { throw HermesSecurityError.dashboardURLInvalid }
        return url
    }

    func sessionToken(baseURL: URL, apiSettings: HermesAPISettings, refresh: Bool = false) async throws -> String {
        try HermesEndpointSecurity.validateSensitiveURL(baseURL)
        let cacheKey = baseURL.absoluteString
        if !refresh, let cached = cachedTokenByBaseURL[cacheKey], !cached.isEmpty { return cached }
        let (data, response) = try await HermesNetworkSessionFactory.session(for: apiSettings).data(from: baseURL)
        try HermesNetworkSessionFactory.validate(response: response)
        let html = String(decoding: data, as: UTF8.self)
        let regex = try NSRegularExpression(pattern: #"window\.__HERMES_SESSION_TOKEN__\s*=\s*"([^"]+)""#)
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        guard let match = regex.firstMatch(in: html, range: range), let tokenRange = Range(match.range(at: 1), in: html) else {
            throw HermesSecurityError.dashboardSessionTokenMissing
        }
        let token = String(html[tokenRange])
        cachedTokenByBaseURL[cacheKey] = token
        return token
    }

    func getJSON<Response: Decodable>(_ type: Response.Type, baseURL: URL, path: String, queryItems: [URLQueryItem] = [], apiSettings: HermesAPISettings, timeout: TimeInterval = 30) async throws -> Response {
        let token = try await sessionToken(baseURL: baseURL, apiSettings: apiSettings)
        var request = try request(baseURL: baseURL, path: path, queryItems: queryItems, method: "GET", token: token, timeout: timeout)
        let (data, response) = try await HermesNetworkSessionFactory.session(for: apiSettings).data(for: request)
        do {
            try HermesNetworkSessionFactory.validate(response: response)
        } catch HermesResponsesError.httpError(401) {
            let refreshed = try await sessionToken(baseURL: baseURL, apiSettings: apiSettings, refresh: true)
            request = try self.request(baseURL: baseURL, path: path, queryItems: queryItems, method: "GET", token: refreshed, timeout: timeout)
            let retry = try await HermesNetworkSessionFactory.session(for: apiSettings).data(for: request)
            try HermesNetworkSessionFactory.validate(response: retry.1)
            return try JSONDecoder().decode(type, from: retry.0)
        }
        return try JSONDecoder().decode(type, from: data)
    }

    func sendJSON<Body: Encodable>(baseURL: URL, path: String, queryItems: [URLQueryItem] = [], method: String, apiSettings: HermesAPISettings, body: Body?, timeout: TimeInterval = 30) async throws -> Data {
        let token = try await sessionToken(baseURL: baseURL, apiSettings: apiSettings)
        var request = try request(baseURL: baseURL, path: path, queryItems: queryItems, method: method, token: token, timeout: timeout)
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)
        }
        let (data, response) = try await HermesNetworkSessionFactory.session(for: apiSettings).data(for: request)
        try HermesNetworkSessionFactory.validate(response: response)
        return data
    }

    func rawConfig(baseURL: URL, apiSettings: HermesAPISettings) async throws -> HermesDashboardRawConfig {
        let token = try await sessionToken(baseURL: baseURL, apiSettings: apiSettings)
        let request = try request(baseURL: baseURL, path: "api/config/raw", method: "GET", token: token, timeout: 30)
        let (data, response) = try await HermesNetworkSessionFactory.session(for: apiSettings).data(for: request)
        try HermesNetworkSessionFactory.validate(response: response)
        let http = response as? HTTPURLResponse
        let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        let yaml = object?["yaml"] as? String ?? object?["yaml_text"] as? String ?? String(decoding: data, as: UTF8.self)
        let revisionValue = object?["revision"] ?? object?["version"] ?? object?["config_revision"]
        return HermesDashboardRawConfig(
            yaml: yaml,
            eTag: http?.value(forHTTPHeaderField: "ETag"),
            lastModified: http?.value(forHTTPHeaderField: "Last-Modified"),
            revision: revisionValue.map { "\($0)" }
        )
    }

    func mutateRawConfig(baseURL: URL, apiSettings: HermesAPISettings, transform: (String) throws -> String) async throws {
        let fetched = try await rawConfig(baseURL: baseURL, apiSettings: apiSettings)
        let updated = try transform(fetched.yaml)
        guard updated != fetched.yaml else { return }
        if fetched.eTag == nil, fetched.lastModified == nil, fetched.revision == nil {
            let latest = try await rawConfig(baseURL: baseURL, apiSettings: apiSettings)
            guard latest.yaml == fetched.yaml else { throw HermesSecurityError.dashboardConfigChanged }
        }
        try await updateRawConfig(updated, previous: fetched, baseURL: baseURL, apiSettings: apiSettings)
    }

    func updateRawConfig(_ yaml: String, previous: HermesDashboardRawConfig, baseURL: URL, apiSettings: HermesAPISettings) async throws {
        let token = try await sessionToken(baseURL: baseURL, apiSettings: apiSettings)
        var request = try request(baseURL: baseURL, path: "api/config/raw", method: "PUT", token: token, timeout: 30)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let eTag = previous.eTag, !eTag.isEmpty { request.setValue(eTag, forHTTPHeaderField: "If-Match") }
        if let lastModified = previous.lastModified, !lastModified.isEmpty { request.setValue(lastModified, forHTTPHeaderField: "If-Unmodified-Since") }
        if let revision = previous.revision, !revision.isEmpty { request.setValue(revision, forHTTPHeaderField: "X-Hermes-Config-Revision") }
        request.httpBody = try JSONEncoder().encode(HermesDashboardRawConfigUpdate(yamlText: yaml))
        let (_, response) = try await HermesNetworkSessionFactory.session(for: apiSettings).data(for: request)
        try HermesNetworkSessionFactory.validate(response: response)
    }

    private func request(baseURL: URL, path: String, queryItems: [URLQueryItem] = [], method: String, token: String, timeout: TimeInterval) throws -> URLRequest {
        var url = baseURL
        for component in path.split(separator: "/").map(String.init) {
            url.appendPathComponent(component)
        }
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { throw HermesSecurityError.dashboardURLInvalid }
        if !queryItems.isEmpty { components.queryItems = queryItems }
        guard let finalURL = components.url else { throw HermesSecurityError.dashboardURLInvalid }
        var request = URLRequest(url: finalURL)
        request.httpMethod = method
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(token, forHTTPHeaderField: "X-Hermes-Session-Token")
        return request
    }

    private func normalizedBaseURL(from value: String) -> URL? {
        var trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        while trimmed.hasSuffix("/") { trimmed.removeLast() }
        guard let url = URL(string: trimmed), ["http", "https"].contains((url.scheme ?? "").lowercased()) else { return nil }
        return url
    }
}

enum HermesPinnedCertificateTrust {
    private static let pinService = "HermesMacOS.CertificatePins"

    static func handle(trust: SecTrust, host: String, allowSelfSignedCertificates: Bool) -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        guard allowSelfSignedCertificates else { return (.performDefaultHandling, nil) }
        var trustError: CFError?
        if SecTrustEvaluateWithError(trust, &trustError) { return (.performDefaultHandling, nil) }
        guard let fingerprint = leafCertificateFingerprint(trust: trust) else { return (.cancelAuthenticationChallenge, nil) }
        let normalized = normalizedHost(host)
        if let pinned = loadPin(forHost: normalized), !pinned.isEmpty {
            guard pinned == fingerprint else { return (.cancelAuthenticationChallenge, nil) }
            return (.useCredential, URLCredential(trust: trust))
        }
        Task { @MainActor in
            HermesLocalApprovalCenter.shared.enqueueCertificatePinApproval(host: normalized, fingerprint: fingerprint)
        }
        return (.cancelAuthenticationChallenge, nil)
    }

    static func approvePin(host: String, fingerprint: String) {
        let normalized = normalizedHost(host)
        HermesKeychainDataProtection.deleteGenericPassword(service: pinService, account: normalized)
        guard let data = fingerprint.data(using: .utf8) else { return }
        var query = pinQuery(host: normalized)
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        SecItemAdd(query as CFDictionary, nil)
        UserDefaults.standard.removeObject(forKey: "hermes.macOS.pinnedServerCertificateSHA256.\(normalized)")
    }

    static func resetPin(host: String) {
        HermesKeychainDataProtection.deleteGenericPassword(service: pinService, account: normalizedHost(host))
    }

    private static func normalizedHost(_ host: String) -> String {
        host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func loadPin(forHost host: String) -> String? {
        if let pin = loadPin(forHost: host, dataProtection: true) { return pin }
        if let legacyPin = loadPin(forHost: host, dataProtection: false) {
            approvePin(host: host, fingerprint: legacyPin)
            return legacyPin
        }
        let legacyKey = "hermes.macOS.pinnedServerCertificateSHA256.\(host)"
        if let legacy = UserDefaults.standard.string(forKey: legacyKey), !legacy.isEmpty {
            approvePin(host: host, fingerprint: legacy)
            return legacy
        }
        return nil
    }

    private static func loadPin(forHost host: String, dataProtection: Bool) -> String? {
        var query = pinQuery(host: host, dataProtection: dataProtection)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        if SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
           let data = item as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }

    private static func pinQuery(host: String, dataProtection: Bool = true) -> [String: Any] {
        HermesKeychainDataProtection.genericPasswordQuery(service: pinService, account: host, dataProtection: dataProtection)
    }

    private static func leafCertificateFingerprint(trust: SecTrust) -> String? {
        if let chain = SecTrustCopyCertificateChain(trust) as? [SecCertificate], let certificate = chain.first {
            let data = SecCertificateCopyData(certificate) as Data
            return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        }
        return nil
    }
}

struct HermesLocalApprovalRequest: Identifiable, Equatable {
    enum Kind: String {
        case filesystem
        case certificatePin
    }

    let id: String
    let kind: Kind
    let title: String
    let command: String
    let description: String
    let createdAt: Date
    let host: String?
    let fingerprint: String?
}

@MainActor
@Observable
final class HermesLocalApprovalCenter {
    static let shared = HermesLocalApprovalCenter()
    private(set) var pending: [HermesLocalApprovalRequest] = []
    private var continuations: [String: CheckedContinuation<Bool, Never>] = [:]

    private init() {}

    func requestFilesystemAccess(path: String, operation: String) async -> Bool {
        let normalized = HermesFilesystemAccessPolicy.standardizedPath(path)
        let id = "local-fs-\(SHA256.hash(data: Data((operation + normalized).utf8)).map { String(format: "%02x", $0) }.joined())"
        if continuations[id] != nil { return await withCheckedContinuation { continuations[id] = $0 } }
        let request = HermesLocalApprovalRequest(
            id: id,
            kind: .filesystem,
            title: "Filesystem access",
            command: operation,
            description: normalized,
            createdAt: Date(),
            host: nil,
            fingerprint: nil
        )
        pending.removeAll { $0.id == id }
        pending.insert(request, at: 0)
        return await withCheckedContinuation { continuation in
            continuations[id] = continuation
        }
    }

    func enqueueCertificatePinApproval(host: String, fingerprint: String) {
        let id = "local-tls-\(host)-\(fingerprint)"
        guard !pending.contains(where: { $0.id == id }) else { return }
        pending.insert(
            HermesLocalApprovalRequest(
                id: id,
                kind: .certificatePin,
                title: "Trust self-signed certificate",
                command: host,
                description: fingerprint,
                createdAt: Date(),
                host: host,
                fingerprint: fingerprint
            ),
            at: 0
        )
    }

    func resolve(id: String, approved: Bool) {
        guard let request = pending.first(where: { $0.id == id }) else { return }
        pending.removeAll { $0.id == id }
        if request.kind == .certificatePin, approved, let host = request.host, let fingerprint = request.fingerprint {
            HermesPinnedCertificateTrust.approvePin(host: host, fingerprint: fingerprint)
        }
        continuations.removeValue(forKey: id)?.resume(returning: approved)
    }
}

enum HermesFilesystemAccessPolicy {
    static let allowedFoldersKey = "hermes.macOS.security.allowedFolders"

    static func allowedFolders() -> [String] {
        let data = UserDefaults.standard.data(forKey: allowedFoldersKey)
        let stored = data.flatMap { try? JSONDecoder().decode([String].self, from: $0) } ?? []
        let defaults = [
            HermesRuntimePaths.defaultHermesHome,
            HermesRuntimePaths.defaultHermesAgentRoot,
            NSHomeDirectory()
        ]
        return Array(Set((stored + defaults).map(standardizedPath).filter { !$0.isEmpty })).sorted()
    }

    static func saveAllowedFolders(_ folders: [String]) {
        let cleaned = folders.map(standardizedPath).filter { !$0.isEmpty }
        if let data = try? JSONEncoder().encode(Array(Set(cleaned)).sorted()) {
            UserDefaults.standard.set(data, forKey: allowedFoldersKey)
        }
    }

    static func isAllowed(_ path: String) -> Bool {
        let target = standardizedPath(path)
        return allowedFolders().contains { folder in
            target == folder || target.hasPrefix(folder.hasSuffix("/") ? folder : folder + "/")
        }
    }

    static func requireAccess(to path: String, operation: String) async throws {
        guard !isAllowed(path) else { return }
        let approved = await HermesLocalApprovalCenter.shared.requestFilesystemAccess(path: path, operation: operation)
        guard approved else { throw HermesSecurityError.localApprovalDenied(path) }
    }

    static func standardizedPath(_ path: String) -> String {
        URL(fileURLWithPath: NSString(string: path.trimmingCharacters(in: .whitespacesAndNewlines)).expandingTildeInPath).standardizedFileURL.path
    }
}

enum HermesRuntimePaths {
    static var defaultHermesHome: String {
        if let value = existingDirectory(ProcessInfo.processInfo.environment["HERMES_HOME"]) { return value }
        let homeDefault = NSString(string: "~/.hermes").expandingTildeInPath
        if FileManager.default.fileExists(atPath: homeDefault) { return homeDefault }
        let legacyExternal = "/Volumes/WDBlack4TB/.hermes"
        if FileManager.default.fileExists(atPath: legacyExternal) { return legacyExternal }
        return homeDefault
    }

    static var defaultHermesAgentRoot: String {
        if let value = existingDirectory(ProcessInfo.processInfo.environment["HERMES_AGENT_ROOT"]) { return value }
        let homeRoot = URL(fileURLWithPath: defaultHermesHome).appendingPathComponent("hermes-agent", isDirectory: true).path
        if FileManager.default.fileExists(atPath: homeRoot) { return homeRoot }
        let userRoot = NSString(string: "~/.hermes/hermes-agent").expandingTildeInPath
        if FileManager.default.fileExists(atPath: userRoot) { return userRoot }
        return userRoot
    }

    static var defaultHermesExecutable: String {
        let venvExecutable = URL(fileURLWithPath: defaultHermesAgentRoot).appendingPathComponent("venv/bin/hermes").path
        if FileManager.default.isExecutableFile(atPath: venvExecutable) { return venvExecutable }
        if FileManager.default.isExecutableFile(atPath: "/opt/homebrew/bin/hermes") { return "/opt/homebrew/bin/hermes" }
        return venvExecutable
    }

    static var defaultPythonExecutable: String {
        let venvPython = URL(fileURLWithPath: defaultHermesAgentRoot).appendingPathComponent("venv/bin/python3").path
        if FileManager.default.isExecutableFile(atPath: venvPython) { return venvPython }
        if FileManager.default.isExecutableFile(atPath: "/opt/homebrew/bin/python3") { return "/opt/homebrew/bin/python3" }
        return "/usr/bin/python3"
    }

    private static func existingDirectory(_ value: String?) -> String? {
        guard let value else { return nil }
        let expanded = NSString(string: value.trimmingCharacters(in: .whitespacesAndNewlines)).expandingTildeInPath
        var isDirectory: ObjCBool = false
        guard !expanded.isEmpty, FileManager.default.fileExists(atPath: expanded, isDirectory: &isDirectory), isDirectory.boolValue else { return nil }
        return expanded
    }
}

enum HermesDebugLogBuffer {
    static func appending(_ existing: String, block: String, maxBytes: Int = 200_000) -> String {
        let sanitized = redact(block)
        let combined = existing.isEmpty ? sanitized : existing + "\n\n" + sanitized
        guard combined.utf8.count > maxBytes else { return combined }
        var suffix = combined.suffix(maxBytes)
        if let firstNewline = suffix.firstIndex(of: "\n") { suffix = suffix[suffix.index(after: firstNewline)...] }
        return "[Earlier debug output truncated]\n" + String(suffix)
    }

    static func redact(_ text: String) -> String {
        var result = text
        let replacements: [(String, String)] = [
            (#"(?i)(authorization\s*[:=]\s*bearer\s+)[^\s\"']+"#, "$1[REDACTED]"),
            (#"(?i)(api[_-]?key\s*[:=]\s*)[^\s\"']+"#, "$1[REDACTED]"),
            (#"(?i)(x-hermes-session-token\s*[:=]\s*)[^\s\"']+"#, "$1[REDACTED]"),
            (#"data:[^\s\"']+;base64,[A-Za-z0-9+/=]{8,}"#, "[data URL redacted]")
        ]
        for (pattern, replacement) in replacements {
            result = result.replacingOccurrences(of: pattern, with: replacement, options: [.regularExpression])
        }
        return result
    }
}

enum HermesYAMLScalar {
    static func quoted(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
        return "\"\(escaped)\""
    }

    static func value(from line: String, key: String) -> String? {
        let escapedKey = NSRegularExpression.escapedPattern(for: key)
        let pattern = #"^\s*"# + escapedKey + #":\s*(?:(?:"((?:\\.|[^"\\])*)")|(?:'([^']*)')|([^#\n]*))"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) else { return nil }
        for rangeIndex in 1..<match.numberOfRanges {
            let range = match.range(at: rangeIndex)
            guard range.location != NSNotFound, let swiftRange = Range(range, in: line) else { continue }
            let raw = String(line[swiftRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            if rangeIndex == 1 { return unescapeDoubleQuoted(raw) }
            return raw
        }
        return nil
    }

    private static func unescapeDoubleQuoted(_ value: String) -> String {
        let json = "\"" + value.replacingOccurrences(of: "\"", with: "\\\"") + "\""
        if let data = json.data(using: .utf8), let decoded = try? JSONDecoder().decode(String.self, from: data) { return decoded }
        return value
    }
}

enum HermesProcessRunner {
    static func run(executable: String, arguments: [String], environment: [String: String]? = nil, currentDirectory: String? = nil, timeout: TimeInterval? = nil) throws -> HermesProcessResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        if let currentDirectory { process.currentDirectoryURL = URL(fileURLWithPath: currentDirectory) }
        if let environment { process.environment = environment }

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        let lock = NSLock()
        var outputData = Data()
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            lock.lock()
            outputData.append(data)
            lock.unlock()
        }

        let semaphore = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in semaphore.signal() }
        try process.run()

        var timedOut = false
        if let timeout, timeout > 0, semaphore.wait(timeout: .now() + timeout) == .timedOut {
            timedOut = true
            process.terminate()
            if semaphore.wait(timeout: .now() + 3) == .timedOut {
                kill(process.processIdentifier, SIGKILL)
                semaphore.wait()
            }
        } else if timeout == nil {
            semaphore.wait()
        }

        pipe.fileHandleForReading.readabilityHandler = nil
        let remainder = pipe.fileHandleForReading.readDataToEndOfFile()
        lock.lock()
        outputData.append(remainder)
        let text = String(data: outputData, encoding: .utf8) ?? ""
        lock.unlock()
        return HermesProcessResult(exitCode: process.terminationStatus, output: text, timedOut: timedOut)
    }
}
