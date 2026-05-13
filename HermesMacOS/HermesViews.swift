//
//  HermesViews.swift
//  HermesMacOS
//

import AppKit
import SwiftUI

struct HermesResponsesConsoleView: View {
    @Binding var apiSettings: HermesAPISettings
    @Binding var requestDraft: HermesRequestDraft
    @Bindable var responseSession: HermesResponsesSession
    @Bindable var promptHistoryStore: HermesPromptHistoryStore
    var workspaceControls = AnyView(EmptyView())

    @State private var apiProfiles: [HermesAPIProfile] = []
    @State private var selectedAttachment: HermesPromptAttachment?
    @State private var isImportingAttachment = false
    @State private var promptText = ""
    @State private var profileRefreshError = ""
    @State private var speechToText = HermesSpeechToTextSession()

    var body: some View {
        VStack(spacing: 0) {
            header
            transcript
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            composer
        }
        .background(HermesLiquidGlassCanvas().ignoresSafeArea())
        .task(id: apiSettings.baseURL) {
            if promptText.isEmpty { promptText = requestDraft.userPrompt }
            await refreshAPIProfiles()
        }
        .onChange(of: apiSettings) { _, _ in Task { await refreshAPIProfiles() } }
        .onChange(of: promptText) { _, text in requestDraft.userPrompt = text }
        .onDisappear { speechToText.stopTranscription() }
        .fileImporter(isPresented: $isImportingAttachment, allowedContentTypes: HermesPromptAttachment.supportedContentTypes, allowsMultipleSelection: false) { result in
            handleAttachmentImport(result)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Label("Ask Hermes", systemImage: "dot.radiowaves.left.and.right")
                    .font(.title2.weight(.semibold))
                workspaceControls
                Spacer()
                if responseSession.isStreaming {
                    ProgressView().controlSize(.small)
                    Text("Streaming")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.hermesSecondaryText)
                }
            }

            HStack(alignment: .top, spacing: 12) {
                HermesProfileSelector(
                    selectedProfile: $requestDraft.profile,
                    apiProfiles: apiProfiles,
                    lockedProfile: responseSession.activeProfile,
                    isDisabled: responseSession.isSending
                ) { newProfile in
                    if responseSession.activeProfile != newProfile {
                        responseSession.terminateAndStartNewSession()
                    }
                }

                HermesStatusCard(title: "Session", value: responseSession.displaySessionTitle, tint: .hermesPurple)
                HermesStatusCard(title: "Status", value: responseSession.connectionStatus, tint: .hermesOrange)
                HermesStatusCard(title: "Events", value: "\(responseSession.eventCount)", tint: .hermesActionBlue)
            }

            if !profileRefreshError.isEmpty {
                Label(profileRefreshError, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(Color.hermesDestructive)
            }
        }
        .padding(18)
        .background(.ultraThinMaterial)
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    if responseSession.entries.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Start a Responses session", systemImage: "bubble.left.and.bubble.right")
                                .font(.headline)
                            Text("Enter a prompt below. Your prompts and Hermes replies will appear here as chat bubbles for this session.")
                                .font(.subheadline)
                                .foregroundStyle(Color.hermesSecondaryText)
                            Text("The macOS tab uses the same Hermes Responses API flow as HermesiOS: profile selection, SSE streaming, cancellation, session continuation, and file/image attachments.")
                                .font(.caption)
                                .foregroundStyle(Color.hermesSecondaryText)
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .hermesCard(tint: Color.hermesActionBlue.opacity(0.08))
                    } else {
                        ForEach(responseSession.entries) { message in
                            HermesResponseBubble(message: message, isResponding: isResponsePlaceholder(message))
                                .id(message.id)
                        }
                    }
                    Color.clear.frame(height: 1).id(Self.transcriptBottomID)
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 16)
            }
            .onAppear { scrollToLatest(proxy, animated: false) }
            .onChange(of: responseSession.entries.count) { _, _ in scrollToLatest(proxy) }
            .onChange(of: responseSession.streamedText) { _, _ in scrollToLatest(proxy) }
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Spacer()
                if canResumeLastResponseSession {
                    Button { responseSession.resumeLastKnownResponseSession() } label: {
                        Label("Resume last", systemImage: "arrow.uturn.forward.circle")
                    }
                    .buttonStyle(.bordered)
                    .disabled(responseSession.isSending)
                }
                if responseSession.hasActiveConversation {
                    Button { responseSession.terminateAndStartNewSession() } label: {
                        Label("End Session", systemImage: "xmark.circle")
                    }
                    .buttonStyle(.bordered)
                }
                if responseSession.isSending {
                    Button("Cancel") { responseSession.cancel() }
                        .buttonStyle(.bordered)
                        .keyboardShortcut(.cancelAction)
                }
            }

            if !responseSession.lastErrorMessage.isEmpty {
                Text(responseSession.lastErrorMessage)
                    .font(.caption)
                    .foregroundStyle(Color.hermesDestructive)
            }

            if !speechToText.statusMessage.isEmpty || !speechToText.lastErrorMessage.isEmpty {
                Label(speechToText.lastErrorMessage.isEmpty ? speechToText.statusMessage : speechToText.lastErrorMessage,
                      systemImage: speechToText.lastErrorMessage.isEmpty ? "waveform" : "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(speechToText.lastErrorMessage.isEmpty ? Color.hermesSecondaryText : Color.hermesDestructive)
            }

            if let selectedAttachment {
                HermesAttachmentChip(attachment: selectedAttachment) { self.selectedAttachment = nil }
                    .disabled(responseSession.isSending)
            }

            HStack(alignment: .bottom, spacing: 12) {
                Button { isImportingAttachment = true } label: {
                    Image(systemName: selectedAttachment == nil ? "paperclip" : "paperclip.circle.fill")
                        .font(.headline)
                        .frame(width: 38, height: 38)
                }
                .buttonStyle(.bordered)
                .disabled(responseSession.isSending)
                .help(selectedAttachment == nil ? "Attach file" : "Change attached file")

                Button {
                    speechToText.toggleTranscription(currentPrompt: promptText) { updatedPrompt in
                        promptText = updatedPrompt
                    }
                } label: {
                    Image(systemName: speechToText.buttonSystemImage)
                        .font(.headline)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(speechToText.isRecording ? Color.hermesDestructive : Color.primary)
                        .frame(width: 38, height: 38)
                }
                .buttonStyle(.bordered)
                .disabled(responseSession.isSending || responseSession.isStreaming)
                .help(speechToText.buttonTitle)

                TextEditor(text: $promptText)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 78, maxHeight: 150)
                    .padding(8)
                    .background(Color.hermesSurfaceInput.opacity(responseSession.isStreaming ? 0.54 : 0.84), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .disabled(responseSession.isStreaming)
                    .help(responseSession.isStreaming ? "This workspace is streaming a response" : "Prompt")
                    .overlay(alignment: .topLeading) {
                        if promptText.isEmpty {
                            Text("Ask Hermes something...")
                                .foregroundStyle(Color.hermesSecondaryText)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 16)
                                .allowsHitTesting(false)
                        }
                    }

                Button {
                    submitPrompt()
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.headline)
                        .frame(width: 42, height: 42)
                }
                .buttonStyle(.borderedProminent)
                .disabled((promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedAttachment == nil) || responseSession.isSending)
                .keyboardShortcut(.return, modifiers: [.command])
                .help("Send prompt (⌘↩)")
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .onChange(of: responseSession.isStreaming) { _, isStreaming in
            if isStreaming { speechToText.stopTranscription() }
        }
    }

    private static let transcriptBottomID = "responses-transcript-bottom"

    private var canResumeLastResponseSession: Bool {
        let last = responseSession.lastKnownResponseID.trimmingCharacters(in: .whitespacesAndNewlines)
        return !last.isEmpty && responseSession.previousResponseID != last && responseSession.latestResponseID != last
    }

    private func isResponsePlaceholder(_ message: HermesResponseMessage) -> Bool {
        responseSession.isSending && message.role != "user" && message.content.isEmpty && responseSession.entries.last?.id == message.id
    }

    private func submitPrompt() {
        speechToText.stopTranscription()
        var submittedDraft = requestDraft
        submittedDraft.userPrompt = promptText
        responseSession.submit(apiSettings: apiSettings, draft: submittedDraft, attachment: selectedAttachment, historyStore: promptHistoryStore)
        promptText = ""
        requestDraft.userPrompt = ""
        selectedAttachment = nil
    }

    private func handleAttachmentImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                selectedAttachment = try HermesPromptAttachment.load(from: url)
                responseSession.lastErrorMessage = ""
            } catch {
                responseSession.lastErrorMessage = error.localizedDescription
            }
        case .failure(let error):
            responseSession.lastErrorMessage = error.localizedDescription
        }
    }

    private func refreshAPIProfiles() async {
        do {
            let profiles = try await HermesAPIProfilesClient.fetchProfiles(apiSettings: apiSettings)
            apiProfiles = profiles
            profileRefreshError = ""
            syncSelectedProfileWithAPIProfiles(profiles, selectedProfile: &requestDraft.profile)
        } catch {
            apiProfiles = []
            profileRefreshError = String(localized: "Profiles unavailable: \(error.localizedDescription)")
        }
    }

    private func syncSelectedProfileWithAPIProfiles(_ profiles: [HermesAPIProfile], selectedProfile: inout String) {
        let current = selectedProfile.trimmingCharacters(in: .whitespacesAndNewlines)
        if current.isEmpty { selectedProfile = profiles.first?.id ?? "default" }
        else if !profiles.isEmpty && !profiles.contains(where: { $0.id == current }) { selectedProfile = profiles.first?.id ?? "default" }
    }

    private func scrollToLatest(_ proxy: ScrollViewProxy, animated: Bool = true) {
        DispatchQueue.main.async {
            if animated {
                withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(Self.transcriptBottomID, anchor: .bottom) }
            } else {
                proxy.scrollTo(Self.transcriptBottomID, anchor: .bottom)
            }
        }
    }
}

private struct HermesProfileSelector: View {
    @Binding var selectedProfile: String
    let apiProfiles: [HermesAPIProfile]
    let lockedProfile: String
    let isDisabled: Bool
    let onProfileSelected: (String) -> Void

    private var currentProfile: String {
        let locked = lockedProfile.trimmingCharacters(in: .whitespacesAndNewlines)
        if !locked.isEmpty { return locked }
        let selected = selectedProfile.trimmingCharacters(in: .whitespacesAndNewlines)
        return selected.isEmpty ? "default" : selected
    }

    private var pickerProfiles: [HermesAPIProfile] {
        var seen = Set<String>()
        var unique = apiProfiles.filter { profile in
            let value = profile.id.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty, !seen.contains(value) else { return false }
            seen.insert(value)
            return true
        }
        if !currentProfile.isEmpty, !seen.contains(currentProfile) {
            unique.insert(HermesAPIProfile(id: currentProfile, name: currentProfile, isDefault: currentProfile == "default", model: nil, provider: nil), at: 0)
        }
        if unique.isEmpty {
            unique.append(HermesAPIProfile(id: "default", name: "default", isDefault: true, model: nil, provider: nil))
        }
        return unique
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("PROFILE")
                .font(.caption2.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(Color.hermesSecondaryText)
            Menu {
                ForEach(pickerProfiles) { profile in
                    Button(profile.id) {
                        selectedProfile = profile.id
                        onProfileSelected(profile.id)
                    }
                }
            } label: {
                Text(currentProfile)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .disabled(isDisabled)
        }
        .padding(12)
        .frame(minWidth: 170, maxWidth: 260, alignment: .leading)
        .hermesCard(tint: Color.hermesActionBlue.opacity(0.08))
    }
}

private struct HermesStatusCard: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(localized: String.LocalizationValue(title)).uppercased())
                .font(.caption2.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(Color.hermesSecondaryText)
            Text(value)
                .font(.caption.weight(.semibold))
                .lineLimit(2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .hermesCard(tint: tint.opacity(0.10))
    }
}

private struct HermesAttachmentChip: View {
    let attachment: HermesPromptAttachment
    let remove: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: attachment.isImage ? "photo" : "doc.text")
                .foregroundStyle(Color.hermesActionBlue)
            VStack(alignment: .leading, spacing: 2) {
                Text(attachment.filename).font(.caption.weight(.semibold)).lineLimit(1)
                Text("\(attachment.mimeType) · \(attachment.formattedByteCount)").font(.caption2).foregroundStyle(Color.hermesSecondaryText).lineLimit(1)
            }
            Spacer(minLength: 8)
            Button(action: remove) { Image(systemName: "xmark.circle.fill") }
                .buttonStyle(.plain)
                .help("Remove attachment")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .hermesCard(tint: Color.hermesActionBlue.opacity(0.08))
    }
}

struct HermesResponseBubble: View {
    let message: HermesResponseMessage
    var isResponding = false

    var body: some View {
        HStack(alignment: .bottom) {
            if isUser { Spacer(minLength: 80) }
            VStack(alignment: isUser ? .trailing : .leading, spacing: 6) {
                Text(isUser ? "You" : "Hermes")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.hermesSecondaryText)
                HermesCopyableBubbleContent(text: displayContent, copyText: message.content, isUser: isUser, rendersMarkdown: !isUser, isResponding: isResponding)
            }
            .frame(maxWidth: 680, alignment: isUser ? .trailing : .leading)
            if !isUser { Spacer(minLength: 80) }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }

    private var isUser: Bool { message.role == "user" }
    private var displayContent: String { message.content }
}

private struct HermesCopyableBubbleContent: View {
    let text: String
    let copyText: String
    let isUser: Bool
    let rendersMarkdown: Bool
    let isResponding: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isResponding {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Hermes is responding…")
                        .foregroundStyle(Color.hermesSecondaryText)
                }
            } else {
                HermesBubbleMessageText(text: text, rendersMarkdown: rendersMarkdown)
                    .textSelection(.enabled)
            }
        }
        .padding(13)
        .background(isUser ? Color.hermesActionBlue.opacity(0.92) : Color.hermesSurface.opacity(0.92), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .foregroundStyle(isUser ? .white : .primary)
        .overlay(alignment: .topTrailing) {
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(copyText, forType: .string)
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .padding(6)
            .opacity(copyText.isEmpty ? 0 : 0.65)
            .disabled(copyText.isEmpty)
            .help("Copy")
        }
    }
}

private struct HermesBubbleMessageText: View {
    let text: String
    let rendersMarkdown: Bool

    var body: some View {
        if rendersMarkdown, let attributedText = try? AttributedString(markdown: text) {
            Text(attributedText)
        } else {
            Text(text)
        }
    }
}

struct SettingsView: View {
    @AppStorage("hermes.appTheme") private var appTheme: HermesAppTheme = .system
    @State private var apiSettings = HermesSettingsStore.loadAPISettings()
    @State private var draft = HermesSettingsStore.loadDraft()
    @AppStorage(hermesDashboardURLStorageKey) private var dashboardURL = defaultHermesDashboardURL

    var body: some View {
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
            }

            Section("Hermes API") {
                TextField("Base URL", text: $apiSettings.baseURL)
                    .textFieldStyle(.roundedBorder)
                SecureField("API key", text: $apiSettings.apiKey)
                    .textFieldStyle(.roundedBorder)
                Toggle("Allow self-signed certificates", isOn: $apiSettings.allowSelfSignedCertificates)
                Button("Restore default endpoint") {
                    apiSettings.baseURL = HermesHostEndpoints.httpURLString(host: defaultHermesMacHost, port: defaultHermesAPIPort, path: "/v1")
                }
            }

            Section("Hermes Dashboard") {
                TextField("Dashboard URL", text: $dashboardURL)
                    .textFieldStyle(.roundedBorder)
                Button("Restore default dashboard") {
                    dashboardURL = defaultHermesDashboardURL
                }
            }

            Section("Ask Hermes defaults") {
                TextField("Default profile", text: $draft.profile)
                Toggle("Stream Responses API output", isOn: $draft.stream)
                TextEditor(text: $draft.userPrompt)
                    .frame(minHeight: 100)
            }
        }
        .formStyle(.grouped)
        .preferredColorScheme(appTheme.colorScheme)
        .padding()
        .frame(minWidth: 560, minHeight: 420)
        .onChange(of: apiSettings) { _, value in HermesSettingsStore.saveAPISettings(value) }
        .onChange(of: draft) { _, value in HermesSettingsStore.saveDraft(value) }
    }
}

struct HermesLiquidGlassCanvas: View {
    var body: some View {
        LinearGradient(colors: [Color(nsColor: .windowBackgroundColor), Color.hermesActionBlue.opacity(0.09), Color.hermesPurple.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

extension View {
    func hermesCard(tint: Color = Color.hermesSurface.opacity(0.82)) -> some View {
        self.background(tint, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.12), lineWidth: 1))
    }
}

extension Color {
    static let hermesActionBlue = Color(red: 0.13, green: 0.48, blue: 0.98)
    static let hermesPurple = Color(red: 0.55, green: 0.36, blue: 0.95)
    static let hermesOrange = Color(red: 1.0, green: 0.55, blue: 0.16)
    static let hermesDestructive = Color(red: 0.93, green: 0.19, blue: 0.25)
    static let hermesSecondaryText = Color.secondary
    static let hermesSurface = Color(nsColor: .controlBackgroundColor)
    static let hermesSurfaceInput = Color(nsColor: .textBackgroundColor)
}
