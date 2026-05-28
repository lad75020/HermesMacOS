//
//  HermesLocalRuntimeModels.swift
//  HermesMacOS
//

import Foundation

struct HermesRuntimeProviderOption: Identifiable, Equatable {
    let value: String
    let label: String

    var id: String { value }
}

struct HermesRuntimeModelSlot: Identifiable, Equatable {
    let id: String
    let label: String
    let section: String
    let key: String
    var provider: String
    var model: String
}

struct HermesRuntimeMainModel: Equatable {
    var provider: String
    var model: String
    var baseURL: String
}

@Observable
final class HermesLocalRuntimeModelsStore {
    var mainModel = HermesRuntimeMainModel(provider: "auto", model: "", baseURL: "")
    var delegationModel = HermesRuntimeModelSlot(id: "delegation", label: "Delegation", section: "delegation", key: "delegation", provider: "", model: "")
    var auxiliaryModels: [HermesRuntimeModelSlot] = []
    var providerOptions: [HermesRuntimeProviderOption] = HermesLocalRuntimeModelsStore.defaultProviderOptions
    var resolvedHermesHome = ""
    var configPath = ""
    var isLoading = false
    var lastStatusMessage = "Not loaded yet."

    private let hermesHome = HermesRuntimePaths.defaultHermesHome
    private var configURL: URL { URL(fileURLWithPath: hermesHome).appendingPathComponent("config.yaml") }

    static let defaultProviderOptions: [HermesRuntimeProviderOption] = [
        .init(value: "auto", label: "Auto-detect"),
        .init(value: "openrouter", label: "OpenRouter"),
        .init(value: "anthropic", label: "Anthropic"),
        .init(value: "openai", label: "OpenAI"),
        .init(value: "google", label: "Google"),
        .init(value: "xai", label: "xAI"),
        .init(value: "nous", label: "Nous"),
        .init(value: "qwen", label: "Qwen"),
        .init(value: "minimax", label: "MiniMax"),
        .init(value: "custom", label: "Local / Custom")
    ]

    private static let auxiliaryModelSlots: [(key: String, label: String)] = [
        ("vision", "Vision"),
        ("web_extract", "Web Extract"),
        ("compression", "Compression"),
        ("session_search", "Session Search"),
        ("skills_hub", "Skills Hub"),
        ("approval", "Approval"),
        ("mcp", "MCP"),
        ("title_generation", "Title Generation"),
        ("curator", "Curator")
    ]

    func refresh() {
        isLoading = true
        lastStatusMessage = "Loading runtime model routing from local config.yaml…"
        let hermesHome = self.hermesHome
        let configURL = self.configURL
        Task.detached(priority: .userInitiated) {
            let result = Self.loadModels(hermesHome: hermesHome, configURL: configURL)
            await MainActor.run {
                self.resolvedHermesHome = hermesHome
                self.configPath = configURL.path
                switch result {
                case .success(let loaded):
                    self.mainModel = loaded.main
                    self.delegationModel = loaded.delegation
                    self.auxiliaryModels = loaded.auxiliary
                    self.lastStatusMessage = "Loaded \(1 + 1 + loaded.auxiliary.count) runtime model slots from \(configURL.path)."
                case .failure(let error):
                    self.lastStatusMessage = "Failed to load models: \(error.localizedDescription)"
                }
                self.isLoading = false
            }
        }
    }

    func saveMain(provider: String, model: String) {
        isLoading = true
        let cleanProvider = provider.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        lastStatusMessage = "Saving main model routing…"
        let configURL = self.configURL
        Task.detached(priority: .userInitiated) {
            let result = Result { try Self.writeMain(configURL: configURL, provider: cleanProvider, model: cleanModel) }
            await MainActor.run {
                switch result {
                case .success:
                    self.mainModel.provider = cleanProvider
                    self.mainModel.model = cleanModel
                    self.lastStatusMessage = "Saved main model routing to \(configURL.path)."
                    self.refresh()
                case .failure(let error):
                    self.lastStatusMessage = "Failed to save main model: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }

    func saveSlot(_ slot: HermesRuntimeModelSlot, provider: String, model: String) {
        isLoading = true
        let cleanProvider = provider.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        lastStatusMessage = "Saving \(slot.label) model routing…"
        let configURL = self.configURL
        Task.detached(priority: .userInitiated) {
            let result = Result { try Self.writeSlot(configURL: configURL, slot: slot, provider: cleanProvider, model: cleanModel) }
            await MainActor.run {
                switch result {
                case .success:
                    if slot.id == self.delegationModel.id {
                        self.delegationModel.provider = cleanProvider
                        self.delegationModel.model = cleanModel
                    } else if let index = self.auxiliaryModels.firstIndex(where: { $0.id == slot.id }) {
                        self.auxiliaryModels[index].provider = cleanProvider
                        self.auxiliaryModels[index].model = cleanModel
                    }
                    self.lastStatusMessage = "Saved \(slot.label) model routing to \(configURL.path)."
                    self.refresh()
                case .failure(let error):
                    self.lastStatusMessage = "Failed to save \(slot.label): \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }

    private struct LoadedModels {
        let main: HermesRuntimeMainModel
        let delegation: HermesRuntimeModelSlot
        let auxiliary: [HermesRuntimeModelSlot]
    }

    private static func loadModels(hermesHome: String, configURL: URL) -> Result<LoadedModels, Error> {
        Result {
            let content = (try? String(contentsOf: configURL, encoding: .utf8)) ?? ""
            let main = HermesRuntimeMainModel(
                provider: readYAMLScalar(content: content, section: "model", key: "provider") ?? readTopLevelYAMLScalar(content: content, key: "provider") ?? "auto",
                model: readYAMLScalar(content: content, section: "model", key: "default") ?? readTopLevelYAMLScalar(content: content, key: "default") ?? "",
                baseURL: readYAMLScalar(content: content, section: "model", key: "base_url") ?? readTopLevelYAMLScalar(content: content, key: "base_url") ?? ""
            )
            let delegation = HermesRuntimeModelSlot(
                id: "delegation",
                label: "Delegation",
                section: "delegation",
                key: "delegation",
                provider: readYAMLScalar(content: content, section: "delegation", key: "provider") ?? "",
                model: readYAMLScalar(content: content, section: "delegation", key: "model") ?? ""
            )
            let auxiliary = auxiliaryModelSlotDefinitions(content: content).map { slot in
                HermesRuntimeModelSlot(
                    id: "auxiliary.\(slot.key)",
                    label: slot.label,
                    section: "auxiliary",
                    key: slot.key,
                    provider: readYAMLScalar(content: content, section: "auxiliary", child: slot.key, key: "provider") ?? "",
                    model: readYAMLScalar(content: content, section: "auxiliary", child: slot.key, key: "model") ?? ""
                )
            }
            return LoadedModels(main: main, delegation: delegation, auxiliary: auxiliary)
        }
    }

    private static func writeMain(configURL: URL, provider: String, model: String) throws {
        var content = (try? String(contentsOf: configURL, encoding: .utf8)) ?? ""
        content = setYAMLScalar(content: content, section: "model", key: "provider", value: provider)
        content = setYAMLScalar(content: content, section: "model", key: "default", value: model)
        content = setYAMLScalar(content: content, section: "model", key: "streaming", rawValue: "true")
        try write(content, to: configURL)
    }

    private static func writeSlot(configURL: URL, slot: HermesRuntimeModelSlot, provider: String, model: String) throws {
        var content = (try? String(contentsOf: configURL, encoding: .utf8)) ?? ""
        if slot.section == "delegation" {
            content = setYAMLScalar(content: content, section: "delegation", key: "provider", value: provider)
            content = setYAMLScalar(content: content, section: "delegation", key: "model", value: model)
        } else {
            content = setYAMLScalar(content: content, section: "auxiliary", child: slot.key, key: "provider", value: provider)
            content = setYAMLScalar(content: content, section: "auxiliary", child: slot.key, key: "model", value: model)
        }
        try write(content, to: configURL)
    }

    private static func auxiliaryModelSlotDefinitions(content: String) -> [(key: String, label: String)] {
        var slots = Self.auxiliaryModelSlots
        let knownKeys = Set(slots.map(\.key))
        for key in configuredAuxiliaryModelKeys(content: content) where !knownKeys.contains(key) {
            slots.append((key, humanizedAuxiliaryLabel(for: key)))
        }
        return slots
    }

    private static func configuredAuxiliaryModelKeys(content: String) -> [String] {
        let lines = content.components(separatedBy: "\n")
        guard let sectionIndex = lines.firstIndex(where: { $0.range(of: #"^auxiliary:\s*(#.*)?$"#, options: .regularExpression) != nil }) else { return [] }
        let sectionIndent = indentation(of: lines[sectionIndex])
        var keys: [String] = []
        var index = sectionIndex + 1
        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && indentation(of: line) <= sectionIndent { break }
            if indentation(of: line) == sectionIndent + 2,
               let key = mappingKey(from: line),
               !keys.contains(key) {
                keys.append(key)
            }
            index += 1
        }
        return keys
    }

    private static func mappingKey(from line: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: #"^\s*([A-Za-z0-9_-]+):\s*(#.*)?$"#),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: line) else { return nil }
        return String(line[range]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func humanizedAuxiliaryLabel(for key: String) -> String {
        key.split(separator: "_")
            .map { word in
                guard let first = word.first else { return "" }
                return String(first).uppercased() + String(word.dropFirst())
            }
            .joined(separator: " ")
    }

    private static func readTopLevelYAMLScalar(content: String, key: String) -> String? {
        firstMatch(in: content, pattern: #"^\#(key):\s*[\"']?([^\"'\n#]*)[\"']?"#)
    }

    private static func readYAMLScalar(content: String, section: String, child: String? = nil, key: String) -> String? {
        let lines = content.components(separatedBy: "\n")
        guard let sectionIndex = lines.firstIndex(where: { $0.range(of: #"^\#(section):\s*(#.*)?$"#, options: .regularExpression) != nil }) else { return nil }
        let sectionIndent = indentation(of: lines[sectionIndex])
        var index = sectionIndex + 1
        if let child {
            var childIndex: Int?
            while index < lines.count {
                let line = lines[index]
                if !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && indentation(of: line) <= sectionIndent { break }
                if indentation(of: line) == sectionIndent + 2 && line.trimmingCharacters(in: .whitespaces).range(of: #"^\#(child):\s*(#.*)?$"#, options: .regularExpression) != nil {
                    childIndex = index
                    break
                }
                index += 1
            }
            guard let childIndex else { return nil }
            let childIndent = indentation(of: lines[childIndex])
            index = childIndex + 1
            while index < lines.count {
                let line = lines[index]
                if !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && indentation(of: line) <= childIndent { break }
                if indentation(of: line) == childIndent + 2, let value = scalarValue(from: line, key: key) { return value }
                index += 1
            }
            return nil
        }
        while index < lines.count {
            let line = lines[index]
            if !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && indentation(of: line) <= sectionIndent { break }
            if indentation(of: line) == sectionIndent + 2, let value = scalarValue(from: line, key: key) { return value }
            index += 1
        }
        return nil
    }

    private static func setYAMLScalar(content: String, section: String, child: String? = nil, key: String, value: String? = nil, rawValue: String? = nil) -> String {
        var lines = content.components(separatedBy: "\n")
        if lines == [""] { lines = [] }
        let replacementValue = rawValue ?? quotedYAML(value ?? "")
        let sectionLine = "\(section):"
        let keyLine = "  \(key): \(replacementValue)"
        let childLine = child.map { "  \($0):" }
        let childKeyLine = child.map { _ in "    \(key): \(replacementValue)" }

        guard let sectionIndex = lines.firstIndex(where: { $0.range(of: #"^\#(section):\s*(#.*)?$"#, options: .regularExpression) != nil }) else {
            lines.append(sectionLine)
            if let childLine, let childKeyLine {
                lines.append(childLine)
                lines.append(childKeyLine)
            } else {
                lines.append(keyLine)
            }
            return lines.joined(separator: "\n") + "\n"
        }

        let sectionIndent = indentation(of: lines[sectionIndex])
        if let child, let childLine, let childKeyLine {
            var index = sectionIndex + 1
            var insertAt = index
            while index < lines.count {
                let line = lines[index]
                if !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && indentation(of: line) <= sectionIndent { break }
                insertAt = index + 1
                if indentation(of: line) == sectionIndent + 2 && line.trimmingCharacters(in: .whitespaces).range(of: #"^\#(child):\s*(#.*)?$"#, options: .regularExpression) != nil {
                    let childIndent = indentation(of: line)
                    var childScan = index + 1
                    var childInsertAt = childScan
                    while childScan < lines.count {
                        let childScanLine = lines[childScan]
                        if !childScanLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && indentation(of: childScanLine) <= childIndent { break }
                        childInsertAt = childScan + 1
                        if indentation(of: childScanLine) == childIndent + 2 && scalarValue(from: childScanLine, key: key) != nil {
                            lines[childScan] = childKeyLine
                            return lines.joined(separator: "\n")
                        }
                        childScan += 1
                    }
                    lines.insert(childKeyLine, at: childInsertAt)
                    return lines.joined(separator: "\n")
                }
                index += 1
            }
            lines.insert(contentsOf: [childLine, childKeyLine], at: insertAt)
            return lines.joined(separator: "\n")
        }

        var index = sectionIndex + 1
        var insertAt = index
        while index < lines.count {
            let line = lines[index]
            if !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && indentation(of: line) <= sectionIndent { break }
            insertAt = index + 1
            if indentation(of: line) == sectionIndent + 2 && scalarValue(from: line, key: key) != nil {
                lines[index] = keyLine
                return lines.joined(separator: "\n")
            }
            index += 1
        }
        lines.insert(keyLine, at: insertAt)
        return lines.joined(separator: "\n")
    }

    private static func scalarValue(from line: String, key: String) -> String? {
        HermesYAMLScalar.value(from: line, key: key)
    }

    private static func indentation(of line: String) -> Int { line.prefix { $0 == " " }.count }

    private static func quotedYAML(_ value: String) -> String {
        HermesYAMLScalar.quoted(value)
    }

    private static func firstMatch(in content: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]),
              let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: content) else { return nil }
        return String(content[range]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func write(_ content: String, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }
}
