//
//  HermesTypography.swift
//  HermesMacOS
//

import CoreText
import SwiftUI

enum HermesWebsiteFontRegistrar {
    private static var didRegister = false

    static func registerBundledFonts() {
        guard !didRegister else { return }
        didRegister = true
        let nestedFontURLs = Bundle.main.urls(forResourcesWithExtension: "woff2", subdirectory: "Fonts") ?? []
        let rootFontURLs = Bundle.main.urls(forResourcesWithExtension: "woff2", subdirectory: nil) ?? []
        for url in nestedFontURLs + rootFontURLs {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}

enum HermesWebsiteFont: String, CaseIterable, Identifiable {
    case rulesExpanded
    case mondwest
    case jetBrainsMono
    case systemRounded
    case systemSerif
    case systemMono

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rulesExpanded: "Rules Expanded"
        case .mondwest: "Mondwest"
        case .jetBrainsMono: "JetBrains Mono"
        case .systemRounded: "System Rounded"
        case .systemSerif: "System Serif"
        case .systemMono: "System Mono"
        }
    }

    func font(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        switch self {
        case .rulesExpanded:
            .custom(weight == .bold || weight == .semibold || weight == .heavy ? "RulesExpanded-Bold" : "RulesExpanded-Regular", size: size)
        case .mondwest:
            .custom("Mondwest-Regular", size: size)
        case .jetBrainsMono:
            .custom(weight == .bold || weight == .semibold || weight == .heavy ? "JetBrainsMono-Bold" : "JetBrainsMono-Regular", size: size)
        case .systemRounded:
            .system(size: size, weight: weight, design: .rounded)
        case .systemSerif:
            .system(size: size, weight: weight, design: .serif)
        case .systemMono:
            .system(size: size, weight: weight, design: .monospaced)
        }
    }
}

private struct HermesWebsiteTitleFontModifier: ViewModifier {
    let size: CGFloat
    let weight: Font.Weight
    @AppStorage("hermes.macOS.titleFont") private var titleFont: HermesWebsiteFont = .rulesExpanded

    func body(content: Content) -> some View {
        content
            .font(titleFont.font(size: size, weight: weight))
            .tracking(0.08 * size)
    }
}

private struct HermesWebsiteLabelFontModifier: ViewModifier {
    let size: CGFloat
    let weight: Font.Weight
    @AppStorage("hermes.macOS.labelFont") private var labelFont: HermesWebsiteFont = .mondwest

    func body(content: Content) -> some View {
        content
            .font(labelFont.font(size: size, weight: weight))
            .tracking(0.10 * size)
    }
}

extension View {
    func hermesWebsiteTitleFont(size: CGFloat = 22, weight: Font.Weight = .bold) -> some View {
        modifier(HermesWebsiteTitleFontModifier(size: size, weight: weight))
    }

    func hermesWebsiteLabelFont(size: CGFloat = 11, weight: Font.Weight = .regular) -> some View {
        modifier(HermesWebsiteLabelFontModifier(size: size, weight: weight))
    }
}
