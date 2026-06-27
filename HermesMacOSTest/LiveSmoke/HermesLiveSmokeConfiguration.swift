import Foundation

enum HermesLiveSmokeConfiguration {
    static var apiBaseURL: String? { ProcessInfo.processInfo.environment["HERMESMACOS_LIVE_API_BASE_URL"] }
    static var dashboardURL: String? { ProcessInfo.processInfo.environment["HERMESMACOS_LIVE_DASHBOARD_URL"] }
    static var tuiGatewayEnabled: Bool { ProcessInfo.processInfo.environment["HERMESMACOS_LIVE_TUI_GATEWAY"] == "1" }
    static var whisperEnabled: Bool { ProcessInfo.processInfo.environment["HERMESMACOS_LIVE_WHISPER"] == "1" }
    static var mutationAllowed: Bool { ProcessInfo.processInfo.environment["HERMESMACOS_LIVE_MUTATION_OK"] == "1" }

    static var hasAnyLiveTarget: Bool {
        apiBaseURL != nil || dashboardURL != nil || tuiGatewayEnabled || whisperEnabled
    }

    static var skipReason: String? {
        hasAnyLiveTarget ? nil : "Live smoke checks are opt-in; set HERMESMACOS_LIVE_* variables to enable."
    }
}
