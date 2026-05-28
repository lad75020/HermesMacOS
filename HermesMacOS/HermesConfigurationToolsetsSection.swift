//
//  HermesConfigurationToolsetsSection.swift
//  HermesMacOS
//

import SwiftUI

extension HermesConfigurationView {
        var filteredDashboardToolsets: [HermesDashboardToolset] {
            let query = toolsetQuery.trimmedForHermes
            guard !query.isEmpty else { return dashboardToolsets.toolsets }
            return dashboardToolsets.toolsets.filter { toolset in
                toolset.name.localizedCaseInsensitiveContains(query) ||
                toolset.displayLabel.localizedCaseInsensitiveContains(query) ||
                toolset.description.localizedCaseInsensitiveContains(query) ||
                toolset.statusLabel.localizedCaseInsensitiveContains(query) ||
                (toolset.tools ?? []).contains { $0.localizedCaseInsensitiveContains(query) }
            }
        }


        var dashboardToolsetsSection: some View {
            runtimeSection(
                title: "Tools",
                subtitle: "Enable or disable dashboard toolsets for new Hermes sessions.",
                systemImage: "wrench.and.screwdriver",
                isExpanded: $isToolsExpanded,
                output: dashboardToolsets.lastErrorMessage
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        TextField("Filter by label, toolset, description, status, or tool", text: $toolsetQuery)
                            .textFieldStyle(.roundedBorder)
                        Button {
                            dashboardToolsets.refresh(dashboardBaseURL: dashboardURL, apiSettings: apiSettings)
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                        .disabled(dashboardToolsets.isLoading)
                    }

                    if dashboardToolsets.isLoading && dashboardToolsets.toolsets.isEmpty {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Loading toolsets from Hermes Dashboard…")
                                .font(.callout)
                                .foregroundStyle(Color.hermesSecondaryText)
                        }
                    } else if filteredDashboardToolsets.isEmpty {
                        Text(dashboardToolsets.toolsets.isEmpty ? "No toolsets reported by the Hermes Dashboard." : "No matching toolsets.")
                            .font(.callout)
                            .foregroundStyle(Color.hermesSecondaryText)
                            .padding(.vertical, 8)
                    } else {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(filteredDashboardToolsets) { toolset in
                                HStack(alignment: .top, spacing: 12) {
                                    Toggle(isOn: Binding(
                                        get: { toolset.enabled },
                                        set: { enabled in
                                            dashboardToolsets.setToolsetEnabled(toolset, enabled: enabled, dashboardBaseURL: dashboardURL, apiSettings: apiSettings)
                                        }
                                    )) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack(spacing: 8) {
                                                Text(toolset.displayLabel)
                                                    .font(.headline)
                                                Text(toolset.name)
                                                    .font(.caption.monospaced())
                                                    .foregroundStyle(Color.hermesSecondaryText)
                                                Text(toolset.statusLabel)
                                                    .font(.caption.weight(.semibold))
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 2)
                                                    .background((toolset.enabled ? Color.green : Color.gray).opacity(0.16), in: Capsule())
                                                    .foregroundStyle(toolset.enabled ? Color.green : Color.hermesSecondaryText)
                                                if toolset.enabled && toolset.configured == false {
                                                    Text("Setup needed")
                                                        .font(.caption.weight(.semibold))
                                                        .padding(.horizontal, 8)
                                                        .padding(.vertical, 2)
                                                        .background(Color.orange.opacity(0.16), in: Capsule())
                                                        .foregroundStyle(Color.orange)
                                                }
                                            }
                                            Text(toolset.description)
                                                .font(.callout)
                                                .foregroundStyle(Color.hermesSecondaryText)
                                            if let tools = toolset.tools, !tools.isEmpty {
                                                Text(tools.prefix(8).joined(separator: ", ") + (tools.count > 8 ? "…" : ""))
                                                    .font(.caption.monospaced())
                                                    .foregroundStyle(Color.hermesSecondaryText.opacity(0.85))
                                            }
                                        }
                                    }
                                    .toggleStyle(.switch)
                                    .disabled(dashboardToolsets.isLoading)
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
                            }
                        }
                    }

                    Text("Toolsets are loaded with GET /api/tools/toolsets and saved through the Hermes Dashboard configuration API; no hermes tools CLI call is used here.")
                        .font(.caption)
                        .foregroundStyle(Color.hermesSecondaryText)
                }
            }
        }


}
