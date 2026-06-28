import XCTest
@testable import HermesMacOS

final class AppShellAndSettingsTests: XCTestCase {
    func testDocumentedTabsHaveStableTitlesAndImages() {
        let titles = HermesMacOSTab.allCases.map(\.title)
        XCTAssertEqual(titles, ["Ask Hermes", "Chat with Hermes", "Memory", "TUI Gateway", "History", "Sessions", "Approvals Inbox", "Kanban", "Hermes Dashboard", "Configuration", "Utilities"])
        XCTAssertEqual(Set(HermesMacOSTab.allCases.map(\.systemImage)).count, HermesMacOSTab.allCases.count)
    }

    func testAPISettingsBuildsCoreEndpointURLs() {
        let base = "http://localhost:8642/v1"
        XCTAssertEqual(HermesAPISettings.responseURL(from: base)?.absoluteString, "http://localhost:8642/v1/responses")
        XCTAssertEqual(HermesAPISettings.chatCompletionsURL(from: base)?.absoluteString, "http://localhost:8642/v1/chat/completions")
        XCTAssertEqual(HermesAPISettings.profilesURL(from: base)?.absoluteString, "http://localhost:8642/v1/profiles")
        XCTAssertEqual(HermesAPISettings.requestCancelURL(from: base, requestID: "req-1")?.absoluteString, "http://localhost:8642/v1/requests/req-1/cancel")
    }

    func testSavedEndpointMatchingNormalizesTrailingSlashes() {
        let saved = HermesSavedEndpoint(apiURL: "http://localhost:8642/v1/", dashboardURL: "http://localhost:9119/")
        XCTAssertTrue(saved.matches(apiURL: "http://localhost:8642/v1", dashboardURL: "http://localhost:9119"))
    }


    func testAppShellSubcategoryCoverageIsExecutable() {
        let appShell = HermesMacOSTestCoverageMap.subcategories(for: "app-shell")
        XCTAssertTrue(appShell.isSuperset(of: Set(["tab list", "selected tab state", "tab visibility filtering", "multi-window endpoint state", "multi-window profile state", "activity indicators"])))
        XCTAssertEqual(HermesMacOSTab.allCases.first, .ask)
        XCTAssertTrue(HermesMacOSTestCoverageMap.category("app-shell").defaultCoverage.contains { $0.contains("AppShellAndSettingsTests") })
    }

    func testSettingsSubcategoryCoverageIsExecutable() throws {
        let settings = HermesMacOSTestCoverageMap.subcategories(for: "settings")
        XCTAssertTrue(settings.isSuperset(of: Set(["API endpoint persistence", "dashboard endpoint persistence", "API key path", "self-signed certificate policy", "saved endpoint pairs", "SSH credentials", "allowed folders", "theme preference", "language preference", "font preference", "tab visibility controls", "reachability indicators"])))
        XCTAssertEqual(Set(HermesAppTheme.allCases.map(\.rawValue)), Set(["system", "light", "dark"]))
        let saved = HermesSavedEndpoint(apiURL: "http://localhost:8642/v1/", dashboardURL: "http://localhost:9119/")
        XCTAssertTrue(saved.matches(apiURL: "http://localhost:8642/v1", dashboardURL: "http://localhost:9119"))
        try HermesTestAssertions.assertTaskManifestContains("AppShellAndSettingsTests.swift")
    }

    func testPromptTabVisibilityDefaultsToVisibleWhenPreferencesAreMissing() {
        let defaults = temporaryDefaults()
        XCTAssertTrue(HermesTabVisibilityPreferences.askHermesVisible(in: defaults))
        XCTAssertTrue(HermesTabVisibilityPreferences.chatHermesVisible(in: defaults))
    }

    func testVisibleTabFilteringAndSelectedTabFallback() {
        let visibleWithoutAsk = HermesTabVisibilityPreferences.visibleTabs(askHermesVisible: false, chatHermesVisible: true)
        XCTAssertFalse(visibleWithoutAsk.contains(.ask))
        XCTAssertTrue(visibleWithoutAsk.contains(.chat))
        XCTAssertTrue(visibleWithoutAsk.contains(.memory))
        XCTAssertEqual(HermesTabVisibilityPreferences.fallbackSelection(from: .ask, askHermesVisible: false, chatHermesVisible: true), .chat)

        let visibleWithoutPromptTabs = HermesTabVisibilityPreferences.visibleTabs(askHermesVisible: false, chatHermesVisible: false)
        XCTAssertFalse(visibleWithoutPromptTabs.contains(.ask))
        XCTAssertFalse(visibleWithoutPromptTabs.contains(.chat))
        XCTAssertEqual(HermesTabVisibilityPreferences.fallbackSelection(from: .chat, askHermesVisible: false, chatHermesVisible: false), .memory)
    }

    func testPromptTabVisibilityPreferencesAreNonSensitiveUserDefaults() {
        let defaults = temporaryDefaults()
        defaults.set(false, forKey: HermesTabVisibilityPreferences.askHermesVisibleKey)
        defaults.set(true, forKey: HermesTabVisibilityPreferences.chatHermesVisibleKey)
        XCTAssertFalse(HermesTabVisibilityPreferences.askHermesVisible(in: defaults))
        XCTAssertTrue(HermesTabVisibilityPreferences.chatHermesVisible(in: defaults))
    }

    private func temporaryDefaults() -> UserDefaults {
        let suite = "HermesMacOSTest.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }
}
