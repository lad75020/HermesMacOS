//
//  HermesConfigurationProfilesSection.swift
//  HermesMacOS
//

import SwiftUI

extension HermesConfigurationView {
        var localProfilesSection: some View {
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


        func profileForm(
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


        func normalized(_ draft: HermesLocalProfileDraft) -> HermesLocalProfileDraft {
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


        func localProfileCard(_ profile: HermesLocalProfileInfo) -> some View {
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


        func profileMetric(_ title: String, _ value: String) -> some View {
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


        func profileBadge(_ text: String, color: Color) -> some View {
            Text(text)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .hermesGlassPanel(tint: color.opacity(0.08), cornerRadius: 10, interactive: false)
        }


        func profileFlag(_ label: String, enabled: Bool) -> some View {
            Label(label, systemImage: enabled ? "checkmark.circle.fill" : "minus.circle")
                .font(.caption.weight(.semibold))
                .foregroundStyle(enabled ? Color.green : Color.secondary)
        }


        func profileStatusChip(title: String, value: String, color: Color) -> some View {
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


}
