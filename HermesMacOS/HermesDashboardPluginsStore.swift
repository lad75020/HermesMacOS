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

@MainActor
@Observable
final class HermesDashboardPluginsStore {
    var plugins: [HermesDashboardPlugin] = []
    var isLoading = false
    var lastErrorMessage = ""

    var activeTask: Task<Void, Never>?

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
            let baseURL = try await HermesDashboardClient.shared.resolvedBaseURL(dashboardBaseURL: dashboardBaseURL, apiBaseURL: apiSettings.baseURL)
            let hub = try await HermesDashboardClient.shared.getJSON(HermesDashboardPluginsHubResponse.self, baseURL: baseURL, path: "api/dashboard/plugins/hub", apiSettings: apiSettings)
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
            let baseURL = try await HermesDashboardClient.shared.resolvedBaseURL(dashboardBaseURL: dashboardBaseURL, apiBaseURL: apiSettings.baseURL)
            let path = (["api", "dashboard", "agent-plugins"] + plugin.name.split(separator: "/").map(String.init) + [enabled ? "enable" : "disable"]).joined(separator: "/")
            _ = try await HermesDashboardClient.shared.sendJSON(
                baseURL: baseURL,
                path: path,
                method: "POST",
                apiSettings: apiSettings,
                body: Optional<Int>.none
            )
            await loadPlugins(dashboardBaseURL: dashboardBaseURL, apiSettings: apiSettings)
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }
}

struct HermesDashboardPluginsHubResponse: Decodable {
    let plugins: [HermesDashboardPlugin]
}
