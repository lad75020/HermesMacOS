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

@MainActor
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
    private let pythonExecutable = HermesRuntimePaths.defaultPythonExecutable
    private let hermesAgentRoot = HermesRuntimePaths.defaultHermesAgentRoot

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
            let baseURL = try await HermesDashboardClient.shared.resolvedBaseURL(dashboardBaseURL: dashboardBaseURL, apiBaseURL: apiSettings.baseURL)
            let rawConfig = try await HermesDashboardClient.shared.rawConfig(baseURL: baseURL, apiSettings: apiSettings)
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
            let baseURL = try await HermesDashboardClient.shared.resolvedBaseURL(dashboardBaseURL: dashboardBaseURL, apiBaseURL: apiSettings.baseURL)
            try await HermesDashboardClient.shared.mutateRawConfig(baseURL: baseURL, apiSettings: apiSettings) { yaml in
                HermesMCPServersYAML.upsertingServer(server, in: yaml)
            }
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
            let baseURL = try await HermesDashboardClient.shared.resolvedBaseURL(dashboardBaseURL: dashboardBaseURL, apiBaseURL: apiSettings.baseURL)
            try await HermesDashboardClient.shared.mutateRawConfig(baseURL: baseURL, apiSettings: apiSettings) { yaml in
                HermesMCPServersYAML.upsertingServer(server, in: yaml)
            }
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
            let baseURL = try await HermesDashboardClient.shared.resolvedBaseURL(dashboardBaseURL: dashboardBaseURL, apiBaseURL: apiSettings.baseURL)
            try await HermesDashboardClient.shared.mutateRawConfig(baseURL: baseURL, apiSettings: apiSettings) { yaml in
                try HermesMCPServersYAML.removingServer(named: server.name, from: yaml)
            }
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
        do {
            let result = try HermesProcessRunner.run(
                executable: executable,
                arguments: arguments,
                environment: normalizedSubprocessEnvironment(hermesHome: hermesHome),
                currentDirectory: workdir,
                timeout: timeout
            )
            return result.output
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
    case serverNotFound(String)

    var errorDescription: String? {
        switch self {
        case .serverNotFound(let name):
            return "MCP server \"\(name)\" was not found in the dashboard config."
        }
    }
}
