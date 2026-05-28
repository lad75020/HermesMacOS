//
//  HermesConfigurationView.swift
//  HermesMacOS
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers


struct HermesConfigurationView: View {
    @AppStorage("hermes.macOS.configuration.skillsExpanded") var isSkillsExpanded = true
    @AppStorage("hermes.macOS.configuration.profilesExpanded") var isProfilesExpanded = true
    @AppStorage("hermes.macOS.configuration.toolsExpanded") var isToolsExpanded = true
    @AppStorage("hermes.macOS.configuration.mcpServersExpanded") var isMCPServersExpanded = true
    @AppStorage("hermes.macOS.configuration.schedulesExpanded") var isSchedulesExpanded = true
    @AppStorage("hermes.macOS.configuration.modelsExpanded") var isModelsExpanded = true
    @AppStorage("hermes.macOS.configuration.pluginsExpanded") var isPluginsExpanded = true
    @StateObject var runtime = HermesLocalConfigurationRuntime()
    @State var dashboardSkills = HermesDashboardSkillsStore()
    @State var dashboardPlugins = HermesDashboardPluginsStore()
    @State var dashboardToolsets = HermesDashboardToolsetsStore()
    @State var dashboardMCPServers = HermesDashboardMCPServersStore()
    @State var dashboardSchedules = HermesDashboardSchedulesStore()
    @State var localRuntimeModels = HermesLocalRuntimeModelsStore()
    @State var localProfiles = HermesLocalProfilesStore()
    @State var skillQuery = ""
    @State var pluginQuery = ""
    @State var toolsetQuery = ""
    @State var mcpQuery = ""
    @State var scheduleQuery = ""
    @State var skillInstallURL = ""
    @State var selectedSkillFileURL: URL?
    @State var skillInstallValidationMessage = ""
    @State var showCreateProfileForm = false
    @State var createProfileDraft = HermesLocalProfileDraft()
    @State var editingProfileName: String?
    @State var editProfileDraft = HermesLocalProfileDraft()
    @State var confirmDeleteProfileName: String?
    @State var mcpName = ""
    @State var mcpTransport = "stdio"
    @State var mcpCommand = ""
    @State var mcpArgs = ""
    @State var mcpURL = ""
    @State var mcpEnv = ""
    @State var mcpHeaders = ""
    @State var mcpAuth = ""
    @State var mcpValidationMessage = ""
    @State var scheduleName = ""
    @State var scheduleExpression = ""
    @State var schedulePrompt = ""
    @State var scheduleSkillName = ""
    @State var scheduleJobKind = "prompt"
    @State var scheduleDeliveryTarget = "local"
    @State var scheduleCustomDeliveryTarget = ""
    @State var selectedScheduleTemplateID = ""
    @State var scheduleChainSourceJobID = ""
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

                dashboardPluginsSection

                localProfilesSection

                dashboardToolsetsSection

                dashboardMCPServersSection

                dashboardSchedulesSection

                localRuntimeModelsSection
            }
            .padding(18)
        }
        .background(HermesLiquidGlassCanvas().ignoresSafeArea())
        .onAppear {
            runtime.remoteHostName = connectedHostName
            refreshConfiguration()
        }
        .onChange(of: connectedHostName) { _, newValue in
            runtime.remoteHostName = newValue
        }
        .confirmationDialog(
            "Delete profile?",
            isPresented: Binding(
                get: { confirmDeleteProfileName != nil },
                set: { isPresented in if !isPresented { confirmDeleteProfileName = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let profileName = confirmDeleteProfileName {
                Button("Delete \(profileName)", role: .destructive) {
                    localProfiles.deleteProfile(profileName, hermesHome: runtime.hermesHome)
                    confirmDeleteProfileName = nil
                }
            }
            Button("Cancel", role: .cancel) { confirmDeleteProfileName = nil }
        }
    }

    private func refreshConfiguration() {
        dashboardSkills.refreshForManagement(dashboardBaseURL: dashboardURL, apiSettings: apiSettings)
        dashboardPlugins.refresh(dashboardBaseURL: dashboardURL, apiSettings: apiSettings)
        dashboardToolsets.refresh(dashboardBaseURL: dashboardURL, apiSettings: apiSettings)
        dashboardMCPServers.refresh(dashboardBaseURL: dashboardURL, apiSettings: apiSettings)
        dashboardSchedules.refresh(dashboardBaseURL: dashboardURL, apiSettings: apiSettings)
        localRuntimeModels.refresh()
        localProfiles.refresh(hermesHome: runtime.hermesHome)
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
        Label("Configuration uses the Hermes Dashboard for skills, tools, MCP servers, and schedules, with direct local system calls only where needed on this Mac.", systemImage: "desktopcomputer")
            .font(.callout)
            .foregroundStyle(Color.hermesSecondaryText)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .hermesGlassPanel(tint: Color.hermesSurface.opacity(0.56), cornerRadius: 14)
    }

    func runtimeSection<Content: View>(
        title: String,
        subtitle: String,
        systemImage: String,
        isExpanded: Binding<Bool>,
        output: String?,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        configurationSection(
            title: title,
            subtitle: subtitle,
            systemImage: systemImage,
            isExpanded: isExpanded
        ) {
            if runtime.runningSections.contains(HermesLocalConfigurationSection(title: title)) {
                ProgressView().controlSize(.small)
            }
        } content: {
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
    }

    func configurationSection<Content: View, Trailing: View>(
        title: String,
        subtitle: String,
        systemImage: String,
        isExpanded: Binding<Bool>,
        @ViewBuilder trailing: @escaping () -> Trailing,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        DisclosureGroup(isExpanded: isExpanded) {
            VStack(alignment: .leading, spacing: 12) {
                content()
            }
            .padding(.top, 12)
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.hermesActionBlue)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .hermesWebsiteTitleFont(size: 17, weight: .bold)
                    if isExpanded.wrappedValue {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(Color.hermesSecondaryText)
                    }
                }
                Spacer()
                trailing()
            }
            .contentShape(Rectangle())
        }
        .tint(Color.hermesActionBlue)
        .padding(16)
        .hermesGlassPanel(cornerRadius: 18)
    }
}


extension String {
    var trimmedForHermes: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
