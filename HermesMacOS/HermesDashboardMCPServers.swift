//
//  HermesDashboardMCPServers.swift
//  HermesMacOS
//

import Foundation

struct HermesDashboardMCPTool: Identifiable, Equatable, Codable {
    let name: String
    let description: String

    var id: String { name }
}

struct HermesDashboardMCPServer: Identifiable, Equatable {
    var name: String
    var command: String?
    var args: [String]
    var url: String?
    var disabled: Bool
    var auth: String?
    var env: [String: String]
    var headers: [String: String]
    var toolsInclude: [String]?
    var toolsExclude: [String]?

    var id: String { name }
    var transportLabel: String {
        if let url, !url.isEmpty { return "HTTP" }
        if let command, !command.isEmpty { return "stdio" }
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
    var configuredToolRuleLabel: String {
        if let toolsInclude { return "\(toolsInclude.count) selected" }
        if let toolsExclude, !toolsExclude.isEmpty { return "\(toolsExclude.count) excluded" }
        return "All discovered tools"
    }
    var authLabel: String {
        if auth?.isEmpty == false { return auth! }
        if !headers.isEmpty { return "headers" }
        return "none"
    }

    func isToolEnabled(_ toolName: String) -> Bool {
        if let include = toolsInclude { return include.contains(toolName) }
        if let exclude = toolsExclude { return !exclude.contains(toolName) }
        return true
    }
}

struct HermesMCPServerDraft {
    enum TransportKind: String {
        case stdio
        case http
    }

    var name: String
    var transportKind: TransportKind
    var command: String
    var args: [String]
    var url: String
    var env: [String: String]
    var headers: [String: String]
    var auth: String?
}

struct HermesMCPServerProbeState: Equatable {
    enum Availability: String {
        case unknown
        case testing
        case available
        case unavailable
    }

    var availability: Availability = .unknown
    var tools: [HermesDashboardMCPTool] = []
    var errorMessage = ""
    var output = ""
    var updatedAt: Date?

    var toolCountLabel: String {
        switch availability {
        case .testing: return "Testing…"
        case .available: return "\(tools.count) tool\(tools.count == 1 ? "" : "s")"
        case .unavailable: return "Unavailable"
        case .unknown: return tools.isEmpty ? "Not tested" : "\(tools.count) tool\(tools.count == 1 ? "" : "s")"
        }
    }

    var statusLabel: String {
        switch availability {
        case .testing: return "Testing"
        case .available: return "Available"
        case .unavailable: return "Unavailable"
        case .unknown: return "Unknown"
        }
    }
}

@Observable
final class HermesDashboardMCPServersStore {
    var servers: [HermesDashboardMCPServer] = []
    var probeStates: [String: HermesMCPServerProbeState] = [:]
    var recentErrorsByServer: [String: [String]] = [:]
    var isLoading = false
    var isTesting = false
    var lastErrorMessage = ""
    var lastActionMessage = ""

    private var activeTask: Task<Void, Never>?
    private var probeTask: Task<Void, Never>?
    private var cachedTokenByBaseURL: [String: String] = [:]
    private let pythonExecutable = "/Users/laurent/.hermes/hermes-agent/venv/bin/python3"
    private let hermesAgentRoot = "/Users/laurent/.hermes/hermes-agent"

    func refresh(dashboardBaseURL: String, apiSettings: HermesAPISettings) {
        activeTask?.cancel()
        activeTask = Task { await loadServers(dashboardBaseURL: dashboardBaseURL, apiSettings: apiSettings) }
    }

    func deleteServer(_ server: HermesDashboardMCPServer, dashboardBaseURL: String, apiSettings: HermesAPISettings) {
        activeTask?.cancel()
        activeTask = Task { await removeServer(server, dashboardBaseURL: dashboardBaseURL, apiSettings: apiSettings) }
    }

    func upsertServer(_ draft: HermesMCPServerDraft, dashboardBaseURL: String, apiSettings: HermesAPISettings) {
        activeTask?.cancel()
        activeTask = Task { await saveServer(draft, dashboardBaseURL: dashboardBaseURL, apiSettings: apiSettings) }
    }

    func setServerEnabled(_ server: HermesDashboardMCPServer, enabled: Bool, dashboardBaseURL: String, apiSettings: HermesAPISettings) {
        var updated = server
        updated.disabled = !enabled
        activeTask?.cancel()
        activeTask = Task { await updateServer(updated, dashboardBaseURL: dashboardBaseURL, apiSettings: apiSettings, successMessage: "\(enabled ? "Enabled" : "Disabled") \(server.name). Reload MCP for active sessions to pick up the change.") }
    }

    func setToolEnabled(_ server: HermesDashboardMCPServer, tool: HermesDashboardMCPTool, enabled: Bool, allTools: [HermesDashboardMCPTool], dashboardBaseURL: String, apiSettings: HermesAPISettings) {
        let allNames = allTools.map(\.name)
        guard allNames.contains(tool.name) else { return }
        let currentSelected: Set<String>
        if let include = server.toolsInclude {
            currentSelected = Set(include)
        } else if let exclude = server.toolsExclude {
            currentSelected = Set(allNames).subtracting(Set(exclude))
        } else {
            currentSelected = Set(allNames)
        }
        var selected = currentSelected
        if enabled { selected.insert(tool.name) } else { selected.remove(tool.name) }

        var updated = server
        let sortedSelected = allNames.filter { selected.contains($0) }
        if sortedSelected.count == allNames.count {
            updated.toolsInclude = nil
            updated.toolsExclude = nil
        } else if sortedSelected.isEmpty {
            updated.toolsInclude = nil
            updated.toolsExclude = allNames
        } else {
            updated.toolsInclude = sortedSelected
            updated.toolsExclude = nil
        }
        activeTask?.cancel()
        activeTask = Task { await updateServer(updated, dashboardBaseURL: dashboardBaseURL, apiSettings: apiSettings, successMessage: "Updated tool filter for \(server.name). Reload MCP for active sessions to pick up the change.") }
    }

    func testConnection(_ server: HermesDashboardMCPServer, hermesHome: String) {
        probeTask?.cancel()
        probeTask = Task { await probeServers([server.name], hermesHome: hermesHome, reloadFirst: false) }
    }

    func testAllConnections(hermesHome: String) {
        let names = servers.map(\.name)
        guard !names.isEmpty else { return }
        probeTask?.cancel()
        probeTask = Task { await probeServers(names, hermesHome: hermesHome, reloadFirst: false) }
    }

    func reloadMCP(hermesHome: String) {
        let names = servers.map(\.name)
        probeTask?.cancel()
        probeTask = Task { await probeServers(names, hermesHome: hermesHome, reloadFirst: true) }
    }

    func refreshRecentErrors(hermesHome: String) {
        recentErrorsByServer = Self.recentErrors(for: servers.map(\.name), hermesHome: hermesHome)
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
            let serverNames = Set(servers.map(\.name))
            probeStates = probeStates.filter { serverNames.contains($0.key) }
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    private func saveServer(_ draft: HermesMCPServerDraft, dashboardBaseURL: String, apiSettings: HermesAPISettings) async {
        isLoading = true
        lastErrorMessage = ""
        lastActionMessage = ""
        defer { isLoading = false }

        do {
            let baseURL = try resolvedDashboardBaseURL(from: dashboardBaseURL, apiBaseURL: apiSettings.baseURL)
            let token = try await dashboardSessionToken(baseURL: baseURL, apiSettings: apiSettings)
            let rawConfig = try await fetchRawConfig(baseURL: baseURL, token: token, apiSettings: apiSettings)
            let server = HermesDashboardMCPServer(
                name: draft.name,
                command: draft.transportKind == .stdio ? draft.command : nil,
                args: draft.transportKind == .stdio ? draft.args : [],
                url: draft.transportKind == .http ? draft.url : nil,
                disabled: false,
                auth: draft.auth,
                env: draft.transportKind == .stdio ? draft.env : [:],
                headers: draft.transportKind == .http ? draft.headers : [:],
                toolsInclude: nil,
                toolsExclude: nil
            )
            let updatedYAML = HermesMCPServersYAML.upsertingServer(server, in: rawConfig.yaml)
            try await updateRawConfig(updatedYAML, baseURL: baseURL, token: token, apiSettings: apiSettings)
            lastActionMessage = "Saved \(draft.name) to dashboard config. Test the connection, then reload MCP for active sessions."
            await loadServers(dashboardBaseURL: dashboardBaseURL, apiSettings: apiSettings)
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    private func updateServer(_ server: HermesDashboardMCPServer, dashboardBaseURL: String, apiSettings: HermesAPISettings, successMessage: String) async {
        isLoading = true
        lastErrorMessage = ""
        lastActionMessage = ""
        defer { isLoading = false }

        do {
            let baseURL = try resolvedDashboardBaseURL(from: dashboardBaseURL, apiBaseURL: apiSettings.baseURL)
            let token = try await dashboardSessionToken(baseURL: baseURL, apiSettings: apiSettings)
            let rawConfig = try await fetchRawConfig(baseURL: baseURL, token: token, apiSettings: apiSettings)
            let updatedYAML = HermesMCPServersYAML.upsertingServer(server, in: rawConfig.yaml)
            try await updateRawConfig(updatedYAML, baseURL: baseURL, token: token, apiSettings: apiSettings)
            lastActionMessage = successMessage
            await loadServers(dashboardBaseURL: dashboardBaseURL, apiSettings: apiSettings)
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    private func removeServer(_ server: HermesDashboardMCPServer, dashboardBaseURL: String, apiSettings: HermesAPISettings) async {
        isLoading = true
        lastErrorMessage = ""
        lastActionMessage = ""
        defer { isLoading = false }

        do {
            let baseURL = try resolvedDashboardBaseURL(from: dashboardBaseURL, apiBaseURL: apiSettings.baseURL)
            let token = try await dashboardSessionToken(baseURL: baseURL, apiSettings: apiSettings)
            let rawConfig = try await fetchRawConfig(baseURL: baseURL, token: token, apiSettings: apiSettings)
            let updatedYAML = try HermesMCPServersYAML.removingServer(named: server.name, from: rawConfig.yaml)
            try await updateRawConfig(updatedYAML, baseURL: baseURL, token: token, apiSettings: apiSettings)
            lastActionMessage = "Deleted \(server.name). Reload MCP for active sessions to drop its tools."
            await loadServers(dashboardBaseURL: dashboardBaseURL, apiSettings: apiSettings)
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    private func probeServers(_ names: [String], hermesHome: String, reloadFirst: Bool) async {
        guard !names.isEmpty else { return }
        isTesting = true
        lastErrorMessage = ""
        lastActionMessage = reloadFirst ? "Reloading MCP discovery…" : "Testing MCP connection…"
        for name in names {
            var state = probeStates[name] ?? HermesMCPServerProbeState()
            state.availability = .testing
            state.errorMessage = ""
            state.updatedAt = Date()
            probeStates[name] = state
        }
        defer { isTesting = false }

        let result = await Task.detached(priority: .userInitiated) { [pythonExecutable, hermesAgentRoot] in
            Self.executeMCPProbe(names: names, hermesHome: hermesHome, pythonExecutable: pythonExecutable, workdir: hermesAgentRoot, reloadFirst: reloadFirst)
        }.value

        for item in result.results {
            var state = HermesMCPServerProbeState()
            state.availability = item.ok ? .available : .unavailable
            state.tools = item.tools ?? []
            state.errorMessage = item.error ?? ""
            state.output = item.output ?? ""
            state.updatedAt = Date()
            probeStates[item.name] = state
        }
        if let error = result.error, !error.isEmpty {
            lastErrorMessage = error
            lastActionMessage = ""
        } else {
            let available = result.results.filter(\.ok).count
            let totalTools = result.results.reduce(0) { $0 + ($1.tools?.count ?? 0) }
            lastActionMessage = reloadFirst ? "Reload probe finished: \(available)/\(result.results.count) available, \(totalTools) tools discovered." : "Connection tests finished: \(available)/\(result.results.count) available, \(totalTools) tools discovered."
        }
        refreshRecentErrors(hermesHome: hermesHome)
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

    private nonisolated static func executeMCPProbe(names: [String], hermesHome: String, pythonExecutable: String, workdir: String, reloadFirst: Bool) -> HermesMCPProbeBatchResult {
        let code = #"""
import json, os, sys, time, traceback
from hermes_cli.config import load_config
from hermes_cli.mcp_config import _probe_single_server

names = sys.argv[1:]
if not names:
    print(json.dumps({"results": []}))
    sys.exit(0)
try:
    if "--reload-first" in names:
        names.remove("--reload-first")
        try:
            from tools.mcp_tool import shutdown_mcp_servers, discover_mcp_tools
            shutdown_mcp_servers()
            discover_mcp_tools()
        except BaseException:
            pass
    cfg = load_config()
    servers = cfg.get("mcp_servers") or {}
    results = []
    for name in names:
        item = {"name": name, "ok": False, "tools": [], "error": "", "output": ""}
        server_cfg = servers.get(name)
        if not isinstance(server_cfg, dict):
            item["error"] = "Server is not present in config.yaml"
            results.append(item)
            continue
        start = time.monotonic()
        try:
            connect_timeout = float(server_cfg.get("connect_timeout", 30) or 30)
            tools = _probe_single_server(name, server_cfg, connect_timeout=connect_timeout)
            elapsed_ms = int((time.monotonic() - start) * 1000)
            item["ok"] = True
            item["tools"] = [{"name": t[0], "description": t[1] or ""} for t in tools]
            item["output"] = f"Connected in {elapsed_ms}ms; discovered {len(tools)} tool(s)."
        except BaseException as exc:
            elapsed_ms = int((time.monotonic() - start) * 1000)
            item["error"] = f"{exc}"
            item["output"] = f"Connection failed after {elapsed_ms}ms: {exc}"
        results.append(item)
    print(json.dumps({"results": results}, ensure_ascii=False))
except BaseException as exc:
    print(json.dumps({"error": str(exc), "results": []}, ensure_ascii=False))
    sys.exit(1)
"""#
        var arguments = ["-c", code]
        if reloadFirst { arguments.append("--reload-first") }
        arguments.append(contentsOf: names)
        let output = runProcess(executable: pythonExecutable, arguments: arguments, hermesHome: hermesHome, workdir: workdir, timeout: 90)
        guard let data = output.data(using: .utf8), let decoded = try? JSONDecoder().decode(HermesMCPProbeBatchResult.self, from: data) else {
            return HermesMCPProbeBatchResult(error: output.trimmingCharacters(in: .whitespacesAndNewlines), results: [])
        }
        return decoded
    }

    private nonisolated static func recentErrors(for serverNames: [String], hermesHome: String) -> [String: [String]] {
        guard !serverNames.isEmpty else { return [:] }
        let logPaths = [
            URL(fileURLWithPath: hermesHome).appendingPathComponent("logs/mcp-stderr.log"),
            URL(fileURLWithPath: hermesHome).appendingPathComponent("logs/errors.log"),
            URL(fileURLWithPath: hermesHome).appendingPathComponent("logs/agent.log")
        ]
        var lines: [String] = []
        for url in logPaths {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            lines.append(contentsOf: text.split(separator: "\n").suffix(500).map(String.init))
        }
        var result: [String: [String]] = [:]
        for name in serverNames {
            let matched = lines.filter { line in
                line.localizedCaseInsensitiveContains("mcp") && line.localizedCaseInsensitiveContains(name)
            }.suffix(5)
            result[name] = matched.map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        }
        return result
    }

    private nonisolated static func runProcess(executable: String, arguments: [String], hermesHome: String, workdir: String, timeout: TimeInterval) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.currentDirectoryURL = URL(fileURLWithPath: workdir)
        process.environment = normalizedSubprocessEnvironment(hermesHome: hermesHome)
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                if process.isRunning { process.terminate() }
            }
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return "{\"error\":\"\(error.localizedDescription)\",\"results\":[]}"
        }
    }

    private nonisolated static func normalizedSubprocessEnvironment(hermesHome: String) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        environment["HERMES_HOME"] = hermesHome
        environment["TERM"] = environment["TERM"] ?? "xterm-256color"
        environment["PATH"] = normalizedPATH(existing: environment["PATH"], hermesHome: hermesHome)
        return environment
    }

    private nonisolated static func normalizedPATH(existing: String?, hermesHome: String) -> String {
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
        let pathSeparator = ":"
        let currentPaths = (existing ?? "")
            .split(separator: ":", omittingEmptySubsequences: true)
            .map(String.init)
        var seen = Set<String>()
        let orderedPaths = (preferredPaths + currentPaths + fallbackPaths).filter { path in
            let standardized = URL(fileURLWithPath: path).standardizedFileURL.path
            guard FileManager.default.fileExists(atPath: standardized), !seen.contains(standardized) else { return false }
            seen.insert(standardized)
            return true
        }
        return orderedPaths.joined(separator: pathSeparator)
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

private struct HermesMCPProbeBatchResult: Codable {
    var error: String?
    var results: [HermesMCPProbeItem]
}

private struct HermesMCPProbeItem: Codable {
    var name: String
    var ok: Bool
    var tools: [HermesDashboardMCPTool]?
    var error: String?
    var output: String?
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
        if lines[start].trimmingCharacters(in: .whitespacesAndNewlines) == "mcp_servers: {}" { return [] }
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

    static func upsertingServer(_ server: HermesDashboardMCPServer, in yaml: String) -> String {
        var lines = yaml.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let hadTrailingNewline = yaml.hasSuffix("\n")
        let block = serializedBlock(for: server)
        guard let start = lines.firstIndex(where: { isTopLevelKey($0, key: "mcp_servers") }) else {
            if !lines.isEmpty, lines.last == "" { lines.removeLast() }
            if !lines.isEmpty { lines.append("") }
            lines.append("mcp_servers:")
            lines.append(contentsOf: block)
            return joined(lines, trailingNewline: hadTrailingNewline || yaml.isEmpty)
        }
        if lines[start].trimmingCharacters(in: .whitespacesAndNewlines) == "mcp_servers: {}" {
            lines[start] = "mcp_servers:"
            lines.insert(contentsOf: block, at: start + 1)
            return joined(lines, trailingNewline: hadTrailingNewline)
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
            if serverName == server.name {
                lines.replaceSubrange(index..<blockEnd, with: block)
                return joined(lines, trailingNewline: hadTrailingNewline)
            }
            index = blockEnd
        }
        lines.insert(contentsOf: block, at: end)
        return joined(lines, trailingNewline: hadTrailingNewline)
    }

    private static func server(named name: String, block: [String]) -> HermesDashboardMCPServer {
        let command = scalarValue(for: "command", in: block)
        let url = scalarValue(for: "url", in: block)
        let disabled = boolValue(for: "disabled", in: block) == true || boolValue(for: "enabled", in: block) == false
        let args = arrayValue(for: "args", in: block)
        let auth = scalarValue(for: "auth", in: block)
        let env = mappingValue(for: "env", in: block)
        let headers = mappingValue(for: "headers", in: block)
        let include = nestedArrayValue(parent: "tools", key: "include", in: block)
        let exclude = nestedArrayValue(parent: "tools", key: "exclude", in: block)
        return HermesDashboardMCPServer(name: name, command: command, args: args, url: url, disabled: disabled, auth: auth, env: env, headers: headers, toolsInclude: include, toolsExclude: exclude)
    }

    private static func serializedBlock(for server: HermesDashboardMCPServer) -> [String] {
        var lines = ["  \(quoteKey(server.name)):"]
        lines.append("    enabled: \(!server.disabled ? "true" : "false")")
        if let url = server.url, !url.isEmpty {
            lines.append("    url: \(quoted(url))")
        } else if let command = server.command, !command.isEmpty {
            lines.append("    command: \(quoted(command))")
            if !server.args.isEmpty { appendArray(server.args, key: "args", indent: 4, to: &lines) }
        }
        if let auth = server.auth, !auth.isEmpty { lines.append("    auth: \(quoted(auth))") }
        if !server.env.isEmpty { appendMapping(server.env, key: "env", indent: 4, to: &lines) }
        if !server.headers.isEmpty { appendMapping(server.headers, key: "headers", indent: 4, to: &lines) }
        if server.toolsInclude != nil || server.toolsExclude != nil {
            lines.append("    tools:")
            if let include = server.toolsInclude { appendArray(include, key: "include", indent: 6, to: &lines) }
            if let exclude = server.toolsExclude { appendArray(exclude, key: "exclude", indent: 6, to: &lines) }
        }
        return lines
    }

    private static func scalarValue(for key: String, in block: [String]) -> String? {
        for line in block {
            guard indentation(of: line) == 4 else { continue }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("\(key):") else { continue }
            let raw = String(trimmed.dropFirst(key.count + 1)).trimmingCharacters(in: .whitespacesAndNewlines)
            if raw.isEmpty || raw == "{}" { return nil }
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
            return parseArray(after: key, offset: offset, indent: 4, in: block) ?? []
        }
        return []
    }

    private static func nestedArrayValue(parent: String, key: String, in block: [String]) -> [String]? {
        guard let parentOffset = block.firstIndex(where: { indentation(of: $0) == 4 && $0.trimmingCharacters(in: .whitespaces).hasPrefix("\(parent):") }) else { return nil }
        var index = parentOffset + 1
        while index < block.count {
            let line = block[index]
            if indentation(of: line) <= 4 { break }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if indentation(of: line) == 6, trimmed.hasPrefix("\(key):") {
                return parseArray(after: key, offset: index, indent: 6, in: block) ?? []
            }
            index += 1
        }
        return nil
    }

    private static func parseArray(after key: String, offset: Int, indent: Int, in block: [String]) -> [String]? {
        let line = block[offset]
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("\(key):") else { return nil }
        let raw = String(trimmed.dropFirst(key.count + 1)).trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.hasPrefix("["), raw.hasSuffix("]") {
            let body = String(raw.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
            if body.isEmpty { return [] }
            return splitInlineArray(body).map { unquoted($0.trimmingCharacters(in: .whitespacesAndNewlines)) }.filter { !$0.isEmpty }
        }
        var values: [String] = []
        var index = offset + 1
        while index < block.count {
            let candidate = block[index]
            let trimmedCandidate = candidate.trimmingCharacters(in: .whitespaces)
            if indentation(of: candidate) <= indent { break }
            if trimmedCandidate.hasPrefix("-") {
                values.append(unquoted(String(trimmedCandidate.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)))
            }
            index += 1
        }
        return values
    }

    private static func mappingValue(for key: String, in block: [String]) -> [String: String] {
        guard let offset = block.firstIndex(where: { indentation(of: $0) == 4 && $0.trimmingCharacters(in: .whitespaces).hasPrefix("\(key):") }) else { return [:] }
        let trimmed = block[offset].trimmingCharacters(in: .whitespaces)
        let raw = String(trimmed.dropFirst(key.count + 1)).trimmingCharacters(in: .whitespacesAndNewlines)
        if raw == "{}" { return [:] }
        var result: [String: String] = [:]
        var index = offset + 1
        while index < block.count {
            let line = block[index]
            if indentation(of: line) <= 4 { break }
            if indentation(of: line) == 6, let split = splitMappingLine(line.trimmingCharacters(in: .whitespaces)) {
                result[unquoted(split.key)] = unquoted(split.value)
            }
            index += 1
        }
        return result
    }

    private static func splitMappingLine(_ line: String) -> (key: String, value: String)? {
        guard let colon = line.firstIndex(of: ":") else { return nil }
        let key = String(line[..<colon]).trimmingCharacters(in: .whitespacesAndNewlines)
        let value = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return nil }
        return (key, value)
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
        return trimmed.replacingOccurrences(of: "\\\"", with: "\"").replacingOccurrences(of: "\\\\", with: "\\")
    }

    private static func quoted(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    private static func quoteKey(_ value: String) -> String {
        let safe = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-.")
        if !value.isEmpty, value.unicodeScalars.allSatisfy({ safe.contains($0) }) { return value }
        return quoted(value)
    }

    private static func appendArray(_ values: [String], key: String, indent: Int, to lines: inout [String]) {
        let spaces = String(repeating: " ", count: indent)
        lines.append("\(spaces)\(key):")
        if values.isEmpty { return }
        for value in values {
            lines.append("\(spaces)  - \(quoted(value))")
        }
    }

    private static func appendMapping(_ mapping: [String: String], key: String, indent: Int, to lines: inout [String]) {
        let spaces = String(repeating: " ", count: indent)
        lines.append("\(spaces)\(key):")
        for key in mapping.keys.sorted() {
            lines.append("\(spaces)  \(quoteKey(key)): \(quoted(mapping[key] ?? ""))")
        }
    }

    private static func splitInlineArray(_ body: String) -> [String] {
        var values: [String] = []
        var current = ""
        var quote: Character?
        var escaping = false
        for character in body {
            if escaping {
                current.append(character)
                escaping = false
            } else if character == "\\" {
                current.append(character)
                escaping = true
            } else if let activeQuote = quote {
                current.append(character)
                if character == activeQuote { quote = nil }
            } else if character == "\"" || character == "'" {
                quote = character
                current.append(character)
            } else if character == "," {
                values.append(current)
                current = ""
            } else {
                current.append(character)
            }
        }
        if !current.isEmpty { values.append(current) }
        return values
    }

    private static func joined(_ lines: [String], trailingNewline: Bool) -> String {
        let text = lines.joined(separator: "\n")
        return trailingNewline ? text + "\n" : text
    }
}
