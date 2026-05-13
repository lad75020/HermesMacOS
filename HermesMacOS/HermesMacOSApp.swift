//
//  HermesMacOSApp.swift
//  HermesMacOS
//

import SwiftUI

@main
struct HermesMacOSApp: App {
    init() {
        HermesWebsiteFontRegistrar.registerBundledFonts()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 920, minHeight: 680)
        }
        .windowStyle(.titleBar)

        Settings {
            SettingsView()
        }
    }
}
