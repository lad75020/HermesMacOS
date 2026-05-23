//
//  HermesConfigurationView.swift
//  HermesMacOS
//

import SwiftUI
import WebKit

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
    @StateObject private var runtime = HermesLocalConfigurationRuntime()
    @State private var dashboardSkills = HermesDashboardSkillsStore()
    @State private var skillQuery = ""
    @State private var profileName = ""
    @State private var selectedTool = ""
    @State private var mcpName = ""
    @State private var mcpURL = ""
    @State private var mcpCommand = ""
    @State private var knowledgeQuery = ""
    @State private var scheduleName = ""
    @State private var scheduleExpression = ""
    @State private var schedulePrompt = ""
    @State private var scheduleID = ""
    @State private var modelProvider = ""
    @State private var modelName = ""
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

                runtimeSection(
                    title: "Profiles",
                    subtitle: "Manage local Hermes profiles directly on this Mac.",
                    systemImage: "person.crop.rectangle.stack",
                    output: runtime.outputs[.profiles]
                ) {
                    HStack {
                        TextField("Profile name", text: $profileName)
                        Button("List") { runtime.run(.profiles, ["profile", "list"]) }
                        Button("Show") { runtime.run(.profiles, ["profile", "show", profileName]) }
                            .disabled(profileName.trimmedForHermes.isEmpty)
                        Button("Use") { runtime.run(.profiles, ["profile", "use", profileName]) }
                            .disabled(profileName.trimmedForHermes.isEmpty)
                        Button("Create") { runtime.run(.profiles, ["profile", "create", profileName]) }
                            .disabled(profileName.trimmedForHermes.isEmpty)
                        Button("Delete") { runtime.run(.profiles, ["profile", "delete", profileName]) }
                            .disabled(profileName.trimmedForHermes.isEmpty)
                    }
                }

                runtimeSection(
                    title: "Tools",
                    subtitle: "Enable or disable toolsets for new Hermes sessions.",
                    systemImage: "wrench.and.screwdriver",
                    output: runtime.outputs[.tools]
                ) {
                    HStack {
                        TextField("Toolset name", text: $selectedTool)
                        Button("List") { runtime.run(.tools, ["tools", "list"]) }
                        Button("Enable") { runtime.run(.tools, ["tools", "enable", selectedTool]) }
                            .disabled(selectedTool.trimmedForHermes.isEmpty)
                        Button("Disable") { runtime.run(.tools, ["tools", "disable", selectedTool]) }
                            .disabled(selectedTool.trimmedForHermes.isEmpty)
                    }
                }

                runtimeSection(
                    title: "MCP Servers",
                    subtitle: "List, add, test, configure, or remove MCP servers in local config.yaml.",
                    systemImage: "point.3.connected.trianglepath.dotted",
                    output: runtime.outputs[.mcpServers]
                ) {
                    HStack {
                        TextField("Server name", text: $mcpName)
                        Button("List") { runtime.run(.mcpServers, ["mcp", "list"]) }
                        Button("Test") { runtime.run(.mcpServers, ["mcp", "test", mcpName]) }
                            .disabled(mcpName.trimmedForHermes.isEmpty)
                        Button("Remove") { runtime.run(.mcpServers, ["mcp", "remove", mcpName]) }
                            .disabled(mcpName.trimmedForHermes.isEmpty)
                    }
                    HStack {
                        TextField("MCP URL", text: $mcpURL)
                        Button("Add URL") { runtime.run(.mcpServers, ["mcp", "add", mcpName, "--url", mcpURL]) }
                            .disabled(mcpName.trimmedForHermes.isEmpty || mcpURL.trimmedForHermes.isEmpty)
                    }
                    HStack {
                        TextField("Command", text: $mcpCommand)
                        Button("Add Command") { runtime.run(.mcpServers, ["mcp", "add", mcpName, "--command", mcpCommand]) }
                            .disabled(mcpName.trimmedForHermes.isEmpty || mcpCommand.trimmedForHermes.isEmpty)
                    }
                }

                runtimeSection(
                    title: "Knowledge Eraser",
                    subtitle: "Search local Hermes knowledge and open files for review or removal.",
                    systemImage: "eraser.line.dashed.fill",
                    output: runtime.outputs[.knowledge]
                ) {
                    HStack {
                        TextField("Topic, phrase, or filename", text: $knowledgeQuery)
                        Button("Search") { runtime.searchKnowledge(knowledgeQuery) }
                            .disabled(knowledgeQuery.trimmedForHermes.isEmpty)
                        Button("Open Knowledge Folder") { runtime.openHermesSubfolder("knowledge") }
                        Button("Open Memory Folder") { runtime.openHermesSubfolder("memory") }
                    }
                    Text("For safety, erasing opens the local files for review instead of deleting broad matches automatically.")
                        .font(.caption)
                        .foregroundStyle(Color.hermesSecondaryText)
                }

                runtimeSection(
                    title: "Schedules",
                    subtitle: "Manage local Hermes cron jobs.",
                    systemImage: "calendar.badge.clock",
                    output: runtime.outputs[.schedules]
                ) {
                    HStack {
                        TextField("Job ID", text: $scheduleID)
                        Button("List") { runtime.run(.schedules, ["cron", "list", "--all"]) }
                        Button("Run") { runtime.run(.schedules, ["cron", "run", scheduleID]) }
                            .disabled(scheduleID.trimmedForHermes.isEmpty)
                        Button("Pause") { runtime.run(.schedules, ["cron", "pause", scheduleID]) }
                            .disabled(scheduleID.trimmedForHermes.isEmpty)
                        Button("Resume") { runtime.run(.schedules, ["cron", "resume", scheduleID]) }
                            .disabled(scheduleID.trimmedForHermes.isEmpty)
                        Button("Remove") { runtime.run(.schedules, ["cron", "remove", scheduleID]) }
                            .disabled(scheduleID.trimmedForHermes.isEmpty)
                    }
                    HStack {
                        TextField("Name", text: $scheduleName)
                        TextField("Schedule, e.g. every 2h", text: $scheduleExpression)
                        TextField("Prompt", text: $schedulePrompt)
                        Button("Create") {
                            var args = ["cron", "create", scheduleExpression, schedulePrompt]
                            if !scheduleName.trimmedForHermes.isEmpty { args += ["--name", scheduleName] }
                            runtime.run(.schedules, args)
                        }
                        .disabled(scheduleExpression.trimmedForHermes.isEmpty || schedulePrompt.trimmedForHermes.isEmpty)
                    }
                }

                runtimeSection(
                    title: "Models",
                    subtitle: "Inspect and update local provider/model routing.",
                    systemImage: "cpu",
                    output: runtime.outputs[.models]
                ) {
                    HStack {
                        TextField("Provider", text: $modelProvider)
                        TextField("Model", text: $modelName)
                        Button("Current Config") { runtime.run(.models, ["config"]) }
                        Button("Set") {
                            runtime.runChained(.models, [
                                ["config", "set", "model.provider", modelProvider],
                                ["config", "set", "model.default", modelName]
                            ])
                        }
                        .disabled(modelProvider.trimmedForHermes.isEmpty || modelName.trimmedForHermes.isEmpty)
                    }
                }
            }
            .padding(18)
        }
        .background(HermesLiquidGlassCanvas().ignoresSafeArea())
        .onAppear { refreshConfiguration() }
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

    private var dashboardSkillsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.hermesActionBlue)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Skills")
                        .hermesWebsiteTitleFont(size: 17, weight: .bold)
                    Text("Loaded from Hermes Dashboard /api/skills. Toggle status via /api/skills/toggle.")
                        .font(.caption)
                        .foregroundStyle(Color.hermesSecondaryText)
                }
                Spacer()
                if dashboardSkills.isLoading { ProgressView().controlSize(.small) }
                Button {
                    dashboardSkills.refreshForManagement(dashboardBaseURL: dashboardURL, apiSettings: apiSettings)
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.bordered)
                .help("Refresh skills from Hermes Dashboard")
            }

            HStack {
                TextField("Filter by name, description, category, or status", text: $skillQuery)
                    .textFieldStyle(.roundedBorder)
                Text("\(filteredDashboardSkills.count)/\(dashboardSkills.skills.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color.hermesSecondaryText)
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
        .padding(16)
        .hermesGlassPanel(cornerRadius: 18)
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

    private var localSystemBanner: some View {
        Label("Configuration uses the Hermes Dashboard for skills and direct local system calls for the remaining macOS runtime controls, without HermesHostCompanion.", systemImage: "desktopcomputer")
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
        output: String?,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.hermesActionBlue)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .hermesWebsiteTitleFont(size: 17, weight: .bold)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.hermesSecondaryText)
                }
                Spacer()
                if runtime.runningSections.contains(HermesLocalConfigurationSection(title: title)) {
                    ProgressView().controlSize(.small)
                }
            }
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
        .padding(16)
        .hermesGlassPanel(cornerRadius: 18)
    }
}

private enum HermesLocalConfigurationSection: String, CaseIterable, Hashable {
    case skills, profiles, tools, mcpServers, knowledge, schedules, models

    init(title: String) {
        switch title {
        case "Skills": self = .skills
        case "Profiles": self = .profiles
        case "Tools": self = .tools
        case "MCP Servers": self = .mcpServers
        case "Knowledge Eraser": self = .knowledge
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
    private let hermesHome = "/Volumes/WDBlack4TB/.hermes"

    func refreshAll() {
        run(.profiles, ["profile", "list"])
        run(.tools, ["tools", "list"])
        run(.mcpServers, ["mcp", "list"])
        searchKnowledge("")
        run(.schedules, ["cron", "list", "--all"])
        run(.models, ["config"])
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

    func searchKnowledge(_ query: String) {
        let trimmed = query.trimmedForHermes
        runningSections.insert(.knowledge)
        outputs[.knowledge] = trimmed.isEmpty ? "Scanning local Hermes knowledge folders…" : "Searching local Hermes knowledge for \"\(trimmed)\"…"
        Task.detached(priority: .userInitiated) { [hermesHome] in
            let result = Self.executeKnowledgeSearch(query: trimmed, hermesHome: hermesHome)
            await MainActor.run {
                self.outputs[.knowledge] = result
                self.runningSections.remove(.knowledge)
            }
        }
    }

    func openHermesSubfolder(_ name: String) {
        let path = "\(hermesHome)/\(name)"
        _ = try? Process.run(URL(fileURLWithPath: "/usr/bin/open"), arguments: [path])
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

    private nonisolated static func executeKnowledgeSearch(query: String, hermesHome: String) -> String {
        let roots = ["knowledge", "memory", "skills"].map { URL(fileURLWithPath: hermesHome).appendingPathComponent($0) }
        let fileManager = FileManager.default
        var matches: [String] = []
        for root in roots where fileManager.fileExists(atPath: root.path) {
            guard let enumerator = fileManager.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else { continue }
            for case let fileURL as URL in enumerator {
                guard (try? fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { continue }
                guard ["md", "txt", "json", "yaml", "yml"].contains(fileURL.pathExtension.lowercased()) else { continue }
                if query.isEmpty {
                    matches.append(fileURL.path)
                } else if let content = try? String(contentsOf: fileURL, encoding: .utf8), content.localizedCaseInsensitiveContains(query) || fileURL.lastPathComponent.localizedCaseInsensitiveContains(query) {
                    matches.append(fileURL.path)
                }
                if matches.count >= 200 { break }
            }
        }
        if matches.isEmpty { return query.isEmpty ? "No local knowledge files found." : "No matches for \"\(query)\"." }
        return matches.prefix(200).joined(separator: "\n")
    }
}
