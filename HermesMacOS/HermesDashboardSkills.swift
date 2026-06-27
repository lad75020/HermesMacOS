//
//  HermesDashboardSkills.swift
//  HermesMacOS
//

import SwiftUI

struct HermesDashboardSkill: Codable, Identifiable, Equatable {
    let name: String
    let description: String?
    let category: String?
    let enabled: Bool?

    var id: String { name }
    var isEnabled: Bool { enabled ?? true }
    var statusLabel: String { isEnabled ? "Enabled" : "Disabled" }
}

@MainActor
@Observable
final class HermesDashboardSkillsStore {
    var skills: [HermesDashboardSkill] = []
    var isLoading = false
    var lastErrorMessage = ""

    private var activeTask: Task<Void, Never>?

    func refreshIfNeeded(dashboardBaseURL: String, apiSettings: HermesAPISettings) {
        guard skills.isEmpty, !isLoading else { return }
        refresh(dashboardBaseURL: dashboardBaseURL, apiSettings: apiSettings)
    }

    func refresh(dashboardBaseURL: String, apiSettings: HermesAPISettings) {
        refresh(dashboardBaseURL: dashboardBaseURL, apiSettings: apiSettings, includeDisabled: false)
    }

    func refreshForManagement(dashboardBaseURL: String, apiSettings: HermesAPISettings) {
        refresh(dashboardBaseURL: dashboardBaseURL, apiSettings: apiSettings, includeDisabled: true)
    }

    func setSkillEnabled(_ skill: HermesDashboardSkill, enabled: Bool, dashboardBaseURL: String, apiSettings: HermesAPISettings) {
        activeTask?.cancel()
        activeTask = Task { await toggleSkill(skill, enabled: enabled, dashboardBaseURL: dashboardBaseURL, apiSettings: apiSettings) }
    }

    private func refresh(dashboardBaseURL: String, apiSettings: HermesAPISettings, includeDisabled: Bool) {
        activeTask?.cancel()
        activeTask = Task { await loadSkills(dashboardBaseURL: dashboardBaseURL, apiSettings: apiSettings, includeDisabled: includeDisabled) }
    }

    private func loadSkills(dashboardBaseURL: String, apiSettings: HermesAPISettings, includeDisabled: Bool) async {
        isLoading = true
        lastErrorMessage = ""
        defer { isLoading = false }

        do {
            let baseURL = try await HermesDashboardClient.shared.resolvedBaseURL(dashboardBaseURL: dashboardBaseURL, apiBaseURL: apiSettings.baseURL)
            let fetched = try await HermesDashboardClient.shared.getJSON([HermesDashboardSkill].self, baseURL: baseURL, path: "api/skills", apiSettings: apiSettings)
            skills = fetched
                .filter { includeDisabled || ($0.enabled ?? true) }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    private func toggleSkill(_ skill: HermesDashboardSkill, enabled: Bool, dashboardBaseURL: String, apiSettings: HermesAPISettings) async {
        isLoading = true
        lastErrorMessage = ""
        defer { isLoading = false }

        do {
            let baseURL = try await HermesDashboardClient.shared.resolvedBaseURL(dashboardBaseURL: dashboardBaseURL, apiBaseURL: apiSettings.baseURL)
            _ = try await HermesDashboardClient.shared.sendJSON(
                baseURL: baseURL,
                path: "api/skills/toggle",
                method: "PUT",
                apiSettings: apiSettings,
                body: HermesDashboardSkillToggleRequest(name: skill.name, enabled: enabled)
            )
            if let index = skills.firstIndex(where: { $0.name == skill.name }) {
                skills[index] = HermesDashboardSkill(
                    name: skill.name,
                    description: skill.description,
                    category: skill.category,
                    enabled: enabled
                )
            }
            await loadSkills(dashboardBaseURL: dashboardBaseURL, apiSettings: apiSettings, includeDisabled: true)
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }
}

private struct HermesDashboardSkillToggleRequest: Encodable {
    let name: String
    let enabled: Bool
}

struct HermesSkillSlashPicker: View {
    let skills: [HermesDashboardSkill]
    let selectedIndex: Int
    let isLoading: Bool
    let errorMessage: String
    let onSelect: (HermesDashboardSkill) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isLoading && skills.isEmpty {
                dropdownRow(title: "Loading skills…", subtitle: nil, isSelected: false)
            } else if !errorMessage.isEmpty && skills.isEmpty {
                dropdownRow(title: "Skills unavailable", subtitle: errorMessage, isSelected: false)
            } else if skills.isEmpty {
                dropdownRow(title: "No matching skills", subtitle: nil, isSelected: false)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical) {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(skills.enumerated()), id: \.element.id) { index, skill in
                                Button { onSelect(skill) } label: {
                                    dropdownRow(title: "/skill \(skill.name)", subtitle: skill.description, isSelected: index == selectedIndex)
                                }
                                .id(skill.id)
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(height: 176)
                    .onChange(of: selectedIndex) { _, newIndex in
                        guard skills.indices.contains(newIndex) else { return }
                        withAnimation(.easeInOut(duration: 0.12)) { proxy.scrollTo(skills[newIndex].id, anchor: .center) }
                    }
                    .onAppear {
                        guard skills.indices.contains(selectedIndex) else { return }
                        proxy.scrollTo(skills[selectedIndex].id, anchor: .center)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.18), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.24), radius: 18, x: 0, y: 10)
    }

    private func dropdownRow(title: String, subtitle: String?, isSelected: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .lineLimit(1)
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(isSelected ? Color.white.opacity(0.82) : Color.hermesSecondaryText)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 35, alignment: .center)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? Color.hermesActionBlue.opacity(0.86) : Color.clear)
        .contentShape(Rectangle())
    }
}

struct HermesSlashCommandSuggestion: Identifiable, Equatable {
    let command: String
    let summary: String
    let category: String
    var aliases: [String] = []

    var id: String { command }
    var displayTitle: String { aliases.isEmpty ? command : "\(command) (\(aliases.joined(separator: ", ")))" }
    var searchableText: String { ([command, summary, category] + aliases).joined(separator: " ") }

    static let all: [HermesSlashCommandSuggestion] = [
        .init(command: "/new", summary: "Fresh session", category: "Session", aliases: ["/reset"]),
        .init(command: "/clear", summary: "Clear screen and start a new CLI session", category: "Session"),
        .init(command: "/retry", summary: "Resend the last message", category: "Session"),
        .init(command: "/undo", summary: "Remove the last exchange", category: "Session"),
        .init(command: "/title", summary: "Name the session", category: "Session"),
        .init(command: "/compress", summary: "Manually compress context", category: "Session"),
        .init(command: "/stop", summary: "Kill background processes", category: "Session"),
        .init(command: "/rollback", summary: "Restore a filesystem checkpoint", category: "Session"),
        .init(command: "/background", summary: "Run a prompt in the background", category: "Session"),
        .init(command: "/queue", summary: "Queue a prompt for next turn", category: "Session"),
        .init(command: "/resume", summary: "Resume a named session", category: "Session"),
        .init(command: "/config", summary: "Show configuration", category: "Configuration"),
        .init(command: "/model", summary: "Show or change model", category: "Configuration"),
        .init(command: "/personality", summary: "Set personality", category: "Configuration"),
        .init(command: "/reasoning", summary: "Set reasoning level or visibility", category: "Configuration"),
        .init(command: "/verbose", summary: "Cycle verbose output", category: "Configuration"),
        .init(command: "/voice", summary: "Voice mode on, off, or TTS", category: "Configuration"),
        .init(command: "/yolo", summary: "Toggle approval bypass", category: "Configuration"),
        .init(command: "/skin", summary: "Change CLI theme", category: "Configuration"),
        .init(command: "/statusbar", summary: "Toggle CLI status bar", category: "Configuration"),
        .init(command: "/tools", summary: "Manage tools", category: "Tools & Skills"),
        .init(command: "/toolsets", summary: "List toolsets", category: "Tools & Skills"),
        .init(command: "/skills", summary: "Search and install skills", category: "Tools & Skills"),
        .init(command: "/skill", summary: "Load a skill into the session", category: "Tools & Skills"),
        .init(command: "/cron", summary: "Manage cron jobs", category: "Tools & Skills"),
        .init(command: "/reload-mcp", summary: "Reload MCP servers", category: "Tools & Skills"),
        .init(command: "/plugins", summary: "List plugins", category: "Tools & Skills"),
        .init(command: "/approve", summary: "Approve a pending gateway command", category: "Gateway"),
        .init(command: "/deny", summary: "Deny a pending gateway command", category: "Gateway"),
        .init(command: "/restart", summary: "Restart gateway", category: "Gateway"),
        .init(command: "/sethome", summary: "Set current chat as home channel", category: "Gateway"),
        .init(command: "/update", summary: "Update Hermes to latest", category: "Gateway"),
        .init(command: "/platforms", summary: "Show platform connection status", category: "Gateway", aliases: ["/gateway"]),
        .init(command: "/branch", summary: "Branch the current session", category: "Utility", aliases: ["/fork"]),
        .init(command: "/fast", summary: "Toggle priority/fast processing", category: "Utility"),
        .init(command: "/browser", summary: "Open CDP browser connection", category: "Utility"),
        .init(command: "/history", summary: "Show conversation history", category: "Utility"),
        .init(command: "/save", summary: "Save conversation to file", category: "Utility"),
        .init(command: "/paste", summary: "Attach clipboard image", category: "Utility"),
        .init(command: "/image", summary: "Attach local image file", category: "Utility"),
        .init(command: "/help", summary: "Show commands", category: "Info"),
        .init(command: "/commands", summary: "Browse all commands", category: "Info"),
        .init(command: "/usage", summary: "Token usage", category: "Info"),
        .init(command: "/insights", summary: "Usage analytics", category: "Info"),
        .init(command: "/status", summary: "Session info", category: "Info"),
        .init(command: "/profile", summary: "Active profile info", category: "Info"),
        .init(command: "/quit", summary: "Exit CLI", category: "Exit", aliases: ["/exit", "/q"])
    ]
}

struct HermesSlashCommandPicker: View {
    let commands: [HermesSlashCommandSuggestion]
    let selectedIndex: Int
    let onSelect: (HermesSlashCommandSuggestion) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if commands.isEmpty {
                dropdownRow(title: "No matching commands", subtitle: nil, isSelected: false)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical) {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(commands.enumerated()), id: \.element.id) { index, command in
                                Button { onSelect(command) } label: {
                                    dropdownRow(title: command.displayTitle, subtitle: "\(command.category) · \(command.summary)", isSelected: index == selectedIndex)
                                }
                                .id(command.id)
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(height: 176)
                    .onChange(of: selectedIndex) { _, newIndex in
                        guard commands.indices.contains(newIndex) else { return }
                        withAnimation(.easeInOut(duration: 0.12)) { proxy.scrollTo(commands[newIndex].id, anchor: .center) }
                    }
                    .onAppear {
                        guard commands.indices.contains(selectedIndex) else { return }
                        proxy.scrollTo(commands[selectedIndex].id, anchor: .center)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.18), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.24), radius: 18, x: 0, y: 10)
    }

    private func dropdownRow(title: String, subtitle: String?, isSelected: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .lineLimit(1)
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(isSelected ? Color.white.opacity(0.82) : Color.hermesSecondaryText)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 35, alignment: .center)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? Color.hermesActionBlue.opacity(0.86) : Color.clear)
        .contentShape(Rectangle())
    }
}

struct HermesLocalPathSuggestion: Identifiable, Equatable {
    let url: URL
    let displayName: String
    let isDirectory: Bool

    var id: String { url.path }
    var subtitle: String { isDirectory ? "Folder" : "File" }
    var insertedPath: String { isDirectory ? url.path + "/" : url.path + " " }
}

@MainActor
@Observable
final class HermesLocalPathSuggestionsStore {
    var suggestions: [HermesLocalPathSuggestion] = []
    var lastErrorMessage = ""
    private var lastQuery = ""

    func refresh(pathToken: String) {
        guard pathToken != lastQuery else { return }
        lastQuery = pathToken
        load(pathToken: pathToken)
    }

    func clear() {
        lastQuery = ""
        suggestions = []
        lastErrorMessage = ""
    }

    private func load(pathToken: String) {
        let expandedToken = NSString(string: pathToken).expandingTildeInPath
        let folderPath: String
        let partialName: String

        if expandedToken.hasSuffix("/") {
            folderPath = expandedToken
            partialName = ""
        } else {
            let nsPath = expandedToken as NSString
            folderPath = nsPath.deletingLastPathComponent.isEmpty ? "/" : nsPath.deletingLastPathComponent
            partialName = nsPath.lastPathComponent
        }

        do {
            let folderURL = URL(fileURLWithPath: folderPath, isDirectory: true)
            let entries = try FileManager.default.contentsOfDirectory(
                at: folderURL,
                includingPropertiesForKeys: [.isDirectoryKey, .isHiddenKey],
                options: partialName.hasPrefix(".") ? [] : [.skipsHiddenFiles]
            )
            suggestions = entries.compactMap { url in
                let name = url.lastPathComponent
                guard partialName.isEmpty || name.range(of: partialName, options: [.caseInsensitive, .anchored]) != nil else { return nil }
                let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
                return HermesLocalPathSuggestion(url: url, displayName: name, isDirectory: values?.isDirectory == true)
            }
            .sorted { lhs, rhs in
                if lhs.isDirectory != rhs.isDirectory { return lhs.isDirectory && !rhs.isDirectory }
                return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
            lastErrorMessage = ""
        } catch {
            suggestions = []
            lastErrorMessage = error.localizedDescription
        }
    }
}

struct HermesPathSlashPicker: View {
    let pathToken: String
    let paths: [HermesLocalPathSuggestion]
    let selectedIndex: Int
    let errorMessage: String
    let onSelect: (HermesLocalPathSuggestion) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !errorMessage.isEmpty && paths.isEmpty {
                dropdownRow(title: "Path unavailable", subtitle: errorMessage, isSelected: false, systemImage: "exclamationmark.triangle")
            } else if paths.isEmpty {
                dropdownRow(title: "No matching paths", subtitle: pathToken, isSelected: false, systemImage: "folder")
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical) {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(paths.enumerated()), id: \.element.id) { index, path in
                                Button { onSelect(path) } label: {
                                    dropdownRow(
                                        title: path.displayName,
                                        subtitle: path.subtitle,
                                        isSelected: index == selectedIndex,
                                        systemImage: path.isDirectory ? "folder.fill" : "doc"
                                    )
                                }
                                .id(path.id)
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(height: 176)
                    .onChange(of: selectedIndex) { _, newIndex in
                        guard paths.indices.contains(newIndex) else { return }
                        withAnimation(.easeInOut(duration: 0.12)) { proxy.scrollTo(paths[newIndex].id, anchor: .center) }
                    }
                    .onAppear {
                        guard paths.indices.contains(selectedIndex) else { return }
                        proxy.scrollTo(paths[selectedIndex].id, anchor: .center)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.18), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.24), radius: 18, x: 0, y: 10)
    }

    private func dropdownRow(title: String, subtitle: String?, isSelected: Bool, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isSelected ? Color.white : Color.hermesSecondaryText)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(isSelected ? Color.white : Color.primary)
                    .lineLimit(1)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(isSelected ? Color.white.opacity(0.82) : Color.hermesSecondaryText)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 35, alignment: .center)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? Color.hermesActionBlue.opacity(0.86) : Color.clear)
        .contentShape(Rectangle())
    }
}

extension String {
    var hermesActiveSlashCompletionToken: String? {
        let tokenStart = lastIndex(where: { $0.isWhitespace }).map { index(after: $0) } ?? startIndex
        guard tokenStart < endIndex else { return nil }
        let token = self[tokenStart...]
        guard token.first == "/" else { return nil }
        return String(token)
    }

    var hermesActiveSlashCommandQuery: String? {
        guard let token = hermesActiveSlashCompletionToken else { return nil }
        let suffix = token.dropFirst()
        guard !suffix.contains("/") else { return nil }
        return String(suffix)
    }

    var hermesActiveSlashSkillQuery: String? {
        guard let range = hermesActiveSkillCommandRange else { return nil }
        let suffix = self[range.upperBound...]
        guard !suffix.contains(where: { $0.isNewline }) else { return nil }
        return String(suffix.drop(while: { $0.isWhitespace }))
    }

    private var hermesActiveSkillCommandRange: Range<String.Index>? {
        let lineStart = lastIndex(where: { $0.isNewline }).map { index(after: $0) } ?? startIndex
        var searchRange = lineStart..<endIndex
        while let range = self.range(of: "/skill", options: [.backwards], range: searchRange) {
            let startsAtBoundary = range.lowerBound == startIndex || self[index(before: range.lowerBound)].isWhitespace
            let endsAtBoundary = range.upperBound == endIndex || self[range.upperBound].isWhitespace
            if startsAtBoundary && endsAtBoundary { return range }
            guard range.lowerBound > lineStart else { break }
            searchRange = lineStart..<range.lowerBound
        }
        return nil
    }

    func replacingActiveSlashSkillQuery(with skillName: String) -> String {
        guard let range = hermesActiveSkillCommandRange else { return self }
        let prefix = self[..<range.lowerBound]
        return "\(prefix)/skill \(skillName) "
    }

    func replacingActiveSlashCommandToken(with command: String) -> String {
        let tokenStart = lastIndex(where: { $0.isWhitespace }).map { index(after: $0) } ?? startIndex
        guard tokenStart < endIndex, self[tokenStart] == "/" else { return self }
        let prefix = self[..<tokenStart]
        return "\(prefix)\(command) "
    }

    func replacingActiveSlashCompletionToken(with replacement: String) -> String {
        let tokenStart = lastIndex(where: { $0.isWhitespace }).map { index(after: $0) } ?? startIndex
        guard tokenStart < endIndex, self[tokenStart] == "/" else { return self }
        let prefix = self[..<tokenStart]
        return "\(prefix)\(replacement)"
    }
}
