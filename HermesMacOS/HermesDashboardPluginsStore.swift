//
//  HermesDashboardPluginsStore.swift
//  HermesMacOS
//

import SwiftUI
import Foundation

struct HermesDashboardPlugin: Decodable, Identifiable, Equatable {
    let name: String
    let version: String
    let description: String
    let source: String
    let runtimeStatus: String
    let hasDashboardManifest: Bool
    let path: String
    let authRequired: Bool
    let authCommand: String

    var id: String { name }
    var isEnabled: Bool { runtimeStatus == "enabled" }
    var canToggle: Bool { !name.isEmpty }
    var statusLabel: String {
        switch runtimeStatus {
        case "enabled": return "Enabled"
        case "disabled": return "Disabled"
        case "inactive": return "Inactive"
        default: return runtimeStatus.isEmpty ? "Unknown" : runtimeStatus.capitalized
        }
    }
    var sourceLabel: String { source.isEmpty ? "bundled" : source }
    var statusColor: Color {
        switch runtimeStatus {
        case "enabled": return .green
        case "disabled": return .orange
        default: return Color.hermesSecondaryText
        }
    }

    enum CodingKeys: String, CodingKey {
        case name
        case version
        case description
        case source
        case runtimeStatus = "runtime_status"
        case hasDashboardManifest = "has_dashboard_manifest"
        case path
        case authRequired = "auth_required"
        case authCommand = "auth_command"
    }
}

@Observable
final class HermesDashboardPluginsStore {
    var plugins: [HermesDashboardPlugin] = []
    var isLoading = false
    var lastErrorMessage = ""

    var activeTask: Task<Void, Never>?
    var cachedTokenByBaseURL: [String: String] = [:]

    func refresh(dashboardBaseURL: String, apiSettings: HermesAPISettings) {
        activeTask?.cancel()
        activeTask = Task { await loadPlugins(dashboardBaseURL: dashboardBaseURL, apiSettings: apiSettings) }
    }

    func setPluginEnabled(_ plugin: HermesDashboardPlugin, enabled: Bool, dashboardBaseURL: String, apiSettings: HermesAPISettings) {
        activeTask?.cancel()
        activeTask = Task { await togglePlugin(plugin, enabled: enabled, dashboardBaseURL: dashboardBaseURL, apiSettings: apiSettings) }
    }

    func loadPlugins(dashboardBaseURL: String, apiSettings: HermesAPISettings) async {
        isLoading = true
        lastErrorMessage = ""
        defer { isLoading = false }

        do {
            let baseURL = try resolvedDashboardBaseURL(from: dashboardBaseURL, apiBaseURL: apiSettings.baseURL)
            let token = try await dashboardSessionToken(baseURL: baseURL, apiSettings: apiSettings)
            let hub = try await fetchPluginsHub(baseURL: baseURL, token: token, apiSettings: apiSettings)
            plugins = hub.plugins.sorted { lhs, rhs in
                lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func togglePlugin(_ plugin: HermesDashboardPlugin, enabled: Bool, dashboardBaseURL: String, apiSettings: HermesAPISettings) async {
        isLoading = true
        lastErrorMessage = ""
        defer { isLoading = false }

        do {
            let baseURL = try resolvedDashboardBaseURL(from: dashboardBaseURL, apiBaseURL: apiSettings.baseURL)
            let token = try await dashboardSessionToken(baseURL: baseURL, apiSettings: apiSettings)
            try await togglePluginRequest(name: plugin.name, enabled: enabled, baseURL: baseURL, token: token, apiSettings: apiSettings)
            await loadPlugins(dashboardBaseURL: dashboardBaseURL, apiSettings: apiSettings)
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func dashboardSessionToken(baseURL: URL, apiSettings: HermesAPISettings) async throws -> String {
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
            throw HermesDashboardPluginsError.missingDashboardSessionToken
        }
        let token = String(html[tokenRange])
        cachedTokenByBaseURL[cacheKey] = token
        return token
    }

    func fetchPluginsHub(baseURL: URL, token: String, apiSettings: HermesAPISettings) async throws -> HermesDashboardPluginsHubResponse {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/dashboard/plugins/hub"))
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(token, forHTTPHeaderField: "X-Hermes-Session-Token")
        let session = HermesNetworkSessionFactory.session(for: apiSettings)
        let (data, response) = try await session.data(for: request)
        try HermesNetworkSessionFactory.validate(response: response)
        return try JSONDecoder().decode(HermesDashboardPluginsHubResponse.self, from: data)
    }

    func togglePluginRequest(name: String, enabled: Bool, baseURL: URL, token: String, apiSettings: HermesAPISettings) async throws {
        var url = baseURL.appendingPathComponent("api/dashboard/agent-plugins")
        for component in name.split(separator: "/").map(String.init) {
            url.appendPathComponent(component)
        }
        url.appendPathComponent(enabled ? "enable" : "disable")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(token, forHTTPHeaderField: "X-Hermes-Session-Token")
        let session = HermesNetworkSessionFactory.session(for: apiSettings)
        let (_, response) = try await session.data(for: request)
        try HermesNetworkSessionFactory.validate(response: response)
    }

    func resolvedDashboardBaseURL(from dashboardBaseURL: String, apiBaseURL: String) throws -> URL {
        let explicit = dashboardBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !explicit.isEmpty, let url = normalizedBaseURL(from: explicit) { return url }
        var fallback = apiBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if fallback.hasSuffix("/v1") { fallback.removeLast(3) }
        guard let url = normalizedBaseURL(from: fallback) else { throw HermesDashboardPluginsError.invalidDashboardURL }
        return url
    }

    func normalizedBaseURL(from value: String) -> URL? {
        var trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        while trimmed.hasSuffix("/") { trimmed.removeLast() }
        return URL(string: trimmed)
    }
}

struct HermesDashboardPluginsHubResponse: Decodable {
    let plugins: [HermesDashboardPlugin]
}

enum HermesDashboardPluginsError: LocalizedError {
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
