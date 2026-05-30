# HermesMacOS codebase structure

## Top-level layout
- `project.yml`: XcodeGen definition for the app target and generated Info.plist settings.
- `HermesMacOS.xcodeproj/`: generated Xcode project checked into the repository.
- `HermesMacOS/`: Swift source files, localized InfoPlist strings, asset catalog, fonts, video resource, and entitlements.
- `README.md`: project overview, setup, build, configuration, and security notes.
- `SECURITY.md`: security model notes for sandboxing, local retention, TLS trust, and SSH keys.
- `docs/`: generated project and codebase documentation.

## Source organization
The source is organized by feature and supporting service, not by a strict MVC or clean-architecture layer directory structure. Files live directly under `HermesMacOS/`.

## Entry points
- `HermesMacOS/HermesMacOSApp.swift`: application entry point, scene setup, settings scene, app commands, startup unlock flow, and root view selection.
- `HermesMacOS/ContentView.swift`: main shell, side tab navigation, multi-window connection state, workspace creation and selection, and feature view composition.
- `HermesMacOS/SettingsView.swift`: settings UI for API endpoint, dashboard endpoint, saved endpoint pairs, SSH credentials, allowed folders, theme, language, and font settings.

## Feature areas
- Ask Hermes: `HermesViews.swift`, `HermesModelsAPI.swift`, `HermesAskWorkspacesView.swift`.
- Chat with Hermes: `HermesChatView.swift`, `HermesChatCompletionsAPI.swift`.
- History and sessions: `HermesHistoryView.swift`, `HermesDashboardHistorySearch.swift`.
- Approvals: `HermesApprovalsInboxView.swift`, approval URL helpers in `HermesModelsAPI.swift`.
- Kanban: `HermesKanbanView.swift`.
- Dashboard embedding: `HermesDashboardWebView.swift`.
- Configuration: `HermesConfigurationView.swift` plus section files for profiles, models, MCP servers, skills, schedules, plugins, and toolsets.
- Dashboard stores: `HermesDashboardSkills.swift`, `HermesDashboardToolsets.swift`, `HermesDashboardSchedules.swift`, `HermesDashboardMCPServers.swift`, `HermesDashboardPluginsStore.swift`.
- Local configuration stores: `HermesLocalProfiles.swift`, `HermesLocalRuntimeModels.swift`, `HermesLocalConfigurationRuntime.swift`, `HermesMCPServersYAML.swift`.
- Utilities: `HermesUtilitiesView.swift`, `HermesInstallationView.swift`, `HermesKnowledgeEraserUtility.swift`, `HermesSpeechToText.swift`.
- Shared security and process helpers: `HermesSecurityUtilities.swift`.
- Styling and resources: `HermesTypography.swift`, `SplashView.swift`, `Assets.xcassets`, `Fonts/`, `Resources/HermesSplash.mp4`, `Localizable.xcstrings`.

## Main tab surface
`HermesMacOSTab` defines these main tabs: Ask Hermes, Chat with Hermes, History, Sessions, Approvals Inbox, Kanban, Hermes Dashboard, Configuration, and Utilities.

## Localization and assets
- `Localizable.xcstrings` contains app-localized strings.
- `en.lproj`, `fr.lproj`, `es.lproj`, `de.lproj`, and `zh-Hans.lproj` contain localized InfoPlist strings.
- Bundled fonts are registered by `HermesTypography.swift`.
- The splash screen uses `Resources/HermesSplash.mp4` through `SplashView.swift`.

## [TODO]
- [TODO] No `Tests/` directory or test target was found in the structure.
- [ASK USER] Should generated `.xcodeproj` continue to be committed, or should `project.yml` be the only project source checked in?

## Evidence
- Terminal scan output generated during this documentation pass: directory tree, code metrics, high-churn files.
- `HermesMacOS/ContentView.swift`: `HermesMacOSTab` cases and root view composition.
- `HermesMacOS/HermesMacOSApp.swift`: `@main` app and root view.
- `HermesMacOS/SettingsView.swift`: settings surface.
- `HermesMacOS/HermesTypography.swift`: bundled font registration.
- `project.yml`: source path and resource exclusions.
- Terminal evidence: 39 Swift files under `HermesMacOS/`.
