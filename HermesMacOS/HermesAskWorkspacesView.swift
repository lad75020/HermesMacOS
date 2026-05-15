//
//  HermesAskWorkspacesView.swift
//  HermesMacOS
//

import SwiftUI

struct HermesAskWorkspacesView: View {
    @Binding var apiSettings: HermesAPISettings
    let workspaces: [HermesAskWorkspace]
    @Binding var selectedWorkspaceID: HermesAskWorkspace.ID
    @Bindable var promptHistory: HermesPromptHistoryStore
    let connectedHostName: String
    let onSelectWorkspace: (HermesAskWorkspace) -> Void
    let onAddWorkspace: () -> Void
    let onDeleteWorkspace: (HermesAskWorkspace) -> Void

    private var selectedWorkspace: HermesAskWorkspace {
        workspaces.first(where: { $0.id == selectedWorkspaceID }) ?? workspaces[0]
    }

    var body: some View {
        HermesAskWorkspaceHost(
            apiSettings: $apiSettings,
            workspace: selectedWorkspace,
            promptHistory: promptHistory,
            connectedHostName: connectedHostName,
            workspaceControls: workspaceControls
        )
        .id(selectedWorkspace.id)
    }

    private var workspaceControls: AnyView {
        AnyView(
            HStack(spacing: 6) {
                Button(action: onAddWorkspace) {
                    HermesComposerCircleButtonLabel(systemImage: "plus", foreground: Color.hermesActionBlue, size: 24)
                }
                .buttonStyle(.plain)
                .help("Open a new Ask Hermes workspace")
                .accessibilityLabel("Open a new Ask Hermes workspace")

                ForEach(workspaces) { workspace in
                    Button {
                        onSelectWorkspace(workspace)
                    } label: {
                        HermesAskWorkspaceButtonLabel(
                            number: workspace.number,
                            isSelected: workspace.id == selectedWorkspaceID,
                            attention: workspace.attention
                        )
                    }
                    .buttonStyle(.plain)
                    .controlSize(.small)
                    .contextMenu {
                        Button(role: .destructive) {
                            onDeleteWorkspace(workspace)
                        } label: {
                            Label("Delete Workspace", systemImage: "trash")
                        }
                        .disabled(workspace.session.isStreaming)
                    }
                    .help("Switch to workspace \(workspace.number)")
                }
            }
        )
    }
}

private struct HermesAskWorkspaceButtonLabel: View {
    let number: Int
    let isSelected: Bool
    let attention: HermesAskWorkspaceAttention?
    @State private var isBlinking = false

    private var backgroundColor: Color {
        switch attention {
        case .streaming:
            return .hermesOrange
        case .completed:
            return .green
        case .failed:
            return .hermesDestructive
        case nil:
            return isSelected ? .hermesActionBlue : .hermesSurface
        }
    }

    private var foregroundColor: Color {
        (attention != nil || isSelected) ? .white : .primary
    }

    private var blinkOpacity: Double {
        attention == .streaming && isBlinking ? 0.45 : 1.0
    }

    var body: some View {
        Text("\(number)")
            .font(.caption.weight(.bold))
            .monospacedDigit()
            .foregroundStyle(foregroundColor)
            .frame(width: 24, height: 24)
            .background(backgroundColor.opacity(blinkOpacity), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).stroke(Color.white.opacity(0.14), lineWidth: 1))
            .task(id: attention) {
                await runBlinkLoop(for: attention)
            }
    }

    @MainActor
    private func runBlinkLoop(for attention: HermesAskWorkspaceAttention?) async {
        guard attention == .streaming else {
            isBlinking = false
            return
        }

        isBlinking = false
        while !Task.isCancelled {
            withAnimation(.easeInOut(duration: 0.45)) {
                isBlinking = true
            }
            do { try await Task.sleep(nanoseconds: 450_000_000) } catch { break }
            if Task.isCancelled { break }
            withAnimation(.easeInOut(duration: 0.45)) {
                isBlinking = false
            }
            do { try await Task.sleep(nanoseconds: 450_000_000) } catch { break }
        }
        isBlinking = false
    }
}

private struct HermesAskWorkspaceHost: View {
    @Binding var apiSettings: HermesAPISettings
    @Bindable var workspace: HermesAskWorkspace
    @Bindable var promptHistory: HermesPromptHistoryStore
    let connectedHostName: String
    let workspaceControls: AnyView

    var body: some View {
        HermesResponsesConsoleView(
            apiSettings: $apiSettings,
            requestDraft: $workspace.draft,
            responseSession: workspace.session,
            promptHistoryStore: promptHistory,
            workspaceControls: workspaceControls,
            connectedHostName: connectedHostName
        )
        .onChange(of: workspace.draft) { _, newValue in
            HermesSettingsStore.saveDraft(newValue)
        }
    }
}
