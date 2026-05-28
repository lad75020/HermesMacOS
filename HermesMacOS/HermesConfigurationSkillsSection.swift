//
//  HermesConfigurationSkillsSection.swift
//  HermesMacOS
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

extension HermesConfigurationView {
        var filteredDashboardSkills: [HermesDashboardSkill] {
            let query = skillQuery.trimmedForHermes
            guard !query.isEmpty else { return dashboardSkills.skills }
            return dashboardSkills.skills.filter { skill in
                skill.name.localizedCaseInsensitiveContains(query) ||
                (skill.description ?? "").localizedCaseInsensitiveContains(query) ||
                (skill.category ?? "").localizedCaseInsensitiveContains(query) ||
                skill.statusLabel.localizedCaseInsensitiveContains(query)
            }
        }


        var dashboardSkillsSection: some View {
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


        var skillInstallSource: String? {
            let trimmedURL = skillInstallURL.trimmedForHermes
            if !trimmedURL.isEmpty { return trimmedURL }
            return selectedSkillFileURL?.path
        }


        func pickSkillFile() {
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


        func addSkill() {
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


        func dashboardSkillRow(_ skill: HermesDashboardSkill) -> some View {
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


}
