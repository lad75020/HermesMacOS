import Foundation

struct HermesMacOSTestCoverageCategory: Equatable {
    enum Scope: String {
        case functional
        case technical
        case security
        case integration
        case utility
        case liveSmoke
    }

    let identifier: String
    let displayName: String
    let scope: Scope
    let defaultCoverage: [String]
    let liveSmokeOnly: Bool
}

enum HermesMacOSTestCoverageMap {
    static let categories: [HermesMacOSTestCoverageCategory] = [
        .init(identifier: "app-shell", displayName: "App shell", scope: .functional, defaultCoverage: ["AppShellAndSettingsTests"], liveSmokeOnly: false),
        .init(identifier: "settings", displayName: "Settings", scope: .functional, defaultCoverage: ["AppShellAndSettingsTests"], liveSmokeOnly: false),
        .init(identifier: "ask-hermes", displayName: "Ask Hermes", scope: .functional, defaultCoverage: ["AskHermesWorkflowTests", "EndpointAndRequestContractTests"], liveSmokeOnly: false),
        .init(identifier: "chat-hermes", displayName: "Chat with Hermes", scope: .functional, defaultCoverage: ["ChatHermesWorkflowTests", "EndpointAndRequestContractTests"], liveSmokeOnly: false),
        .init(identifier: "tui-gateway", displayName: "TUI Gateway", scope: .integration, defaultCoverage: ["TUIGatewayWorkflowTests", "StreamingAndGatewayEventTests"], liveSmokeOnly: false),
        .init(identifier: "history-sessions", displayName: "History and Sessions", scope: .functional, defaultCoverage: ["DashboardBackedWorkflowTests"], liveSmokeOnly: false),
        .init(identifier: "approvals", displayName: "Approvals", scope: .functional, defaultCoverage: ["ApprovalsAndKanbanWorkflowTests"], liveSmokeOnly: false),
        .init(identifier: "kanban", displayName: "Kanban", scope: .functional, defaultCoverage: ["ApprovalsAndKanbanWorkflowTests"], liveSmokeOnly: false),
        .init(identifier: "dashboard", displayName: "Dashboard embedding", scope: .integration, defaultCoverage: ["DashboardBackedWorkflowTests"], liveSmokeOnly: false),
        .init(identifier: "configuration", displayName: "Configuration", scope: .functional, defaultCoverage: ["DashboardBackedWorkflowTests", "YAMLConfigurationMutationTests"], liveSmokeOnly: false),
        .init(identifier: "local-runtime", displayName: "Local runtime", scope: .utility, defaultCoverage: ["LocalRuntimeWorkflowTests", "YAMLConfigurationMutationTests"], liveSmokeOnly: false),
        .init(identifier: "utilities", displayName: "Utilities", scope: .utility, defaultCoverage: ["UtilitiesWorkflowTests"], liveSmokeOnly: false),
        .init(identifier: "security", displayName: "Security", scope: .security, defaultCoverage: ["SecurityGuardrailTests", "FailureRedactionTests", "RetentionAndKeychainContractTests"], liveSmokeOnly: false),
        .init(identifier: "attachments", displayName: "Attachments", scope: .technical, defaultCoverage: ["AttachmentPayloadTests"], liveSmokeOnly: false),
        .init(identifier: "async-lifecycle", displayName: "Async lifecycle", scope: .technical, defaultCoverage: ["AsyncLifecycleTests"], liveSmokeOnly: false),
        .init(identifier: "localization-accessibility", displayName: "Localization/accessibility", scope: .functional, defaultCoverage: ["LocalizationAndAccessibilityTests"], liveSmokeOnly: false),
        .init(identifier: "live-api", displayName: "Optional live Hermes services", scope: .liveSmoke, defaultCoverage: ["LiveSmokeSkipTests"], liveSmokeOnly: true)
    ]

    static var identifiers: Set<String> { Set(categories.map(\.identifier)) }
    static var documentedSurfaceCount: Int { categories.count }
}
