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
    let onSelectWorkspace: (HermesAskWorkspace) -> Void
    let onAddWorkspace: () -> Void

    private var selectedWorkspace: HermesAskWorkspace {
        workspaces.first(where: { $0.id == selectedWorkspaceID }) ?? workspaces[0]
    }

    var body: some View {
        HermesAskWorkspaceHost(
            apiSettings: $apiSettings,
            workspace: selectedWorkspace,
            promptHistory: promptHistory,
            workspaceControls: workspaceControls
        )
        .id(selectedWorkspace.id)
    }

    private var workspaceControls: AnyView {
        AnyView(
            HStack(spacing: 6) {
                Button(action: onAddWorkspace) {
                    Image(systemName: "plus")
                        .font(.caption.weight(.bold))
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Open a new Ask Hermes workspace")

                if workspaces.count > 1 {
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
                        .help("Switch to workspace \(workspace.number)")
                    }
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
            .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: isBlinking)
            .onAppear { isBlinking = attention == .streaming }
            .onChange(of: attention) { _, newValue in
                if newValue == .streaming { isBlinking.toggle() }
                else { isBlinking = false }
            }
    }
}

private struct HermesAskWorkspaceHost: View {
    @Binding var apiSettings: HermesAPISettings
    @Bindable var workspace: HermesAskWorkspace
    @Bindable var promptHistory: HermesPromptHistoryStore
    let workspaceControls: AnyView

    var body: some View {
        HermesResponsesConsoleView(
            apiSettings: $apiSettings,
            requestDraft: $workspace.draft,
            responseSession: workspace.session,
            promptHistoryStore: promptHistory,
            workspaceControls: workspaceControls
        )
        .onChange(of: workspace.draft) { _, newValue in
            HermesSettingsStore.saveDraft(newValue)
        }
    }
}
