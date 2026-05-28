//
//  HermesSecurityUtilities.swift
//  HermesMacOS
//

import CryptoKit
import Darwin
import Foundation
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

    var errorDescription: String? {
        switch self {
        case .insecureTransport(let host):
            return String(localized: "Remote HTTP is blocked for sensitive Hermes traffic to \(host). Use HTTPS or localhost.")
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

enum HermesAPIKeychain {
    private static let service = "HermesMacOS.APIKeys"
    private static let account = "default"

    static func loadAPIKey() -> String {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data, let key = String(data: data, encoding: .utf8) else { return "" }
        return key
    }

    static func saveAPIKey(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        SecItemDelete(baseQuery() as CFDictionary)
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else { return }
        var query = baseQuery()
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        SecItemAdd(query as CFDictionary, nil)
    }

    private static func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

enum HermesPinnedCertificateTrust {
    private static let defaultsPrefix = "hermes.macOS.pinnedServerCertificateSHA256."

    static func handle(trust: SecTrust, host: String, allowSelfSignedCertificates: Bool) -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        guard allowSelfSignedCertificates else { return (.performDefaultHandling, nil) }
        var trustError: CFError?
        if SecTrustEvaluateWithError(trust, &trustError) { return (.performDefaultHandling, nil) }
        guard let fingerprint = leafCertificateFingerprint(trust: trust) else { return (.cancelAuthenticationChallenge, nil) }
        let key = defaultsPrefix + normalizedHost(host)
        let defaults = UserDefaults.standard
        if let pinned = defaults.string(forKey: key), !pinned.isEmpty {
            guard pinned == fingerprint else { return (.cancelAuthenticationChallenge, nil) }
            return (.useCredential, URLCredential(trust: trust))
        }
        defaults.set(fingerprint, forKey: key)
        return (.useCredential, URLCredential(trust: trust))
    }

    private static func normalizedHost(_ host: String) -> String {
        host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func leafCertificateFingerprint(trust: SecTrust) -> String? {
        if let chain = SecTrustCopyCertificateChain(trust) as? [SecCertificate], let certificate = chain.first {
            let data = SecCertificateCopyData(certificate) as Data
            return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        }
        return nil
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
