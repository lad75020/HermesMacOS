//
//  HermesConfigurationMCPServersSection.swift
//  HermesMacOS
//

import SwiftUI

extension HermesConfigurationView {
        var filteredDashboardMCPServers: [HermesDashboardMCPServer] {
            let query = mcpQuery.trimmedForHermes
            guard !query.isEmpty else { return dashboardMCPServers.servers }
            return dashboardMCPServers.servers.filter { server in
                server.name.localizedCaseInsensitiveContains(query) ||
                server.primaryDetail.localizedCaseInsensitiveContains(query) ||
                server.transportLabel.localizedCaseInsensitiveContains(query) ||
                server.statusLabel.localizedCaseInsensitiveContains(query)
            }
        }


        var canAddMCPServer: Bool {
            let name = mcpName.trimmedForHermes
            guard !name.isEmpty, !dashboardMCPServers.isLoading else { return false }
            if mcpTransport == "http" { return !mcpURL.trimmedForHermes.isEmpty }
            return !mcpCommand.trimmedForHermes.isEmpty
        }


        var mcpWorkbenchOutput: String {
            let messages = [dashboardMCPServers.lastActionMessage, dashboardMCPServers.lastErrorMessage, runtime.outputs[.mcpServers] ?? ""].filter { !$0.isEmpty }
            return messages.isEmpty ? "MCP Server Workbench ready. Test servers, tune tool filters, add stdio/HTTP servers, and reload MCP discovery." : messages.joined(separator: "\n")
        }


        var dashboardMCPServersSection: some View {
            runtimeSection(
                title: "MCP Server Workbench",
                subtitle: "Inspect configured command/URL, test availability, view discovered tools, tune tool filters, and add stdio or HTTP servers.",
                systemImage: "point.3.connected.trianglepath.dotted",
                isExpanded: $isMCPServersExpanded,
                output: mcpWorkbenchOutput
            ) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        TextField("Search MCP servers, tools, command, URL, auth, or status", text: $mcpQuery)
                        Button {
                            dashboardMCPServers.refresh(dashboardBaseURL: dashboardURL, apiSettings: apiSettings)
                            dashboardMCPServers.refreshRecentErrors(hermesHome: runtime.hermesHome)
                        } label: {
                            Label("Refresh config", systemImage: "arrow.clockwise")
                        }
                        .disabled(dashboardMCPServers.isLoading)
                        Button {
                            dashboardMCPServers.testAllConnections(hermesHome: runtime.hermesHome)
                        } label: {
                            Label("Test all", systemImage: "checkmark.seal")
                        }
                        .disabled(dashboardMCPServers.isTesting || dashboardMCPServers.servers.isEmpty)
                        Button {
                            dashboardMCPServers.reloadMCP(hermesHome: runtime.hermesHome)
                        } label: {
                            Label("Reload MCP", systemImage: "arrow.triangle.2.circlepath")
                        }
                        .disabled(dashboardMCPServers.isTesting || dashboardMCPServers.servers.isEmpty)
                    }

                    addMCPServerWizard

                    if dashboardMCPServers.isLoading && dashboardMCPServers.servers.isEmpty {
                        ProgressView("Loading MCP servers from dashboard config…")
                            .controlSize(.small)
                    } else if !dashboardMCPServers.lastErrorMessage.isEmpty {
                        Text(dashboardMCPServers.lastErrorMessage)
                            .font(.caption)
                            .foregroundStyle(Color.orange)
                    } else if filteredDashboardMCPServers.isEmpty {
                        Text(dashboardMCPServers.servers.isEmpty ? "No MCP servers found in dashboard config." : "No matching MCP servers.")
                            .font(.caption)
                            .foregroundStyle(Color.hermesSecondaryText)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(filteredDashboardMCPServers) { server in
                                mcpServerWorkbenchRow(server)
                            }
                        }
                    }
                }
                .onAppear { dashboardMCPServers.refreshRecentErrors(hermesHome: runtime.hermesHome) }
            }
        }


        var addMCPServerWizard: some View {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Label("Add MCP server", systemImage: "plus.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.hermesSecondaryText)
                    Picker("Transport", selection: $mcpTransport) {
                        Text("stdio").tag("stdio")
                        Text("HTTP").tag("http")
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                    Spacer()
                    Button { addMCPServer() } label: {
                        Label("Save server", systemImage: "externaldrive.badge.plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canAddMCPServer)
                }

                HStack(spacing: 10) {
                    TextField("Name, e.g. github", text: $mcpName)
                    if mcpTransport == "http" {
                        TextField("URL, e.g. https://example.com/mcp", text: $mcpURL)
                    } else {
                        TextField("Command, e.g. npx", text: $mcpCommand)
                        TextField("Args, e.g. -y @modelcontextprotocol/server-filesystem", text: $mcpArgs)
                    }
                }

                if mcpTransport == "http" {
                    TextField("Auth mode, e.g. oauth or header (optional)", text: $mcpAuth)
                    TextField("Auth headers, one per line", text: $mcpHeaders, axis: .vertical)
                        .lineLimit(2...5)
                } else {
                    TextField("Environment, one per line: KEY=value", text: $mcpEnv, axis: .vertical)
                        .lineLimit(2...5)
                }

                Text("Arguments are shell-split with quote support. Environment names and HTTP header lines are validated before writing config.yaml.")
                    .font(.caption)
                    .foregroundStyle(Color.hermesSecondaryText)
                if !mcpValidationMessage.isEmpty {
                    Text(mcpValidationMessage)
                        .font(.caption)
                        .foregroundStyle(Color.orange)
                }
            }
            .padding(12)
            .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
        }


        func addMCPServer() {
            let name = mcpName.trimmedForHermes
            guard isValidMCPName(name) else {
                mcpValidationMessage = "Use a server name with letters, numbers, underscores, or hyphens."
                return
            }

            let env: [String: String]
            let headers: [String: String]
            do {
                env = try parseMCPKeyValueLines(mcpEnv, separator: "=")
                headers = try parseMCPKeyValueLines(mcpHeaders, separator: ":")
            } catch {
                mcpValidationMessage = error.localizedDescription
                return
            }

            if mcpTransport == "http" {
                let urlText = mcpURL.trimmedForHermes
                guard let url = URL(string: urlText), ["http", "https"].contains(url.scheme?.lowercased() ?? ""), url.host?.isEmpty == false else {
                    mcpValidationMessage = "Enter a valid http or https MCP endpoint URL."
                    return
                }
            } else {
                guard !mcpCommand.trimmedForHermes.isEmpty else {
                    mcpValidationMessage = "Enter a command for the stdio server."
                    return
                }
            }

            let draft = HermesMCPServerDraft(
                name: name,
                transportKind: mcpTransport == "http" ? .http : .stdio,
                command: mcpCommand.trimmedForHermes,
                args: splitMCPArguments(mcpArgs),
                url: mcpURL.trimmedForHermes,
                env: env,
                headers: headers,
                auth: mcpAuth.trimmedForHermes.isEmpty ? nil : mcpAuth.trimmedForHermes
            )
            mcpValidationMessage = ""
            dashboardMCPServers.upsertServer(draft, dashboardBaseURL: dashboardURL, apiSettings: apiSettings)
            mcpName = ""
            mcpCommand = ""
            mcpArgs = ""
            mcpURL = ""
            mcpEnv = ""
            mcpHeaders = ""
            mcpAuth = ""
        }


        func isValidMCPName(_ name: String) -> Bool {
            guard !name.isEmpty else { return false }
            return name.range(of: #"^[A-Za-z0-9_-]+$"#, options: .regularExpression) != nil
        }


        func parseMCPKeyValueLines(_ text: String, separator: Character) throws -> [String: String] {
            var result: [String: String] = [:]
            for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
                let line = String(rawLine).trimmedForHermes
                guard !line.isEmpty else { continue }
                guard let index = line.firstIndex(of: separator) else {
                    throw HermesConfigurationValidationError(message: "Expected \(separator == "=" ? "KEY=VALUE" : "Header: value") on every line.")
                }
                let key = String(line[..<index]).trimmedForHermes
                let value = String(line[line.index(after: index)...]).trimmedForHermes
                guard !key.isEmpty else { throw HermesConfigurationValidationError(message: "Key names cannot be empty.") }
                if separator == "=" && key.range(of: #"^[A-Za-z_][A-Za-z0-9_]*$"#, options: .regularExpression) == nil {
                    throw HermesConfigurationValidationError(message: "Invalid environment variable name: \(key)")
                }
                result[key] = value
            }
            return result
        }


        func splitMCPArguments(_ text: String) -> [String] {
            var result: [String] = []
            var current = ""
            var quote: Character?
            var escaping = false
            for character in text {
                if escaping {
                    current.append(character)
                    escaping = false
                } else if character == "\\" {
                    escaping = true
                } else if let activeQuote = quote {
                    if character == activeQuote {
                        quote = nil
                    } else {
                        current.append(character)
                    }
                } else if character == "\"" || character == "'" {
                    quote = character
                } else if character.isWhitespace {
                    if !current.isEmpty {
                        result.append(current)
                        current = ""
                    }
                } else {
                    current.append(character)
                }
            }
            if escaping { current.append("\\") }
            if !current.isEmpty { result.append(current) }
            return result
        }


        func mcpServerWorkbenchRow(_ server: HermesDashboardMCPServer) -> some View {
            let probe = dashboardMCPServers.probeStates[server.name] ?? HermesMCPServerProbeState()
            let recentErrors = dashboardMCPServers.recentErrorsByServer[server.name] ?? []
            return VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(server.name)
                                .font(.headline)
                            mcpPill(server.transportLabel, color: Color.hermesActionBlue)
                            mcpPill(server.statusLabel, color: server.disabled ? Color.gray : Color.green)
                            mcpPill(probe.statusLabel, color: probe.availability == .available ? Color.green : (probe.availability == .unavailable ? Color.orange : Color.gray))
                            mcpPill(probe.toolCountLabel, color: Color.purple)
                        }
                        Text(server.primaryDetail)
                            .font(.caption.monospaced())
                            .foregroundStyle(Color.hermesSecondaryText)
                            .textSelection(.enabled)
                        HStack(spacing: 12) {
                            configurationSummaryRow(label: "Tools", value: server.configuredToolRuleLabel)
                            configurationSummaryRow(label: "Auth", value: server.authLabel)
                            if !server.env.isEmpty { configurationSummaryRow(label: "Env", value: "\(server.env.count) vars") }
                            if !server.headers.isEmpty { configurationSummaryRow(label: "Headers", value: "\(server.headers.count) headers") }
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 8) {
                        Toggle("Enabled", isOn: Binding(
                            get: { !server.disabled },
                            set: { enabled in dashboardMCPServers.setServerEnabled(server, enabled: enabled, dashboardBaseURL: dashboardURL, apiSettings: apiSettings) }
                        ))
                        .toggleStyle(.switch)
                        .disabled(dashboardMCPServers.isLoading)
                        HStack(spacing: 8) {
                            Button {
                                dashboardMCPServers.testConnection(server, hermesHome: runtime.hermesHome)
                            } label: {
                                Label("Test connection", systemImage: "bolt.horizontal.circle")
                            }
                            .disabled(dashboardMCPServers.isTesting || server.disabled)
                            Button(role: .destructive) {
                                dashboardMCPServers.deleteServer(server, dashboardBaseURL: dashboardURL, apiSettings: apiSettings)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .disabled(dashboardMCPServers.isLoading)
                        }
                    }
                }

                if probe.availability == .testing {
                    ProgressView("Testing connection…")
                        .controlSize(.small)
                }
                if !probe.errorMessage.isEmpty {
                    Label(probe.errorMessage, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(Color.orange)
                        .textSelection(.enabled)
                }

                DisclosureGroup("Discovered tools") {
                    if probe.tools.isEmpty {
                        Text(server.disabled ? "Enable this server before testing tools." : "Run Test connection to discover tools and tool count.")
                            .font(.caption)
                            .foregroundStyle(Color.hermesSecondaryText)
                    } else {
                        VStack(spacing: 6) {
                            ForEach(probe.tools) { tool in
                                HStack(alignment: .top, spacing: 8) {
                                    Toggle("", isOn: Binding(
                                        get: { server.isToolEnabled(tool.name) },
                                        set: { enabled in
                                            dashboardMCPServers.setToolEnabled(server, tool: tool, enabled: enabled, allTools: probe.tools, dashboardBaseURL: dashboardURL, apiSettings: apiSettings)
                                        }
                                    ))
                                    .labelsHidden()
                                    .disabled(dashboardMCPServers.isLoading)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(tool.name)
                                            .font(.caption.monospaced().weight(.semibold))
                                        if !tool.description.isEmpty {
                                            Text(tool.description)
                                                .font(.caption2)
                                                .foregroundStyle(Color.hermesSecondaryText)
                                                .lineLimit(2)
                                        }
                                    }
                                    Spacer()
                                }
                            }
                        }
                        .padding(.top, 6)
                    }
                }
                .font(.caption.weight(.semibold))

                DisclosureGroup("Recent MCP errors") {
                    if recentErrors.isEmpty {
                        Text("No recent errors found in mcp-stderr.log or errors.log for this server.")
                            .font(.caption)
                            .foregroundStyle(Color.hermesSecondaryText)
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(recentErrors, id: \.self) { line in
                                Text(line)
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(Color.orange)
                                    .textSelection(.enabled)
                            }
                        }
                    }
                }
                .font(.caption.weight(.semibold))
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
        }


        func mcpPill(_ text: String, color: Color) -> some View {
            Text(text)
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(color.opacity(0.16), in: Capsule())
                .foregroundStyle(color)
        }


}
