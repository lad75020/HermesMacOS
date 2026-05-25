//
//  HermesViews.swift
//  HermesMacOS
//

import AppKit
import SwiftUI

struct HermesConnectedHostLabel: View {
    let hostName: String
    let windowID: UUID

    @State private var savedEndpoints = HermesSettingsStore.loadSavedEndpoints()
    @State private var selectedEndpointID = ""
    @State private var connectionCenter = HermesWindowConnectionCenter.shared

    var body: some View {
        Group {
            if savedEndpoints.isEmpty {
                hostText
            } else {
                Picker("Connected host", selection: $selectedEndpointID) {
                    Text(hostName).tag("")
                    ForEach(savedEndpoints) { endpoint in
                        Text(endpoint.title).tag(endpoint.id)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .controlSize(.small)
                .frame(maxWidth: 240, alignment: .trailing)
                .onChange(of: selectedEndpointID) { _, newValue in
                    applyEndpoint(id: newValue)
                }
            }
        }
        .accessibilityLabel("Connected host: \(hostName)")
        .help("Connected host: \(hostName)")
        .onAppear { reloadSavedEndpoints() }
        .onChange(of: hostName) { _, _ in syncSelectedEndpoint() }
        .onReceive(NotificationCenter.default.publisher(for: .hermesConnectionEndpointDidChange)) { _ in
            reloadSavedEndpoints()
        }
    }

    private var hostText: some View {
        Text(hostName)
            .hermesWebsiteLabelFont(size: 10, weight: .semibold)
            .foregroundStyle(Color.hermesSecondaryText)
            .lineLimit(1)
            .truncationMode(.middle)
            .multilineTextAlignment(.trailing)
            .frame(maxWidth: 240, alignment: .trailing)
    }

    private func reloadSavedEndpoints() {
        savedEndpoints = HermesSettingsStore.loadSavedEndpoints()
        syncSelectedEndpoint()
    }

    private func syncSelectedEndpoint() {
        guard let connection = connectionCenter.connection(id: windowID),
              let matchingEndpoint = savedEndpoints.first(where: { endpoint in
                  endpoint.matches(apiURL: connection.apiSettings.baseURL, dashboardURL: connection.dashboardURL)
              })
        else {
            if !selectedEndpointID.isEmpty { selectedEndpointID = "" }
            return
        }
        if selectedEndpointID != matchingEndpoint.id { selectedEndpointID = matchingEndpoint.id }
    }

    private func applyEndpoint(id: String) {
        guard !id.isEmpty,
              let endpoint = savedEndpoints.first(where: { $0.id == id })
        else { return }
        var newAPISettings = connectionCenter.connection(id: windowID)?.apiSettings ?? HermesSettingsStore.loadAPISettings()
        newAPISettings.baseURL = endpoint.apiURL
        HermesSettingsStore.saveSelectedEndpointID(id)
        connectionCenter.applyEndpoint(to: windowID, apiSettings: newAPISettings, dashboardURL: endpoint.dashboardURL)
    }
}

struct HermesResponsesConsoleView: View {
    @Binding var apiSettings: HermesAPISettings
    let dashboardURL: String
    @Binding var requestDraft: HermesRequestDraft
    @Bindable var responseSession: HermesResponsesSession
    @Bindable var promptHistoryStore: HermesPromptHistoryStore
    @Binding var showsStreamOutputBubbles: Bool
    var workspaceControls = AnyView(EmptyView())
    let connectedHostName: String
    let connectedWindowID: UUID

    @AppStorage("hermes.macOS.chatBubbleFontSize") private var chatBubbleFontSize = 14.0
    @AppStorage("hermes.macOS.promptFontSize") private var promptFontSize = 14.0

    @State private var apiProfiles: [HermesAPIProfile] = []
    @State private var selectedAttachment: HermesPromptAttachment?
    @State private var isImportingAttachment = false
    @State private var promptText = ""
    @State private var profileRefreshError = ""
    @State private var speechToText = HermesSpeechToTextSession()
    @State private var dashboardSkills = HermesDashboardSkillsStore()
    @State private var localPathSuggestions = HermesLocalPathSuggestionsStore()
    @State private var selectedSkillIndex = 0

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
        .onChange(of: promptText) { _, text in
            requestDraft.userPrompt = text
            handlePromptSkillQueryChange()
        }
        .onChange(of: requestDraft.profile) { _, _ in clampReasoningLevelIfNeeded() }
        .onChange(of: apiProfiles) { _, _ in clampReasoningLevelIfNeeded() }
        .onDisappear { speechToText.stopTranscription() }
        .fileImporter(isPresented: $isImportingAttachment, allowedContentTypes: HermesPromptAttachment.supportedContentTypes, allowsMultipleSelection: false) { result in
            handleAttachmentImport(result)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Label("Ask Hermes", systemImage: "dot.radiowaves.left.and.right")
                    .hermesWebsiteTitleFont(size: 22, weight: .bold)
                workspaceControls
                Spacer()
                HermesConnectedHostLabel(hostName: connectedHostName, windowID: connectedWindowID)
                if responseSession.isStreaming {
                    ProgressView().controlSize(.small)
                    Text("Streaming")
                        .hermesWebsiteLabelFont(size: 11, weight: .bold)
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

                if selectedProfileSupportsReasoning {
                    HermesReasoningLevelPill(
                        reasoningLevel: $requestDraft.reasoningLevel,
                        isDisabled: responseSession.isSending
                    )
                }

                HermesStatusCard(title: "Session", value: responseSession.displaySessionTitle, tint: .hermesPurple, minimumWidth: 180, maximumWidth: .infinity)
                HermesStatusCard(title: "Status", value: responseSession.connectionStatus, tint: .hermesOrange, minimumWidth: 224, maximumWidth: 252)
                HermesStatusCard(title: "Events", value: "\(responseSession.eventCount)", tint: .hermesActionBlue, minimumWidth: 112, maximumWidth: 126)
            }

            if !profileRefreshError.isEmpty {
                Label(profileRefreshError, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(Color.hermesDestructive)
            }
        }
        .padding(18)
        .hermesGlassPanel(cornerRadius: 0)
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    if responseSession.entries.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Start a Responses session", systemImage: "bubble.left.and.bubble.right")
                                .hermesWebsiteTitleFont(size: 15, weight: .bold)
                            Text("Enter a prompt below. Your prompts and Hermes replies will appear here as chat bubbles for this session.")
                                .font(.subheadline)
                                .foregroundStyle(Color.hermesSecondaryText)
                            Text("The macOS tab uses the same Hermes Responses API flow as HermesiOS: profile selection, SSE streaming, cancellation, session continuation, and file/image attachments.")
                                .font(.caption)
                                .foregroundStyle(Color.hermesSecondaryText)
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .hermesGlassPanel(tint: Color.hermesActionBlue.opacity(0.07))
                    } else {
                        ForEach(responseSession.entries) { message in
                            HermesResponseBubble(
                                message: message,
                                fontSize: chatBubbleFontSize,
                                isResponding: isResponsePlaceholder(message),
                                responseElapsedSeconds: responseElapsedSeconds(for: message)
                            )
                                .id(message.id)
                            if showsStreamOutputBubbles,
                               message.role == "user",
                               let outputBubble = responseSession.streamOutputBubble(after: message.id),
                               !outputBubble.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                HermesStreamOutputBubbleView(
                                    text: outputBubble.text,
                                    isComplete: outputBubble.isComplete,
                                    fontSize: max(11, chatBubbleFontSize - 1)
                                )
                                .id(outputBubble.id)
                            }
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
            .onChange(of: responseSession.streamOutputBubbles) { _, _ in scrollToLatest(proxy) }
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
                VStack(alignment: .leading, spacing: 8) {
                    if shouldShowSkillPicker {
                        HermesSkillSlashPicker(
                            skills: filteredSkillSuggestions,
                            selectedIndex: selectedSkillIndex,
                            isLoading: dashboardSkills.isLoading,
                            errorMessage: dashboardSkills.lastErrorMessage,
                            onSelect: selectSkillSuggestion
                        )
                    } else if shouldShowPathPicker, let activePathToken {
                        HermesPathSlashPicker(
                            pathToken: activePathToken,
                            paths: localPathSuggestions.suggestions,
                            selectedIndex: selectedSkillIndex,
                            errorMessage: localPathSuggestions.lastErrorMessage,
                            onSelect: selectPathSuggestion
                        )
                    }

                    TextEditor(text: $promptText)
                        .font(.system(size: promptFontSize))
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 78, maxHeight: 150)
                        .padding(8)
                        .hermesGlassInput(tint: Color.hermesSurfaceInput.opacity(responseSession.isStreaming ? 0.42 : 0.70))
                        .disabled(responseSession.isStreaming)
                        .help(responseSession.isStreaming ? "This workspace is streaming a response" : "Prompt")
                        .onKeyPress(.upArrow) {
                            guard shouldShowCompletionPicker else { return .ignored }
                            moveSkillSelection(delta: -1)
                            return .handled
                        }
                        .onKeyPress(.downArrow) {
                            guard shouldShowCompletionPicker else { return .ignored }
                            moveSkillSelection(delta: 1)
                            return .handled
                        }
                        .onKeyPress(.return) {
                            guard shouldShowCompletionPicker else { return .ignored }
                            if shouldShowSkillPicker, let skill = selectedSkillSuggestion {
                                selectSkillSuggestion(skill)
                                return .handled
                            }
                            if shouldShowPathPicker, let path = selectedPathSuggestion {
                                selectPathSuggestion(path)
                                return .handled
                            }
                            return .ignored
                        }
                        .onKeyPress(.tab) {
                            guard shouldShowPathPicker,
                                  let path = selectedPathSuggestion,
                                  path.isDirectory
                            else { return .ignored }
                            selectPathSuggestion(path)
                            return .handled
                        }
                        .overlay(alignment: .topLeading) {
                            if promptText.isEmpty {
                                Text("Ask Hermes something...")
                                    .font(.system(size: promptFontSize))
                                    .foregroundStyle(Color.hermesSecondaryText)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 16)
                                    .allowsHitTesting(false)
                            }
                        }
                }

                VStack(spacing: 8) {
                    Button { isImportingAttachment = true } label: {
                        HermesComposerCircleButtonLabel(systemImage: selectedAttachment == nil ? "paperclip" : "paperclip.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .disabled(responseSession.isSending)
                    .help(selectedAttachment == nil ? "Attach file" : "Change attached file")

                    Button {
                        speechToText.toggleTranscription(currentPrompt: promptText) { updatedPrompt in
                            promptText = updatedPrompt
                        }
                    } label: {
                        HermesComposerCircleButtonLabel(
                            systemImage: speechToText.buttonSystemImage,
                            foreground: speechToText.isRecording ? Color.hermesDestructive : Color.primary
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(responseSession.isSending || responseSession.isStreaming)
                    .help(speechToText.buttonTitle)

                    Button {
                        submitPrompt()
                    } label: {
                        HermesComposerSendButtonLabel()
                    }
                    .buttonStyle(.plain)
                    .disabled((promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedAttachment == nil) || responseSession.isSending)
                    .keyboardShortcut(.return, modifiers: [.command])
                    .help("Send prompt (⌘↩)")
                }
            }
        }
        .padding(16)
        .hermesGlassPanel(cornerRadius: 0)
        .onChange(of: responseSession.isStreaming) { _, isStreaming in
            if isStreaming { speechToText.stopTranscription() }
        }
    }

    private static let transcriptBottomID = "responses-transcript-bottom"

    private var activeSlashToken: String? { promptText.hermesActiveSlashCompletionToken }
    private var activeSkillQuery: String? { promptText.hermesActiveSlashSkillQuery }

    private var filteredSkillSuggestions: [HermesDashboardSkill] {
        guard let query = activeSkillQuery else { return [] }
        if query.isEmpty { return dashboardSkills.skills }
        return dashboardSkills.skills.filter { $0.name.range(of: query, options: [.caseInsensitive, .anchored]) != nil }
    }

    private var activePathToken: String? {
        guard let token = activeSlashToken else { return nil }
        let pathText = token.dropFirst()
        guard !pathText.isEmpty, !dashboardSkills.isLoading, filteredSkillSuggestions.isEmpty else { return nil }
        return token
    }

    private var shouldShowSkillPicker: Bool {
        activeSkillQuery != nil && (dashboardSkills.isLoading || (!dashboardSkills.lastErrorMessage.isEmpty && activePathToken == nil) || !filteredSkillSuggestions.isEmpty)
    }

    private var shouldShowPathPicker: Bool { activePathToken != nil }

    private var shouldShowCompletionPicker: Bool { shouldShowSkillPicker || shouldShowPathPicker }

    private var selectedSkillSuggestion: HermesDashboardSkill? {
        let suggestions = filteredSkillSuggestions
        guard suggestions.indices.contains(selectedSkillIndex) else { return suggestions.first }
        return suggestions[selectedSkillIndex]
    }

    private var selectedPathSuggestion: HermesLocalPathSuggestion? {
        let suggestions = localPathSuggestions.suggestions
        guard suggestions.indices.contains(selectedSkillIndex) else { return suggestions.first }
        return suggestions[selectedSkillIndex]
    }

    private func handlePromptSkillQueryChange() {
        guard activeSlashToken != nil else {
            localPathSuggestions.clear()
            selectedSkillIndex = 0
            return
        }
        dashboardSkills.refreshIfNeeded(dashboardBaseURL: dashboardURL, apiSettings: apiSettings)
        if let activePathToken {
            localPathSuggestions.refresh(pathToken: activePathToken)
        } else {
            localPathSuggestions.clear()
        }
        let count = shouldShowSkillPicker ? filteredSkillSuggestions.count : localPathSuggestions.suggestions.count
        if count == 0 || selectedSkillIndex >= count { selectedSkillIndex = 0 }
    }

    private func moveSkillSelection(delta: Int) {
        let count = shouldShowSkillPicker ? filteredSkillSuggestions.count : localPathSuggestions.suggestions.count
        guard count > 0 else { return }
        selectedSkillIndex = (selectedSkillIndex + delta + count) % count
    }

    private func selectSkillSuggestion(_ skill: HermesDashboardSkill) {
        promptText = promptText.replacingActiveSlashSkillQuery(with: skill.name)
        localPathSuggestions.clear()
        selectedSkillIndex = 0
    }

    private func selectPathSuggestion(_ path: HermesLocalPathSuggestion) {
        promptText = promptText.replacingActiveSlashCompletionToken(with: path.insertedPath)
        selectedSkillIndex = 0
    }

    private var canResumeLastResponseSession: Bool {
        let last = responseSession.lastKnownResponseID.trimmingCharacters(in: .whitespacesAndNewlines)
        return !last.isEmpty && responseSession.previousResponseID != last && responseSession.latestResponseID != last
    }

    private var selectedProfileSupportsReasoning: Bool {
        selectedAPIProfile?.supportsReasoningLevel ?? false
    }

    private var selectedAPIProfile: HermesAPIProfile? {
        let locked = responseSession.activeProfile.trimmingCharacters(in: .whitespacesAndNewlines)
        let selected = requestDraft.profile.trimmingCharacters(in: .whitespacesAndNewlines)
        let current = locked.isEmpty ? (selected.isEmpty ? "default" : selected) : locked
        return apiProfiles.first { $0.id == current }
    }

    private func clampReasoningLevelIfNeeded() {
        if !selectedProfileSupportsReasoning, requestDraft.reasoningLevel != .off {
            requestDraft.reasoningLevel = .off
        } else if selectedProfileSupportsReasoning, requestDraft.reasoningLevel == .off {
            requestDraft.reasoningLevel = .medium
        }
    }

    private func isResponsePlaceholder(_ message: HermesResponseMessage) -> Bool {
        responseSession.isSending && message.role != "user" && message.content.isEmpty && responseSession.entries.last?.id == message.id
    }

    private func responseElapsedSeconds(for message: HermesResponseMessage) -> Int? {
        if message.role == "user" { return nil }
        if responseSession.activeResponseMessageID == message.id {
            return responseSession.activeResponseElapsedSeconds ?? message.responseElapsedSeconds
        }
        return message.responseElapsedSeconds
    }

    private func submitPrompt() {
        speechToText.stopTranscription()
        var submittedDraft = requestDraft
        submittedDraft.userPrompt = promptText
        if !selectedProfileSupportsReasoning { submittedDraft.reasoningLevel = .off }
        responseSession.submit(
            apiSettings: apiSettings,
            draft: submittedDraft,
            attachment: selectedAttachment,
            historyStore: promptHistoryStore,
            showsStreamOutputBubble: showsStreamOutputBubbles
        )
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

private struct HermesMarqueeText: View {
    let text: String
    let font: Font
    var startDelay: Double = 0.7
    var pointsPerSecond: Double = 34
    var gap: CGFloat = 36

    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var isScrolling = false

    init(_ text: String, font: Font, startDelay: Double = 0.7, pointsPerSecond: Double = 34, gap: CGFloat = 36) {
        self.text = text
        self.font = font
        self.startDelay = startDelay
        self.pointsPerSecond = pointsPerSecond
        self.gap = gap
    }

    private var shouldScroll: Bool { textWidth > containerWidth + 1 && containerWidth > 0 }
    private var duration: Double { max(4.0, Double(textWidth + gap) / pointsPerSecond) }

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: gap) {
                measuredText
                if shouldScroll { plainText }
            }
            .offset(x: shouldScroll && isScrolling ? -(textWidth + gap) : 0)
            .animation(shouldScroll ? .linear(duration: duration).repeatForever(autoreverses: false) : nil, value: isScrolling)
            .onAppear { updateContainerWidth(geometry.size.width) }
            .onChange(of: geometry.size.width) { _, width in updateContainerWidth(width) }
            .onChange(of: text) { _, _ in restartIfNeeded() }
        }
        .frame(height: 17)
        .clipped()
        .onPreferenceChange(HermesMarqueeTextWidthKey.self) { width in
            textWidth = width
            restartIfNeeded()
        }
        .accessibilityLabel(text)
        .help(text)
    }

    private var measuredText: some View {
        plainText.background(
            GeometryReader { proxy in
                Color.clear.preference(key: HermesMarqueeTextWidthKey.self, value: proxy.size.width)
            }
        )
    }

    private var plainText: some View {
        Text(text)
            .font(font)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }

    private func updateContainerWidth(_ width: CGFloat) {
        containerWidth = width
        restartIfNeeded()
    }

    private func restartIfNeeded() {
        isScrolling = false
        guard shouldScroll else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + startDelay) {
            guard shouldScroll else { return }
            isScrolling = true
        }
    }
}

private struct HermesMarqueeTextWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

struct HermesComposerCircleButtonLabel: View {
    let systemImage: String
    var foreground: Color = .primary
    var background: Color = .hermesSurface
    var size: CGFloat = 34

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 15, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(foreground)
            .frame(width: size, height: size)
            .background(background, in: Circle())
            .overlay(Circle().stroke(Color.white.opacity(0.14), lineWidth: 1))
            .contentShape(Circle())
    }
}

struct HermesComposerSendButtonLabel: View {
    var body: some View {
        Image(systemName: "paperplane.fill")
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 42, height: 42)
            .background(Color.hermesActionBlue, in: Circle())
            .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
            .contentShape(Circle())
    }
}

struct HermesProfileSelector: View {
    @Environment(\.colorScheme) private var colorScheme
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
                .hermesWebsiteLabelFont(size: 10, weight: .bold)
                .foregroundStyle(Color.hermesSecondaryText)
            Menu {
                ForEach(pickerProfiles) { profile in
                    Button(profile.id) {
                        selectedProfile = profile.id
                        onProfileSelected(profile.id)
                    }
                }
            } label: {
                HermesMarqueeText(currentProfile, font: .system(size: 11, weight: .semibold, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .disabled(isDisabled)
        }
        .padding(12)
        .frame(minWidth: 85, maxWidth: 130, alignment: .leading)
        .hermesGlassPanel(tint: colorScheme == .light ? Color.hermesLightGlassPaleBlue : Color.hermesActionBlue.opacity(0.07))
    }
}

private struct HermesReasoningLevelPill: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var reasoningLevel: HermesReasoningLevel
    let isDisabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("REASONING")
                .hermesWebsiteLabelFont(size: 10, weight: .bold)
                .foregroundStyle(Color.hermesSecondaryText)
            Menu {
                ForEach(HermesReasoningLevel.allCases.filter { $0 != .off }) { level in
                    Button(level.title) { reasoningLevel = level }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "brain")
                        .font(.caption.weight(.semibold))
                    Text(reasoningLevel == .off ? HermesReasoningLevel.medium.title : reasoningLevel.title)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .disabled(isDisabled)
            .help("Reasoning effort sent as reasoning.effort when the selected profile model supports it")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 11)
        .frame(minWidth: 118, maxWidth: 142, alignment: .leading)
        .hermesGlassPanel(tint: colorScheme == .light ? Color.hermesLightGlassNeutral : Color.hermesPurple.opacity(0.08))
    }
}

struct HermesStatusCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let value: String
    let tint: Color
    var minimumWidth: CGFloat = 120
    var maximumWidth: CGFloat = 150

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(localized: String.LocalizationValue(title)).uppercased())
                .hermesWebsiteLabelFont(size: 10, weight: .bold)
                .foregroundStyle(Color.hermesSecondaryText)
            HermesMarqueeText(value, font: .system(size: 11, weight: .semibold, design: .monospaced))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 11)
        .frame(minWidth: minimumWidth, maxWidth: maximumWidth, alignment: .leading)
        .hermesGlassPanel(tint: colorScheme == .light ? Color.hermesLightGlassPaleBlue : tint.opacity(0.09))
    }
}

struct HermesAttachmentChip: View {
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
        .hermesGlassPanel(tint: Color.hermesActionBlue.opacity(0.07))
    }
}

struct HermesResponseBubble: View {
    let message: HermesResponseMessage
    let fontSize: Double
    var isResponding = false
    var responseElapsedSeconds: Int?

    var body: some View {
        HStack(alignment: .bottom) {
            if isUser { Spacer(minLength: 80) }
            VStack(alignment: isUser ? .trailing : .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(isUser ? "You" : "Hermes")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.hermesSecondaryText)
                    if let responseElapsedSeconds, !isUser {
                        Text(Self.formattedElapsedTime(responseElapsedSeconds))
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .foregroundStyle(Color.hermesOrange)
                            .accessibilityLabel("Response elapsed time \(Self.formattedElapsedAccessibilityTime(responseElapsedSeconds))")
                    }
                }
                HermesCopyableBubbleContent(text: displayContent, copyText: message.content, isUser: isUser, rendersMarkdown: !isUser, fontSize: fontSize, isResponding: isResponding)
            }
            .frame(maxWidth: 680, alignment: isUser ? .trailing : .leading)
            if !isUser { Spacer(minLength: 80) }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }

    private var isUser: Bool { message.role == "user" }
    private var displayContent: String { message.content }

    private static func formattedElapsedTime(_ seconds: Int) -> String {
        let clampedSeconds = max(0, seconds)
        let hours = clampedSeconds / 3_600
        let minutes = (clampedSeconds % 3_600) / 60
        let remainingSeconds = clampedSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
        }
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }

    private static func formattedElapsedAccessibilityTime(_ seconds: Int) -> String {
        let clampedSeconds = max(0, seconds)
        let hours = clampedSeconds / 3_600
        let minutes = (clampedSeconds % 3_600) / 60
        let remainingSeconds = clampedSeconds % 60
        if hours > 0 {
            return "\(hours) hours, \(minutes) minutes, \(remainingSeconds) seconds"
        }
        if minutes > 0 {
            return "\(minutes) minutes, \(remainingSeconds) seconds"
        }
        return "\(remainingSeconds) seconds"
    }
}

private struct HermesStreamOutputBubbleView: View {
    let text: String
    let isComplete: Bool
    let fontSize: Double

    private var displayText: String {
        let displayLineFeeds = HermesBubbleTextFormatter.displayLineFeeds(in: text)
        let normalized = displayLineFeeds.split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        return normalized.isEmpty ? "…" : normalized
    }

    var body: some View {
        HStack(alignment: .bottom) {
            Spacer(minLength: 80)
            VStack(alignment: .leading, spacing: 5) {
                Text("Stream output")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.hermesSecondaryText)
                Text(displayText)
                    .font(.system(size: fontSize, design: .monospaced))
                    .foregroundStyle(Color.hermesSecondaryText)
                    .lineLimit(isComplete ? 1 : nil)
                    .truncationMode(.tail)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(10)
            .frame(maxWidth: 680, alignment: .leading)
            .background(Color.gray.opacity(0.18), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.gray.opacity(0.20), lineWidth: 1))
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

struct HermesCopyableBubbleContent: View {
    let text: String
    let copyText: String
    let isUser: Bool
    let rendersMarkdown: Bool
    let fontSize: Double
    let isResponding: Bool

    private var renderableText: String {
        if rendersMarkdown, let imageMarkdown = HermesImageJSONFormatter.renderableImageMarkdown(from: text) {
            return imageMarkdown
        }
        return HermesBubbleTextFormatter.displayLineFeeds(in: text)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isResponding {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Hermes is responding…")
                        .foregroundStyle(Color.hermesSecondaryText)
                }
            } else {
                HermesBubbleMessageText(text: renderableText, rendersMarkdown: rendersMarkdown, fontSize: fontSize)
                    .textSelection(.enabled)
            }
        }
        .padding(13)
        .hermesGlassPanel(tint: isUser ? Color.hermesActionBlue.opacity(0.86) : Color.hermesSurface.opacity(0.78), cornerRadius: 18, interactive: true)
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
    let fontSize: Double

    private var renderableText: String {
        if rendersMarkdown, let imageMarkdown = HermesImageJSONFormatter.renderableImageMarkdown(from: text) {
            return imageMarkdown
        }
        return HermesBubbleTextFormatter.displayLineFeeds(in: text)
    }

    private var renderedImages: [HermesRenderedBubbleImage] {
        rendersMarkdown ? HermesRenderedBubbleImage.extract(from: renderableText) : []
    }

    private var textWithoutRenderedImages: String {
        guard rendersMarkdown else { return text }
        return HermesRenderedBubbleImage.removingImageMarkdown(from: renderableText)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !textWithoutRenderedImages.isEmpty {
                if rendersMarkdown, let attributedText = try? AttributedString(markdown: textWithoutRenderedImages) {
                    Text(attributedText)
                        .font(.system(size: fontSize))
                } else {
                    Text(textWithoutRenderedImages)
                        .font(.system(size: fontSize))
                }
            }
            ForEach(renderedImages) { renderedImage in
                HermesRenderedBubbleImageView(renderedImage: renderedImage)
            }
        }
    }
}

enum HermesBubbleTextFormatter {
    static func displayLineFeeds(in text: String) -> String {
        text
            .replacingOccurrences(of: "\\r\\n", with: "\n")
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\r", with: "\n")
    }
}

private struct HermesRenderedBubbleImage: Identifiable {
    private static let maxEncodedCharacters = 32_000_000
    private static let maxImageBytes = 24_000_000
    private static let dataCache = NSCache<NSString, NSData>()

    let id: String
    let source: String
    let altText: String
    let data: Data?
    let fileExtension: String

    var nsImage: NSImage? { data.flatMap(NSImage.init(data:)) }

    static func extract(from text: String) -> [HermesRenderedBubbleImage] {
        markdownImageMatches(in: text).compactMap { match in
            guard isPotentiallyRenderableSource(match.source) else { return nil }
            let imageData = data(from: match.source)
            return HermesRenderedBubbleImage(
                id: "\(match.altText)::\(match.source.prefix(96))::\(imageData?.count ?? 0)::\(match.source.count)",
                source: match.source,
                altText: match.altText.isEmpty ? "Hermes image" : match.altText,
                data: imageData,
                fileExtension: fileExtension(from: match.source)
            )
        }
    }

    static func removingImageMarkdown(from text: String) -> String {
        var result = text
        for token in renderableImageTokens(in: text).reversed() {
            result.replaceSubrange(token, with: "")
        }
        return result
    }

    private static func markdownImageMatches(in text: String) -> [(altText: String, source: String)] {
        guard let regex = try? NSRegularExpression(pattern: #"!\[([^\]]*)\]\(([^\s)]+)\)"#, options: [.dotMatchesLineSeparators]) else { return [] }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: nsRange).compactMap { match in
            guard let altRange = Range(match.range(at: 1), in: text), let sourceRange = Range(match.range(at: 2), in: text) else { return nil }
            return (String(text[altRange]), String(text[sourceRange]))
        }
    }

    private static func renderableImageTokens(in text: String) -> [Range<String.Index>] {
        guard let regex = try? NSRegularExpression(pattern: #"!\[([^\]]*)\]\(([^\s)]+)\)"#, options: [.dotMatchesLineSeparators]) else { return [] }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: nsRange).compactMap { match in
            guard let tokenRange = Range(match.range, in: text), let sourceRange = Range(match.range(at: 2), in: text), isPotentiallyRenderableSource(String(text[sourceRange])) else { return nil }
            return tokenRange
        }
    }

    private static func isPotentiallyRenderableSource(_ source: String) -> Bool {
        let lower = source.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if lower.localizedCaseInsensitiveContains(";base64,"), let separator = lower.range(of: ";base64,") {
            return allowedDataImagePrefix(String(lower[..<separator.lowerBound]))
        }
        if source.hasPrefix("/"), hermesGeneratedImageURL(fromPath: source) != nil { return true }
        if source.hasPrefix("file://"), let url = URL(string: source), hermesGeneratedImageURL(fromPath: url.path) != nil { return true }
        return false
    }

    private static func data(from source: String) -> Data? {
        let cacheKey = NSString(string: "\(source.count):\(source.hashValue)")
        if let cached = dataCache.object(forKey: cacheKey) { return cached as Data }
        let loaded: Data?
        if source.localizedCaseInsensitiveContains(";base64,"), let separator = source.range(of: ";base64,") {
            guard source.count <= maxEncodedCharacters + 512 else { return nil }
            let prefix = String(source[..<separator.lowerBound]).lowercased()
            guard allowedDataImagePrefix(prefix) else { return nil }
            let encoded = source[separator.upperBound...].filter { !$0.isWhitespace }
            guard encoded.count <= maxEncodedCharacters, let decoded = Data(base64Encoded: String(encoded)), decoded.count <= maxImageBytes else { return nil }
            loaded = decoded
        } else if source.hasPrefix("/"), let url = hermesGeneratedImageURL(fromPath: source) {
            loaded = limitedFileData(from: url)
        } else if source.hasPrefix("file://"), let url = URL(string: source), let safeURL = hermesGeneratedImageURL(fromPath: url.path) {
            loaded = limitedFileData(from: safeURL)
        } else {
            loaded = nil
        }
        if let loaded { dataCache.setObject(loaded as NSData, forKey: cacheKey) }
        return loaded
    }

    private static func allowedDataImagePrefix(_ prefix: String) -> Bool {
        guard prefix.lowercased().hasPrefix("data:") else { return false }
        let mediaType = prefix.dropFirst("data:".count).split(separator: ";", maxSplits: 1, omittingEmptySubsequences: true).first.map(String.init) ?? ""
        return ["image/png", "image/jpeg", "image/jpg", "image/gif", "image/webp", "image/heic"].contains(mediaType.lowercased())
    }

    private static func limitedFileData(from url: URL) -> Data? {
        guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= maxImageBytes else { return nil }
        guard let data = try? Data(contentsOf: url), data.count <= maxImageBytes else { return nil }
        return data
    }

    private static func hermesGeneratedImageURL(fromPath path: String) -> URL? {
        let candidate = URL(fileURLWithPath: NSString(string: path).expandingTildeInPath).resolvingSymlinksInPath().standardizedFileURL
        guard FileManager.default.fileExists(atPath: candidate.path) else { return nil }
        let cache = URL(fileURLWithPath: NSString(string: "~/.hermes/cache/images").expandingTildeInPath).resolvingSymlinksInPath().standardizedFileURL
        let candidatePath = candidate.path
        let cachePath = cache.path
        guard candidatePath == cachePath || candidatePath.hasPrefix(cachePath + "/") else { return nil }
        return candidate
    }

    private static func fileExtension(from source: String) -> String {
        if source.localizedCaseInsensitiveContains("image/jpeg") || source.localizedCaseInsensitiveContains("image/jpg") { return "jpg" }
        if source.localizedCaseInsensitiveContains("image/webp") { return "webp" }
        if source.localizedCaseInsensitiveContains("image/gif") { return "gif" }
        let pathExtension = URL(string: source)?.pathExtension ?? URL(fileURLWithPath: source).pathExtension
        return pathExtension.isEmpty ? "png" : pathExtension
    }
}

private struct HermesRenderedBubbleImageView: View {
    let renderedImage: HermesRenderedBubbleImage
    @State private var saveStatus = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let image = renderedImage.nsImage {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 520, maxHeight: 360)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.white.opacity(0.18), lineWidth: 1))
                HStack(spacing: 10) {
                    Button("Copy Image") { copy(image) }
                    Button("Save Image") { save() }
                    if !saveStatus.isEmpty {
                        Text(saveStatus)
                            .font(.caption)
                            .foregroundStyle(Color.hermesSecondaryText)
                    }
                }
                .font(.caption)
            } else {
                Text("Image output received but could not be decoded.")
                    .font(.caption)
                    .foregroundStyle(Color.hermesSecondaryText)
            }
        }
        .accessibilityLabel(renderedImage.altText)
    }

    private func copy(_ image: NSImage) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
        saveStatus = "Copied"
    }

    private func save() {
        guard let data = renderedImage.data else { saveStatus = "No image data"; return }
        let folder = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        let formatter = DateFormatter(); formatter.dateFormat = "yyyyMMdd-HHmmss"
        let url = folder.appendingPathComponent("hermes-image-\(formatter.string(from: Date())).\(renderedImage.fileExtension)")
        do {
            try data.write(to: url, options: .atomic)
            saveStatus = "Saved to Downloads"
        } catch {
            saveStatus = "Save failed"
        }
    }
}

struct SettingsView: View {
    @AppStorage("hermes.appTheme") private var appTheme: HermesAppTheme = .system
    @AppStorage("hermes.appLanguage") private var appLanguage: HermesAppLanguageSelection = .automatic
    @AppStorage("hermes.macOS.titleFont") private var titleFont: HermesWebsiteFont = .rulesExpanded
    @AppStorage("hermes.macOS.labelFont") private var labelFont: HermesWebsiteFont = .mondwest
    @AppStorage("hermes.macOS.chatBubbleFontSize") private var chatBubbleFontSize = 14.0
    @AppStorage("hermes.macOS.promptFontSize") private var promptFontSize = 14.0
    @State private var apiSettings = HermesSettingsStore.loadAPISettings()
    @State private var draft = HermesSettingsStore.loadDraft()
    @State private var chatDraft = HermesSettingsStore.loadChatDraft()
    @State private var savedEndpoints = HermesSettingsStore.loadSavedEndpoints()
    @State private var selectedEndpointID = HermesSettingsStore.loadSelectedEndpointID()
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

    private func announceConnectionEndpointChange() {
        NotificationCenter.default.post(name: .hermesConnectionEndpointDidChange, object: nil)
    }
}

struct HermesLiquidGlassCanvas: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if colorScheme == .light {
            LinearGradient(
                colors: [
                    Color.white,
                    Color.hermesLightGlassPaleBlue.opacity(0.58),
                    Color.hermesLightGlassGrey.opacity(0.64),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color.hermesActionBlue.opacity(0.09),
                    Color.hermesPurple.opacity(0.08),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

extension View {
    @ViewBuilder
    func hermesGlassPanel(tint: Color = Color.hermesSurface.opacity(0.66), cornerRadius: CGFloat = 22, interactive: Bool = false) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(macOS 26.0, *) {
            self
                .background(tint, in: shape)
                .glassEffect(.regular.tint(tint).interactive(interactive), in: shape)
                .overlay(shape.strokeBorder(.white.opacity(0.16), lineWidth: 1))
                .shadow(color: .black.opacity(0.10), radius: 18, y: 8)
        } else {
            self
                .background(.ultraThinMaterial, in: shape)
                .background(tint, in: shape)
                .overlay(shape.strokeBorder(.white.opacity(0.14), lineWidth: 1))
                .shadow(color: .black.opacity(0.08), radius: 14, y: 6)
        }
    }

    func hermesGlassInput(tint: Color = Color.hermesSurfaceInput.opacity(0.70), cornerRadius: CGFloat = 14) -> some View {
        hermesGlassPanel(tint: tint, cornerRadius: cornerRadius, interactive: true)
    }

    func hermesCard(tint: Color = Color.hermesSurface.opacity(0.82)) -> some View {
        hermesGlassPanel(tint: tint, cornerRadius: 18)
    }
}

extension Color {
    static let hermesActionBlue = Color(red: 0.13, green: 0.48, blue: 0.98)
    static let hermesPurple = Color(red: 0.55, green: 0.36, blue: 0.95)
    static let hermesOrange = Color(red: 1.0, green: 0.55, blue: 0.16)
    static let hermesDestructive = Color(red: 0.93, green: 0.19, blue: 0.25)
    static let hermesSecondaryText = hermesDynamicColor(
        name: "HermesSecondaryText",
        light: NSColor(calibratedRed: 0.32, green: 0.40, blue: 0.48, alpha: 1.0),
        dark: .secondaryLabelColor
    )
    static let hermesSurface = hermesDynamicColor(
        name: "HermesSurface",
        light: NSColor(calibratedRed: 0.93, green: 0.97, blue: 1.0, alpha: 0.90),
        dark: .controlBackgroundColor
    )
    static let hermesSurfaceInput = hermesDynamicColor(
        name: "HermesSurfaceInput",
        light: NSColor(calibratedRed: 0.97, green: 0.99, blue: 1.0, alpha: 0.94),
        dark: .textBackgroundColor
    )
    static let hermesLightGlassPaleBlue = Color(red: 0.90, green: 0.95, blue: 1.0)
    static let hermesLightGlassGrey = Color(red: 0.95, green: 0.97, blue: 0.99)
    static let hermesLightGlassNeutral = hermesDynamicColor(
        name: "HermesLightGlassNeutral",
        light: NSColor(calibratedRed: 0.94, green: 0.96, blue: 0.98, alpha: 0.88),
        dark: .controlBackgroundColor
    )

    private static func hermesDynamicColor(name: String, light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: NSColor.Name(name)) { appearance in
            let bestMatch = appearance.bestMatch(from: [.aqua, .darkAqua])
            return bestMatch == .darkAqua ? dark : light
        })
    }
}
