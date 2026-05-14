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
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 920, minHeight: 680)
                .environment(\.locale, appLanguage.locale)
        }
        .windowStyle(.titleBar)

        Settings {
            SettingsView()
                .environment(\.locale, appLanguage.locale)
        }
    }
}
