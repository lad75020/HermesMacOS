//
//  HermesConfigurationRuntimeModelSlotEditorCard.swift
//  HermesMacOS
//

import SwiftUI
import Foundation

struct HermesRuntimeModelSlotEditorCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let provider: String
    let model: String
    let providerOptions: [HermesRuntimeProviderOption]
    let allowEmptyProvider: Bool
    let onSave: (String, String) -> Void

    @State var draftProvider: String
    @State var draftModel: String
    @State var saved = false

    init(
        title: String,
        subtitle: String,
        systemImage: String,
        provider: String,
        model: String,
        providerOptions: [HermesRuntimeProviderOption],
        allowEmptyProvider: Bool = false,
        onSave: @escaping (String, String) -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.provider = provider
        self.model = model
        self.providerOptions = providerOptions
        self.allowEmptyProvider = allowEmptyProvider
        self.onSave = onSave
        _draftProvider = State(initialValue: provider.isEmpty && !allowEmptyProvider ? "auto" : provider)
        _draftModel = State(initialValue: model)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.hermesActionBlue)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.hermesSecondaryText)
                }
                Spacer()
                if saved {
                    Label("Saved", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                }
            }

            Picker("Provider", selection: $draftProvider) {
                if allowEmptyProvider {
                    Text("Unset / inherit default").tag("")
                }
                ForEach(providerOptions) { option in
                    Text(option.label).tag(option.value)
                }
                if !provider.isEmpty && !providerOptions.contains(where: { $0.value == provider }) {
                    Text(provider).tag(provider)
                }
            }
            .pickerStyle(.menu)

            TextField("Model, e.g. anthropic/claude-sonnet-4", text: $draftModel)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 10) {
                Button("Save") {
                    onSave(draftProvider.trimmedForHermes, draftModel.trimmedForHermes)
                    saved = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { saved = false }
                }
                .buttonStyle(.borderedProminent)

                Button("Reset Draft") {
                    draftProvider = provider.isEmpty && !allowEmptyProvider ? "auto" : provider
                    draftModel = model
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.hermesSurfaceInput, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onChange(of: provider) { _, newValue in
            draftProvider = newValue.isEmpty && !allowEmptyProvider ? "auto" : newValue
        }
        .onChange(of: model) { _, newValue in
            draftModel = newValue
        }
    }
}
