//
//  HermesConfigurationPluginsSection.swift
//  HermesMacOS
//

import SwiftUI

extension HermesConfigurationView {
        var filteredDashboardPlugins: [HermesDashboardPlugin] {
            let query = pluginQuery.trimmedForHermes
            guard !query.isEmpty else { return dashboardPlugins.plugins }
            return dashboardPlugins.plugins.filter { plugin in
                plugin.name.localizedCaseInsensitiveContains(query) ||
                plugin.description.localizedCaseInsensitiveContains(query) ||
                plugin.version.localizedCaseInsensitiveContains(query) ||
                plugin.source.localizedCaseInsensitiveContains(query) ||
                plugin.statusLabel.localizedCaseInsensitiveContains(query) ||
                plugin.path.localizedCaseInsensitiveContains(query)
            }
        }


        var dashboardPluginsSection: some View {
            configurationSection(
                title: "Plugins",
                subtitle: "List, enable, and disable Hermes Agent plugins through Hermes Dashboard plugin APIs.",
                systemImage: "puzzlepiece.extension",
                isExpanded: $isPluginsExpanded
            ) {
                if dashboardPlugins.isLoading { ProgressView().controlSize(.small) }
                Button {
                    dashboardPlugins.refresh(dashboardBaseURL: dashboardURL, apiSettings: apiSettings)
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.bordered)
                .help("Refresh plugins from Hermes Dashboard")
            } content: {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        TextField("Filter by name, description, source, status, version, or path", text: $pluginQuery)
                            .textFieldStyle(.roundedBorder)
                        Text("\(filteredDashboardPlugins.count)/\(dashboardPlugins.plugins.count)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(Color.hermesSecondaryText)
                    }

                    if !dashboardPlugins.lastErrorMessage.isEmpty {
                        Label(dashboardPlugins.lastErrorMessage, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(Color.hermesDestructive)
                    }

                    if dashboardPlugins.isLoading && dashboardPlugins.plugins.isEmpty {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text("Loading plugins from Hermes Dashboard…")
                                .font(.callout)
                                .foregroundStyle(Color.hermesSecondaryText)
                        }
                    } else if filteredDashboardPlugins.isEmpty {
                        Text(dashboardPlugins.plugins.isEmpty ? "No Hermes Agent plugins reported by the Dashboard." : "No matching plugins.")
                            .font(.callout)
                            .foregroundStyle(Color.hermesSecondaryText)
                            .padding(.vertical, 8)
                    } else {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 8) {
                                ForEach(filteredDashboardPlugins) { plugin in
                                    dashboardPluginRow(plugin)
                                }
                            }
                            .padding(2)
                        }
                        .frame(minHeight: 180, maxHeight: 360)
                    }

                    Text("Plugins are loaded from GET /api/dashboard/plugins/hub and toggled with the dashboard agent-plugin enable/disable endpoints. Restart or reset Hermes sessions if a plugin change needs runtime reload.")
                        .font(.caption)
                        .foregroundStyle(Color.hermesSecondaryText)
                }
            }
        }


        func dashboardPluginRow(_ plugin: HermesDashboardPlugin) -> some View {
            HStack(alignment: .top, spacing: 12) {
                Toggle(isOn: Binding(
                    get: { plugin.isEnabled },
                    set: { enabled in
                        dashboardPlugins.setPluginEnabled(plugin, enabled: enabled, dashboardBaseURL: dashboardURL, apiSettings: apiSettings)
                    }
                )) {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 8) {
                            Text(plugin.name)
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .lineLimit(1)
                            if !plugin.version.isEmpty {
                                Text("v\(plugin.version)")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(Color.hermesSecondaryText)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(Color.white.opacity(0.08), in: Capsule())
                            }
                            Text(plugin.sourceLabel)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Color.hermesSecondaryText)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color.white.opacity(0.08), in: Capsule())
                            Text(plugin.statusLabel)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(plugin.statusColor)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(plugin.statusColor.opacity(0.14), in: Capsule())
                        }
                        if !plugin.description.isEmpty {
                            Text(plugin.description)
                                .font(.caption)
                                .foregroundStyle(Color.hermesSecondaryText)
                                .lineLimit(2)
                        }
                        if !plugin.path.isEmpty {
                            Text(plugin.path)
                                .font(.caption2.monospaced())
                                .foregroundStyle(Color.hermesSecondaryText.opacity(0.85))
                                .lineLimit(1)
                        }
                        HStack(spacing: 12) {
                            if plugin.hasDashboardManifest {
                                Label("Dashboard", systemImage: "rectangle.3.group")
                            }
                            if plugin.authRequired {
                                Label(plugin.authCommand.isEmpty ? "Auth required" : plugin.authCommand, systemImage: "key")
                            }
                        }
                        .font(.caption2)
                        .foregroundStyle(Color.orange)
                    }
                }
                .toggleStyle(.switch)
                .disabled(dashboardPlugins.isLoading || !plugin.canToggle)
                .help(plugin.isEnabled ? "Disable \(plugin.name)" : "Enable \(plugin.name)")
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.black.opacity(0.16), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }


}
