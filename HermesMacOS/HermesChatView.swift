//
//  HermesChatView.swift
//  HermesMacOS
//

import AppKit
import SwiftUI

struct HermesChatConsoleView: View {
    @Binding var apiSettings: HermesAPISettings
    @Binding var chatDraft: HermesChatDraft
    @Bindable var chatSession: HermesChatSession
    @Bindable var promptHistoryStore: HermesPromptHistoryStore
    let dashboardURL: String
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
            if promptText.isEmpty { promptText = chatDraft.userPrompt }
            await refreshAPIProfiles()
        }
        .onChange(of: apiSettings) { _, _ in Task { await refreshAPIProfiles() } }
        .onChange(of: promptText) { _, text in
            chatDraft.userPrompt = text
            handlePromptSkillQueryChange()
        }
        .onDisappear { speechToText.stopTranscription() }
        .fileImporter(isPresented: $isImportingAttachment, allowedContentTypes: HermesPromptAttachment.supportedContentTypes, allowsMultipleSelection: false) { result in
            handleAttachmentImport(result)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Label("Chat with Hermes", systemImage: "text.bubble")
                    .hermesWebsiteTitleFont(size: 22, weight: .bold)
                Spacer()
                HermesConnectedHostLabel(hostName: connectedHostName, windowID: connectedWindowID)
                if chatSession.isStreaming {
                    ProgressView().controlSize(.small)
                    Text("Streaming")
                        .hermesWebsiteLabelFont(size: 11, weight: .bold)
                        .foregroundStyle(Color.hermesSecondaryText)
                }
            }

            HStack(alignment: .top, spacing: 12) {
                HermesProfileSelector(
                    selectedProfile: $chatDraft.profile,
                    apiProfiles: apiProfiles,
                    lockedProfile: chatSession.activeProfile,
                    isDisabled: chatSession.isSending
                ) { newProfile in
                    if chatSession.activeProfile != newProfile {
                        chatSession.resetConversation()
                    }
                }

                HermesStatusCard(title: "Session", value: chatSession.displaySessionTitle, tint: .hermesActionBlue, minimumWidth: 180, maximumWidth: .infinity)
                HermesStatusCard(title: "Status", value: chatSession.connectionStatus, tint: .hermesOrange, minimumWidth: 224, maximumWidth: 320)
                HermesStatusCard(title: "Events", value: "\(chatSession.eventCount)", tint: .hermesPurple, minimumWidth: 112, maximumWidth: 126)
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
                    if chatSession.entries.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Start a Chat Completions session", systemImage: "bubble.left.and.bubble.right")
                                .hermesWebsiteTitleFont(size: 15, weight: .bold)
                            Text("Enter a prompt below. Your prompts and Hermes replies will appear here as chat bubbles for this session.")
                                .font(.subheadline)
                                .foregroundStyle(Color.hermesSecondaryText)
                            Text("This tab uses Hermes /v1/chat/completions for a conversational Chat with Hermes flow, with profile selection, SSE streaming, session resume, and file/image attachments.")
                                .font(.caption)
                                .foregroundStyle(Color.hermesSecondaryText)
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .hermesGlassPanel(tint: Color.hermesActionBlue.opacity(0.07))
                    } else {
                        ForEach(chatSession.entries) { message in
                            HermesChatBubble(
                                message: message,
                                liveContent: liveContent(for: message),
                                fontSize: chatBubbleFontSize,
                                isResponding: isChatPlaceholder(message),
                                responseElapsedSeconds: responseElapsedSeconds(for: message),
                                tokenUsage: tokenUsage(for: message)
                            )
                                .id(message.id)
                        }
                    }
                    Color.clear.frame(height: 1).id(Self.transcriptBottomID)
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 16)
            }
            .onAppear { scrollToLatest(proxy, animated: false) }
            .onChange(of: chatSession.entries.count) { _, _ in scrollToLatest(proxy) }
            .onChange(of: chatSession.streamedText) { _, _ in scrollToLatest(proxy) }
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Spacer()
                if canResumeLastChatSession {
                    Button { chatSession.resumeLastKnownChatSession() } label: {
                        Label("Resume last", systemImage: "arrow.uturn.forward.circle")
                    }
                    .buttonStyle(.bordered)
                    .disabled(chatSession.isSending)
                }
                if !chatSession.entries.isEmpty && !chatSession.isSending {
                    Button("New Chat") { chatSession.resetConversation() }
                        .buttonStyle(.bordered)
                }
                if chatSession.isSending {
                    Button("Cancel") { chatSession.cancel() }
                        .buttonStyle(.bordered)
                        .keyboardShortcut(.cancelAction)
                }
            }

            if !chatSession.lastErrorMessage.isEmpty {
                Text(chatSession.lastErrorMessage)
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
                    .disabled(chatSession.isSending)
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
                    } else if shouldShowCommandPicker {
                        HermesSlashCommandPicker(
                            commands: filteredSlashCommandSuggestions,
                            selectedIndex: selectedSkillIndex,
                            onSelect: selectSlashCommandSuggestion
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
                        .hermesGlassInput(tint: Color.hermesSurfaceInput.opacity(chatSession.isStreaming ? 0.42 : 0.70))
                        .disabled(chatSession.isStreaming)
                        .help(chatSession.isStreaming ? "This chat is streaming a response" : "Prompt")
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
                            if shouldShowCommandPicker, let command = selectedSlashCommandSuggestion {
                                selectSlashCommandSuggestion(command)
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
                    .disabled(chatSession.isSending)
                    .help(selectedAttachment == nil ? "Attach file" : "Change attached file")

                    Button {
                        speechToText.toggleTranscription(currentPrompt: promptText) { updatedPrompt in
                            promptText = updatedPrompt
                        }
                    } label: {
                        HermesComposerCircleButtonLabel(
                            systemImage: speechToText.buttonSystemImage,
                            foreground: (speechToText.isRecording || speechToText.isProcessing) ? Color.hermesDestructive : Color.primary
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(chatSession.isSending || chatSession.isStreaming)
                    .help(speechToText.buttonTitle)

                    Button { submitPrompt() } label: {
                        HermesComposerSendButtonLabel()
                    }
                    .buttonStyle(.plain)
                    .disabled((promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedAttachment == nil) || chatSession.isSending || speechToText.isRecording || speechToText.isProcessing)
                    .keyboardShortcut(.return, modifiers: [.command])
                    .help("Send message (⌘↩)")
                }
            }
        }
        .padding(16)
        .hermesGlassPanel(cornerRadius: 0)
        .onChange(of: chatSession.isStreaming) { _, isStreaming in
            if isStreaming { speechToText.stopTranscription() }
        }
    }

    private static let transcriptBottomID = "chat-transcript-bottom"

    private var activeSlashToken: String? { promptText.hermesActiveSlashCompletionToken }
    private var activeSlashCommandQuery: String? { promptText.hermesActiveSlashCommandQuery }
    private var activeSkillQuery: String? { promptText.hermesActiveSlashSkillQuery }

    private var filteredSlashCommandSuggestions: [HermesSlashCommandSuggestion] {
        guard let query = activeSlashCommandQuery else { return [] }
        if query.isEmpty { return HermesSlashCommandSuggestion.all }
        return HermesSlashCommandSuggestion.all.filter { suggestion in
            suggestion.command.dropFirst().range(of: query, options: [.caseInsensitive, .anchored]) != nil ||
            suggestion.aliases.contains { alias in alias.dropFirst().range(of: query, options: [.caseInsensitive, .anchored]) != nil } ||
            suggestion.searchableText.range(of: query, options: [.caseInsensitive]) != nil
        }
    }

    private var filteredSkillSuggestions: [HermesDashboardSkill] {
        guard let query = activeSkillQuery else { return [] }
        if query.isEmpty { return dashboardSkills.skills }
        return dashboardSkills.skills.filter { $0.name.range(of: query, options: [.caseInsensitive, .anchored]) != nil }
    }

    private var activePathToken: String? {
        guard let token = activeSlashToken else { return nil }
        let pathText = token.dropFirst()
        guard activeSkillQuery == nil,
              !pathText.isEmpty,
              !dashboardSkills.isLoading,
              filteredSkillSuggestions.isEmpty,
              filteredSlashCommandSuggestions.isEmpty
        else { return nil }
        return token
    }

    private var shouldShowSkillPicker: Bool {
        activeSkillQuery != nil && (dashboardSkills.isLoading || (!dashboardSkills.lastErrorMessage.isEmpty && activePathToken == nil) || !filteredSkillSuggestions.isEmpty)
    }

    private var shouldShowCommandPicker: Bool {
        activeSkillQuery == nil && activeSlashCommandQuery != nil && !filteredSlashCommandSuggestions.isEmpty
    }

    private var shouldShowPathPicker: Bool { activePathToken != nil }

    private var shouldShowCompletionPicker: Bool { shouldShowSkillPicker || shouldShowCommandPicker || shouldShowPathPicker }

    private var selectedSkillSuggestion: HermesDashboardSkill? {
        let suggestions = filteredSkillSuggestions
        guard suggestions.indices.contains(selectedSkillIndex) else { return suggestions.first }
        return suggestions[selectedSkillIndex]
    }

    private var selectedSlashCommandSuggestion: HermesSlashCommandSuggestion? {
        let suggestions = filteredSlashCommandSuggestions
        guard suggestions.indices.contains(selectedSkillIndex) else { return suggestions.first }
        return suggestions[selectedSkillIndex]
    }

    private var selectedPathSuggestion: HermesLocalPathSuggestion? {
        let suggestions = localPathSuggestions.suggestions
        guard suggestions.indices.contains(selectedSkillIndex) else { return suggestions.first }
        return suggestions[selectedSkillIndex]
    }

    private func handlePromptSkillQueryChange() {
        guard activeSlashToken != nil || activeSkillQuery != nil else {
            localPathSuggestions.clear()
            selectedSkillIndex = 0
            return
        }
        if activeSkillQuery != nil {
            dashboardSkills.refreshIfNeeded(dashboardBaseURL: dashboardURL, apiSettings: apiSettings)
        }
        if let activePathToken {
            localPathSuggestions.refresh(pathToken: activePathToken)
        } else {
            localPathSuggestions.clear()
        }
        let count = activeCompletionSuggestionCount
        if count == 0 || selectedSkillIndex >= count { selectedSkillIndex = 0 }
    }

    private var activeCompletionSuggestionCount: Int {
        if shouldShowSkillPicker { return filteredSkillSuggestions.count }
        if shouldShowCommandPicker { return filteredSlashCommandSuggestions.count }
        if shouldShowPathPicker { return localPathSuggestions.suggestions.count }
        return 0
    }

    private func moveSkillSelection(delta: Int) {
        let count = activeCompletionSuggestionCount
        guard count > 0 else { return }
        selectedSkillIndex = (selectedSkillIndex + delta + count) % count
    }

    private func selectSkillSuggestion(_ skill: HermesDashboardSkill) {
        promptText = promptText.replacingActiveSlashSkillQuery(with: skill.name)
        localPathSuggestions.clear()
        selectedSkillIndex = 0
    }

    private func selectSlashCommandSuggestion(_ command: HermesSlashCommandSuggestion) {
        promptText = promptText.replacingActiveSlashCommandToken(with: command.command)
        localPathSuggestions.clear()
        selectedSkillIndex = 0
    }

    private func selectPathSuggestion(_ path: HermesLocalPathSuggestion) {
        promptText = promptText.replacingActiveSlashCompletionToken(with: path.insertedPath)
        selectedSkillIndex = 0
    }

    private var canResumeLastChatSession: Bool {
        let last = chatSession.lastKnownChatSessionID.trimmingCharacters(in: .whitespacesAndNewlines)
        return !last.isEmpty && chatSession.activeChatSessionID != last
    }

    private func submitPrompt() {
        speechToText.stopTranscription()
        var submittedDraft = chatDraft
        submittedDraft.userPrompt = promptText
        promptHistoryStore.record(submittedDraft.userPrompt, source: .chatWithHermes)
        chatSession.submit(apiSettings: apiSettings, draft: submittedDraft, attachment: selectedAttachment, messageHistory: promptHistoryStore)
        promptText = ""
        chatDraft.userPrompt = ""
        selectedAttachment = nil
    }

    private func handleAttachmentImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                selectedAttachment = try HermesPromptAttachment.load(from: url)
                chatSession.lastErrorMessage = ""
            } catch {
                chatSession.lastErrorMessage = error.localizedDescription
            }
        case .failure(let error):
            chatSession.lastErrorMessage = error.localizedDescription
        }
    }

    private func isChatPlaceholder(_ message: HermesChatMessage) -> Bool {
        chatSession.isSending && message.role != "user" && resolvedLiveContent(for: message).isEmpty && message.id == chatSession.entries.last(where: { $0.role != "user" })?.id
    }

    private func liveContent(for message: HermesChatMessage) -> String? {
        let content = resolvedLiveContent(for: message)
        return content.isEmpty ? nil : content
    }

    private func responseElapsedSeconds(for message: HermesChatMessage) -> Int? {
        guard message.role != "user" else { return nil }
        if message.id == chatSession.activeResponseMessageID {
            return chatSession.activeResponseElapsedSeconds
        }
        return nil
    }

    private func tokenUsage(for message: HermesChatMessage) -> HermesTokenUsage? {
        guard message.role != "user" else { return nil }
        if message.id == chatSession.activeResponseMessageID {
            return chatSession.activeResponseTokenUsage ?? message.tokenUsage
        }
        return message.tokenUsage
    }

    private func resolvedLiveContent(for message: HermesChatMessage) -> String {
        guard chatSession.isSending,
              message.role != "user",
              message.id == chatSession.entries.last(where: { $0.role != "user" })?.id
        else { return "" }
        return chatSession.streamedText
    }

    private func refreshAPIProfiles() async {
        do {
            let profiles = try await HermesAPIProfilesClient.fetchProfiles(apiSettings: apiSettings)
            apiProfiles = profiles
            profileRefreshError = ""
            syncSelectedProfileWithAPIProfiles(profiles, selectedProfile: &chatDraft.profile)
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

struct HermesChatBubble: View {
    let message: HermesChatMessage
    let liveContent: String?
    let fontSize: Double
    var isResponding = false
    var responseElapsedSeconds: Int?
    var tokenUsage: HermesTokenUsage?

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
                            .accessibilityLabel("Response streaming time \(Self.formattedElapsedAccessibilityTime(responseElapsedSeconds))")
                    }
                    if let tokenUsage, !tokenUsage.isEmpty, !isUser {
                        Text(tokenUsage.displayText)
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .foregroundStyle(Color.hermesSecondaryText)
                            .accessibilityLabel("Response token usage: \(tokenUsage.accessibilityText)")
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
    private var displayContent: String { liveContent ?? message.content }

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
