//
//  HermesDashboardToolsets.swift
//  HermesMacOS
//

import Foundation

struct HermesDashboardToolset: Codable, Identifiable, Equatable {
    let name: String
    let label: String
    let description: String
    let enabled: Bool
    let available: Bool?
    let configured: Bool?
    let tools: [String]?

    var id: String { name }
    var statusLabel: String { enabled ? "Enabled" : "Disabled" }
    var displayLabel: String {
        let scalars = label.unicodeScalars.drop { scalar in
            CharacterSet.whitespacesAndNewlines.contains(scalar) || scalar.properties.isEmojiPresentation
        }
        let trimmed = String(String.UnicodeScalarView(scalars)).trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? name : trimmed
    }
}

@Observable
final class HermesDashboardToolsetsStore {
    var toolsets: [HermesDashboardToolset] = []
    var isLoading = false
    var lastErrorMessage = ""

    private var activeTask: Task<Void, Never>?
    private var cachedTokenByBaseURL: [String: String] = [:]

    func refresh(dashboardBaseURL: String, apiSettings: HermesAPISettings) {
        activeTask?.cancel()
        activeTask = Task { await loadToolsets(dashboardBaseURL: dashboardBaseURL, apiSettings: apiSettings) }
    }

    func setToolsetEnabled(_ toolset: HermesDashboardToolset, enabled: Bool, dashboardBaseURL: String, apiSettings: HermesAPISettings) {
        activeTask?.cancel()
        activeTask = Task { await toggleToolset(toolset, enabled: enabled, dashboardBaseURL: dashboardBaseURL, apiSettings: apiSettings) }
    }

    private func loadToolsets(dashboardBaseURL: String, apiSettings: HermesAPISettings) async {
        isLoading = true
        lastErrorMessage = ""
        defer { isLoading = false }

        do {
            let baseURL = try resolvedDashboardBaseURL(from: dashboardBaseURL, apiBaseURL: apiSettings.baseURL)
            let token = try await dashboardSessionToken(baseURL: baseURL, apiSettings: apiSettings)
            let fetched = try await fetchToolsets(baseURL: baseURL, token: token, apiSettings: apiSettings)
            toolsets = fetched.sorted { lhs, rhs in
                lhs.displayLabel.localizedCaseInsensitiveCompare(rhs.displayLabel) == .orderedAscending
            }
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    private func toggleToolset(_ toolset: HermesDashboardToolset, enabled: Bool, dashboardBaseURL: String, apiSettings: HermesAPISettings) async {
        isLoading = true
        lastErrorMessage = ""
        defer { isLoading = false }

        do {
            let baseURL = try resolvedDashboardBaseURL(from: dashboardBaseURL, apiBaseURL: apiSettings.baseURL)
            let token = try await dashboardSessionToken(baseURL: baseURL, apiSettings: apiSettings)
            let rawConfig = try await fetchRawConfig(baseURL: baseURL, token: token, apiSettings: apiSettings)
            var enabledNames = Set(toolsets.filter(\.enabled).map(\.name))
            if enabled {
                enabledNames.insert(toolset.name)
            } else {
                enabledNames.remove(toolset.name)
            }
            let allConfigurableToolsets = Set(toolsets.map(\.name))
            let updatedYAML = HermesToolsetsYAMLUpdater.updatedYAML(
                rawConfig.yaml,
                enabledToolsets: enabledNames,
                allConfigurableToolsets: allConfigurableToolsets
            )
            try await updateRawConfig(updatedYAML, baseURL: baseURL, token: token, apiSettings: apiSettings)
            await loadToolsets(dashboardBaseURL: dashboardBaseURL, apiSettings: apiSettings)
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
            throw HermesDashboardToolsetsError.missingDashboardSessionToken
        }
        let token = String(html[tokenRange])
        cachedTokenByBaseURL[cacheKey] = token
        return token
    }

    private func fetchToolsets(baseURL: URL, token: String, apiSettings: HermesAPISettings) async throws -> [HermesDashboardToolset] {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/tools/toolsets"))
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(token, forHTTPHeaderField: "X-Hermes-Session-Token")
        let session = HermesNetworkSessionFactory.session(for: apiSettings)
        let (data, response) = try await session.data(for: request)
        try HermesNetworkSessionFactory.validate(response: response)
        return try JSONDecoder().decode([HermesDashboardToolset].self, from: data)
    }

    private func fetchRawConfig(baseURL: URL, token: String, apiSettings: HermesAPISettings) async throws -> HermesDashboardRawConfigResponse {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/config/raw"))
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(token, forHTTPHeaderField: "X-Hermes-Session-Token")
        let session = HermesNetworkSessionFactory.session(for: apiSettings)
        let (data, response) = try await session.data(for: request)
        try HermesNetworkSessionFactory.validate(response: response)
        return try JSONDecoder().decode(HermesDashboardRawConfigResponse.self, from: data)
    }

    private func updateRawConfig(_ yaml: String, baseURL: URL, token: String, apiSettings: HermesAPISettings) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/config/raw"))
        request.httpMethod = "PUT"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(token, forHTTPHeaderField: "X-Hermes-Session-Token")
        request.httpBody = try JSONEncoder().encode(HermesDashboardRawConfigUpdate(yamlText: yaml))
        let session = HermesNetworkSessionFactory.session(for: apiSettings)
        let (_, response) = try await session.data(for: request)
        try HermesNetworkSessionFactory.validate(response: response)
    }

    private func resolvedDashboardBaseURL(from dashboardBaseURL: String, apiBaseURL: String) throws -> URL {
        let explicit = dashboardBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !explicit.isEmpty, let url = normalizedBaseURL(from: explicit) { return url }
        var fallback = apiBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if fallback.hasSuffix("/v1") { fallback.removeLast(3) }
        guard let url = normalizedBaseURL(from: fallback) else { throw HermesDashboardToolsetsError.invalidDashboardURL }
        return url
    }

    private func normalizedBaseURL(from value: String) -> URL? {
        var trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        while trimmed.hasSuffix("/") { trimmed.removeLast() }
        return URL(string: trimmed)
    }
}

private struct HermesDashboardRawConfigResponse: Decodable {
    let yaml: String
}

private struct HermesDashboardRawConfigUpdate: Encodable {
    let yamlText: String

    enum CodingKeys: String, CodingKey {
        case yamlText = "yaml_text"
    }
}

enum HermesDashboardToolsetsError: LocalizedError {
    case invalidDashboardURL
    case missingDashboardSessionToken

    var errorDescription: String? {
        switch self {
        case .invalidDashboardURL:
            return "The Hermes dashboard URL is invalid."
        case .missingDashboardSessionToken:
            return "The dashboard session token was not found in the dashboard HTML."
        }
    }
}

private enum HermesToolsetsYAMLUpdater {
    static func updatedYAML(_ yaml: String, enabledToolsets: Set<String>, allConfigurableToolsets: Set<String>) -> String {
        var lines = yaml.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let hadTrailingNewline = yaml.hasSuffix("\n")
        let replacementEntries = mergedToolsetEntries(
            existingEntries: cliToolsetEntries(in: lines),
            enabledToolsets: enabledToolsets,
            allConfigurableToolsets: allConfigurableToolsets
        )
        let cliBlock = cliBlockLines(entries: replacementEntries)

        guard let platformStart = lines.firstIndex(where: { isTopLevelKey($0, key: "platform_toolsets") }) else {
            if !lines.isEmpty, lines.last?.isEmpty == false { lines.append("") }
            lines.append("platform_toolsets:")
            lines.append(contentsOf: cliBlock)
            return joined(lines, trailingNewline: hadTrailingNewline || yaml.isEmpty)
        }

        let platformEnd = nextTopLevelIndex(in: lines, after: platformStart) ?? lines.count
        if let cliRange = cliRange(in: lines, platformStart: platformStart, platformEnd: platformEnd) {
            lines.replaceSubrange(cliRange, with: cliBlock)
        } else {
            lines.insert(contentsOf: cliBlock, at: platformEnd)
        }
        return joined(lines, trailingNewline: hadTrailingNewline)
    }

    private static func mergedToolsetEntries(existingEntries: [String], enabledToolsets: Set<String>, allConfigurableToolsets: Set<String>) -> [String] {
        let preserved = existingEntries.filter { entry in
            !allConfigurableToolsets.contains(entry) && !entry.hasPrefix("hermes-") && entry != "no_mcp"
        }
        return Array(Set(preserved).union(enabledToolsets)).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private static func cliBlockLines(entries: [String]) -> [String] {
        if entries.isEmpty { return ["  cli: []"] }
        return ["  cli:"] + entries.map { "    - \($0)" }
    }

    private static func cliToolsetEntries(in lines: [String]) -> [String] {
        guard let platformStart = lines.firstIndex(where: { isTopLevelKey($0, key: "platform_toolsets") }) else { return [] }
        let platformEnd = nextTopLevelIndex(in: lines, after: platformStart) ?? lines.count
        guard let range = cliRange(in: lines, platformStart: platformStart, platformEnd: platformEnd) else { return [] }
        return parseCLIEntries(from: Array(lines[range]))
    }

    private static func cliRange(in lines: [String], platformStart: Int, platformEnd: Int) -> Range<Int>? {
        guard platformStart + 1 < platformEnd else { return nil }
        for index in (platformStart + 1)..<platformEnd {
            if isIndentedKey(lines[index], key: "cli", indent: 2) {
                var end = index + 1
                while end < platformEnd {
                    let line = lines[end]
                    if line.trimmingCharacters(in: .whitespaces).isEmpty || line.trimmingCharacters(in: .whitespaces).hasPrefix("#") {
                        end += 1
                        continue
                    }
                    if indentation(of: line) <= 2 { break }
                    end += 1
                }
                return index..<end
            }
        }
        return nil
    }

    private static func parseCLIEntries(from lines: [String]) -> [String] {
        guard let first = lines.first else { return [] }
        let trimmedFirst = first.trimmingCharacters(in: .whitespaces)
        if let bracketStart = trimmedFirst.firstIndex(of: "["), let bracketEnd = trimmedFirst.lastIndex(of: "]"), bracketStart < bracketEnd {
            let contents = trimmedFirst[trimmedFirst.index(after: bracketStart)..<bracketEnd]
            return contents.split(separator: ",").map { cleanYAMLScalar(String($0)) }.filter { !$0.isEmpty }
        }
        return lines.dropFirst().compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("- ") else { return nil }
            return cleanYAMLScalar(String(trimmed.dropFirst(2)))
        }
    }

    private static func cleanYAMLScalar(_ value: String) -> String {
        var trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if let commentIndex = trimmed.firstIndex(of: "#") {
            trimmed = String(trimmed[..<commentIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if trimmed.count >= 2,
           let first = trimmed.first,
           let last = trimmed.last,
           (first == "\"" && last == "\"") || (first == "'" && last == "'") {
            trimmed = String(trimmed.dropFirst().dropLast())
        }
        return trimmed
    }

    private static func isTopLevelKey(_ line: String, key: String) -> Bool {
        line.hasPrefix("\(key):")
    }

    private static func isIndentedKey(_ line: String, key: String, indent: Int) -> Bool {
        indentation(of: line) == indent && line.trimmingCharacters(in: .whitespaces).hasPrefix("\(key):")
    }

    private static func indentation(of line: String) -> Int {
        line.prefix { $0 == " " }.count
    }

    private static func nextTopLevelIndex(in lines: [String], after index: Int) -> Int? {
        guard index + 1 < lines.count else { return nil }
        for candidate in (index + 1)..<lines.count {
            let line = lines[candidate]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            if indentation(of: line) == 0 && trimmed.contains(":") { return candidate }
        }
        return nil
    }

    private static func joined(_ lines: [String], trailingNewline: Bool) -> String {
        let body = lines.joined(separator: "\n")
        return trailingNewline ? body + "\n" : body
    }
}
