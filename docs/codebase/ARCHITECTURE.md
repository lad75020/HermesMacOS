# HermesMacOS codebase architecture

## Summary
HermesMacOS is a native SwiftUI control surface for Hermes Agent. `ContentView` owns the main shell and composes feature views. Feature views hold observable session/store objects that talk to either the Hermes API gateway, the Hermes Dashboard, or local filesystem/process helpers.

## High-level data flow
```text
User action in SwiftUI
  -> feature view validates input and updates local state
  -> observable session/store builds an API request, dashboard request, local file mutation, or process command
  -> shared helpers apply endpoint, token, TLS, Keychain, filesystem, and process policy
  -> response updates observable state
  -> SwiftUI redraws the active tab, status chips, history rows, or utility panel
```

## Main composition
- `HermesMacOSApp` initializes the app scene and shows either the unlock failure UI or `ContentView`.
- `ContentView` owns global app state for selected tab, API settings, dashboard URL, window ID, Ask workspaces, Chat session, history stores, approvals store, Kanban store, and installation session.
- `HermesSideTabSwitcher` renders navigation and reachability LEDs.
- Feature views receive the current `HermesAPISettings`, dashboard URL, and window identity.

## Network architecture
- `HermesAPISettings` builds Hermes API URLs for `/v1/responses`, `/v1/chat/completions`, `/v1/requests/{id}/cancel`, `/v1/profiles`, `/v1/approvals`, and `/v1/approvals/resolve`.
- `HermesNetworkSessionFactory` creates `URLSession` instances with 30-second request timeout and 3600-second resource timeout, and optionally a delegate for pinned self-signed certificate handling.
- `HermesResponsesSession` streams or fetches Responses API output and parses SSE events into visible assistant text, stream-output pills, token usage, and raw debug JSON.
- `HermesChatSession` performs the equivalent workflow for `/v1/chat/completions`.
- `HermesDashboardClient` discovers a dashboard session token from dashboard HTML, caches it by base URL, retries token fetches on selected 401 flows, and provides `getJSON`, `sendJSON`, and raw config helpers.

## Dashboard-backed stores
Dashboard-backed features are represented as stores with async refresh and mutation methods:
- `HermesDashboardHistorySearchSession`: conversation search through `api/sessions/search/conversations`.
- `HermesSessionsStore`: paged session list and per-session messages through `api/sessions` and `api/sessions/{id}/messages`.
- `HermesApprovalsInboxStore`: pending approvals and resolution through Hermes API approval endpoints.
- `HermesDashboardSkillsStore`: skills from `api/skills`, toggled by `api/skills/toggle`.
- `HermesDashboardToolsetsStore`: toolsets from `api/tools/toolsets`.
- `HermesDashboardSchedulesStore`: cron jobs from `api/cron/jobs` plus pause, resume, trigger, create, and update actions.
- `HermesDashboardMCPServersStore`: MCP server loading, update, deletion, probe, and recent error handling.
- `HermesDashboardPluginsStore`: plugin hub data from `api/dashboard/plugins/hub`.
- `HermesKanbanStore`: plugin-backed Kanban boards, tasks, comments, task actions, and live updates.

## Local runtime architecture
Local configuration is handled by local stores and helpers:
- `HermesLocalProfilesStore` reads and mutates Hermes profiles under the Hermes home directory.
- `HermesLocalRuntimeModelsStore` reads and writes model provider/model YAML values in `config.yaml`.
- `HermesMCPServersYAML` parses, removes, and upserts MCP server blocks in YAML text.
- `HermesLocalConfigurationRuntime` executes Hermes CLI commands for refreshing, skill installation, and MCP server addition.
- `HermesInstallationSession` runs git commands against local or SSH-backed Hermes Agent repositories.

## Security architecture
- Sensitive remote plaintext HTTP is blocked by `HermesEndpointSecurity.validateSensitiveURL`, except loopback hosts.
- API keys, SSH keys, TLS certificate pins, and local retention encryption keys use the data-protection Keychain.
- Retained prompts, responses, and clipboard items use AES-GCM encryption before storage in UserDefaults.
- Startup unlock uses `LocalAuthentication` through `HermesSecretUnlockGate`.
- Untrusted self-signed TLS certificate fingerprints are approved through local approval flow before being pinned.
- Local filesystem access is guarded by an allowlist and a local approvals center where practical.

## State and concurrency patterns
- UI state is mostly `@State`, `@Binding`, and `@AppStorage` inside SwiftUI views.
- Long-running operations use Swift concurrency tasks (`Task`, async methods, async sequences for SSE lines and WebSocket messages).
- Observable feature sessions/stores are marked with `@Observable` and generally confined to the main actor for UI updates.
- Background loops are used for reachability checks, approvals auto-refresh, Kanban live updates, clipboard monitoring, and tab blink indicators.

## Intent vs reality
- Intent from README: native SwiftUI control surface for APIs, dashboard data, local utilities, and repository maintenance. Reality in source matches this.
- Intent from SECURITY.md: sandbox disabled with guardrails. Reality in `project.yml` and source matches broad filesystem/process workflows and security helpers.
- README says no separate test runner. Reality matches `xcodebuild -list`, which reports no test target.

## [TODO]
- [TODO] The Kanban plugin API paths are assembled inside `HermesKanbanStore`; document exact server-side contract after checking the matching plugin implementation.
- [ASK USER] Should local runtime mutation remain inside the app, or should these operations move behind a narrower Hermes Dashboard/API endpoint over time?

## Evidence
- `HermesMacOS/HermesMacOSApp.swift`: scene setup and startup unlock.
- `HermesMacOS/ContentView.swift`: tab composition, app state, workspace state.
- `HermesMacOS/HermesModelsAPI.swift`: endpoint builders, network factory, Responses session.
- `HermesMacOS/HermesChatCompletionsAPI.swift`: Chat Completions session.
- `HermesMacOS/HermesSecurityUtilities.swift`: endpoint security, Keychain, encryption, dashboard client, approvals, process runner.
- `HermesMacOS/HermesDashboard*.swift`: dashboard-backed stores.
- `HermesMacOS/HermesLocal*.swift`, `HermesMacOS/HermesMCPServersYAML.swift`: local configuration stores.
- `README.md` and `SECURITY.md`: stated app intent and security intent.
