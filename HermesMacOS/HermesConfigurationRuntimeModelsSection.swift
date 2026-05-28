//
//  HermesConfigurationRuntimeModelsSection.swift
//  HermesMacOS
//

import SwiftUI

extension HermesConfigurationView {
        var localRuntimeModelsSection: some View {
            runtimeSection(
                title: "Models",
                subtitle: "Configure main, delegation, and auxiliary runtime model routing in local config.yaml.",
                systemImage: "cpu",
                isExpanded: $isModelsExpanded,
                output: localRuntimeModels.lastStatusMessage
            ) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Works like HermesiOS Agent Runtime: edit provider and model slots for the main conversation, delegated sub-agents, and auxiliary tasks. Changes are written directly on this Mac.")
                        .font(.subheadline)
                        .foregroundStyle(Color.hermesSecondaryText)

                    VStack(alignment: .leading, spacing: 6) {
                        configurationSummaryRow(label: "Hermes Home", value: localRuntimeModels.resolvedHermesHome.isEmpty ? HermesRuntimePaths.defaultHermesHome : localRuntimeModels.resolvedHermesHome)
                        configurationSummaryRow(label: "Config", value: localRuntimeModels.configPath.isEmpty ? URL(fileURLWithPath: HermesRuntimePaths.defaultHermesHome).appendingPathComponent("config.yaml").path : localRuntimeModels.configPath)
                    }

                    HStack {
                        Button("Reload Models") { localRuntimeModels.refresh() }
                        if localRuntimeModels.isLoading { ProgressView().controlSize(.small) }
                        Spacer()
                    }

                    HermesRuntimeModelSlotEditorCard(
                        title: "Main Model",
                        subtitle: "Primary model for interactive Hermes Agent turns (`model.provider` and `model.default`).",
                        systemImage: "sparkles",
                        provider: localRuntimeModels.mainModel.provider,
                        model: localRuntimeModels.mainModel.model,
                        providerOptions: mainModelProviderOptions,
                        onSave: { provider, model in localRuntimeModels.saveMain(provider: provider, model: model) }
                    )

                    HermesRuntimeModelSlotEditorCard(
                        title: "Delegation Model",
                        subtitle: "Model used when Hermes spawns delegated sub-agents (`delegation.provider` and `delegation.model`). Leave blank to inherit defaults.",
                        systemImage: "person.2.wave.2",
                        provider: localRuntimeModels.delegationModel.provider,
                        model: localRuntimeModels.delegationModel.model,
                        providerOptions: runtimeModelProviderOptions,
                        allowEmptyProvider: true,
                        onSave: { provider, model in
                            localRuntimeModels.saveSlot(localRuntimeModels.delegationModel, provider: provider, model: model)
                        }
                    )

                    Text("Auxiliary Models")
                        .hermesWebsiteTitleFont(size: 15, weight: .bold)
                    Text("Use auto for Hermes automatic routing, main to inherit the main model, or leave model empty to use the provider's default auxiliary model.")
                        .font(.caption)
                        .foregroundStyle(Color.hermesSecondaryText)

                    ForEach(localRuntimeModels.auxiliaryModels) { slot in
                        HermesRuntimeModelSlotEditorCard(
                            title: slot.label,
                            subtitle: "Writes `auxiliary.\(slot.key).provider` and `auxiliary.\(slot.key).model`.",
                            systemImage: auxiliaryModelIcon(for: slot.key),
                            provider: slot.provider,
                            model: slot.model,
                            providerOptions: runtimeModelProviderOptions,
                            allowEmptyProvider: true,
                            onSave: { provider, model in
                                localRuntimeModels.saveSlot(slot, provider: provider, model: model)
                            }
                        )
                    }
                }
            }
        }


        var mainModelProviderOptions: [HermesRuntimeProviderOption] {
            localRuntimeModels.providerOptions.filter { $0.value != "main" }
        }


        var runtimeModelProviderOptions: [HermesRuntimeProviderOption] {
            var options = localRuntimeModels.providerOptions
            if !options.contains(where: { $0.value == "main" }) {
                options.insert(.init(value: "main", label: "Main model"), at: min(1, options.count))
            }
            return options
        }


        func configurationSummaryRow(label: String, value: String) -> some View {
            HStack(alignment: .top) {
                Text(label).fontWeight(.semibold)
                Spacer()
                Text(value)
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(Color.hermesSecondaryText)
                    .textSelection(.enabled)
            }
            .font(.caption)
        }


        func auxiliaryModelIcon(for key: String) -> String {
            switch key {
            case "vision": "eye"
            case "web_extract": "doc.text.magnifyingglass"
            case "compression": "arrow.down.forward.and.arrow.up.backward"
            case "title_generation": "textformat"
            case "mcp": "point.3.connected.trianglepath.dotted"
            case "curator": "wand.and.stars"
            case "skills_hub": "square.stack.3d.up.fill"
            case "approval": "checkmark.shield"
            case "session_search": "magnifyingglass.circle"
            default: "cpu"
            }
        }


}
