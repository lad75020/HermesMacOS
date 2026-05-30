//
//  HermesMacOSApp.swift
//  HermesMacOS
//

import SwiftUI

enum HermesAppLanguageSelection: String, CaseIterable, Identifiable {
    case automatic = "automatic"
    case english = "en"
    case french = "fr"
    case spanish = "es"
    case german = "de"
    case chineseSimplified = "zh-Hans"

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .automatic: "Automatic"
        case .english: "English"
        case .french: "French"
        case .spanish: "Spanish"
        case .german: "German"
        case .chineseSimplified: "Chinese (Simplified)"
        }
    }

    var locale: Locale {
        Locale(identifier: localeIdentifier)
    }

    var localeIdentifier: String {
        switch self {
        case .automatic: Self.systemSupportedLanguage.rawValue
        default: rawValue
        }
    }

    static var forcedLanguages: [HermesAppLanguageSelection] {
        [.english, .french, .spanish, .german, .chineseSimplified]
    }

    static var systemSupportedLanguage: HermesAppLanguageSelection {
        for languageIdentifier in Locale.preferredLanguages {
            if let selection = selection(for: languageIdentifier) { return selection }
        }
        return .english
    }

    static func selection(for languageIdentifier: String) -> HermesAppLanguageSelection? {
        let normalized = languageIdentifier.replacingOccurrences(of: "_", with: "-").lowercased()
        if normalized == "zh-hans" || normalized.hasPrefix("zh-hans-") || normalized == "zh-cn" || normalized.hasPrefix("zh-cn-") || normalized == "zh-sg" || normalized.hasPrefix("zh-sg-") { return .chineseSimplified }
        if normalized == "en" || normalized.hasPrefix("en-") { return .english }
        if normalized == "fr" || normalized.hasPrefix("fr-") { return .french }
        if normalized == "es" || normalized.hasPrefix("es-") { return .spanish }
        if normalized == "de" || normalized.hasPrefix("de-") { return .german }
        return nil
    }
}

@main
struct HermesMacOSApp: App {
    @AppStorage("hermes.appLanguage") private var appLanguage: HermesAppLanguageSelection = .automatic

    init() {
        HermesWebsiteFontRegistrar.registerBundledFonts()
        HermesSSHKeychain.cleanupTemporaryIdentityFiles()
    }

    var body: some Scene {
        WindowGroup("HermesMacOS", id: "main") {
            HermesMacOSRootView()
                .frame(minWidth: 920, minHeight: 680)
                .environment(\.locale, appLanguage.locale)
        }
        .defaultSize(width: 1_104, height: 816)
        .windowStyle(.titleBar)
        .commands {
            HermesWindowCommands()
        }

        Settings {
            SettingsView()
                .environment(\.locale, appLanguage.locale)
        }
    }
}

private struct HermesWindowCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Hermes Window") {
                openWindow(id: "main")
            }
            .keyboardShortcut("n", modifiers: [.command])
        }
    }
}

private struct HermesMacOSRootView: View {
    @State private var startupState: HermesMacOSStartupState = .splash

    var body: some View {
        Group {
            switch startupState {
            case .splash, .unlocking:
                SplashView()
                    .transition(.opacity)
            case .unlocked:
                ContentView()
                    .transition(.opacity)
            case .failed(let message):
                HermesSecretUnlockFailureView(message: message) {
                    Task { await unlockAndShowContent() }
                }
                .transition(.opacity)
            }
        }
        .task {
            guard startupState == .splash else { return }
            await unlockAndShowContent()
        }
    }

    private func unlockAndShowContent() async {
        startupState = .unlocking
        try? await Task.sleep(for: .seconds(2))
        do {
            try await HermesSecretUnlockGate.shared.unlockIfNeeded()
            withAnimation(.easeOut(duration: 0.25)) {
                startupState = .unlocked
            }
        } catch {
            withAnimation(.easeOut(duration: 0.2)) {
                startupState = .failed(error.localizedDescription)
            }
        }
    }
}

private enum HermesMacOSStartupState: Equatable {
    case splash
    case unlocking
    case unlocked
    case failed(String)
}

private struct HermesSecretUnlockFailureView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "lock.trianglebadge.exclamationmark")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(Color.hermesDestructive)
            Text("HermesMacOS secrets are locked")
                .font(.title2.weight(.semibold))
            Text(message)
                .font(.callout)
                .foregroundStyle(Color.hermesSecondaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            Button("Unlock HermesMacOS", action: retry)
                .buttonStyle(.borderedProminent)
        }
        .padding(36)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(HermesLiquidGlassCanvas().ignoresSafeArea())
    }
}
