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
    let requiredSubcategories: [String]
    let defaultCoverage: [String]
    let liveSmokeOnly: Bool

    init(
        identifier: String,
        displayName: String,
        scope: Scope,
        requiredSubcategories: [String],
        defaultCoverage: [String],
        liveSmokeOnly: Bool
    ) {
        self.identifier = identifier
        self.displayName = displayName
        self.scope = scope
        self.requiredSubcategories = requiredSubcategories
        self.defaultCoverage = defaultCoverage
        self.liveSmokeOnly = liveSmokeOnly
    }
}

enum HermesMacOSTestCoverageMap {
    static let categories: [HermesMacOSTestCoverageCategory] = [
        .init(
            identifier: "app-shell",
            displayName: "App shell",
            scope: .functional,
            requiredSubcategories: ["tab list", "selected tab state", "tab visibility filtering", "multi-window endpoint state", "multi-window profile state", "activity indicators"],
            defaultCoverage: ["AppShellAndSettingsTests"],
            liveSmokeOnly: false
        ),
        .init(
            identifier: "settings",
            displayName: "Settings",
            scope: .functional,
            requiredSubcategories: ["API endpoint persistence", "dashboard endpoint persistence", "API key path", "self-signed certificate policy", "saved endpoint pairs", "SSH credentials", "allowed folders", "theme preference", "language preference", "font preference", "tab visibility controls", "reachability indicators"],
            defaultCoverage: ["AppShellAndSettingsTests"],
            liveSmokeOnly: false
        ),
        .init(
            identifier: "ask-hermes",
            displayName: "Ask Hermes",
            scope: .functional,
            requiredSubcategories: ["profile loading", "streaming responses", "non-streaming responses", "reasoning settings", "attachments", "cancellation", "previous response continuation", "multi-workspace behavior", "retained history", "user-visible errors"],
            defaultCoverage: ["AskHermesWorkflowTests", "EndpointAndRequestContractTests"],
            liveSmokeOnly: false
        ),
        .init(
            identifier: "chat-hermes",
            displayName: "Chat with Hermes",
            scope: .functional,
            requiredSubcategories: ["system prompt", "streaming responses", "non-streaming responses", "attachments", "cancellation", "session continuation headers", "retained history", "user-visible errors"],
            defaultCoverage: ["ChatHermesWorkflowTests", "EndpointAndRequestContractTests"],
            liveSmokeOnly: false
        ),
        .init(
            identifier: "tui-gateway",
            displayName: "TUI Gateway",
            scope: .integration,
            requiredSubcategories: ["WebSocket authentication", "workspace create", "workspace activate", "workspace resume", "workspace close", "prompt submission", "attachment flow", "interrupt", "request-response bubbles", "event grouping", "background completion", "malformed events", "unknown events"],
            defaultCoverage: ["TUIGatewayWorkflowTests", "StreamingAndGatewayEventTests"],
            liveSmokeOnly: false
        ),
        .init(
            identifier: "memory",
            displayName: "Memory",
            scope: .functional,
            requiredSubcategories: ["Hindsight provider boundary", "memory list", "pagination", "filtering", "delete confirmation", "delete failure handling", "provider empty state", "provider error state", "sanitized provider errors"],
            defaultCoverage: ["MemoryTabWorkflowTests", "HindsightMemoryClientTests"],
            liveSmokeOnly: false
        ),
        .init(
            identifier: "history-sessions",
            displayName: "History and Sessions",
            scope: .functional,
            requiredSubcategories: ["dashboard search", "paged session list", "per-session messages", "resume into Ask", "resume into Chat", "resume into TUI", "Hindsight session retention", "empty state", "error state", "token-refresh state"],
            defaultCoverage: ["DashboardBackedWorkflowTests"],
            liveSmokeOnly: false
        ),
        .init(
            identifier: "approvals",
            displayName: "Approvals",
            scope: .functional,
            requiredSubcategories: ["pending approvals", "approve mutation", "deny mutation", "auto-refresh", "unavailable API state"],
            defaultCoverage: ["ApprovalsAndKanbanWorkflowTests"],
            liveSmokeOnly: false
        ),
        .init(
            identifier: "kanban",
            displayName: "Kanban",
            scope: .functional,
            requiredSubcategories: ["board load", "task mutations", "comment mutations", "action mutations", "live updates", "plugin unavailable state"],
            defaultCoverage: ["ApprovalsAndKanbanWorkflowTests"],
            liveSmokeOnly: false
        ),
        .init(
            identifier: "dashboard",
            displayName: "Dashboard embedding",
            scope: .integration,
            requiredSubcategories: ["URL construction", "dashboard availability", "session-token dependency", "visible errors"],
            defaultCoverage: ["DashboardBackedWorkflowTests"],
            liveSmokeOnly: false
        ),
        .init(
            identifier: "configuration",
            displayName: "Configuration",
            scope: .functional,
            requiredSubcategories: ["profiles", "models", "skills", "schedules", "plugins", "toolsets", "MCP servers", "raw config", "token refresh", "mutation failure handling"],
            defaultCoverage: ["DashboardBackedWorkflowTests", "YAMLConfigurationMutationTests"],
            liveSmokeOnly: false
        ),
        .init(
            identifier: "local-runtime",
            displayName: "Local runtime",
            scope: .utility,
            requiredSubcategories: ["profile config", "model provider settings", "MCP YAML editing", "Hermes CLI refresh", "Hermes CLI add", "repository status", "repository preview", "repository update review", "dirty state", "conflict state", "Git", "SSH", "temporary local files only"],
            defaultCoverage: ["LocalRuntimeWorkflowTests", "YAMLConfigurationMutationTests"],
            liveSmokeOnly: false
        ),
        .init(
            identifier: "utilities",
            displayName: "Utilities",
            scope: .utility,
            requiredSubcategories: ["clipboard retention", "prompt retention", "response retention", "raw stream debug controls", "knowledge eraser scan", "knowledge eraser review", "knowledge eraser archive", "knowledge eraser erase", "knowledge eraser Hindsight provider", "speech-to-text selection", "recording stop", "recording cancel", "reachability monitoring"],
            defaultCoverage: ["UtilitiesWorkflowTests"],
            liveSmokeOnly: false
        ),
        .init(
            identifier: "security",
            displayName: "Security",
            scope: .security,
            requiredSubcategories: ["sensitive URL validation", "bearer-token redaction", "dashboard-token redaction", "SSH redaction", "API Keychain storage", "SSH Keychain storage", "encrypted retention", "retention clear paths", "TLS pin approval", "TLS pin reset", "filesystem allowlist", "filesystem approval", "bounded process execution", "temporary SSH key cleanup"],
            defaultCoverage: ["SecurityGuardrailTests", "FailureRedactionTests", "RetentionAndKeychainContractTests"],
            liveSmokeOnly: false
        ),
        .init(
            identifier: "attachments",
            displayName: "Attachments",
            scope: .technical,
            requiredSubcategories: ["MIME inference", "size limits", "count limits", "payload encoding", "unsupported visible errors", "oversized visible errors"],
            defaultCoverage: ["AttachmentPayloadTests"],
            liveSmokeOnly: false
        ),
        .init(
            identifier: "async-lifecycle",
            displayName: "Async lifecycle",
            scope: .technical,
            requiredSubcategories: ["cancellation", "timeout", "retry", "background polling", "auto-refresh", "network cleanup", "WebSocket cleanup", "speech cleanup", "reachability cleanup", "approvals cleanup", "Kanban cleanup", "clipboard monitoring cleanup", "repository-operation cleanup", "no unbounded background loops"],
            defaultCoverage: ["AsyncLifecycleTests"],
            liveSmokeOnly: false
        ),
        .init(
            identifier: "localization-accessibility",
            displayName: "Localization/accessibility",
            scope: .functional,
            requiredSubcategories: ["primary navigation labels", "critical control strings", "supported app surfaces", "Memory tab controls", "Settings tab visibility controls"],
            defaultCoverage: ["LocalizationAndAccessibilityTests"],
            liveSmokeOnly: false
        ),
        .init(
            identifier: "live-api",
            displayName: "Optional live Hermes services",
            scope: .liveSmoke,
            requiredSubcategories: ["explicit enablement", "clear skip reason", "destination validation", "destructive operation confirmation", "secret redaction"],
            defaultCoverage: ["LiveSmokeSkipTests"],
            liveSmokeOnly: true
        )
    ]

    static var identifiers: Set<String> { Set(categories.map(\.identifier)) }
    static var documentedSurfaceCount: Int { categories.count }
    static var allRequiredSubcategories: Set<String> { Set(categories.flatMap(\.requiredSubcategories)) }

    static func category(_ identifier: String) -> HermesMacOSTestCoverageCategory {
        guard let category = categories.first(where: { $0.identifier == identifier }) else {
            preconditionFailure("Unknown HermesMacOSTest coverage category: \(identifier)")
        }
        return category
    }

    static func subcategories(for identifier: String) -> Set<String> {
        Set(category(identifier).requiredSubcategories)
    }

    static func covers(_ identifier: String, _ subcategory: String) -> Bool {
        subcategories(for: identifier).contains(subcategory)
    }
}
