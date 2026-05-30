//
//  HermesLocalProfiles.swift
//  HermesMacOS
//

import Darwin
import Foundation
import Observation

struct HermesLocalProfileInfo: Identifiable, Equatable {
    let id: String
    let name: String
    let path: String
    let isDefault: Bool
    let isActive: Bool
    let provider: String
    let model: String
    let baseURL: String
    let hasConfig: Bool
    let hasEnv: Bool
    let hasSoul: Bool
    let skillCount: Int
    let gatewayRunning: Bool
}

struct HermesLocalProfileDraft: Equatable {
    var name = ""
    var provider = "auto"
    var model = ""
    var baseURL = ""
    var createEnv = false
    var createSoul = false
    var cloneSkills = false
}

@MainActor
@Observable
final class HermesLocalProfilesStore {
    var profiles: [HermesLocalProfileInfo] = []
    var activeProfileName = "default"
    var profilesDirectoryPath = ""
    var lastOutput = ""
    var errorMessage: String?
    var isBusy = false

    var namedProfileCount: Int { profiles.filter { !$0.isDefault }.count }
    var defaultProfile: HermesLocalProfileInfo? { profiles.first(where: { $0.isDefault }) }

    private let fileManager = FileManager.default

    func refresh(hermesHome: String) {
        isBusy = true
        errorMessage = nil
        do {
            let homeURL = try resolvedHermesHome(from: hermesHome)
            let activeName = readActiveProfileName(homeURL: homeURL)
            let profilesURL = homeURL.appendingPathComponent("profiles", isDirectory: true)
            var loaded = [profileInfo(name: "default", profileURL: homeURL, homeURL: homeURL, isDefault: true, isActive: activeName == "default")]

            if let names = try? fileManager.contentsOfDirectory(atPath: profilesURL.path) {
                let named = names
                    .filter { !$0.hasPrefix(".") }
                    .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
                    .compactMap { name -> HermesLocalProfileInfo? in
                        let url = profilesURL.appendingPathComponent(name, isDirectory: true)
                        var isDirectory: ObjCBool = false
                        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else { return nil }
                        return profileInfo(name: name, profileURL: url, homeURL: homeURL, isDefault: false, isActive: activeName == name)
                    }
                loaded.append(contentsOf: named)
            }

            profiles = loaded
            activeProfileName = activeName
            profilesDirectoryPath = profilesURL.path
        } catch {
            errorMessage = error.localizedDescription
            lastOutput = error.localizedDescription
        }
        isBusy = false
    }

    func createProfile(_ draft: HermesLocalProfileDraft, hermesHome: String) {
        perform(hermesHome: hermesHome) { [self] homeURL in
            let name = try normalizedProfileName(draft.name)
            guard name != "default" else { throw HermesLocalProfilesError.profileAlreadyExists(name) }
            let profileURL = profileURL(for: name, homeURL: homeURL)
            guard !fileManager.fileExists(atPath: profileURL.path) else { throw HermesLocalProfilesError.profileAlreadyExists(name) }
            try fileManager.createDirectory(at: profileURL, withIntermediateDirectories: true)
            try seedProfileFiles(profileURL: profileURL, homeURL: homeURL, provider: draft.provider, model: draft.model, baseURL: draft.baseURL, createEnv: draft.createEnv, createSoul: draft.createSoul)
            if draft.cloneSkills { try cloneDefaultSkills(profileURL: profileURL, homeURL: homeURL) }
            return "Created profile \(name) at \(profileURL.path)"
        }
    }

    func editProfile(originalName: String, draft: HermesLocalProfileDraft, hermesHome: String) {
        perform(hermesHome: hermesHome) { [self] homeURL in
            let oldName = try normalizedProfileName(originalName)
            let newName = try normalizedProfileName(draft.name)
            if oldName == "default" && newName != "default" { throw HermesLocalProfilesError.cannotRenameDefault }
            var currentURL = profileURL(for: oldName, homeURL: homeURL)
            if oldName != newName {
                let destination = profileURL(for: newName, homeURL: homeURL)
                guard !fileManager.fileExists(atPath: destination.path) else { throw HermesLocalProfilesError.profileAlreadyExists(newName) }
                try fileManager.moveItem(at: currentURL, to: destination)
                currentURL = destination
                if readActiveProfileName(homeURL: homeURL) == oldName {
                    try writeActiveProfileName(newName, homeURL: homeURL)
                }
            }
            try seedProfileFiles(profileURL: currentURL, homeURL: homeURL, provider: draft.provider, model: draft.model, baseURL: draft.baseURL, createEnv: draft.createEnv, createSoul: draft.createSoul)
            return "Saved profile \(newName) at \(currentURL.path)"
        }
    }

    func useProfile(_ name: String, hermesHome: String) {
        perform(hermesHome: hermesHome) { [self] homeURL in
            let normalized = try normalizedProfileName(name)
            let url = profileURL(for: normalized, homeURL: homeURL)
            guard fileManager.fileExists(atPath: url.path) else { throw HermesLocalProfilesError.profileNotFound(normalized) }
            try writeActiveProfileName(normalized, homeURL: homeURL)
            return "Active profile set to \(normalized)"
        }
    }

    func deleteProfile(_ name: String, hermesHome: String) {
        perform(hermesHome: hermesHome) { [self] homeURL in
            let normalized = try normalizedProfileName(name)
            guard normalized != "default" else { throw HermesLocalProfilesError.cannotDeleteDefault }
            let url = profileURL(for: normalized, homeURL: homeURL)
            guard fileManager.fileExists(atPath: url.path) else { throw HermesLocalProfilesError.profileNotFound(normalized) }
            try fileManager.removeItem(at: url)
            if readActiveProfileName(homeURL: homeURL) == normalized {
                try writeActiveProfileName("default", homeURL: homeURL)
            }
            return "Deleted profile \(normalized)"
        }
    }

    func draftFromDefault() -> HermesLocalProfileDraft {
        guard let defaultProfile else { return HermesLocalProfileDraft() }
        var draft = draft(for: defaultProfile)
        draft.name = ""
        draft.cloneSkills = defaultProfile.skillCount > 0
        return draft
    }

    func draft(for profile: HermesLocalProfileInfo) -> HermesLocalProfileDraft {
        HermesLocalProfileDraft(
            name: profile.name,
            provider: profile.provider.isEmpty ? "auto" : profile.provider,
            model: profile.model,
            baseURL: profile.baseURL,
            createEnv: profile.hasEnv,
            createSoul: profile.hasSoul,
            cloneSkills: false
        )
    }

    private func perform(hermesHome: String, action: @escaping (URL) throws -> String) {
        isBusy = true
        errorMessage = nil
        Task {
            do {
                let homeURL = try resolvedHermesHome(from: hermesHome)
                try await HermesFilesystemAccessPolicy.requireAccess(to: homeURL.path, operation: "Modify local Hermes profile")
                let output = try action(homeURL)
                lastOutput = output
                refresh(hermesHome: homeURL.path)
            } catch {
                let message = error.localizedDescription
                errorMessage = message
                lastOutput = message
            }
            isBusy = false
        }
    }

    private func profileInfo(name: String, profileURL: URL, homeURL: URL, isDefault: Bool, isActive: Bool) -> HermesLocalProfileInfo {
        let configURL = profileURL.appendingPathComponent("config.yaml")
        let config = readProfileConfig(profileURL: profileURL)
        return HermesLocalProfileInfo(
            id: name,
            name: name,
            path: profileURL.path,
            isDefault: isDefault,
            isActive: isActive,
            provider: config.provider,
            model: config.model,
            baseURL: config.baseURL,
            hasConfig: fileManager.fileExists(atPath: configURL.path),
            hasEnv: fileManager.fileExists(atPath: profileURL.appendingPathComponent(".env").path),
            hasSoul: fileManager.fileExists(atPath: profileURL.appendingPathComponent("SOUL.md").path),
            skillCount: countSkills(profileURL: profileURL),
            gatewayRunning: isGatewayRunning(profileURL: profileURL)
        )
    }

    private func readProfileConfig(profileURL: URL) -> (model: String, provider: String, baseURL: String) {
        let configURL = profileURL.appendingPathComponent("config.yaml")
        guard let content = try? String(contentsOf: configURL, encoding: .utf8) else { return ("", "", "") }
        return (
            readYAMLScalar(content: content, section: "model", key: "default") ?? firstTopLevelYAMLScalar(named: "default", in: content) ?? "",
            readYAMLScalar(content: content, section: "model", key: "provider") ?? firstTopLevelYAMLScalar(named: "provider", in: content) ?? "auto",
            readYAMLScalar(content: content, section: "model", key: "base_url") ?? firstTopLevelYAMLScalar(named: "base_url", in: content) ?? ""
        )
    }

    private func seedProfileFiles(profileURL: URL, homeURL: URL, provider: String, model: String, baseURL: String, createEnv: Bool, createSoul: Bool) throws {
        try fileManager.createDirectory(at: profileURL, withIntermediateDirectories: true)
        let defaultConfigURL = homeURL.appendingPathComponent("config.yaml")
        let configURL = profileURL.appendingPathComponent("config.yaml")
        if !fileManager.fileExists(atPath: configURL.path), fileManager.fileExists(atPath: defaultConfigURL.path) {
            try fileManager.copyItem(at: defaultConfigURL, to: configURL)
        }
        try writeModelFields(configURL: configURL, provider: provider, model: model, baseURL: baseURL)
        try syncOptionalFile(fileName: ".env", enabled: createEnv, profileURL: profileURL, homeURL: homeURL)
        try syncOptionalFile(fileName: "SOUL.md", enabled: createSoul, profileURL: profileURL, homeURL: homeURL)
    }

    private func syncOptionalFile(fileName: String, enabled: Bool, profileURL: URL, homeURL: URL) throws {
        let destinationURL = profileURL.appendingPathComponent(fileName)
        if enabled {
            if !fileManager.fileExists(atPath: destinationURL.path) {
                let sourceURL = homeURL.appendingPathComponent(fileName)
                if fileManager.fileExists(atPath: sourceURL.path) {
                    try fileManager.copyItem(at: sourceURL, to: destinationURL)
                } else {
                    try "".write(to: destinationURL, atomically: true, encoding: .utf8)
                }
            }
        } else if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
    }

    private func cloneDefaultSkills(profileURL: URL, homeURL: URL) throws {
        let sourceURL = homeURL.appendingPathComponent("skills", isDirectory: true)
        let destinationURL = profileURL.appendingPathComponent("skills", isDirectory: true)
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: sourceURL.path, isDirectory: &isDirectory), isDirectory.boolValue else { return }
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
    }

    private func writeModelFields(configURL: URL, provider: String, model: String, baseURL: String) throws {
        var content = (try? String(contentsOf: configURL, encoding: .utf8)) ?? ""
        content = setYAMLScalar(content: content, section: "model", key: "provider", value: provider.trimmingCharacters(in: .whitespacesAndNewlines))
        content = setYAMLScalar(content: content, section: "model", key: "default", value: model.trimmingCharacters(in: .whitespacesAndNewlines))
        content = setYAMLScalar(content: content, section: "model", key: "base_url", value: baseURL.trimmingCharacters(in: .whitespacesAndNewlines))
        try content.write(to: configURL, atomically: true, encoding: .utf8)
    }

    private func countSkills(profileURL: URL) -> Int {
        let skillsURL = profileURL.appendingPathComponent("skills", isDirectory: true)
        guard let categories = try? fileManager.contentsOfDirectory(at: skillsURL, includingPropertiesForKeys: [.isDirectoryKey]) else { return 0 }
        var count = 0
        for categoryURL in categories {
            guard (try? categoryURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { continue }
            guard let candidates = try? fileManager.contentsOfDirectory(at: categoryURL, includingPropertiesForKeys: [.isDirectoryKey]) else { continue }
            for candidateURL in candidates where fileManager.fileExists(atPath: candidateURL.appendingPathComponent("SKILL.md").path) {
                count += 1
            }
        }
        return count
    }

    private func isGatewayRunning(profileURL: URL) -> Bool {
        let pidURL = profileURL.appendingPathComponent("gateway.pid")
        guard let raw = try? String(contentsOf: pidURL, encoding: .utf8), let pid = Int32(raw.trimmingCharacters(in: .whitespacesAndNewlines)) else { return false }
        return kill(pid, 0) == 0
    }

    private func readActiveProfileName(homeURL: URL) -> String {
        let activeURL = homeURL.appendingPathComponent("active_profile")
        guard let raw = try? String(contentsOf: activeURL, encoding: .utf8) else { return "default" }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "default" : trimmed
    }

    private func writeActiveProfileName(_ name: String, homeURL: URL) throws {
        if name == "default" {
            let activeURL = homeURL.appendingPathComponent("active_profile")
            if fileManager.fileExists(atPath: activeURL.path) { try fileManager.removeItem(at: activeURL) }
        } else {
            try name.write(to: homeURL.appendingPathComponent("active_profile"), atomically: true, encoding: .utf8)
        }
    }

    private func profileURL(for name: String, homeURL: URL) -> URL {
        name == "default" ? homeURL : homeURL.appendingPathComponent("profiles", isDirectory: true).appendingPathComponent(name, isDirectory: true)
    }

    private func normalizedProfileName(_ name: String) throws -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        guard !trimmed.isEmpty,
              trimmed != ".",
              trimmed != "..",
              !trimmed.hasPrefix("-"),
              !trimmed.contains("/"),
              !trimmed.contains("\\"),
              trimmed.rangeOfCharacter(from: allowed.inverted) == nil
        else { throw HermesLocalProfilesError.invalidProfileName }
        return trimmed
    }

    private func resolvedHermesHome(from path: String) throws -> URL {
        let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        let expanded = (trimmedPath.isEmpty ? "~/.hermes" : trimmedPath as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expanded, isDirectory: true)
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else { throw HermesLocalProfilesError.invalidHermesHome(path) }
        return url
    }

    private func firstTopLevelYAMLScalar(named key: String, in content: String) -> String? {
        for line in content.components(separatedBy: "\n") where indentation(of: line) == 0 {
            if let value = HermesYAMLScalar.value(from: line, key: key) { return value }
        }
        return nil
    }

    private func readYAMLScalar(content: String, section: String, key: String) -> String? {
        let lines = content.components(separatedBy: "\n")
        guard let sectionIndex = lines.firstIndex(where: { $0.range(of: #"^\#(section):\s*(#.*)?$"#, options: .regularExpression) != nil }) else { return nil }
        let sectionIndent = indentation(of: lines[sectionIndex])
        var index = sectionIndex + 1
        while index < lines.count {
            let line = lines[index]
            if !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && indentation(of: line) <= sectionIndent { break }
            if indentation(of: line) == sectionIndent + 2, let value = scalarValue(from: line, key: key) { return value }
            index += 1
        }
        return nil
    }

    private func scalarValue(from line: String, key: String) -> String? {
        HermesYAMLScalar.value(from: line, key: key)
    }

    private func firstMatch(in content: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(content.startIndex..<content.endIndex, in: content)
        guard let match = regex.firstMatch(in: content, range: range), match.numberOfRanges > 1,
              let valueRange = Range(match.range(at: 1), in: content) else { return nil }
        return String(content[valueRange]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func indentation(of line: String) -> Int { line.prefix { $0 == " " }.count }

    private func setYAMLScalar(content: String, section: String, key: String, value: String) -> String {
        var lines = content.components(separatedBy: "\n")
        if lines == [""] { lines = [] }
        let sectionLine = "\(section):"
        let keyLine = "  \(key): \(quotedYAML(value))"
        guard let sectionIndex = lines.firstIndex(where: { $0.range(of: #"^\#(section):\s*(#.*)?$"#, options: .regularExpression) != nil }) else {
            lines.append(sectionLine)
            lines.append(keyLine)
            return lines.joined(separator: "\n")
        }
        let sectionIndent = indentation(of: lines[sectionIndex])
        var insertIndex = sectionIndex + 1
        var index = sectionIndex + 1
        while index < lines.count {
            let line = lines[index]
            if !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && indentation(of: line) <= sectionIndent { break }
            if indentation(of: line) == sectionIndent + 2, scalarValue(from: line, key: key) != nil {
                lines[index] = keyLine
                return lines.joined(separator: "\n")
            }
            insertIndex = index + 1
            index += 1
        }
        lines.insert(keyLine, at: insertIndex)
        return lines.joined(separator: "\n")
    }

    private func quotedYAML(_ value: String) -> String {
        HermesYAMLScalar.quoted(value)
    }
}

private enum HermesLocalProfilesError: LocalizedError {
    case invalidHermesHome(String)
    case invalidProfileName
    case cannotDeleteDefault
    case cannotRenameDefault
    case profileAlreadyExists(String)
    case profileNotFound(String)

    var errorDescription: String? {
        switch self {
        case .invalidHermesHome(let path):
            return "The Hermes home path '\(path)' is invalid."
        case .invalidProfileName:
            return "Enter a valid profile name using letters, numbers, dots, underscores, or dashes."
        case .cannotDeleteDefault:
            return "Cannot delete the default profile."
        case .cannotRenameDefault:
            return "Cannot rename the default profile."
        case .profileAlreadyExists(let name):
            return "A profile named '\(name)' already exists."
        case .profileNotFound(let name):
            return "Profile '\(name)' was not found."
        }
    }
}
