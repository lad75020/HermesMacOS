# HermesMacOS testing

## Current test setup
No dedicated test target, unit test bundle, UI test bundle, or separate test runner was detected in the repository. The Xcode project list reports one application target and one scheme, both named `HermesMacOS`.

## Current verification path
The repository README documents build verification through Xcode or command-line `xcodebuild`:

```bash
xcodegen generate
xcodebuild   -project HermesMacOS.xcodeproj   -scheme HermesMacOS   -destination 'generic/platform=macOS'   build
```

If DerivedData is locked by Xcode, README documents using an isolated DerivedData path.

## Manual smoke checks implied by code
After a successful build, these areas need manual or integration smoke checks because they depend on live Hermes services or macOS permissions:
- Ask Hermes: configure API base URL, fetch profiles, submit streaming and non-streaming requests, cancel an active request, resume a previous session.
- Chat with Hermes: submit streaming and non-streaming chat prompts, system prompt, attachments, and cancellation.
- Dashboard-backed tabs: verify the dashboard URL serves HTML with `window.__HERMES_SESSION_TOKEN__`, then exercise history, sessions, skills, schedules, plugins, toolsets, MCP servers, and raw config operations.
- Approvals Inbox: trigger a local approval, approve/deny, and confirm auto-refresh updates the tab state.
- Kanban: connect to a dashboard/plugin that exposes the expected Kanban API and live update stream.
- Speech-to-text: grant microphone and speech recognition permissions, test Apple local transcription, then test Whisper WebSocket if available.
- Local retention: opt into clipboard monitoring and message history, relaunch, and confirm retained data is readable after LocalAuthentication unlock.
- TLS pinning: connect to a self-signed trusted host, review the approval prompt, pin the fingerprint, then reset and repeat.
- SSH/gitrepo update: configure a saved remote endpoint with SSH credentials and run a preview before an update.

## Suggested future automated coverage
- Pure Swift unit tests for YAML manipulation in `HermesMCPServersYAML` and `HermesToolsetsYAMLUpdater`.
- Unit tests for endpoint URL normalization in `HermesHostEndpoints` and `HermesAPISettings`.
- Unit tests for redaction in `HermesSecretRedactor`.
- Unit tests for attachment limits, MIME inference, and request body encoding in `HermesPromptAttachment` and Chat attachment payloads.
- Unit tests for `HermesRequestFailureClassifier`.
- Integration tests with a mock HTTP server for Hermes API and Dashboard endpoints.
- UI smoke tests for tab navigation and settings persistence if a stable test host is available.

## [TODO]
- [TODO] Add actual test targets before documenting exact test commands beyond build verification.
- [ASK USER] Which live Hermes host should be treated as the canonical integration-test target, if any?

## Evidence
- `README.md`: build commands and note that the repository does not declare a separate test runner.
- Terminal evidence: `xcodebuild -list -project HermesMacOS.xcodeproj` reported only target `HermesMacOS` and scheme `HermesMacOS`.
- `project.yml`: one application target and no test target.
- `HermesMacOS/HermesMCPServersYAML.swift`, `HermesDashboardToolsets.swift`: pure parsing/update logic suitable for unit tests.
- `HermesMacOS/HermesSecurityUtilities.swift`: redaction and encrypted retention helpers.
- `HermesMacOS/HermesModelsAPI.swift`, `HermesChatCompletionsAPI.swift`: request construction and streaming logic.
