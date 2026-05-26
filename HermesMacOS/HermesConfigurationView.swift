//
//  HermesConfigurationView.swift
//  HermesMacOS
//

import SwiftUI
import WebKit
import AppKit
import UniformTypeIdentifiers

struct HermesDashboardView: View {
    let dashboardURL: String
    let webViewStore: HermesDashboardWebViewStore
    let colorScheme: ColorScheme
    let connectedHostName: String
    let connectedWindowID: UUID
    @State private var reloadToken = UUID()

    private var normalizedDashboardURL: URL? {
        HermesConfigurationWebURL.normalizedURL(from: dashboardURL, colorScheme: colorScheme)
    }

    var body: some View {
        VStack(spacing: 16) {
            header

            Group {
                if let normalizedDashboardURL {
                    HermesDashboardWebView(store: webViewStore, url: normalizedDashboardURL, reloadToken: reloadToken)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                        )
                } else {
                    ContentUnavailableView(
                        "Dashboard URL required",
                        systemImage: "exclamationmark.triangle",
                        description: Text("Set the Hermes Dashboard URL in Settings, then return here to load Hermes Dashboard.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .hermesGlassPanel(tint: Color.hermesSurface.opacity(0.72), cornerRadius: 20)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(18)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Label("Hermes Dashboard", systemImage: "speedometer")
                .hermesWebsiteTitleFont(size: 22, weight: .bold)
            Button {
                reloadToken = UUID()
            } label: {
                Label("Reload", systemImage: "arrow.clockwise")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderedProminent)
            .disabled(normalizedDashboardURL == nil)
            .help("Reload")
            .accessibilityLabel("Reload")
            Spacer()
            HermesConnectedHostLabel(hostName: connectedHostName, windowID: connectedWindowID)
            Text("Hermes Dashboard")
                .hermesWebsiteLabelFont(size: 11, weight: .bold)
                .foregroundStyle(Color.hermesSecondaryText)
        }
        .padding(18)
        .hermesGlassPanel(cornerRadius: 18)
    }
}

private enum HermesConfigurationWebURL {
    static func normalizedURL(from string: String, colorScheme: ColorScheme) -> URL? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let baseURL: URL?
        if let url = URL(string: trimmed), url.scheme != nil, url.host != nil {
            baseURL = url
        } else {
            baseURL = URL(string: "https://\(trimmed)").flatMap { $0.host == nil ? nil : $0 }
        }

        guard let baseURL else { return nil }
        return themedURL(from: baseURL, colorScheme: colorScheme)
    }

    private static let darkDashboardThemeName = "mono"
    private static let lightDashboardThemeName = "solarized-light"

    private static func themedURL(from url: URL, colorScheme: ColorScheme) -> URL? {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        var queryItems = components.queryItems?.filter { $0.name.lowercased() != "theme" } ?? []
        queryItems.append(URLQueryItem(name: "theme", value: colorScheme == .dark ? darkDashboardThemeName : lightDashboardThemeName))
        components.queryItems = queryItems
        return components.url
    }
}

@MainActor
final class HermesDashboardWebViewStore {
    let webView: WKWebView
    private var lastLoadedURL: URL?
    private var lastReloadToken: UUID?

    private static let themeOverrideScript = """
    (() => {
      const desiredTheme = new URLSearchParams(window.location.search).get('theme');
      if (!desiredTheme) return;

      const storageKey = 'hermes-dashboard-theme';
      window.localStorage.setItem(storageKey, desiredTheme);

      const originalFetch = window.fetch;
      if (typeof originalFetch !== 'function' || window.__hermesConfigurationThemeFetchPatched) return;
      window.__hermesConfigurationThemeFetchPatched = true;

      window.fetch = (...args) => {
        return originalFetch(...args).then(async (response) => {
          try {
            const input = args[0];
            const url = typeof input === 'string' ? input : (input && input.url) || '';
            if (url.includes('/api/dashboard/themes') && response.ok) {
              const body = await response.clone().json();
              body.active = desiredTheme;
              const headers = new Headers(response.headers);
              headers.set('content-type', 'application/json');
              return new Response(JSON.stringify(body), {
                status: response.status,
                statusText: response.statusText,
                headers,
              });
            }
          } catch (_) {}
          return response;
        });
      };
    })();
    """

    init() {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.userContentController.addUserScript(
            WKUserScript(
                source: Self.themeOverrideScript,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
        )
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
    }

    func loadIfNeeded(url: URL, reloadToken: UUID) {
        if lastLoadedURL != url {
            lastLoadedURL = url
            lastReloadToken = reloadToken
            webView.load(URLRequest(url: url))
            return
        }

        if lastReloadToken != reloadToken {
            lastReloadToken = reloadToken
            webView.reload()
        }
    }
}

struct HermesDashboardWebView: NSViewRepresentable {
    let store: HermesDashboardWebViewStore
    let url: URL
    let reloadToken: UUID

    func makeNSView(context: Context) -> WKWebView {
        store.loadIfNeeded(url: url, reloadToken: reloadToken)
        return store.webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        store.loadIfNeeded(url: url, reloadToken: reloadToken)
    }
}


struct HermesConfigurationView: View {
    @AppStorage("hermes.macOS.configuration.skillsExpanded") private var isSkillsExpanded = true
    @AppStorage("hermes.macOS.configuration.profilesExpanded") private var isProfilesExpanded = true
    @AppStorage("hermes.macOS.configuration.toolsExpanded") private var isToolsExpanded = true
    @AppStorage("hermes.macOS.configuration.mcpServersExpanded") private var isMCPServersExpanded = true
    @AppStorage("hermes.macOS.configuration.schedulesExpanded") private var isSchedulesExpanded = true
    @AppStorage("hermes.macOS.configuration.modelsExpanded") private var isModelsExpanded = true
    @AppStorage("hermes.macOS.configuration.pluginsExpanded") private var isPluginsExpanded = true
    @StateObject private var runtime = HermesLocalConfigurationRuntime()
    @State private var dashboardSkills = HermesDashboardSkillsStore()
    @State private var dashboardPlugins = HermesDashboardPluginsStore()
    @State private var dashboardToolsets = HermesDashboardToolsetsStore()
    @State private var dashboardMCPServers = HermesDashboardMCPServersStore()
    @State private var dashboardSchedules = HermesDashboardSchedulesStore()
    @State private var localRuntimeModels = HermesLocalRuntimeModelsStore()
    @State private var localProfiles = HermesLocalProfilesStore()
    @State private var skillQuery = ""
    @State private var pluginQuery = ""
    @State private var toolsetQuery = ""
    @State private var mcpQuery = ""
    @State private var scheduleQuery = ""
    @State private var skillInstallURL = ""
    @State private var selectedSkillFileURL: URL?
    @State private var skillInstallValidationMessage = ""
    @State private var showCreateProfileForm = false
    @State private var createProfileDraft = HermesLocalProfileDraft()
    @State private var editingProfileName: String?
    @State private var editProfileDraft = HermesLocalProfileDraft()
    @State private var confirmDeleteProfileName: String?
    @State private var mcpName = ""
    @State private var mcpTransport = "stdio"
    @State private var mcpCommand = ""
    @State private var mcpArgs = ""
    @State private var mcpURL = ""
    @State private var mcpEnv = ""
    @State private var mcpHeaders = ""
    @State private var mcpAuth = ""
    @State private var mcpValidationMessage = ""
    @State private var scheduleName = ""
    @State private var scheduleExpression = ""
    @State private var schedulePrompt = ""
    @State private var scheduleSkillName = ""
    @State private var scheduleJobKind = "prompt"
    @State private var scheduleDeliveryTarget = "local"
    @State private var scheduleCustomDeliveryTarget = ""
    @State private var selectedScheduleTemplateID = ""
    @State private var scheduleChainSourceJobID = ""
    let apiSettings: HermesAPISettings
    let dashboardURL: String
    let connectedHostName: String
    let connectedWindowID: UUID

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                localSystemBanner
                dashboardSkillsSection

                dashboardPluginsSection

                localProfilesSection

                dashboardToolsetsSection

                dashboardMCPServersSection

                dashboardSchedulesSection

                localRuntimeModelsSection
            }
            .padding(18)
        }
        .background(HermesLiquidGlassCanvas().ignoresSafeArea())
        .onAppear {
            runtime.remoteHostName = connectedHostName
            refreshConfiguration()
        }
        .onChange(of: connectedHostName) { _, newValue in
            runtime.remoteHostName = newValue
        }
        .confirmationDialog(
            "Delete profile?",
            isPresented: Binding(
                get: { confirmDeleteProfileName != nil },
                set: { isPresented in if !isPresented { confirmDeleteProfileName = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let profileName = confirmDeleteProfileName {
                Button("Delete \(profileName)", role: .destructive) {
                    localProfiles.deleteProfile(profileName, hermesHome: runtime.hermesHome)
                    confirmDeleteProfileName = nil
                }
            }
            Button("Cancel", role: .cancel) { confirmDeleteProfileName = nil }
        }
    }

    private var filteredDashboardSkills: [HermesDashboardSkill] {
        let query = skillQuery.trimmedForHermes
        guard !query.isEmpty else { return dashboardSkills.skills }
        return dashboardSkills.skills.filter { skill in
            skill.name.localizedCaseInsensitiveContains(query) ||
            (skill.description ?? "").localizedCaseInsensitiveContains(query) ||
            (skill.category ?? "").localizedCaseInsensitiveContains(query) ||
            skill.statusLabel.localizedCaseInsensitiveContains(query)
        }
    }

    private var filteredDashboardPlugins: [HermesDashboardPlugin] {
        let query = pluginQuery.trimmedForHermes
        guard !query.isEmpty else { return dashboardPlugins.plugins }
        return dashboardPlugins.plugins.filter { plugin in
            plugin.name.localizedCaseInsensitiveContains(query) ||
            plugin.description.localizedCaseInsensitiveContains(query) ||
            plugin.version.localizedCaseInsensitiveContains(query) ||
            plugin.source.localizedCaseInsensitiveContains(query) ||
            plugin.statusLabel.localizedCaseInsensitiveContains(query) ||
            plugin.path.localizedCaseInsensitiveContains(query)
        }
    }

    private var filteredDashboardToolsets: [HermesDashboardToolset] {
        let query = toolsetQuery.trimmedForHermes
        guard !query.isEmpty else { return dashboardToolsets.toolsets }
        return dashboardToolsets.toolsets.filter { toolset in
            toolset.name.localizedCaseInsensitiveContains(query) ||
            toolset.displayLabel.localizedCaseInsensitiveContains(query) ||
            toolset.description.localizedCaseInsensitiveContains(query) ||
            toolset.statusLabel.localizedCaseInsensitiveContains(query) ||
            (toolset.tools ?? []).contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    private var filteredDashboardMCPServers: [HermesDashboardMCPServer] {
        let query = mcpQuery.trimmedForHermes
        guard !query.isEmpty else { return dashboardMCPServers.servers }
        return dashboardMCPServers.servers.filter { server in
            server.name.localizedCaseInsensitiveContains(query) ||
            server.primaryDetail.localizedCaseInsensitiveContains(query) ||
            server.transportLabel.localizedCaseInsensitiveContains(query) ||
            server.statusLabel.localizedCaseInsensitiveContains(query)
        }
    }

    private var filteredDashboardSchedules: [HermesDashboardScheduleJob] {
        let query = scheduleQuery.trimmedForHermes
        guard !query.isEmpty else { return dashboardSchedules.jobs }
        return dashboardSchedules.jobs.filter { job in
            job.displayName.localizedCaseInsensitiveContains(query) ||
            job.scheduleLabel.localizedCaseInsensitiveContains(query) ||
            job.statusLabel.localizedCaseInsensitiveContains(query) ||
            job.profileLabel.localizedCaseInsensitiveContains(query) ||
            job.skillLabel.localizedCaseInsensitiveContains(query) ||
            job.deliveryLabel.localizedCaseInsensitiveContains(query) ||
            job.chainLabel.localizedCaseInsensitiveContains(query) ||
            job.contentPreview.localizedCaseInsensitiveContains(query)
        }
    }

    private var selectedScheduleDeliveryValue: String {
        if scheduleDeliveryTarget == "custom" { return scheduleCustomDeliveryTarget.trimmedForHermes }
        return scheduleDeliveryTarget
    }

    private var selectedScheduleChainJobs: [String] {
        scheduleChainSourceJobID.trimmedForHermes.isEmpty ? [] : [scheduleChainSourceJobID.trimmedForHermes]
    }

    private var canCreateSchedule: Bool {
        !scheduleName.trimmedForHermes.isEmpty &&
        !scheduleExpression.trimmedForHermes.isEmpty &&
        !selectedScheduleDeliveryValue.isEmpty &&
        (!schedulePrompt.trimmedForHermes.isEmpty || !scheduleSkillName.trimmedForHermes.isEmpty) &&
        (scheduleJobKind == "prompt" || !scheduleSkillName.trimmedForHermes.isEmpty) &&
        !dashboardSchedules.isLoading
    }

    private var canAddMCPServer: Bool {
        let name = mcpName.trimmedForHermes
        guard !name.isEmpty, !dashboardMCPServers.isLoading else { return false }
        if mcpTransport == "http" { return !mcpURL.trimmedForHermes.isEmpty }
        return !mcpCommand.trimmedForHermes.isEmpty
    }

    private var mcpWorkbenchOutput: String {
        let messages = [dashboardMCPServers.lastActionMessage, dashboardMCPServers.lastErrorMessage, runtime.outputs[.mcpServers] ?? ""].filter { !$0.isEmpty }
        return messages.isEmpty ? "MCP Server Workbench ready. Test servers, tune tool filters, add stdio/HTTP servers, and reload MCP discovery." : messages.joined(separator: "\n")
    }

    private var scheduleStudioOutput: String {
        let messages = [dashboardSchedules.lastActionMessage, dashboardSchedules.lastErrorMessage].filter { !$0.isEmpty }
        return messages.isEmpty ? "Automation Studio ready. Create prompt jobs, skill-backed jobs, chained jobs, or queue existing jobs to run now." : messages.joined(separator: "\n")
    }

    private var schedulePreviewText: String {
        let chainName = dashboardSchedules.jobs.first(where: { $0.id == scheduleChainSourceJobID })?.displayName ?? scheduleChainSourceJobID
        var lines = [
            "Name: \(scheduleName.trimmedForHermes.isEmpty ? "Untitled schedule" : scheduleName.trimmedForHermes)",
            "Type: \(scheduleJobKind == "skill" ? "Skill-backed" : "Prompt-based")",
            "Schedule: \(scheduleExpression.trimmedForHermes.isEmpty ? "—" : scheduleExpression.trimmedForHermes)",
            "Delivery: \(selectedScheduleDeliveryValue.isEmpty ? "—" : selectedScheduleDeliveryValue)"
        ]
        if !scheduleSkillName.trimmedForHermes.isEmpty { lines.append("Skills: \(scheduleSkillName.trimmedForHermes)") }
        if !scheduleChainSourceJobID.trimmedForHermes.isEmpty { lines.append("Context from: \(chainName)") }
        lines.append("Prompt preview:\n\(schedulePrompt.trimmedForHermes.isEmpty ? "—" : schedulePrompt.trimmedForHermes)")
        return lines.joined(separator: "\n")
    }

    private var dashboardSkillsSection: some View {
        configurationSection(
            title: "Skills",
            subtitle: "Loaded from Hermes Dashboard /api/skills. Toggle status via /api/skills/toggle.",
            systemImage: "square.stack.3d.up.fill",
            isExpanded: $isSkillsExpanded
        ) {
            if dashboardSkills.isLoading { ProgressView().controlSize(.small) }
            Button {
                dashboardSkills.refreshForManagement(dashboardBaseURL: dashboardURL, apiSettings: apiSettings)
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.bordered)
            .help("Refresh skills from Hermes Dashboard")
        } content: {
            HStack {
                TextField("Filter by name, description, category, or status", text: $skillQuery)
                    .textFieldStyle(.roundedBorder)
                Text("\(filteredDashboardSkills.count)/\(dashboardSkills.skills.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color.hermesSecondaryText)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Button {
                        pickSkillFile()
                    } label: {
                        Label("Choose SKILL.md", systemImage: "doc.badge.plus")
                    }
                    .buttonStyle(.bordered)

                    Text(selectedSkillFileURL?.lastPathComponent ?? "No local file selected")
                        .font(.caption)
                        .foregroundStyle(Color.hermesSecondaryText)
                        .lineLimit(1)

                    Spacer()
                }
                HStack(spacing: 8) {
                    TextField("Or paste a skill URL", text: $skillInstallURL)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        addSkill()
                    } label: {
                        Label("Add skill", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(skillInstallSource == nil || runtime.runningSections.contains(.skills))
                }
                if runtime.runningSections.contains(.skills) {
                    Label("Installing skill…", systemImage: "hourglass")
                        .font(.caption)
                        .foregroundStyle(Color.hermesSecondaryText)
                }
                if !skillInstallValidationMessage.isEmpty {
                    Label(skillInstallValidationMessage, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(Color.hermesDestructive)
                }
                if let installOutput = runtime.outputs[.skills], !installOutput.isEmpty {
                    ScrollView {
                        Text(installOutput)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(Color.hermesSecondaryText)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                    }
                    .frame(minHeight: 60, maxHeight: 140)
                    .background(Color.black.opacity(0.16), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }

            if !dashboardSkills.lastErrorMessage.isEmpty {
                Label(dashboardSkills.lastErrorMessage, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(Color.hermesDestructive)
            }

            if dashboardSkills.skills.isEmpty && dashboardSkills.isLoading == false {
                Text("No skills loaded. Check the Dashboard URL setting and press Refresh.")
                    .font(.caption)
                    .foregroundStyle(Color.hermesSecondaryText)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.black.opacity(0.16), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(filteredDashboardSkills) { skill in
                            dashboardSkillRow(skill)
                        }
                    }
                    .padding(2)
                }
                .frame(minHeight: 180, maxHeight: 360)
            }
        }
    }

    private var dashboardPluginsSection: some View {
        configurationSection(
            title: "Plugins",
            subtitle: "List, enable, and disable Hermes Agent plugins through Hermes Dashboard plugin APIs.",
            systemImage: "puzzlepiece.extension",
            isExpanded: $isPluginsExpanded
        ) {
            if dashboardPlugins.isLoading { ProgressView().controlSize(.small) }
            Button {
                dashboardPlugins.refresh(dashboardBaseURL: dashboardURL, apiSettings: apiSettings)
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.bordered)
            .help("Refresh plugins from Hermes Dashboard")
        } content: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    TextField("Filter by name, description, source, status, version, or path", text: $pluginQuery)
                        .textFieldStyle(.roundedBorder)
                    Text("\(filteredDashboardPlugins.count)/\(dashboardPlugins.plugins.count)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Color.hermesSecondaryText)
                }

                if !dashboardPlugins.lastErrorMessage.isEmpty {
                    Label(dashboardPlugins.lastErrorMessage, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(Color.hermesDestructive)
                }

                if dashboardPlugins.isLoading && dashboardPlugins.plugins.isEmpty {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Loading plugins from Hermes Dashboard…")
                            .font(.callout)
                            .foregroundStyle(Color.hermesSecondaryText)
                    }
                } else if filteredDashboardPlugins.isEmpty {
                    Text(dashboardPlugins.plugins.isEmpty ? "No Hermes Agent plugins reported by the Dashboard." : "No matching plugins.")
                        .font(.callout)
                        .foregroundStyle(Color.hermesSecondaryText)
                        .padding(.vertical, 8)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(filteredDashboardPlugins) { plugin in
                                dashboardPluginRow(plugin)
                            }
                        }
                        .padding(2)
                    }
                    .frame(minHeight: 180, maxHeight: 360)
                }

                Text("Plugins are loaded from GET /api/dashboard/plugins/hub and toggled with the dashboard agent-plugin enable/disable endpoints. Restart or reset Hermes sessions if a plugin change needs runtime reload.")
                    .font(.caption)
                    .foregroundStyle(Color.hermesSecondaryText)
            }
        }
    }

    private func dashboardPluginRow(_ plugin: HermesDashboardPlugin) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Toggle(isOn: Binding(
                get: { plugin.isEnabled },
                set: { enabled in
                    dashboardPlugins.setPluginEnabled(plugin, enabled: enabled, dashboardBaseURL: dashboardURL, apiSettings: apiSettings)
                }
            )) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(plugin.name)
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .lineLimit(1)
                        if !plugin.version.isEmpty {
                            Text("v\(plugin.version)")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Color.hermesSecondaryText)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color.white.opacity(0.08), in: Capsule())
                        }
                        Text(plugin.sourceLabel)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.hermesSecondaryText)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.08), in: Capsule())
                        Text(plugin.statusLabel)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(plugin.statusColor)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(plugin.statusColor.opacity(0.14), in: Capsule())
                    }
                    if !plugin.description.isEmpty {
                        Text(plugin.description)
                            .font(.caption)
                            .foregroundStyle(Color.hermesSecondaryText)
                            .lineLimit(2)
                    }
                    if !plugin.path.isEmpty {
                        Text(plugin.path)
                            .font(.caption2.monospaced())
                            .foregroundStyle(Color.hermesSecondaryText.opacity(0.85))
                            .lineLimit(1)
                    }
                    HStack(spacing: 12) {
                        if plugin.hasDashboardManifest {
                            Label("Dashboard", systemImage: "rectangle.3.group")
                        }
                        if plugin.authRequired {
                            Label(plugin.authCommand.isEmpty ? "Auth required" : plugin.authCommand, systemImage: "key")
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(Color.orange)
                }
            }
            .toggleStyle(.switch)
            .disabled(dashboardPlugins.isLoading || !plugin.canToggle)
            .help(plugin.isEnabled ? "Disable \(plugin.name)" : "Enable \(plugin.name)")
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.16), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var skillInstallSource: String? {
        let trimmedURL = skillInstallURL.trimmedForHermes
        if !trimmedURL.isEmpty { return trimmedURL }
        return selectedSkillFileURL?.path
    }

    private func pickSkillFile() {
        let panel = NSOpenPanel()
        panel.title = "Choose a SKILL.md file"
        panel.prompt = "Choose"
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        if let markdownType = UTType(filenameExtension: "md") {
            panel.allowedContentTypes = [markdownType]
        }
        if panel.runModal() == .OK, let url = panel.url {
            selectedSkillFileURL = url
            skillInstallValidationMessage = url.lastPathComponent == "SKILL.md" ? "" : "Selected file is not named SKILL.md. Hermes may reject it."
        }
    }

    private func addSkill() {
        guard let source = skillInstallSource else {
            skillInstallValidationMessage = "Choose a SKILL.md file or enter a web URL."
            return
        }
        let trimmedURL = skillInstallURL.trimmedForHermes
        if !trimmedURL.isEmpty {
            guard let url = URL(string: trimmedURL), ["http", "https"].contains(url.scheme?.lowercased() ?? ""), url.host?.isEmpty == false else {
                skillInstallValidationMessage = "Enter a valid http or https skill URL."
                return
            }
        } else if let selectedSkillFileURL, selectedSkillFileURL.lastPathComponent != "SKILL.md" {
            skillInstallValidationMessage = "Choose a file named SKILL.md."
            return
        }
        let localFileURL = trimmedURL.isEmpty ? selectedSkillFileURL : nil
        let didAccessLocalFile = localFileURL?.startAccessingSecurityScopedResource() ?? false
        skillInstallValidationMessage = ""
        runtime.installSkill(from: source) {
            if didAccessLocalFile {
                localFileURL?.stopAccessingSecurityScopedResource()
            }
            selectedSkillFileURL = nil
            skillInstallURL = ""
            dashboardSkills.refreshForManagement(dashboardBaseURL: dashboardURL, apiSettings: apiSettings)
        }
    }

    private func addMCPServer() {
        let name = mcpName.trimmedForHermes
        guard isValidMCPName(name) else {
            mcpValidationMessage = "Use a server name with letters, numbers, underscores, or hyphens."
            return
        }

        let env: [String: String]
        let headers: [String: String]
        do {
            env = try parseMCPKeyValueLines(mcpEnv, separator: "=")
            headers = try parseMCPKeyValueLines(mcpHeaders, separator: ":")
        } catch {
            mcpValidationMessage = error.localizedDescription
            return
        }

        if mcpTransport == "http" {
            let urlText = mcpURL.trimmedForHermes
            guard let url = URL(string: urlText), ["http", "https"].contains(url.scheme?.lowercased() ?? ""), url.host?.isEmpty == false else {
                mcpValidationMessage = "Enter a valid http or https MCP endpoint URL."
                return
            }
        } else {
            guard !mcpCommand.trimmedForHermes.isEmpty else {
                mcpValidationMessage = "Enter a command for the stdio server."
                return
            }
        }

        let draft = HermesMCPServerDraft(
            name: name,
            transportKind: mcpTransport == "http" ? .http : .stdio,
            command: mcpCommand.trimmedForHermes,
            args: splitMCPArguments(mcpArgs),
            url: mcpURL.trimmedForHermes,
            env: env,
            headers: headers,
            auth: mcpAuth.trimmedForHermes.isEmpty ? nil : mcpAuth.trimmedForHermes
        )
        mcpValidationMessage = ""
        dashboardMCPServers.upsertServer(draft, dashboardBaseURL: dashboardURL, apiSettings: apiSettings)
        mcpName = ""
        mcpCommand = ""
        mcpArgs = ""
        mcpURL = ""
        mcpEnv = ""
        mcpHeaders = ""
        mcpAuth = ""
    }

    private func isValidMCPName(_ name: String) -> Bool {
        guard !name.isEmpty else { return false }
        return name.range(of: #"^[A-Za-z0-9_-]+$"#, options: .regularExpression) != nil
    }

    private func parseMCPKeyValueLines(_ text: String, separator: Character) throws -> [String: String] {
        var result: [String: String] = [:]
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine).trimmedForHermes
            guard !line.isEmpty else { continue }
            guard let index = line.firstIndex(of: separator) else {
                throw HermesConfigurationValidationError(message: "Expected \(separator == "=" ? "KEY=VALUE" : "Header: value") on every line.")
            }
            let key = String(line[..<index]).trimmedForHermes
            let value = String(line[line.index(after: index)...]).trimmedForHermes
            guard !key.isEmpty else { throw HermesConfigurationValidationError(message: "Key names cannot be empty.") }
            if separator == "=" && key.range(of: #"^[A-Za-z_][A-Za-z0-9_]*$"#, options: .regularExpression) == nil {
                throw HermesConfigurationValidationError(message: "Invalid environment variable name: \(key)")
            }
            result[key] = value
        }
        return result
    }

    private func splitMCPArguments(_ text: String) -> [String] {
        var result: [String] = []
        var current = ""
        var quote: Character?
        var escaping = false
        for character in text {
            if escaping {
                current.append(character)
                escaping = false
            } else if character == "\\" {
                escaping = true
            } else if let activeQuote = quote {
                if character == activeQuote {
                    quote = nil
                } else {
                    current.append(character)
                }
            } else if character == "\"" || character == "'" {
                quote = character
            } else if character.isWhitespace {
                if !current.isEmpty {
                    result.append(current)
                    current = ""
                }
            } else {
                current.append(character)
            }
        }
        if escaping { current.append("\\") }
        if !current.isEmpty { result.append(current) }
        return result
    }

    private func dashboardSkillRow(_ skill: HermesDashboardSkill) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(skill.name)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .lineLimit(1)
                    Text(skill.category?.isEmpty == false ? skill.category! : "Uncategorized")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.hermesSecondaryText)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.08), in: Capsule())
                    Text(skill.statusLabel)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(skill.isEnabled ? Color.green : Color.hermesSecondaryText)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background((skill.isEnabled ? Color.green : Color.gray).opacity(0.14), in: Capsule())
                }
                if let description = skill.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(Color.hermesSecondaryText)
                        .lineLimit(2)
                }
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { skill.isEnabled },
                set: { enabled in
                    dashboardSkills.setSkillEnabled(skill, enabled: enabled, dashboardBaseURL: dashboardURL, apiSettings: apiSettings)
                }
            ))
            .labelsHidden()
            .disabled(dashboardSkills.isLoading)
            .help(skill.isEnabled ? "Disable \(skill.name)" : "Enable \(skill.name)")
        }
        .padding(10)
        .background(Color.black.opacity(0.16), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func refreshConfiguration() {
        dashboardSkills.refreshForManagement(dashboardBaseURL: dashboardURL, apiSettings: apiSettings)
        dashboardPlugins.refresh(dashboardBaseURL: dashboardURL, apiSettings: apiSettings)
        dashboardToolsets.refresh(dashboardBaseURL: dashboardURL, apiSettings: apiSettings)
        dashboardMCPServers.refresh(dashboardBaseURL: dashboardURL, apiSettings: apiSettings)
        dashboardSchedules.refresh(dashboardBaseURL: dashboardURL, apiSettings: apiSettings)
        localRuntimeModels.refresh()
        localProfiles.refresh(hermesHome: runtime.hermesHome)
        runtime.refreshAll()
    }

    private var header: some View {
        HStack(spacing: 12) {
            Label("Configuration", systemImage: "gearshape.2")
                .hermesWebsiteTitleFont(size: 22, weight: .bold)
            Spacer()
            HermesConnectedHostLabel(hostName: connectedHostName, windowID: connectedWindowID)
            Button {
                refreshConfiguration()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderedProminent)
            .help("Refresh local Hermes runtime status")
        }
        .padding(18)
        .hermesGlassPanel(cornerRadius: 18)
    }

    private var localRuntimeModelsSection: some View {
        runtimeSection(
            title: "Models",
            subtitle: "Configure main, delegation, and auxiliary runtime model routing in local config.yaml.",
            systemImage: "cpu",
            isExpanded: $isModelsExpanded,
            output: localRuntimeModels.lastStatusMessage
        ) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Works like HermesiOS Agent Runtime: edit provider and model slots for the main conversation, delegated sub-agents, and auxiliary tasks. Changes are written directly on this Mac.")
                    .font(.subheadline)
                    .foregroundStyle(Color.hermesSecondaryText)

                VStack(alignment: .leading, spacing: 6) {
                    configurationSummaryRow(label: "Hermes Home", value: localRuntimeModels.resolvedHermesHome.isEmpty ? "/Volumes/WDBlack4TB/.hermes" : localRuntimeModels.resolvedHermesHome)
                    configurationSummaryRow(label: "Config", value: localRuntimeModels.configPath.isEmpty ? "/Volumes/WDBlack4TB/.hermes/config.yaml" : localRuntimeModels.configPath)
                }

                HStack {
                    Button("Reload Models") { localRuntimeModels.refresh() }
                    if localRuntimeModels.isLoading { ProgressView().controlSize(.small) }
                    Spacer()
                }

                HermesRuntimeModelSlotEditorCard(
                    title: "Main Model",
                    subtitle: "Primary model for interactive Hermes Agent turns (`model.provider` and `model.default`).",
                    systemImage: "sparkles",
                    provider: localRuntimeModels.mainModel.provider,
                    model: localRuntimeModels.mainModel.model,
                    providerOptions: mainModelProviderOptions,
                    onSave: { provider, model in localRuntimeModels.saveMain(provider: provider, model: model) }
                )

                HermesRuntimeModelSlotEditorCard(
                    title: "Delegation Model",
                    subtitle: "Model used when Hermes spawns delegated sub-agents (`delegation.provider` and `delegation.model`). Leave blank to inherit defaults.",
                    systemImage: "person.2.wave.2",
                    provider: localRuntimeModels.delegationModel.provider,
                    model: localRuntimeModels.delegationModel.model,
                    providerOptions: runtimeModelProviderOptions,
                    allowEmptyProvider: true,
                    onSave: { provider, model in
                        localRuntimeModels.saveSlot(localRuntimeModels.delegationModel, provider: provider, model: model)
                    }
                )

                Text("Auxiliary Models")
                    .hermesWebsiteTitleFont(size: 15, weight: .bold)
                Text("Use auto for Hermes automatic routing, main to inherit the main model, or leave model empty to use the provider's default auxiliary model.")
                    .font(.caption)
                    .foregroundStyle(Color.hermesSecondaryText)

                ForEach(localRuntimeModels.auxiliaryModels) { slot in
                    HermesRuntimeModelSlotEditorCard(
                        title: slot.label,
                        subtitle: "Writes `auxiliary.\(slot.key).provider` and `auxiliary.\(slot.key).model`.",
                        systemImage: auxiliaryModelIcon(for: slot.key),
                        provider: slot.provider,
                        model: slot.model,
                        providerOptions: runtimeModelProviderOptions,
                        allowEmptyProvider: true,
                        onSave: { provider, model in
                            localRuntimeModels.saveSlot(slot, provider: provider, model: model)
                        }
                    )
                }
            }
        }
    }

    private var mainModelProviderOptions: [HermesRuntimeProviderOption] {
        localRuntimeModels.providerOptions.filter { $0.value != "main" }
    }

    private var runtimeModelProviderOptions: [HermesRuntimeProviderOption] {
        var options = localRuntimeModels.providerOptions
        if !options.contains(where: { $0.value == "main" }) {
            options.insert(.init(value: "main", label: "Main model"), at: min(1, options.count))
        }
        return options
    }

    private func configurationSummaryRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label).fontWeight(.semibold)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(Color.hermesSecondaryText)
                .textSelection(.enabled)
        }
        .font(.caption)
    }

    private func auxiliaryModelIcon(for key: String) -> String {
        switch key {
        case "vision": "eye"
        case "web_extract": "doc.text.magnifyingglass"
        case "compression": "arrow.down.forward.and.arrow.up.backward"
        case "title_generation": "textformat"
        case "mcp": "point.3.connected.trianglepath.dotted"
        case "curator": "wand.and.stars"
        case "skills_hub": "square.stack.3d.up.fill"
        case "approval": "checkmark.shield"
        case "session_search": "magnifyingglass.circle"
        default: "cpu"
        }
    }

    private var localProfilesSection: some View {
        runtimeSection(
            title: "Profiles",
            subtitle: "\(localProfiles.profiles.count) profiles · \(localProfiles.namedProfileCount) named · active: \(localProfiles.activeProfileName)",
            systemImage: "person.crop.rectangle.stack",
            isExpanded: $isProfilesExpanded,
            output: localProfiles.errorMessage ?? localProfiles.lastOutput
        ) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    profileStatusChip(title: "Profiles", value: "\(localProfiles.profiles.count)", color: .hermesActionBlue)
                    profileStatusChip(title: "Named", value: "\(localProfiles.namedProfileCount)", color: .green)
                    profileStatusChip(title: "Active", value: localProfiles.activeProfileName, color: .hermesOrange)
                    Spacer()
                    ProgressView().opacity(localProfiles.isBusy ? 1 : 0)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Profiles are read from the local Hermes home and its profiles/ folder. Create and edit profile model settings from the default profile values, then refresh whenever the filesystem changes.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if !localProfiles.profilesDirectoryPath.isEmpty {
                        Text(localProfiles.profilesDirectoryPath)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                    }

                    HStack {
                        Button {
                            localProfiles.refresh(hermesHome: runtime.hermesHome)
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                        .disabled(localProfiles.isBusy)

                        Button {
                            createProfileDraft = localProfiles.draftFromDefault()
                            editingProfileName = nil
                            showCreateProfileForm.toggle()
                        } label: {
                            Label(showCreateProfileForm ? "Hide Form" : "Create", systemImage: showCreateProfileForm ? "xmark" : "plus")
                        }
                        .disabled(localProfiles.isBusy)
                    }
                }
                .padding(12)
                .hermesGlassPanel(tint: Color.white.opacity(0.05), cornerRadius: 14, interactive: false)

                if let message = localProfiles.errorMessage, !message.isEmpty {
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }

                if showCreateProfileForm {
                    profileForm(
                        title: "Create Profile",
                        draft: $createProfileDraft,
                        isEditingDefault: false,
                        showsCloneSkills: true,
                        submitTitle: "Create",
                        submitIcon: "plus.circle.fill"
                    ) {
                        localProfiles.createProfile(normalized(createProfileDraft), hermesHome: runtime.hermesHome)
                        createProfileDraft = localProfiles.draftFromDefault()
                        showCreateProfileForm = false
                    } reset: {
                        createProfileDraft = localProfiles.draftFromDefault()
                    } cancel: {
                        showCreateProfileForm = false
                    }
                }

                if let editingProfileName {
                    profileForm(
                        title: "Edit Profile",
                        draft: $editProfileDraft,
                        isEditingDefault: editingProfileName == "default",
                        showsCloneSkills: false,
                        submitTitle: "Save",
                        submitIcon: "square.and.pencil"
                    ) {
                        localProfiles.editProfile(originalName: editingProfileName, draft: normalized(editProfileDraft), hermesHome: runtime.hermesHome)
                        self.editingProfileName = nil
                    } reset: {
                        if let profile = localProfiles.profiles.first(where: { $0.name == editingProfileName }) {
                            editProfileDraft = localProfiles.draft(for: profile)
                        }
                    } cancel: {
                        self.editingProfileName = nil
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Runtime Profiles")
                        .font(.headline)
                    if localProfiles.profiles.isEmpty {
                        ContentUnavailableView(
                            "No Profiles Loaded",
                            systemImage: "person.crop.rectangle.stack",
                            description: Text("Refresh to list the default profile and every named directory under the Hermes profiles folder.")
                        )
                    } else {
                        ForEach(localProfiles.profiles) { profile in
                            localProfileCard(profile)
                        }
                    }
                }
                .padding(12)
                .hermesGlassPanel(tint: Color.white.opacity(0.05), cornerRadius: 14, interactive: false)
            }
        }
    }

    private func profileForm(
        title: String,
        draft: Binding<HermesLocalProfileDraft>,
        isEditingDefault: Bool,
        showsCloneSkills: Bool,
        submitTitle: String,
        submitIcon: String,
        submit: @escaping () -> Void,
        reset: @escaping () -> Void,
        cancel: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            TextField("Profile name", text: draft.name)
                .textFieldStyle(.roundedBorder)
                .disabled(isEditingDefault)

            HStack(spacing: 10) {
                TextField("Provider", text: draft.provider)
                    .textFieldStyle(.roundedBorder)
                TextField("Model", text: draft.model)
                    .textFieldStyle(.roundedBorder)
            }

            TextField("Base URL (optional)", text: draft.baseURL)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 16) {
                Toggle(".env file", isOn: draft.createEnv)
                    .tint(.hermesActionBlue)
                Toggle("SOUL.md", isOn: draft.createSoul)
                    .tint(.hermesActionBlue)
            }

            if showsCloneSkills {
                Toggle("Clone default skills folder", isOn: draft.cloneSkills)
                    .tint(.hermesActionBlue)
            }

            Text("Creating a profile copies the default config as a template, writes provider/model/base URL, and optionally creates or copies .env, SOUL.md, and skills. Editing uses the same persistent fields; the default profile name cannot change.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button {
                    submit()
                } label: {
                    Label(submitTitle, systemImage: submitIcon)
                }
                .buttonStyle(.borderedProminent)
                .disabled(draft.wrappedValue.name.trimmedForHermes.isEmpty || localProfiles.isBusy)

                Button("Reset") { reset() }
                    .disabled(localProfiles.isBusy)

                Button("Cancel") { cancel() }
                    .disabled(localProfiles.isBusy)
            }
        }
        .padding(12)
        .hermesGlassPanel(tint: Color.hermesActionBlue.opacity(0.06), cornerRadius: 14, interactive: false)
    }

    private func normalized(_ draft: HermesLocalProfileDraft) -> HermesLocalProfileDraft {
        HermesLocalProfileDraft(
            name: draft.name.trimmedForHermes,
            provider: draft.provider.trimmedForHermes,
            model: draft.model.trimmedForHermes,
            baseURL: draft.baseURL.trimmedForHermes,
            createEnv: draft.createEnv,
            createSoul: draft.createSoul,
            cloneSkills: draft.cloneSkills
        )
    }

    private func localProfileCard(_ profile: HermesLocalProfileInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(profile.name)
                            .font(.headline.weight(.semibold))
                        if profile.isDefault { profileBadge("Default", color: .hermesActionBlue) }
                        if profile.isActive { profileBadge("Active", color: .green) }
                        if profile.gatewayRunning { profileBadge("Gateway", color: .hermesOrange) }
                    }
                    Text(profile.path)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
                Spacer()
                Image(systemName: profile.isActive ? "checkmark.seal.fill" : "person.crop.rectangle")
                    .font(.title3)
                    .foregroundStyle(profile.isActive ? Color.green : Color.secondary)
            }

            HStack(spacing: 8) {
                profileMetric("Provider", profile.provider.isEmpty ? "—" : profile.provider)
                profileMetric("Model", profile.model.isEmpty ? "—" : profile.model)
                profileMetric("Base URL", profile.baseURL.isEmpty ? "—" : profile.baseURL)
                profileMetric("Skills", "\(profile.skillCount)")
            }

            HStack(spacing: 8) {
                profileFlag("config.yaml", enabled: profile.hasConfig)
                profileFlag(".env", enabled: profile.hasEnv)
                profileFlag("SOUL.md", enabled: profile.hasSoul)
                Spacer()
                Button {
                    editProfileDraft = localProfiles.draft(for: profile)
                    editingProfileName = profile.name
                    showCreateProfileForm = false
                } label: {
                    Label("Edit", systemImage: "square.and.pencil")
                }
                .disabled(localProfiles.isBusy)

                if !profile.isActive {
                    Button {
                        localProfiles.useProfile(profile.name, hermesHome: runtime.hermesHome)
                    } label: {
                        Label("Use", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .disabled(localProfiles.isBusy)
                }

                if !profile.isDefault {
                    Button(role: .destructive) {
                        confirmDeleteProfileName = profile.name
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .disabled(localProfiles.isBusy)
                }
            }
        }
        .padding(14)
        .hermesGlassPanel(tint: profile.isActive ? Color.green.opacity(0.08) : Color.white.opacity(0.05), cornerRadius: 18, interactive: true)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(profile.isActive ? Color.green.opacity(0.28) : Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func profileMetric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.monospaced())
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(9)
        .hermesGlassPanel(tint: Color.hermesActionBlue.opacity(0.06), cornerRadius: 12, interactive: false)
    }

    private func profileBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .hermesGlassPanel(tint: color.opacity(0.08), cornerRadius: 10, interactive: false)
    }

    private func profileFlag(_ label: String, enabled: Bool) -> some View {
        Label(label, systemImage: enabled ? "checkmark.circle.fill" : "minus.circle")
            .font(.caption.weight(.semibold))
            .foregroundStyle(enabled ? Color.green : Color.secondary)
    }

    private func profileStatusChip(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.monospacedDigit().weight(.semibold))
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .hermesGlassPanel(tint: color.opacity(0.08), cornerRadius: 12, interactive: false)
    }

    private var dashboardToolsetsSection: some View {
        runtimeSection(
            title: "Tools",
            subtitle: "Enable or disable dashboard toolsets for new Hermes sessions.",
            systemImage: "wrench.and.screwdriver",
            isExpanded: $isToolsExpanded,
            output: dashboardToolsets.lastErrorMessage
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    TextField("Filter by label, toolset, description, status, or tool", text: $toolsetQuery)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        dashboardToolsets.refresh(dashboardBaseURL: dashboardURL, apiSettings: apiSettings)
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .disabled(dashboardToolsets.isLoading)
                }

                if dashboardToolsets.isLoading && dashboardToolsets.toolsets.isEmpty {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Loading toolsets from Hermes Dashboard…")
                            .font(.callout)
                            .foregroundStyle(Color.hermesSecondaryText)
                    }
                } else if filteredDashboardToolsets.isEmpty {
                    Text(dashboardToolsets.toolsets.isEmpty ? "No toolsets reported by the Hermes Dashboard." : "No matching toolsets.")
                        .font(.callout)
                        .foregroundStyle(Color.hermesSecondaryText)
                        .padding(.vertical, 8)
                } else {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(filteredDashboardToolsets) { toolset in
                            HStack(alignment: .top, spacing: 12) {
                                Toggle(isOn: Binding(
                                    get: { toolset.enabled },
                                    set: { enabled in
                                        dashboardToolsets.setToolsetEnabled(toolset, enabled: enabled, dashboardBaseURL: dashboardURL, apiSettings: apiSettings)
                                    }
                                )) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(spacing: 8) {
                                            Text(toolset.displayLabel)
                                                .font(.headline)
                                            Text(toolset.name)
                                                .font(.caption.monospaced())
                                                .foregroundStyle(Color.hermesSecondaryText)
                                            Text(toolset.statusLabel)
                                                .font(.caption.weight(.semibold))
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 2)
                                                .background((toolset.enabled ? Color.green : Color.gray).opacity(0.16), in: Capsule())
                                                .foregroundStyle(toolset.enabled ? Color.green : Color.hermesSecondaryText)
                                            if toolset.enabled && toolset.configured == false {
                                                Text("Setup needed")
                                                    .font(.caption.weight(.semibold))
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 2)
                                                    .background(Color.orange.opacity(0.16), in: Capsule())
                                                    .foregroundStyle(Color.orange)
                                            }
                                        }
                                        Text(toolset.description)
                                            .font(.callout)
                                            .foregroundStyle(Color.hermesSecondaryText)
                                        if let tools = toolset.tools, !tools.isEmpty {
                                            Text(tools.prefix(8).joined(separator: ", ") + (tools.count > 8 ? "…" : ""))
                                                .font(.caption.monospaced())
                                                .foregroundStyle(Color.hermesSecondaryText.opacity(0.85))
                                        }
                                    }
                                }
                                .toggleStyle(.switch)
                                .disabled(dashboardToolsets.isLoading)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
                        }
                    }
                }

                Text("Toolsets are loaded with GET /api/tools/toolsets and saved through the Hermes Dashboard configuration API; no hermes tools CLI call is used here.")
                    .font(.caption)
                    .foregroundStyle(Color.hermesSecondaryText)
            }
        }
    }

    private var dashboardMCPServersSection: some View {
        runtimeSection(
            title: "MCP Server Workbench",
            subtitle: "Inspect configured command/URL, test availability, view discovered tools, tune tool filters, and add stdio or HTTP servers.",
            systemImage: "point.3.connected.trianglepath.dotted",
            isExpanded: $isMCPServersExpanded,
            output: mcpWorkbenchOutput
        ) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    TextField("Search MCP servers, tools, command, URL, auth, or status", text: $mcpQuery)
                    Button {
                        dashboardMCPServers.refresh(dashboardBaseURL: dashboardURL, apiSettings: apiSettings)
                        dashboardMCPServers.refreshRecentErrors(hermesHome: runtime.hermesHome)
                    } label: {
                        Label("Refresh config", systemImage: "arrow.clockwise")
                    }
                    .disabled(dashboardMCPServers.isLoading)
                    Button {
                        dashboardMCPServers.testAllConnections(hermesHome: runtime.hermesHome)
                    } label: {
                        Label("Test all", systemImage: "checkmark.seal")
                    }
                    .disabled(dashboardMCPServers.isTesting || dashboardMCPServers.servers.isEmpty)
                    Button {
                        dashboardMCPServers.reloadMCP(hermesHome: runtime.hermesHome)
                    } label: {
                        Label("Reload MCP", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .disabled(dashboardMCPServers.isTesting || dashboardMCPServers.servers.isEmpty)
                }

                addMCPServerWizard

                if dashboardMCPServers.isLoading && dashboardMCPServers.servers.isEmpty {
                    ProgressView("Loading MCP servers from dashboard config…")
                        .controlSize(.small)
                } else if !dashboardMCPServers.lastErrorMessage.isEmpty {
                    Text(dashboardMCPServers.lastErrorMessage)
                        .font(.caption)
                        .foregroundStyle(Color.orange)
                } else if filteredDashboardMCPServers.isEmpty {
                    Text(dashboardMCPServers.servers.isEmpty ? "No MCP servers found in dashboard config." : "No matching MCP servers.")
                        .font(.caption)
                        .foregroundStyle(Color.hermesSecondaryText)
                } else {
                    VStack(spacing: 10) {
                        ForEach(filteredDashboardMCPServers) { server in
                            mcpServerWorkbenchRow(server)
                        }
                    }
                }
            }
            .onAppear { dashboardMCPServers.refreshRecentErrors(hermesHome: runtime.hermesHome) }
        }
    }

    private var addMCPServerWizard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Label("Add MCP server", systemImage: "plus.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.hermesSecondaryText)
                Picker("Transport", selection: $mcpTransport) {
                    Text("stdio").tag("stdio")
                    Text("HTTP").tag("http")
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
                Spacer()
                Button { addMCPServer() } label: {
                    Label("Save server", systemImage: "externaldrive.badge.plus")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canAddMCPServer)
            }

            HStack(spacing: 10) {
                TextField("Name, e.g. github", text: $mcpName)
                if mcpTransport == "http" {
                    TextField("URL, e.g. https://example.com/mcp", text: $mcpURL)
                } else {
                    TextField("Command, e.g. npx", text: $mcpCommand)
                    TextField("Args, e.g. -y @modelcontextprotocol/server-filesystem", text: $mcpArgs)
                }
            }

            if mcpTransport == "http" {
                TextField("Auth mode, e.g. oauth or header (optional)", text: $mcpAuth)
                TextField("Auth headers, one per line", text: $mcpHeaders, axis: .vertical)
                    .lineLimit(2...5)
            } else {
                TextField("Environment, one per line: KEY=value", text: $mcpEnv, axis: .vertical)
                    .lineLimit(2...5)
            }

            Text("Arguments are shell-split with quote support. Environment names and HTTP header lines are validated before writing config.yaml.")
                .font(.caption)
                .foregroundStyle(Color.hermesSecondaryText)
            if !mcpValidationMessage.isEmpty {
                Text(mcpValidationMessage)
                    .font(.caption)
                    .foregroundStyle(Color.orange)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    private func mcpServerWorkbenchRow(_ server: HermesDashboardMCPServer) -> some View {
        let probe = dashboardMCPServers.probeStates[server.name] ?? HermesMCPServerProbeState()
        let recentErrors = dashboardMCPServers.recentErrorsByServer[server.name] ?? []
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(server.name)
                            .font(.headline)
                        mcpPill(server.transportLabel, color: Color.hermesActionBlue)
                        mcpPill(server.statusLabel, color: server.disabled ? Color.gray : Color.green)
                        mcpPill(probe.statusLabel, color: probe.availability == .available ? Color.green : (probe.availability == .unavailable ? Color.orange : Color.gray))
                        mcpPill(probe.toolCountLabel, color: Color.purple)
                    }
                    Text(server.primaryDetail)
                        .font(.caption.monospaced())
                        .foregroundStyle(Color.hermesSecondaryText)
                        .textSelection(.enabled)
                    HStack(spacing: 12) {
                        configurationSummaryRow(label: "Tools", value: server.configuredToolRuleLabel)
                        configurationSummaryRow(label: "Auth", value: server.authLabel)
                        if !server.env.isEmpty { configurationSummaryRow(label: "Env", value: "\(server.env.count) vars") }
                        if !server.headers.isEmpty { configurationSummaryRow(label: "Headers", value: "\(server.headers.count) headers") }
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 8) {
                    Toggle("Enabled", isOn: Binding(
                        get: { !server.disabled },
                        set: { enabled in dashboardMCPServers.setServerEnabled(server, enabled: enabled, dashboardBaseURL: dashboardURL, apiSettings: apiSettings) }
                    ))
                    .toggleStyle(.switch)
                    .disabled(dashboardMCPServers.isLoading)
                    HStack(spacing: 8) {
                        Button {
                            dashboardMCPServers.testConnection(server, hermesHome: runtime.hermesHome)
                        } label: {
                            Label("Test connection", systemImage: "bolt.horizontal.circle")
                        }
                        .disabled(dashboardMCPServers.isTesting || server.disabled)
                        Button(role: .destructive) {
                            dashboardMCPServers.deleteServer(server, dashboardBaseURL: dashboardURL, apiSettings: apiSettings)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .disabled(dashboardMCPServers.isLoading)
                    }
                }
            }

            if probe.availability == .testing {
                ProgressView("Testing connection…")
                    .controlSize(.small)
            }
            if !probe.errorMessage.isEmpty {
                Label(probe.errorMessage, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(Color.orange)
                    .textSelection(.enabled)
            }

            DisclosureGroup("Discovered tools") {
                if probe.tools.isEmpty {
                    Text(server.disabled ? "Enable this server before testing tools." : "Run Test connection to discover tools and tool count.")
                        .font(.caption)
                        .foregroundStyle(Color.hermesSecondaryText)
                } else {
                    VStack(spacing: 6) {
                        ForEach(probe.tools) { tool in
                            HStack(alignment: .top, spacing: 8) {
                                Toggle("", isOn: Binding(
                                    get: { server.isToolEnabled(tool.name) },
                                    set: { enabled in
                                        dashboardMCPServers.setToolEnabled(server, tool: tool, enabled: enabled, allTools: probe.tools, dashboardBaseURL: dashboardURL, apiSettings: apiSettings)
                                    }
                                ))
                                .labelsHidden()
                                .disabled(dashboardMCPServers.isLoading)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(tool.name)
                                        .font(.caption.monospaced().weight(.semibold))
                                    if !tool.description.isEmpty {
                                        Text(tool.description)
                                            .font(.caption2)
                                            .foregroundStyle(Color.hermesSecondaryText)
                                            .lineLimit(2)
                                    }
                                }
                                Spacer()
                            }
                        }
                    }
                    .padding(.top, 6)
                }
            }
            .font(.caption.weight(.semibold))

            DisclosureGroup("Recent MCP errors") {
                if recentErrors.isEmpty {
                    Text("No recent errors found in mcp-stderr.log or errors.log for this server.")
                        .font(.caption)
                        .foregroundStyle(Color.hermesSecondaryText)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(recentErrors, id: \.self) { line in
                            Text(line)
                                .font(.caption2.monospaced())
                                .foregroundStyle(Color.orange)
                                .textSelection(.enabled)
                        }
                    }
                }
            }
            .font(.caption.weight(.semibold))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    private func mcpPill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.16), in: Capsule())
            .foregroundStyle(color)
    }

    private var dashboardSchedulesSection: some View {
        runtimeSection(
            title: "Schedules",
            subtitle: "Cron / Automation Studio: create prompt or skill-backed jobs, choose delivery, chain outputs, preview, and operate runs.",
            systemImage: "calendar.badge.clock",
            isExpanded: $isSchedulesExpanded,
            output: scheduleStudioOutput
        ) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    TextField("Search schedules, skills, delivery, output, or profile", text: $scheduleQuery)
                    Button {
                        dashboardSchedules.refresh(dashboardBaseURL: dashboardURL, apiSettings: apiSettings)
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .disabled(dashboardSchedules.isLoading)
                }

                scheduleAutomationStudio

                if dashboardSchedules.isLoading && dashboardSchedules.jobs.isEmpty {
                    ProgressView("Loading schedules from Hermes Dashboard…")
                        .controlSize(.small)
                } else if !dashboardSchedules.lastErrorMessage.isEmpty {
                    Text(dashboardSchedules.lastErrorMessage)
                        .font(.caption)
                        .foregroundStyle(Color.orange)
                } else if filteredDashboardSchedules.isEmpty {
                    Text(dashboardSchedules.jobs.isEmpty ? "No schedules reported by the Hermes Dashboard." : "No matching schedules.")
                        .font(.caption)
                        .foregroundStyle(Color.hermesSecondaryText)
                } else {
                    VStack(spacing: 8) {
                        ForEach(filteredDashboardSchedules) { job in
                            dashboardScheduleRow(job)
                        }
                    }
                }
            }
        }
    }

    private var scheduleAutomationStudio: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Picker("Template", selection: $selectedScheduleTemplateID) {
                    Text("Custom").tag("")
                    ForEach(HermesScheduleAutomationTemplate.defaults) { template in
                        Text(template.title).tag(template.id)
                    }
                }
                .frame(maxWidth: 280)
                Button {
                    applySelectedScheduleTemplate()
                } label: {
                    Label("Apply template", systemImage: "wand.and.stars")
                }
                .disabled(selectedScheduleTemplateID.isEmpty)
                Spacer()
                Picker("Job type", selection: $scheduleJobKind) {
                    Text("Prompt job").tag("prompt")
                    Text("Skill-backed").tag("skill")
                }
                .pickerStyle(.segmented)
                .frame(width: 260)
            }

            HStack(spacing: 10) {
                TextField("Name", text: $scheduleName)
                TextField("Schedule, e.g. every 2h or 0 9 * * *", text: $scheduleExpression)
            }

            TextField(scheduleJobKind == "skill" ? "Task instruction for the selected skill" : "Self-contained prompt", text: $schedulePrompt, axis: .vertical)
                .lineLimit(3...7)

            HStack(spacing: 10) {
                skillSelector
                Picker("Deliver", selection: $scheduleDeliveryTarget) {
                    ForEach(HermesScheduleDeliveryTarget.defaults) { target in
                        Text(target.title).tag(target.id)
                    }
                }
                .frame(width: 190)
                if scheduleDeliveryTarget == "custom" {
                    TextField("platform:chat_id:thread_id or local", text: $scheduleCustomDeliveryTarget)
                        .frame(minWidth: 220)
                }
            }

            HStack(spacing: 10) {
                Picker("Use output from", selection: $scheduleChainSourceJobID) {
                    Text("No upstream job").tag("")
                    ForEach(dashboardSchedules.jobs) { job in
                        Text("\(job.displayName) (\(job.id))").tag(job.id)
                    }
                }
                .frame(maxWidth: 420)
                Button {
                    addSchedule()
                } label: {
                    Label("Create automation", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canCreateSchedule)
            }

            VStack(alignment: .leading, spacing: 6) {
                Label("Test run preview", systemImage: "doc.text.magnifyingglass")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.hermesSecondaryText)
                Text(schedulePreviewText)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Color.hermesSecondaryText)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color.black.opacity(0.16), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    private var skillSelector: some View {
        HStack(spacing: 8) {
            TextField(scheduleJobKind == "skill" ? "Required skill name" : "Optional skill name", text: $scheduleSkillName)
            Menu {
                ForEach(dashboardSkills.skills.filter { $0.isEnabled }) { skill in
                    Button(skill.name) { scheduleSkillName = skill.name }
                }
            } label: {
                Label("Pick skill", systemImage: "square.stack.3d.up")
                    .labelStyle(.titleAndIcon)
            }
            .disabled(dashboardSkills.skills.isEmpty)
        }
    }

    private func applySelectedScheduleTemplate() {
        guard let template = HermesScheduleAutomationTemplate.defaults.first(where: { $0.id == selectedScheduleTemplateID }) else { return }
        scheduleName = template.title
        scheduleExpression = template.schedule
        schedulePrompt = template.prompt
        scheduleSkillName = template.skillName
        scheduleJobKind = template.skillName.isEmpty ? "prompt" : "skill"
        scheduleDeliveryTarget = template.delivery
        scheduleCustomDeliveryTarget = ""
    }

    private func jobDisplayName(for id: String) -> String {
        dashboardSchedules.jobs.first(where: { $0.id == id })?.displayName ?? id
    }

    private func addSchedule() {
        dashboardSchedules.createSchedule(
            name: scheduleName,
            schedule: scheduleExpression,
            prompt: schedulePrompt,
            skillName: scheduleSkillName,
            delivery: selectedScheduleDeliveryValue,
            contextFrom: selectedScheduleChainJobs,
            dashboardBaseURL: dashboardURL,
            apiSettings: apiSettings
        )
        scheduleName = ""
        scheduleExpression = ""
        schedulePrompt = ""
        scheduleSkillName = ""
        scheduleChainSourceJobID = ""
    }

    private func dashboardScheduleRow(_ job: HermesDashboardScheduleJob) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(job.displayName)
                            .font(.headline)
                        Text(job.statusLabel)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background((job.isEnabled ? Color.green : Color.gray).opacity(0.16), in: Capsule())
                            .foregroundStyle(job.isEnabled ? Color.green : Color.hermesSecondaryText)
                        Text(job.profileLabel)
                            .font(.caption.monospaced())
                            .foregroundStyle(Color.hermesSecondaryText)
                        Text(job.deliveryLabel)
                            .font(.caption.monospaced())
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color.hermesActionBlue.opacity(0.12), in: Capsule())
                            .foregroundStyle(Color.hermesActionBlue)
                    }
                    Text(job.scheduleLabel)
                        .font(.caption.monospaced())
                        .foregroundStyle(Color.hermesSecondaryText)
                    if !job.skillLabel.isEmpty {
                        Text("Skill: \(job.skillLabel)")
                            .font(.caption)
                            .foregroundStyle(Color.hermesActionBlue)
                    }
                    if !job.chainLabel.isEmpty {
                        Text("Uses output from: \(job.chainLabel.split(separator: ",").map { jobDisplayName(for: String($0).trimmedForHermes) }.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundStyle(Color.hermesSecondaryText)
                    }
                    Text(job.contentPreview)
                        .font(.caption)
                        .foregroundStyle(Color.hermesSecondaryText)
                        .lineLimit(3)
                    HStack(spacing: 12) {
                        Text("Next: \(job.nextRunAt ?? "—")")
                        Text("Last: \(job.lastRunAt ?? "—")")
                        Text("Status: \(job.lastStatusLabel)")
                    }
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(Color.hermesSecondaryText.opacity(0.85))
                    if !job.failureLabel.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Last failure")
                                .font(.caption2.weight(.semibold))
                            Text(job.failureLabel)
                                .font(.caption)
                                .lineLimit(3)
                        }
                        .foregroundStyle(Color.orange)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 8) {
                    Button {
                        dashboardSchedules.runJobNow(job, dashboardBaseURL: dashboardURL, apiSettings: apiSettings)
                    } label: {
                        Label("Run now", systemImage: "play.circle")
                    }
                    .disabled(dashboardSchedules.isLoading)

                    Button {
                        dashboardSchedules.setJobEnabled(job, enabled: !job.isEnabled, dashboardBaseURL: dashboardURL, apiSettings: apiSettings)
                    } label: {
                        Label(job.isEnabled ? "Pause" : "Resume", systemImage: job.isEnabled ? "pause.circle" : "arrow.clockwise.circle")
                    }
                    .disabled(dashboardSchedules.isLoading)

                    Button {
                        dashboardSchedules.loadLastOutput(for: job, hermesHome: runtime.hermesHome)
                    } label: {
                        Label("Output", systemImage: "doc.text")
                    }
                }
                .buttonStyle(.bordered)
            }

            if let output = dashboardSchedules.lastOutputByJobID[job.id], !output.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Run output")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.hermesSecondaryText)
                    ScrollView {
                        Text(output)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(Color.hermesSecondaryText)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                    }
                    .frame(minHeight: 80, maxHeight: 220)
                    .background(Color.black.opacity(0.16), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    private var localSystemBanner: some View {
        Label("Configuration uses the Hermes Dashboard for skills, tools, MCP servers, and schedules, with direct local system calls only where needed on this Mac.", systemImage: "desktopcomputer")
            .font(.callout)
            .foregroundStyle(Color.hermesSecondaryText)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .hermesGlassPanel(tint: Color.hermesSurface.opacity(0.56), cornerRadius: 14)
    }

    private func runtimeSection<Content: View>(
        title: String,
        subtitle: String,
        systemImage: String,
        isExpanded: Binding<Bool>,
        output: String?,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        configurationSection(
            title: title,
            subtitle: subtitle,
            systemImage: systemImage,
            isExpanded: isExpanded
        ) {
            if runtime.runningSections.contains(HermesLocalConfigurationSection(title: title)) {
                ProgressView().controlSize(.small)
            }
        } content: {
            content()
                .textFieldStyle(.roundedBorder)
            ScrollView {
                Text(output ?? "Not loaded yet.")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Color.hermesSecondaryText)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
            }
            .frame(minHeight: 96, maxHeight: 180)
            .background(Color.black.opacity(0.16), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func configurationSection<Content: View, Trailing: View>(
        title: String,
        subtitle: String,
        systemImage: String,
        isExpanded: Binding<Bool>,
        @ViewBuilder trailing: @escaping () -> Trailing,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        DisclosureGroup(isExpanded: isExpanded) {
            VStack(alignment: .leading, spacing: 12) {
                content()
            }
            .padding(.top, 12)
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.hermesActionBlue)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .hermesWebsiteTitleFont(size: 17, weight: .bold)
                    if isExpanded.wrappedValue {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(Color.hermesSecondaryText)
                    }
                }
                Spacer()
                trailing()
            }
            .contentShape(Rectangle())
        }
        .tint(Color.hermesActionBlue)
        .padding(16)
        .hermesGlassPanel(cornerRadius: 18)
    }
}

private struct HermesScheduleAutomationTemplate: Identifiable {
    let id: String
    let title: String
    let schedule: String
    let prompt: String
    let skillName: String
    let delivery: String

    static let defaults: [HermesScheduleAutomationTemplate] = [
        HermesScheduleAutomationTemplate(
            id: "daily-briefing",
            title: "Daily briefing",
            schedule: "0 8 * * *",
            prompt: "Create a concise daily briefing for Laurent. Include the most important calendar/context reminders, noteworthy AI or developer news, and actionable next steps. Keep it short and cite sources when web results are used.",
            skillName: "",
            delivery: "local"
        ),
        HermesScheduleAutomationTemplate(
            id: "repo-check",
            title: "Repo check",
            schedule: "0 9 * * 1-5",
            prompt: "Inspect the configured repository. Summarize git status, recent changes, failing checks, and any risky TODOs. Do not modify files; report only.",
            skillName: "codebase-inspection",
            delivery: "local"
        ),
        HermesScheduleAutomationTemplate(
            id: "blog-watcher",
            title: "Blog watcher",
            schedule: "every 6h",
            prompt: "Scan the configured blogs or RSS feeds and report only genuinely new or important items. Start with [SILENT] if there is nothing worth sharing.",
            skillName: "blogwatcher",
            delivery: "local"
        ),
        HermesScheduleAutomationTemplate(
            id: "session-cleanup",
            title: "Session cleanup",
            schedule: "0 3 * * 0",
            prompt: "Review Hermes session storage for stale, empty, or failed sessions that are safe to clean up. Summarize candidates and actions taken; avoid deleting active sessions.",
            skillName: "",
            delivery: "local"
        ),
        HermesScheduleAutomationTemplate(
            id: "model-eval",
            title: "Model eval",
            schedule: "0 6 * * 0",
            prompt: "Run or prepare the configured lightweight model evaluation, then summarize score deltas, failures, and recommended follow-up. Keep raw logs out of the delivery unless needed.",
            skillName: "evaluating-llms-harness",
            delivery: "local"
        ),
        HermesScheduleAutomationTemplate(
            id: "backup",
            title: "Backup",
            schedule: "0 2 * * *",
            prompt: "Create or verify the configured Hermes backup. Report backup path, size, retention status, and any failure that needs attention.",
            skillName: "",
            delivery: "local"
        )
    ]
}

private struct HermesScheduleDeliveryTarget: Identifiable {
    let id: String
    let title: String

    static let defaults: [HermesScheduleDeliveryTarget] = [
        HermesScheduleDeliveryTarget(id: "local", title: "Local only"),
        HermesScheduleDeliveryTarget(id: "origin", title: "Origin chat"),
        HermesScheduleDeliveryTarget(id: "all", title: "All home channels"),
        HermesScheduleDeliveryTarget(id: "telegram", title: "Telegram"),
        HermesScheduleDeliveryTarget(id: "discord", title: "Discord"),
        HermesScheduleDeliveryTarget(id: "slack", title: "Slack"),
        HermesScheduleDeliveryTarget(id: "email", title: "Email"),
        HermesScheduleDeliveryTarget(id: "custom", title: "Custom…")
    ]
}

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

    private var activeTask: Task<Void, Never>?
    private var cachedTokenByBaseURL: [String: String] = [:]

    func refresh(dashboardBaseURL: String, apiSettings: HermesAPISettings) {
        activeTask?.cancel()
        activeTask = Task { await loadPlugins(dashboardBaseURL: dashboardBaseURL, apiSettings: apiSettings) }
    }

    func setPluginEnabled(_ plugin: HermesDashboardPlugin, enabled: Bool, dashboardBaseURL: String, apiSettings: HermesAPISettings) {
        activeTask?.cancel()
        activeTask = Task { await togglePlugin(plugin, enabled: enabled, dashboardBaseURL: dashboardBaseURL, apiSettings: apiSettings) }
    }

    private func loadPlugins(dashboardBaseURL: String, apiSettings: HermesAPISettings) async {
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

    private func togglePlugin(_ plugin: HermesDashboardPlugin, enabled: Bool, dashboardBaseURL: String, apiSettings: HermesAPISettings) async {
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
            throw HermesDashboardPluginsError.missingDashboardSessionToken
        }
        let token = String(html[tokenRange])
        cachedTokenByBaseURL[cacheKey] = token
        return token
    }

    private func fetchPluginsHub(baseURL: URL, token: String, apiSettings: HermesAPISettings) async throws -> HermesDashboardPluginsHubResponse {
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

    private func togglePluginRequest(name: String, enabled: Bool, baseURL: URL, token: String, apiSettings: HermesAPISettings) async throws {
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

    private func resolvedDashboardBaseURL(from dashboardBaseURL: String, apiBaseURL: String) throws -> URL {
        let explicit = dashboardBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !explicit.isEmpty, let url = normalizedBaseURL(from: explicit) { return url }
        var fallback = apiBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if fallback.hasSuffix("/v1") { fallback.removeLast(3) }
        guard let url = normalizedBaseURL(from: fallback) else { throw HermesDashboardPluginsError.invalidDashboardURL }
        return url
    }

    private func normalizedBaseURL(from value: String) -> URL? {
        var trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        while trimmed.hasSuffix("/") { trimmed.removeLast() }
        return URL(string: trimmed)
    }
}

private struct HermesDashboardPluginsHubResponse: Decodable {
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

private struct HermesRuntimeModelSlotEditorCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let provider: String
    let model: String
    let providerOptions: [HermesRuntimeProviderOption]
    let allowEmptyProvider: Bool
    let onSave: (String, String) -> Void

    @State private var draftProvider: String
    @State private var draftModel: String
    @State private var saved = false

    init(
        title: String,
        subtitle: String,
        systemImage: String,
        provider: String,
        model: String,
        providerOptions: [HermesRuntimeProviderOption],
        allowEmptyProvider: Bool = false,
        onSave: @escaping (String, String) -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.provider = provider
        self.model = model
        self.providerOptions = providerOptions
        self.allowEmptyProvider = allowEmptyProvider
        self.onSave = onSave
        _draftProvider = State(initialValue: provider.isEmpty && !allowEmptyProvider ? "auto" : provider)
        _draftModel = State(initialValue: model)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.hermesActionBlue)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.hermesSecondaryText)
                }
                Spacer()
                if saved {
                    Label("Saved", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                }
            }

            Picker("Provider", selection: $draftProvider) {
                if allowEmptyProvider {
                    Text("Unset / inherit default").tag("")
                }
                ForEach(providerOptions) { option in
                    Text(option.label).tag(option.value)
                }
                if !provider.isEmpty && !providerOptions.contains(where: { $0.value == provider }) {
                    Text(provider).tag(provider)
                }
            }
            .pickerStyle(.menu)

            TextField("Model, e.g. anthropic/claude-sonnet-4", text: $draftModel)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 10) {
                Button("Save") {
                    onSave(draftProvider.trimmedForHermes, draftModel.trimmedForHermes)
                    saved = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { saved = false }
                }
                .buttonStyle(.borderedProminent)

                Button("Reset Draft") {
                    draftProvider = provider.isEmpty && !allowEmptyProvider ? "auto" : provider
                    draftModel = model
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.hermesSurfaceInput, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onChange(of: provider) { _, newValue in
            draftProvider = newValue.isEmpty && !allowEmptyProvider ? "auto" : newValue
        }
        .onChange(of: model) { _, newValue in
            draftModel = newValue
        }
    }
}

private enum HermesLocalConfigurationSection: String, CaseIterable, Hashable {
    case skills, profiles, tools, mcpServers, schedules, models

    init(title: String) {
        switch title {
        case "Skills": self = .skills
        case "Profiles": self = .profiles
        case "Tools": self = .tools
        case "MCP Servers": self = .mcpServers
        case "Schedules": self = .schedules
        case "Models": self = .models
        default: self = .skills
        }
    }
}

private struct HermesConfigurationValidationError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

private extension String {
    var trimmedForHermes: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

@MainActor
private final class HermesLocalConfigurationRuntime: ObservableObject {
    @Published var outputs: [HermesLocalConfigurationSection: String] = [:]
    @Published var runningSections: Set<HermesLocalConfigurationSection> = []

    private let hermesExecutable = "/Users/laurent/.hermes/hermes-agent/venv/bin/hermes"
    let hermesHome = "/Volumes/WDBlack4TB/.hermes"
    var remoteHostName = defaultHermesMacHost

    func refreshAll() {
    }

    func run(_ section: HermesLocalConfigurationSection, _ arguments: [String]) {
        let cleanArguments = arguments.map { $0.trimmedForHermes }.filter { !$0.isEmpty }
        guard cleanArguments.isEmpty == false else { return }
        runningSections.insert(section)
        outputs[section] = "$ hermes \(cleanArguments.joined(separator: " "))\nRunning…"
        Task.detached(priority: .userInitiated) { [hermesExecutable, hermesHome, remoteHostName] in
            let result = Self.execute(executable: hermesExecutable, arguments: cleanArguments, hermesHome: hermesHome, remoteHostName: remoteHostName)
            await MainActor.run {
                self.outputs[section] = result
                self.runningSections.remove(section)
            }
        }
    }

    func runChained(_ section: HermesLocalConfigurationSection, _ commands: [[String]]) {
        runningSections.insert(section)
        outputs[section] = "Running \(commands.count) local Hermes commands…"
        Task.detached(priority: .userInitiated) { [hermesExecutable, hermesHome, remoteHostName] in
            let combined = commands.map { command in
                Self.execute(executable: hermesExecutable, arguments: command.map { $0.trimmedForHermes }.filter { !$0.isEmpty }, hermesHome: hermesHome, remoteHostName: remoteHostName)
            }.joined(separator: "\n\n")
            await MainActor.run {
                self.outputs[section] = combined
                self.runningSections.remove(section)
            }
        }
    }

    func installSkill(from source: String, completion: @escaping @MainActor () -> Void) {
        let trimmedSource = source.trimmedForHermes
        guard !trimmedSource.isEmpty else { return }
        runningSections.insert(.skills)
        outputs[.skills] = "$ hermes skills install \(trimmedSource)\nRunning…"
        Task.detached(priority: .userInitiated) { [hermesExecutable, hermesHome, remoteHostName] in
            let result = Self.execute(executable: hermesExecutable, arguments: ["skills", "install", trimmedSource], hermesHome: hermesHome, remoteHostName: remoteHostName)
            await MainActor.run {
                self.outputs[.skills] = result
                self.runningSections.remove(.skills)
                completion()
            }
        }
    }

    func addMCPServer(name: String, command: String, args: [String], completion: @escaping @MainActor () -> Void) {
        let cleanName = name.trimmedForHermes
        let cleanCommand = command.trimmedForHermes
        guard !cleanName.isEmpty, !cleanCommand.isEmpty else { return }
        let cleanArgs = args.map { $0.trimmedForHermes }.filter { !$0.isEmpty }
        let arguments = ["mcp", "add", cleanName, "--command", cleanCommand] + (cleanArgs.isEmpty ? [] : ["--args"] + cleanArgs)
        runningSections.insert(.mcpServers)
        outputs[.mcpServers] = "$ hermes \(arguments.joined(separator: " "))\nRunning…"
        Task.detached(priority: .userInitiated) { [hermesExecutable, hermesHome, remoteHostName] in
            let result = Self.execute(executable: hermesExecutable, arguments: arguments, hermesHome: hermesHome, remoteHostName: remoteHostName)
            await MainActor.run {
                self.outputs[.mcpServers] = result
                self.runningSections.remove(.mcpServers)
                completion()
            }
        }
    }

    private nonisolated static func execute(executable: String, arguments: [String], hermesHome: String, remoteHostName: String) -> String {
        let process = Process()
        let normalizedHost = HermesHostEndpoints.normalizedHost(remoteHostName)
        let isRemote = !HermesSSHHostCredentials.isLocalHost(normalizedHost)
        let commandLabel = "$ hermes \(arguments.joined(separator: " "))"
        var temporaryIdentityURL: URL?
        defer {
            if let temporaryIdentityURL { try? FileManager.default.removeItem(at: temporaryIdentityURL) }
        }

        if isRemote {
            let credentials = HermesSettingsStore.loadSSHCredentials(forHost: normalizedHost)
            let username = credentials.username.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !username.isEmpty else { return "\(commandLabel)\nSSH settings missing for \(normalizedHost): enter a username in Settings." }
            do { temporaryIdentityURL = try HermesSSHKeychain.temporaryIdentityFile(forHost: normalizedHost) }
            catch { return "\(commandLabel)\nSSH settings missing for \(normalizedHost): \(error.localizedDescription)" }
            let remoteCommand = HermesShellQuoting.command(
                executable,
                arguments: arguments,
                environment: ["HERMES_HOME": hermesHome, "TERM": "xterm-256color"]
            )
            process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
            process.arguments = [
                "-i", temporaryIdentityURL!.path,
                "-o", "BatchMode=yes",
                "-o", "IdentitiesOnly=yes",
                "-o", "StrictHostKeyChecking=accept-new",
                "\(username)@\(normalizedHost)",
                remoteCommand
            ]
        } else {
            process.executableURL = FileManager.default.isExecutableFile(atPath: executable) ? URL(fileURLWithPath: executable) : URL(fileURLWithPath: "/opt/homebrew/bin/hermes")
            process.arguments = arguments
            var environment = ProcessInfo.processInfo.environment
            environment["HERMES_HOME"] = hermesHome
            environment["TERM"] = environment["TERM"] ?? "xterm-256color"
            process.environment = environment
        }

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            DispatchQueue.global().asyncAfter(deadline: .now() + 120) {
                if process.isRunning { process.terminate() }
            }
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let text = String(data: data, encoding: .utf8) ?? ""
            let status = isRemote ? "ssh \(normalizedHost) exit \(process.terminationStatus)" : "exit \(process.terminationStatus)"
            return [commandLabel, status, text.isEmpty ? "No output." : text].joined(separator: "\n")
        } catch {
            return "Failed to run hermes \(arguments.joined(separator: " ")): \(error.localizedDescription)"
        }
    }

}
