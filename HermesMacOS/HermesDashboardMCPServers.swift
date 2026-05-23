//
//  HermesDashboardMCPServers.swift
//  HermesMacOS
//

import Foundation

struct HermesDashboardMCPServer: Identifiable, Equatable {
    let name: String
    let command: String?
    let args: [String]
    let url: String?
    let disabled: Bool

    var id: String { name }
    var transportLabel: String {
        if let url, !url.isEmpty { return "HTTP" }
        if let command, !command.isEmpty { return "Command" }
        return "Configured"
    }
    var primaryDetail: String {
        if let url, !url.isEmpty { return url }
        if let command, !command.isEmpty {
            let joinedArgs = args.joined(separator: " ")
            return joinedArgs.isEmpty ? command : "\(command) \(joinedArgs)"
        }
        return "No command or URL configured"
    }
    var statusLabel: String { disabled ? "Disabled" : "Enabled" }
}

@Observable
final class HermesDashboardMCPServersStore {
    var servers: [HermesDashboardMCPServer] = []
    var isLoading = false
    var lastErrorMessage = ""

    private var activeTask: Task<Void, Never>?
    private var cachedTokenByBaseURL: [String: String] = [:]

    func refresh(dashboardBaseURL: String, apiSettings: HermesAPISettings) {
        activeTask?.cancel()
        activeTask = Task { await loadServers(dashboardBaseURL: dashboardBaseURL, apiSettings: apiSettings) }
    }

    func deleteServer(_ server: HermesDashboardMCPServer, dashboardBaseURL: String, apiSettings: HermesAPISettings) {
        activeTask?.cancel()
        activeTask = Task { await removeServer(server, dashboardBaseURL: dashboardBaseURL, apiSettings: apiSettings) }
    }

    private func loadServers(dashboardBaseURL: String, apiSettings: HermesAPISettings) async {
        isLoading = true
        lastErrorMessage = ""
        defer { isLoading = false }

        do {
            let baseURL = try resolvedDashboardBaseURL(from: dashboardBaseURL, apiBaseURL: apiSettings.baseURL)
            let token = try await dashboardSessionToken(baseURL: baseURL, apiSettings: apiSettings)
            let rawConfig = try await fetchRawConfig(baseURL: baseURL, token: token, apiSettings: apiSettings)
            servers = HermesMCPServersYAML.parseServers(from: rawConfig.yaml).sorted { lhs, rhs in
                lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    private func removeServer(_ server: HermesDashboardMCPServer, dashboardBaseURL: String, apiSettings: HermesAPISettings) async {
        isLoading = true
        lastErrorMessage = ""
        defer { isLoading = false }

        do {
            let baseURL = try resolvedDashboardBaseURL(from: dashboardBaseURL, apiBaseURL: apiSettings.baseURL)
            let token = try await dashboardSessionToken(baseURL: baseURL, apiSettings: apiSettings)
            let rawConfig = try await fetchRawConfig(baseURL: baseURL, token: token, apiSettings: apiSettings)
            let updatedYAML = try HermesMCPServersYAML.removingServer(named: server.name, from: rawConfig.yaml)
            try await updateRawConfig(updatedYAML, baseURL: baseURL, token: token, apiSettings: apiSettings)
            await loadServers(dashboardBaseURL: dashboardBaseURL, apiSettings: apiSettings)
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    private func dashboardSessionToken(baseURL: URL, apiSettings: HermesAPISettings) async throws -> String {
        let cacheKey = baseURL.absoluteString
        if let cached = cachedTokenByBaseURL[cacheKey], !cached.isEmpty { return cached }

        let session = HermesNetworkSessionFactory.session(for: apiSettings)
        let (data, response) = try await session.data(from: baseURL)
        try HermesNetworkSessionFactory.validate(response: response)
        let html = String(decoding: data, as: UTF8.self)
        let pattern = #"window\.__HERMES_SESSION_TOKEN__=\"([^\"]+)\""#
        let regex = try NSRegularExpression(pattern: pattern)
        let nsRange = NSRange(html.startIndex..<html.endIndex, in: html)
        guard let match = regex.firstMatch(in: html, range: nsRange), let tokenRange = Range(match.range(at: 1), in: html) else {
            throw HermesDashboardMCPServersError.missingDashboardSessionToken
        }
        let token = String(html[tokenRange])
        cachedTokenByBaseURL[cacheKey] = token
        return token
    }

    private func fetchRawConfig(baseURL: URL, token: String, apiSettings: HermesAPISettings) async throws -> HermesDashboardMCPRawConfigResponse {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/config/raw"))
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(token, forHTTPHeaderField: "X-Hermes-Session-Token")
        let session = HermesNetworkSessionFactory.session(for: apiSettings)
        let (data, response) = try await session.data(for: request)
        try HermesNetworkSessionFactory.validate(response: response)
        return try JSONDecoder().decode(HermesDashboardMCPRawConfigResponse.self, from: data)
    }

    private func updateRawConfig(_ yaml: String, baseURL: URL, token: String, apiSettings: HermesAPISettings) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/config/raw"))
        request.httpMethod = "PUT"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(token, forHTTPHeaderField: "X-Hermes-Session-Token")
        request.httpBody = try JSONEncoder().encode(HermesDashboardMCPRawConfigUpdate(yamlText: yaml))
        let session = HermesNetworkSessionFactory.session(for: apiSettings)
        let (_, response) = try await session.data(for: request)
        try HermesNetworkSessionFactory.validate(response: response)
    }

    private func resolvedDashboardBaseURL(from dashboardBaseURL: String, apiBaseURL: String) throws -> URL {
        let explicit = dashboardBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !explicit.isEmpty, let url = normalizedBaseURL(from: explicit) { return url }
        var fallback = apiBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if fallback.hasSuffix("/v1") { fallback.removeLast(3) }
        guard let url = normalizedBaseURL(from: fallback) else { throw HermesDashboardMCPServersError.invalidDashboardURL }
        return url
    }

    private func normalizedBaseURL(from value: String) -> URL? {
        var trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        while trimmed.hasSuffix("/") { trimmed.removeLast() }
        return URL(string: trimmed)
    }
}

private struct HermesDashboardMCPRawConfigResponse: Decodable {
    let yaml: String
}

private struct HermesDashboardMCPRawConfigUpdate: Encodable {
    let yamlText: String

    enum CodingKeys: String, CodingKey {
        case yamlText = "yaml_text"
    }
}

enum HermesDashboardMCPServersError: LocalizedError {
    case invalidDashboardURL
    case missingDashboardSessionToken
    case serverNotFound(String)

    var errorDescription: String? {
        switch self {
        case .invalidDashboardURL:
            return "The Hermes dashboard URL is invalid."
        case .missingDashboardSessionToken:
            return "The dashboard session token was not found in the dashboard HTML."
        case .serverNotFound(let name):
            return "MCP server \"\(name)\" was not found in the dashboard config."
        }
    }
}

private enum HermesMCPServersYAML {
    static func parseServers(from yaml: String) -> [HermesDashboardMCPServer] {
        let lines = yaml.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard let start = lines.firstIndex(where: { isTopLevelKey($0, key: "mcp_servers") }) else { return [] }
        let end = nextTopLevelIndex(in: lines, after: start) ?? lines.count
        guard start + 1 < end else { return [] }
        var servers: [HermesDashboardMCPServer] = []
        var index = start + 1
        while index < end {
            let line = lines[index]
            guard indentation(of: line) == 2, let name = mappingKey(from: line) else {
                index += 1
                continue
            }
            let blockStart = index
            var blockEnd = index + 1
            while blockEnd < end {
                let candidate = lines[blockEnd]
                if !candidate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                   indentation(of: candidate) == 2,
                   mappingKey(from: candidate) != nil {
                    break
                }
                blockEnd += 1
            }
            let block = Array(lines[blockStart..<blockEnd])
            servers.append(server(named: name, block: block))
            index = blockEnd
        }
        return servers
    }

    static func removingServer(named name: String, from yaml: String) throws -> String {
        var lines = yaml.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let hadTrailingNewline = yaml.hasSuffix("\n")
        guard let start = lines.firstIndex(where: { isTopLevelKey($0, key: "mcp_servers") }) else {
            throw HermesDashboardMCPServersError.serverNotFound(name)
        }
        let end = nextTopLevelIndex(in: lines, after: start) ?? lines.count
        var index = start + 1
        while index < end {
            guard indentation(of: lines[index]) == 2, let serverName = mappingKey(from: lines[index]) else {
                index += 1
                continue
            }
            var blockEnd = index + 1
            while blockEnd < end {
                let candidate = lines[blockEnd]
                if !candidate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                   indentation(of: candidate) == 2,
                   mappingKey(from: candidate) != nil {
                    break
                }
                blockEnd += 1
            }
            if serverName == name {
                lines.removeSubrange(index..<blockEnd)
                let newEnd = end - (blockEnd - index)
                let hasRemainingServer = lines[(start + 1)..<newEnd].contains { indentation(of: $0) == 2 && mappingKey(from: $0) != nil }
                if !hasRemainingServer {
                    lines[start] = "mcp_servers: {}"
                }
                return joined(lines, trailingNewline: hadTrailingNewline)
            }
            index = blockEnd
        }
        throw HermesDashboardMCPServersError.serverNotFound(name)
    }

    private static func server(named name: String, block: [String]) -> HermesDashboardMCPServer {
        let command = scalarValue(for: "command", in: block)
        let url = scalarValue(for: "url", in: block)
        let disabled = boolValue(for: "disabled", in: block) == true || boolValue(for: "enabled", in: block) == false
        let args = arrayValue(for: "args", in: block)
        return HermesDashboardMCPServer(name: name, command: command, args: args, url: url, disabled: disabled)
    }

    private static func scalarValue(for key: String, in block: [String]) -> String? {
        for line in block {
            guard indentation(of: line) == 4 else { continue }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("\(key):") else { continue }
            let raw = String(trimmed.dropFirst(key.count + 1)).trimmingCharacters(in: .whitespacesAndNewlines)
            return unquoted(raw)
        }
        return nil
    }

    private static func boolValue(for key: String, in block: [String]) -> Bool? {
        guard let value = scalarValue(for: key, in: block)?.lowercased() else { return nil }
        if ["true", "yes", "on", "1"].contains(value) { return true }
        if ["false", "no", "off", "0"].contains(value) { return false }
        return nil
    }

    private static func arrayValue(for key: String, in block: [String]) -> [String] {
        for (offset, line) in block.enumerated() {
            guard indentation(of: line) == 4 else { continue }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("\(key):") else { continue }
            let raw = String(trimmed.dropFirst(key.count + 1)).trimmingCharacters(in: .whitespacesAndNewlines)
            if raw.hasPrefix("["), raw.hasSuffix("]") {
                return raw.dropFirst().dropLast().split(separator: ",").map { unquoted(String($0).trimmingCharacters(in: .whitespacesAndNewlines)) }.filter { !$0.isEmpty }
            }
            var values: [String] = []
            var index = offset + 1
            while index < block.count {
                let candidate = block[index]
                let trimmedCandidate = candidate.trimmingCharacters(in: .whitespaces)
                if indentation(of: candidate) <= 4 { break }
                if trimmedCandidate.hasPrefix("-") {
                    values.append(unquoted(String(trimmedCandidate.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)))
                }
                index += 1
            }
            return values
        }
        return []
    }

    private static func isTopLevelKey(_ line: String, key: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return indentation(of: line) == 0 && (trimmed == "\(key):" || trimmed.hasPrefix("\(key):"))
    }

    private static func nextTopLevelIndex(in lines: [String], after start: Int) -> Int? {
        guard start + 1 < lines.count else { return nil }
        return lines[(start + 1)...].firstIndex { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            return !trimmed.isEmpty && !trimmed.hasPrefix("#") && indentation(of: line) == 0 && trimmed.contains(":")
        }
    }

    private static func mappingKey(from line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasSuffix(":"), !trimmed.hasPrefix("-") else { return nil }
        return unquoted(String(trimmed.dropLast()).trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private static func indentation(of line: String) -> Int {
        line.prefix { $0 == " " }.count
    }

    private static func unquoted(_ value: String) -> String {
        var trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if (trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"")) || (trimmed.hasPrefix("'") && trimmed.hasSuffix("'")) {
            trimmed.removeFirst()
            trimmed.removeLast()
        }
        return trimmed
    }

    private static func joined(_ lines: [String], trailingNewline: Bool) -> String {
        let text = lines.joined(separator: "\n")
        return trailingNewline ? text + "\n" : text
    }
}
