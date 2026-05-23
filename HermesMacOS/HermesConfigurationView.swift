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
    @StateObject private var runtime = HermesLocalConfigurationRuntime()
    @State private var dashboardSkills = HermesDashboardSkillsStore()
    @State private var dashboardToolsets = HermesDashboardToolsetsStore()
    @State private var dashboardMCPServers = HermesDashboardMCPServersStore()
    @State private var dashboardSchedules = HermesDashboardSchedulesStore()
    @State private var localRuntimeModels = HermesLocalRuntimeModelsStore()
    @State private var localProfiles = HermesLocalProfilesStore()
    @State private var skillQuery = ""
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
    @State private var mcpCommand = ""
    @State private var mcpArgs = ""
    @State private var mcpValidationMessage = ""
    @State private var scheduleName = ""
    @State private var scheduleExpression = ""
    @State private var schedulePrompt = ""
    @State private var scheduleSkillName = ""
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

                localProfilesSection

                dashboardToolsetsSection

                dashboardMCPServersSection

                dashboardSchedulesSection

                localRuntimeModelsSection
            }
            .padding(18)
        }
        .background(HermesLiquidGlassCanvas().ignoresSafeArea())
        .onAppear { refreshConfiguration() }
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
            job.contentPreview.localizedCaseInsensitiveContains(query)
        }
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
        let command = mcpCommand.trimmedForHermes
        guard !name.isEmpty, !command.isEmpty else {
            mcpValidationMessage = "Enter an MCP server name and command."
            return
        }
        let args = splitMCPArguments(mcpArgs)
        mcpValidationMessage = ""
        runtime.addMCPServer(name: name, command: command, args: args) {
            mcpName = ""
            mcpCommand = ""
            mcpArgs = ""
            dashboardMCPServers.refresh(dashboardBaseURL: dashboardURL, apiSettings: apiSettings)
        }
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
            title: "MCP Servers",
            subtitle: "Loaded from Hermes Dashboard config. Delete through dashboard config; add command servers locally with hermes mcp add.",
            systemImage: "point.3.connected.trianglepath.dotted",
            isExpanded: $isMCPServersExpanded,
            output: runtime.outputs[.mcpServers]
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    TextField("Search MCP servers", text: $mcpQuery)
                    Button {
                        dashboardMCPServers.refresh(dashboardBaseURL: dashboardURL, apiSettings: apiSettings)
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .disabled(dashboardMCPServers.isLoading)
                }

                HStack {
                    TextField("Name", text: $mcpName)
                    TextField("Command", text: $mcpCommand)
                    TextField("Args, e.g. -y package@latest", text: $mcpArgs)
                    Button("Add") { addMCPServer() }
                        .disabled(mcpName.trimmedForHermes.isEmpty || mcpCommand.trimmedForHermes.isEmpty || runtime.runningSections.contains(.mcpServers))
                }
                Text("Add uses local CLI: hermes mcp add <NAME> --command <COMMAND> --args <ARGS>.")
                    .font(.caption)
                    .foregroundStyle(Color.hermesSecondaryText)
                if !mcpValidationMessage.isEmpty {
                    Text(mcpValidationMessage)
                        .font(.caption)
                        .foregroundStyle(Color.orange)
                }

                if dashboardMCPServers.isLoading {
                    ProgressView("Loading MCP servers from dashboard…")
                        .controlSize(.small)
                } else if !dashboardMCPServers.lastErrorMessage.isEmpty {
                    Text(dashboardMCPServers.lastErrorMessage)
                        .font(.caption)
                        .foregroundStyle(Color.orange)
                } else if filteredDashboardMCPServers.isEmpty {
                    Text("No MCP servers found in dashboard config.")
                        .font(.caption)
                        .foregroundStyle(Color.hermesSecondaryText)
                } else {
                    VStack(spacing: 8) {
                        ForEach(filteredDashboardMCPServers) { server in
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 5) {
                                    HStack(spacing: 8) {
                                        Text(server.name)
                                            .font(.headline)
                                        Text(server.transportLabel)
                                            .font(.caption.weight(.semibold))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 2)
                                            .background(Color.hermesActionBlue.opacity(0.16), in: Capsule())
                                            .foregroundStyle(Color.hermesActionBlue)
                                        Text(server.statusLabel)
                                            .font(.caption.weight(.semibold))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 2)
                                            .background((server.disabled ? Color.gray : Color.green).opacity(0.16), in: Capsule())
                                            .foregroundStyle(server.disabled ? Color.hermesSecondaryText : Color.green)
                                    }
                                    Text(server.primaryDetail)
                                        .font(.caption.monospaced())
                                        .foregroundStyle(Color.hermesSecondaryText)
                                }
                                Spacer()
                                Button(role: .destructive) {
                                    dashboardMCPServers.deleteServer(server, dashboardBaseURL: dashboardURL, apiSettings: apiSettings)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .disabled(dashboardMCPServers.isLoading)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
                        }
                    }
                }
            }
        }
    }

    private var dashboardSchedulesSection: some View {
        runtimeSection(
            title: "Schedules",
            subtitle: "Loaded from Hermes Dashboard /api/cron/jobs. Enable, disable, and create cron schedules without hermes cron list.",
            systemImage: "calendar.badge.clock",
            isExpanded: $isSchedulesExpanded,
            output: dashboardSchedules.lastErrorMessage
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    TextField("Search schedules", text: $scheduleQuery)
                    Button {
                        dashboardSchedules.refresh(dashboardBaseURL: dashboardURL, apiSettings: apiSettings)
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .disabled(dashboardSchedules.isLoading)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        TextField("Name", text: $scheduleName)
                        TextField("Schedule, e.g. every 2h or 0 9 * * *", text: $scheduleExpression)
                    }
                    TextField("Content / prompt", text: $schedulePrompt, axis: .vertical)
                        .lineLimit(2...5)
                    HStack {
                        TextField("Optional skill name to execute", text: $scheduleSkillName)
                        Button {
                            addSchedule()
                        } label: {
                            Label("Add schedule", systemImage: "plus.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(scheduleName.trimmedForHermes.isEmpty || scheduleExpression.trimmedForHermes.isEmpty || (schedulePrompt.trimmedForHermes.isEmpty && scheduleSkillName.trimmedForHermes.isEmpty) || dashboardSchedules.isLoading)
                    }
                    Text("Provide content, a skill name, or both. Skill-backed jobs are created through the dashboard API and annotated with the selected skill.")
                        .font(.caption)
                        .foregroundStyle(Color.hermesSecondaryText)
                }
                .padding(12)
                .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

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

    private func addSchedule() {
        dashboardSchedules.createSchedule(
            name: scheduleName,
            schedule: scheduleExpression,
            prompt: schedulePrompt,
            skillName: scheduleSkillName,
            dashboardBaseURL: dashboardURL,
            apiSettings: apiSettings
        )
        scheduleName = ""
        scheduleExpression = ""
        schedulePrompt = ""
        scheduleSkillName = ""
    }

    private func dashboardScheduleRow(_ job: HermesDashboardScheduleJob) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Toggle(isOn: Binding(
                get: { job.isEnabled },
                set: { enabled in
                    dashboardSchedules.setJobEnabled(job, enabled: enabled, dashboardBaseURL: dashboardURL, apiSettings: apiSettings)
                }
            )) {
                VStack(alignment: .leading, spacing: 5) {
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
                    }
                    Text(job.scheduleLabel)
                        .font(.caption.monospaced())
                        .foregroundStyle(Color.hermesSecondaryText)
                    if !job.skillLabel.isEmpty {
                        Text("Skill: \(job.skillLabel)")
                            .font(.caption)
                            .foregroundStyle(Color.hermesActionBlue)
                    }
                    Text(job.contentPreview)
                        .font(.caption)
                        .foregroundStyle(Color.hermesSecondaryText)
                        .lineLimit(2)
                    HStack(spacing: 12) {
                        Text("Next: \(job.nextRunAt ?? "—")")
                        Text("Last: \(job.lastRunAt ?? "—")")
                    }
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(Color.hermesSecondaryText.opacity(0.85))
                    if let lastError = job.lastError, !lastError.isEmpty {
                        Text(lastError)
                            .font(.caption)
                            .foregroundStyle(Color.orange)
                            .lineLimit(2)
                    }
                }
            }
            .toggleStyle(.switch)
            .disabled(dashboardSchedules.isLoading)
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

private extension String {
    var trimmedForHermes: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

@MainActor
private final class HermesLocalConfigurationRuntime: ObservableObject {
    @Published var outputs: [HermesLocalConfigurationSection: String] = [:]
    @Published var runningSections: Set<HermesLocalConfigurationSection> = []

    private let hermesExecutable = "/Users/laurent/.hermes/hermes-agent/venv/bin/hermes"
    let hermesHome = "/Volumes/WDBlack4TB/.hermes"

    func refreshAll() {
    }

    func run(_ section: HermesLocalConfigurationSection, _ arguments: [String]) {
        let cleanArguments = arguments.map { $0.trimmedForHermes }.filter { !$0.isEmpty }
        guard cleanArguments.isEmpty == false else { return }
        runningSections.insert(section)
        outputs[section] = "$ hermes \(cleanArguments.joined(separator: " "))\nRunning…"
        Task.detached(priority: .userInitiated) { [hermesExecutable, hermesHome] in
            let result = Self.execute(executable: hermesExecutable, arguments: cleanArguments, hermesHome: hermesHome)
            await MainActor.run {
                self.outputs[section] = result
                self.runningSections.remove(section)
            }
        }
    }

    func runChained(_ section: HermesLocalConfigurationSection, _ commands: [[String]]) {
        runningSections.insert(section)
        outputs[section] = "Running \(commands.count) local Hermes commands…"
        Task.detached(priority: .userInitiated) { [hermesExecutable, hermesHome] in
            let combined = commands.map { command in
                Self.execute(executable: hermesExecutable, arguments: command.map { $0.trimmedForHermes }.filter { !$0.isEmpty }, hermesHome: hermesHome)
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
        Task.detached(priority: .userInitiated) { [hermesExecutable, hermesHome] in
            let result = Self.execute(executable: hermesExecutable, arguments: ["skills", "install", trimmedSource], hermesHome: hermesHome)
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
        Task.detached(priority: .userInitiated) { [hermesExecutable, hermesHome] in
            let result = Self.execute(executable: hermesExecutable, arguments: arguments, hermesHome: hermesHome)
            await MainActor.run {
                self.outputs[.mcpServers] = result
                self.runningSections.remove(.mcpServers)
                completion()
            }
        }
    }

    private nonisolated static func execute(executable: String, arguments: [String], hermesHome: String) -> String {
        let process = Process()
        process.executableURL = FileManager.default.isExecutableFile(atPath: executable) ? URL(fileURLWithPath: executable) : URL(fileURLWithPath: "/opt/homebrew/bin/hermes")
        process.arguments = arguments
        var environment = ProcessInfo.processInfo.environment
        environment["HERMES_HOME"] = hermesHome
        environment["TERM"] = environment["TERM"] ?? "xterm-256color"
        process.environment = environment
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            DispatchQueue.global().asyncAfter(deadline: .now() + 120) {
                if process.isRunning {
                    process.terminate()
                }
            }
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let text = String(data: data, encoding: .utf8) ?? ""
            let command = "$ hermes \(arguments.joined(separator: " "))"
            let status = "exit \(process.terminationStatus)"
            return [command, status, text.isEmpty ? "No output." : text].joined(separator: "\n")
        } catch {
            return "Failed to run hermes \(arguments.joined(separator: " ")): \(error.localizedDescription)"
        }
    }

}
