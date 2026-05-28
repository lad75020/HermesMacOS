//
//  SettingsView.swift
//  HermesMacOS
//

import AppKit
import SwiftUI

struct SettingsView: View {
    @AppStorage("hermes.appTheme") private var appTheme: HermesAppTheme = .system
    @AppStorage("hermes.appLanguage") private var appLanguage: HermesAppLanguageSelection = .automatic
    @AppStorage("hermes.macOS.titleFont") private var titleFont: HermesWebsiteFont = .rulesExpanded
    @AppStorage("hermes.macOS.labelFont") private var labelFont: HermesWebsiteFont = .mondwest
    @AppStorage("hermes.macOS.chatBubbleFontSize") private var chatBubbleFontSize = 14.0
    @AppStorage("hermes.macOS.promptFontSize") private var promptFontSize = 14.0
    @AppStorage(hermesSpeechToTextEngineStorageKey) private var speechToTextEngine: HermesSpeechToTextEngine = .appleLocal
    @State private var apiSettings = HermesSettingsStore.loadAPISettings()
    @State private var draft = HermesSettingsStore.loadDraft()
    @State private var chatDraft = HermesSettingsStore.loadChatDraft()
    @State private var savedEndpoints = HermesSettingsStore.loadSavedEndpoints()
    @State private var selectedEndpointID = HermesSettingsStore.loadSelectedEndpointID()
    @State private var sshCredentials = HermesSettingsStore.loadSSHCredentials(forHost: HermesSettingsStore.loadAPISettings().hostName)
    @State private var sshKeyStatusMessage = ""
    @State private var selectedWindowID = ""
    @State private var isApplyingSavedEndpoint = false
    @State private var connectionCenter = HermesWindowConnectionCenter.shared
    @AppStorage(hermesDashboardURLStorageKey) private var dashboardURL = defaultHermesDashboardURL

    var body: some View {
        ZStack {
            HermesLiquidGlassCanvas().ignoresSafeArea()
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: $appTheme) {
                        ForEach(HermesAppTheme.allCases) { theme in
                            Text(theme.title).tag(theme)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text("Choose a fixed light or dark appearance, or follow the macOS system theme.")
                        .font(.caption)
                        .foregroundStyle(Color.hermesSecondaryText)
                    Divider()
                    Picker("App language", selection: $appLanguage) {
                        Text("Automatic (System)").tag(HermesAppLanguageSelection.automatic)
                        ForEach(HermesAppLanguageSelection.forcedLanguages) { language in
                            Text(language.title).tag(language)
                        }
                    }
                    Text("Automatic uses the macOS language when Hermes supports it, otherwise English. You can force any supported language.")
                        .font(.caption)
                        .foregroundStyle(Color.hermesSecondaryText)
                    Divider()
                    Picker("Title font", selection: $titleFont) {
                        ForEach(HermesWebsiteFont.allCases) { font in
                            Text(font.title).tag(font)
                        }
                    }
                    Picker("Label font", selection: $labelFont) {
                        ForEach(HermesWebsiteFont.allCases) { font in
                            Text(font.title).tag(font)
                        }
                    }
                    Button("Restore website fonts") {
                        titleFont = .rulesExpanded
                        labelFont = .mondwest
                    }
                    Text("Titles default to the dashboard’s Rules Expanded look; compact labels default to Mondwest. Chat bubbles and prompt composer fonts stay controlled separately below.")
                        .font(.caption)
                        .foregroundStyle(Color.hermesSecondaryText)
                    Divider()
                    Stepper("Chat bubble font: \(Int(chatBubbleFontSize)) pt", value: $chatBubbleFontSize, in: 11...24, step: 1)
                    Stepper("Prompt area font: \(Int(promptFontSize)) pt", value: $promptFontSize, in: 11...24, step: 1)
                    Button("Restore default font sizes") {
                        chatBubbleFontSize = 14
                        promptFontSize = 14
                    }
                    Text("Adjust the text size used in Ask Hermes chat bubbles and in the prompt composer.")
                        .font(.caption)
                        .foregroundStyle(Color.hermesSecondaryText)
                }

                Section("Speech to text") {
                    Picker("Transcription engine", selection: $speechToTextEngine) {
                        ForEach(HermesSpeechToTextEngine.allCases) { engine in
                            Text(engine.title).tag(engine)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text(speechToTextEngine.description)
                        .font(.caption)
                        .foregroundStyle(Color.hermesSecondaryText)
                    Text("The selected engine is used by the microphone button in both Ask Hermes and Chat with Hermes prompt composers.")
                        .font(.caption)
                        .foregroundStyle(Color.hermesSecondaryText)
                }

                Section("Hermes API") {
                    if !connectionCenter.windowConnections.isEmpty {
                        Picker("Apply host to window", selection: $selectedWindowID) {
                            ForEach(connectionCenter.windowConnections) { window in
                                Text(window.title).tag(window.id.uuidString)
                            }
                        }
                        Text("Changes below apply only to the selected Hermes window. Other open windows keep their current host.")
                            .font(.caption)
                            .foregroundStyle(Color.hermesSecondaryText)
                    } else {
                        Text("Open a Hermes window to target a host from Settings.")
                            .font(.caption)
                            .foregroundStyle(Color.hermesSecondaryText)
                    }

                    if !savedEndpoints.isEmpty {
                        Picker("Saved connection", selection: $selectedEndpointID) {
                            Text("Choose saved URL…").tag("")
                            ForEach(savedEndpoints) { endpoint in
                                Text(endpoint.title).tag(endpoint.id)
                            }
                        }
                        Text(selectedEndpointDescription)
                            .font(.caption)
                            .foregroundStyle(Color.hermesSecondaryText)
                    }
                    TextField("Base URL", text: $apiSettings.baseURL)
                        .textFieldStyle(.roundedBorder)
                    SecureField("API key", text: $apiSettings.apiKey)
                        .textFieldStyle(.roundedBorder)
                    Toggle("Allow self-signed certificates", isOn: $apiSettings.allowSelfSignedCertificates)
                    HStack {
                        Button("Save current URLs") { saveCurrentEndpoint() }
                            .disabled(currentEndpointURLsAreEmpty)
                        if selectedSavedEndpoint != nil {
                            Button("Remove selected URL") { removeSelectedEndpoint() }
                        }
                        Button("Restore default endpoint") {
                            apiSettings.baseURL = HermesHostEndpoints.httpURLString(host: defaultHermesMacHost, port: defaultHermesAPIPort, path: "/v1")
                            announceConnectionEndpointChange()
                        }
                    }
                    Text("Saved connections store an API URL together with its matching dashboard URL. Selecting one switches the selected Hermes window, not every open window.")
                        .font(.caption)
                        .foregroundStyle(Color.hermesSecondaryText)

                    if currentAPIHostIsRemote {
                        Divider()
                        VStack(alignment: .leading, spacing: 8) {
                            Text("SSH for \(currentAPIHost)")
                                .font(.headline)
                            TextField("SSH username", text: $sshCredentials.username)
                                .textFieldStyle(.roundedBorder)
                            HStack(spacing: 10) {
                                Button("Choose private SSH key…") { chooseSSHPrivateKey() }
                                if sshCredentials.hasPrivateKey {
                                    Button("Remove key") { removeSSHPrivateKey() }
                                }
                                Spacer()
                            }
                            Text(sshKeyStatusText)
                                .font(.caption)
                                .foregroundStyle(Color.hermesSecondaryText)
                        }
                        Text("For non-local hosts, HermesMacOS runs local system calls over SSH with this username and the private key stored in Keychain. The key is written only to a temporary 0600 identity file while ssh is running.")
                            .font(.caption)
                            .foregroundStyle(Color.hermesSecondaryText)
                    }
                }

                Section("Hermes Dashboard") {
                    TextField("Dashboard URL", text: $dashboardURL)
                        .textFieldStyle(.roundedBorder)
                    Button("Restore default dashboard") {
                        dashboardURL = defaultHermesDashboardURL
                        announceConnectionEndpointChange()
                    }
                }

                Section("Ask Hermes defaults") {
                    TextField("Default profile", text: $draft.profile)
                    Toggle("Stream Responses API output", isOn: $draft.stream)
                    Picker("Default reasoning level", selection: $draft.reasoningLevel) {
                        ForEach(HermesReasoningLevel.allCases.filter { $0 != .off }) { level in
                            Text(level.title).tag(level)
                        }
                    }
                    TextEditor(text: $draft.userPrompt)
                        .frame(minHeight: 100)
                }

                Section("Chat with Hermes defaults") {
                    TextField("Default profile", text: $chatDraft.profile)
                    Toggle("Stream Chat Completions output", isOn: $chatDraft.stream)
                    TextField("Common system prompt (optional)", text: $chatDraft.systemPrompt, axis: .vertical)
                        .lineLimit(2...5)
                    TextEditor(text: $chatDraft.userPrompt)
                        .frame(minHeight: 100)
                }
            }
            .scrollContentBackground(.hidden)
            .formStyle(.grouped)
        }
        .preferredColorScheme(appTheme.colorScheme)
        .padding()
        .frame(minWidth: 560, minHeight: 420)
        .onAppear {
            ensureSelectedWindowTarget()
        }
        .onChange(of: activeWindowIDs) { _, _ in
            ensureSelectedWindowTarget()
        }
        .onChange(of: selectedWindowID) { _, _ in
            loadSelectedWindowConnection()
        }
        .onChange(of: apiSettings) { _, value in
            HermesSettingsStore.saveAPISettings(value)
            loadSSHCredentialsForCurrentHost()
            if !isApplyingSavedEndpoint {
                syncSelectedEndpointWithCurrentURLs()
                applyCurrentSettingsToSelectedWindow()
                announceConnectionEndpointChange()
            }
        }
        .onChange(of: dashboardURL) { _, _ in
            if !isApplyingSavedEndpoint {
                syncSelectedEndpointWithCurrentURLs()
                applyCurrentSettingsToSelectedWindow()
                announceConnectionEndpointChange()
            }
        }
        .onChange(of: selectedEndpointID) { _, newValue in
            HermesSettingsStore.saveSelectedEndpointID(newValue)
            applySelectedEndpoint(id: newValue)
        }
        .onChange(of: draft) { _, value in HermesSettingsStore.saveDraft(value) }
        .onChange(of: chatDraft) { _, value in HermesSettingsStore.saveChatDraft(value) }
        .onChange(of: sshCredentials) { _, value in saveCurrentSSHCredentials(value) }
    }

    private var currentAPIHost: String { apiSettings.hostName }
    private var currentAPIHostIsRemote: Bool { !HermesSSHHostCredentials.isLocalHost(currentAPIHost) }

    private var sshKeyStatusText: String {
        if !sshKeyStatusMessage.isEmpty { return sshKeyStatusMessage }
        if sshCredentials.hasPrivateKey {
            let label = sshCredentials.keyDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
            return label.isEmpty ? "Private key is stored in Keychain." : "Private key stored in Keychain: \(label)"
        }
        return "No private key stored for this host."
    }

    private var selectedSavedEndpoint: HermesSavedEndpoint? {
        savedEndpoints.first { $0.id == selectedEndpointID }
    }

    private var activeWindowIDs: [String] {
        connectionCenter.windowConnections.map { $0.id.uuidString }
    }

    private var selectedWindowUUID: UUID? {
        UUID(uuidString: selectedWindowID)
    }

    private var selectedWindowConnection: HermesWindowConnection? {
        guard let selectedWindowUUID else { return nil }
        return connectionCenter.connection(id: selectedWindowUUID)
    }

    private var selectedEndpointDescription: String {
        let fallback = selectedWindowConnection.map { "Pick a saved API/dashboard URL pair to switch \($0.title)." } ?? "Pick a saved API/dashboard URL pair, then choose a window to apply it."
        return selectedSavedEndpoint?.subtitle ?? fallback
    }

    private var currentEndpointURLsAreEmpty: Bool {
        apiSettings.baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && dashboardURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func ensureSelectedWindowTarget() {
        if selectedWindowConnection != nil { return }
        if let firstWindow = connectionCenter.windowConnections.first {
            selectedWindowID = firstWindow.id.uuidString
            loadConnection(firstWindow)
        }
    }

    private func loadSelectedWindowConnection() {
        guard let connection = selectedWindowConnection else { return }
        loadConnection(connection)
    }

    private func loadConnection(_ connection: HermesWindowConnection) {
        isApplyingSavedEndpoint = true
        apiSettings = connection.apiSettings
        dashboardURL = connection.dashboardURL
        syncSelectedEndpointWithCurrentURLs()
        DispatchQueue.main.async {
            isApplyingSavedEndpoint = false
        }
    }

    private func applyCurrentSettingsToSelectedWindow() {
        guard let selectedWindowUUID else { return }
        connectionCenter.applyEndpoint(to: selectedWindowUUID, apiSettings: apiSettings, dashboardURL: dashboardURL)
    }

    private func saveCurrentEndpoint() {
        let apiURL = apiSettings.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentDashboardURL = dashboardURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiURL.isEmpty || !currentDashboardURL.isEmpty else { return }

        if let existing = savedEndpoints.first(where: { $0.matches(apiURL: apiURL, dashboardURL: currentDashboardURL) }) {
            selectedEndpointID = existing.id
            HermesSettingsStore.saveSelectedEndpointID(existing.id)
            return
        }

        let endpoint = HermesSavedEndpoint(apiURL: apiURL, dashboardURL: currentDashboardURL)
        savedEndpoints.append(endpoint)
        saveSavedEndpoints()
        selectedEndpointID = endpoint.id
        HermesSettingsStore.saveSelectedEndpointID(endpoint.id)
    }

    private func removeSelectedEndpoint() {
        guard !selectedEndpointID.isEmpty else { return }
        savedEndpoints.removeAll { $0.id == selectedEndpointID }
        selectedEndpointID = ""
        saveSavedEndpoints()
        HermesSettingsStore.saveSelectedEndpointID("")
    }

    private func applySelectedEndpoint(id: String) {
        guard let endpoint = savedEndpoints.first(where: { $0.id == id }) else { return }
        isApplyingSavedEndpoint = true
        if apiSettings.baseURL != endpoint.apiURL { apiSettings.baseURL = endpoint.apiURL }
        if dashboardURL != endpoint.dashboardURL { dashboardURL = endpoint.dashboardURL }
        HermesSettingsStore.saveAPISettings(apiSettings)
        HermesSettingsStore.saveSelectedEndpointID(id)
        applyCurrentSettingsToSelectedWindow()
        announceConnectionEndpointChange()
        DispatchQueue.main.async {
            isApplyingSavedEndpoint = false
            syncSelectedEndpointWithCurrentURLs()
        }
    }

    private func syncSelectedEndpointWithCurrentURLs() {
        guard let matchingEndpoint = savedEndpoints.first(where: { $0.matches(apiURL: apiSettings.baseURL, dashboardURL: dashboardURL) }) else {
            if !selectedEndpointID.isEmpty {
                selectedEndpointID = ""
                HermesSettingsStore.saveSelectedEndpointID("")
            }
            return
        }
        if selectedEndpointID != matchingEndpoint.id {
            selectedEndpointID = matchingEndpoint.id
            HermesSettingsStore.saveSelectedEndpointID(matchingEndpoint.id)
        }
    }

    private func saveSavedEndpoints() {
        savedEndpoints.sort { left, right in
            left.title.localizedStandardCompare(right.title) == .orderedAscending
        }
        HermesSettingsStore.saveSavedEndpoints(savedEndpoints)
    }

    private func loadSSHCredentialsForCurrentHost() {
        let host = currentAPIHost
        sshCredentials = HermesSettingsStore.loadSSHCredentials(forHost: host)
        sshKeyStatusMessage = ""
    }

    private func saveCurrentSSHCredentials(_ value: HermesSSHHostCredentials) {
        guard currentAPIHostIsRemote else { return }
        var saved = value
        saved.host = currentAPIHost
        HermesSettingsStore.saveSSHCredentials(saved)
        if let index = savedEndpoints.firstIndex(where: { $0.matches(apiURL: apiSettings.baseURL, dashboardURL: dashboardURL) }) {
            savedEndpoints[index].sshUsername = saved.username
            savedEndpoints[index].sshKeyDisplayName = saved.keyDisplayName
            saveSavedEndpoints()
        }
    }

    private func chooseSSHPrivateKey() {
        let panel = NSOpenPanel()
        panel.title = "Choose private SSH key for \(currentAPIHost)"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: NSString(string: "~/.ssh").expandingTildeInPath, isDirectory: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            try HermesSSHKeychain.savePrivateKey(data, displayName: url.lastPathComponent, forHost: currentAPIHost)
            sshCredentials.host = currentAPIHost
            sshCredentials.keyDisplayName = url.lastPathComponent
            HermesSettingsStore.saveSSHCredentials(sshCredentials)
            sshKeyStatusMessage = "Private key loaded into Keychain."
        } catch {
            sshKeyStatusMessage = "Could not store key: \(error.localizedDescription)"
        }
    }

    private func removeSSHPrivateKey() {
        HermesSSHKeychain.deletePrivateKey(forHost: currentAPIHost)
        sshCredentials.keyDisplayName = ""
        HermesSettingsStore.saveSSHCredentials(sshCredentials)
        sshKeyStatusMessage = "Private key removed from Keychain."
    }

    private func announceConnectionEndpointChange() {
        NotificationCenter.default.post(name: .hermesConnectionEndpointDidChange, object: nil)
    }
}
