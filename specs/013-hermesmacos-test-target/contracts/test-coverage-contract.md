# Contract: HermesMacOSTest Coverage and Execution

## Target Contract

- Target name: `HermesMacOSTest` exactly.
- Platform: macOS.
- Minimum supported OS: macOS 26.0.
- Toolchain: Xcode 26.6 with Apple Swift 6.3.3; project language mode: Swift 6.
- Source of truth: `project.yml`, regenerated into `HermesMacOS.xcodeproj`.
- Default execution must not require live Hermes services, microphone permission, SSH access, real API keys, real dashboard tokens, or real Hermes home access.

## Command Contract

The implemented feature must support these commands from the repository root:

```bash
xcodegen generate
xcodebuild -list -project HermesMacOS.xcodeproj
xcodebuild -project HermesMacOS.xcodeproj -scheme HermesMacOS -destination 'generic/platform=macOS' build
xcodebuild -project HermesMacOS.xcodeproj -scheme HermesMacOSTest -destination 'platform=macOS' test
```

If Xcode locks shared DerivedData, the same build/test commands must support an isolated `-derivedDataPath`.

## Coverage Contract

Each category below must be represented in `HermesMacOSTest/Coverage/HermesMacOSTestCoverageMap.swift` and mapped to at least one default test or explicit opt-in live-smoke check.

| Category | Required coverage |
| --- | --- |
| App shell | tab list, selected tab state, multi-window endpoint/profile state, activity indicators |
| Settings | API/dashboard endpoints, API key path, self-signed certificate policy, saved endpoint pairs, SSH credentials, allowed folders, theme/language/font preferences |
| Ask Hermes | profile loading, streaming and non-streaming responses, reasoning settings, attachments, cancellation, previous response continuation, retained history, user-visible errors |
| Chat with Hermes | system prompt, streaming and non-streaming responses, attachments, cancellation, session continuation headers, retained history, user-visible errors |
| TUI Gateway | WebSocket authentication, workspace create/activate/resume/close, prompt submission, attachment flow, interrupt, request-response bubbles, event grouping, background completion, malformed/unknown events |
| History and Sessions | dashboard search, paged session list, per-session messages, resume into Ask/Chat/TUI where supported, empty/error/token-refresh states |
| Approvals | pending approvals, approve/deny, auto-refresh, unavailable API state |
| Kanban | board load, task/comment/action mutations, live updates, plugin unavailable state |
| Dashboard embedding | URL construction, dashboard availability, session-token dependency, visible errors |
| Configuration | profiles, models, skills, schedules, plugins, toolsets, MCP servers, raw config, token refresh, mutation failure handling |
| Local runtime | profile config, model provider settings, MCP YAML editing, Hermes CLI refresh/add operations, temporary local files only |
| Utilities | clipboard retention, prompt/response retention, raw stream debug controls, knowledge eraser scan/review/archive/erase, speech-to-text selection and cleanup, reachability monitoring |
| Security | sensitive URL validation, bearer/dashboard/SSH redaction, Keychain paths, encrypted retention, TLS pin approval/reset, filesystem allowlist/approval, bounded process execution, temporary SSH key cleanup |
| Attachments | MIME inference, size/count limits, payload encoding, unsupported/oversized visible errors |
| Async lifecycle | cancellation, timeout, retry, background polling, auto-refresh, cleanup of tasks/resources |
| Localization/accessibility | primary navigation labels and critical control strings for supported app surfaces |

## Fixture Contract

- Fixtures must be deterministic and committed under `HermesMacOSTest/Fixtures/` unless generated in temporary directories during a test.
- Fake secrets must use obviously fake values and must be asserted absent from visible output and failure text.
- Local runtime fixtures must be created under temporary directories and cleaned up after tests.
- Stream fixtures must include success, partial, malformed, interrupted, cancelled, and unknown-event cases where relevant.
- Dashboard fixtures must include valid token, missing token, expired/unauthorized token, refreshed token, and malformed HTML cases.

## Live Smoke Contract

Optional live smoke checks may cover real Hermes API, Dashboard, TUI Gateway, Whisper, microphone, TLS approval, SSH, and repository operations only when explicitly enabled through documented environment or scheme settings.

Live smoke checks must:

1. Skip with a clear reason when configuration is missing.
2. Validate sensitive destinations before sending credentials.
3. Avoid destructive operations unless an additional explicit confirmation setting is present.
4. Never print raw API keys, dashboard tokens, SSH keys, prompts, responses, clipboard history, or raw stream secrets.

## Failure Contract

A failing test must identify:

- the workflow or guardrail category,
- the fixture or route involved,
- the expected contract,
- the observed failure,
- and the remediation surface when obvious.

Example naming pattern:

```text
AskHermesWorkflowTests.streamingCancellationSendsRequestIdAndShowsCancelledState
SecurityGuardrailTests.remotePlaintextHTTPWithBearerTokenIsBlocked
YAMLConfigurationMutationTests.upsertingMCPServerPreservesUnrelatedConfig
```
