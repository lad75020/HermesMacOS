# HermesMacOS codebase conventions

## File and type naming
- Swift source files use PascalCase names that match their primary view, store, or feature area, for example `HermesChatView.swift`, `HermesDashboardSchedules.swift`, and `HermesSecurityUtilities.swift`.
- Most app-specific types use a `Hermes` or `HermesMacOS` prefix.
- View structs end with `View`, `Panel`, `Row`, `Card`, or similar UI nouns.
- Store/session classes end with `Store` or `Session`.
- Data transfer objects use descriptive Swift structs such as `HermesDashboardScheduleJob`, `HermesChatCompletionsRequestBody`, and `HermesApprovalResolveBody`.

## Source organization conventions
- Feature files live directly under `HermesMacOS/`; the repo does not use nested feature directories.
- Large feature areas are split by dashboard domain or configuration section, for example `HermesConfigurationSkillsSection.swift` and `HermesConfigurationMCPServersSection.swift`.
- Extensions are used to split a large `HermesConfigurationView` across section files.

## State management
- SwiftUI views use `@State`, `@Binding`, `@Environment`, and `@AppStorage`.
- Observable mutable domain state uses `@Observable` classes such as `HermesResponsesSession`, `HermesChatSession`, stores, and utility managers.
- User-facing settings that are not sensitive use `@AppStorage` or `UserDefaults`.
- Sensitive values use Keychain helpers or encrypted retention storage.

## Async and error handling
- Network and local mutations are async and update user-visible status strings.
- Feature stores usually keep `isLoading`, `lastErrorMessage`, or `statusMessage` fields.
- HTTP responses are validated centrally by `HermesNetworkSessionFactory.validate(response:)`.
- Custom error enums implement `LocalizedError` for user-facing messages.
- Cancellation flows track an explicit request ID and call `/v1/requests/{id}/cancel` when possible.

## Network request conventions
- Hermes API requests include `X-Hermes-Profile` when profile selection matters.
- Active session continuation includes `X-Hermes-Session-Id` and `x-openclaw-session-key` when a Hermes session ID is available.
- API keys are sent as `Authorization: Bearer ...` only after sensitive URL validation.
- Streaming responses use SSE line parsing and raw debug capture.
- Dashboard API calls retrieve a session token from dashboard HTML before calling JSON endpoints.

## Storage conventions
- API keys and SSH private keys use Keychain services.
- Local retention values are stored under encrypted UserDefaults keys prefixed with `hermes.macOS.encrypted.`.
- Common `@AppStorage` keys use a `hermes.macOS.` or `hermes.app` prefix.
- Legacy plaintext UserDefaults values are migrated to encrypted storage on load where the code supports migration.

## UI conventions
- The main UI uses a glass-panel visual language with app-specific colors and custom fonts.
- Accessibility labels and selected traits are present on key navigation controls.
- Long-running tab activity is surfaced through side-tab color and blink states.
- Settings and utility sections use disclosure state persisted in `@AppStorage`.

## Formatting and linting
No SwiftFormat, SwiftLint, `.editorconfig`, or other formatting/lint config was detected. Formatting conventions are therefore implicit in existing Swift files.

## [TODO]
- [TODO] Add a formatter/linter policy if the team wants a mechanically enforceable style.
- [ASK USER] Should new feature files continue the flat `HermesMacOS/` layout, or should the project move to feature directories as it grows?

## Evidence
- `HermesMacOS/*.swift`: file naming and `Hermes` type prefixes.
- `HermesMacOS/HermesConfigurationView.swift` plus `HermesConfiguration*Section.swift`: extension-based feature splitting.
- `HermesMacOS/HermesModelsAPI.swift`: request headers, session ID, API key, cancellation, network validation.
- `HermesMacOS/HermesSecurityUtilities.swift`: Keychain, encryption, LocalizedError, endpoint validation.
- `HermesMacOS/ContentView.swift`, `SettingsView.swift`, `HermesUtilitiesView.swift`: `@State`, `@AppStorage`, persisted disclosure settings.
- Scan output: no linting or formatting config detected.
