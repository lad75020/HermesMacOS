# Data Model: HermesMacOS Test Target

## HermesMacOSTest Target

**Purpose**: Native Xcode test target that builds with HermesMacOS and executes deterministic Swift tests.

**Key fields / settings**:
- `name`: `HermesMacOSTest` exactly.
- `platform`: macOS.
- `minimumOS`: macOS 26.0.
- `languageMode`: Swift 6 language mode under Xcode 26.6 / Apple Swift 6.3.3.
- `hostApplication`: HermesMacOS app target where app-hosted tests require runtime loading.
- `defaultExecution`: mock-backed and safe without live Hermes services.

**Validation rules**:
- Target must be generated from `project.yml`.
- Target must appear in `xcodebuild -list`.
- Target or associated scheme must be runnable from command line and Xcode.
- Target must not require real API keys, dashboard tokens, SSH keys, microphone permission, or real Hermes home access by default.

## Coverage Category

**Purpose**: A documented feature/integration/security area that requires executable test or explicit opt-in smoke coverage.

**Fields**:
- `identifier`: stable category key, e.g. `ask-hermes.streaming` or `security.redaction`.
- `displayName`: maintainer-readable name.
- `scope`: functional, technical, security, integration, utility, or live-smoke.
- `documentedSource`: reference doc or source file establishing the category.
- `defaultCoverage`: one or more default tests, or an explicit reason it is live-smoke only.
- `riskLevel`: high for secrets, local mutation, process execution, TLS, SSH, and raw prompt/response retention.

**Validation rules**:
- Every documented main tab and Settings surface must have at least one category.
- Every Hermes API/Dashboard/TUI/local runtime/security integration listed in docs must have at least one category.
- Live-smoke-only categories must state why default automation is unsafe or impractical.

## Functional Test Suite

**Purpose**: Tests that validate user-facing workflow behavior using observable state, fixtures, and mocks.

**Fields**:
- `suiteName`: e.g. `AskHermesWorkflowTests`.
- `coveredCategories`: coverage category identifiers.
- `fixtures`: mock responses, streams, dashboard HTML, local runtime trees.
- `expectedStates`: loading, empty, success, error, cancellation, token refresh, retry, or unavailable states.

**Validation rules**:
- Must not call live Hermes endpoints by default.
- Must use fake credentials and redaction assertions when secrets appear in fixtures.
- Must clean temporary files after execution.

## Technical Test Suite

**Purpose**: Tests pure contracts and helper behavior: URL construction, headers, parsers, redaction, encryption, YAML mutation, async cleanup, and error classification.

**Fields**:
- `suiteName`: e.g. `EndpointAndRequestContractTests`.
- `productionSurface`: source type or helper under test.
- `fixtures`: request bodies, fixture YAML, stream lines, fake errors, fake certificates.
- `assertions`: expected values and failure messages.

**Validation rules**:
- Tests must be deterministic.
- Failure names must identify the broken contract or guardrail.
- Tests that touch async behavior must have bounded timeouts or injectable clocks.

## Mock Hermes API

**Purpose**: Deterministic stand-in for Hermes gateway endpoints.

**Fields**:
- `route`: `/v1/responses`, `/v1/chat/completions`, `/v1/profiles`, `/v1/approvals`, `/v1/approvals/resolve`, or `/v1/requests/{id}/cancel`.
- `method`: expected HTTP method.
- `requiredHeaders`: `Authorization`, `X-Hermes-Profile`, cancellation/request IDs, session headers where applicable.
- `responseFixture`: JSON or stream fixture.
- `failureMode`: timeout, network loss, 4xx/5xx, malformed body, or cancellation.

**Validation rules**:
- Fake secrets must never appear unredacted in assertion output.
- Streaming fixtures must include partial, complete, malformed, interrupted, and unknown-event cases where relevant.

## Mock Dashboard

**Purpose**: Deterministic stand-in for dashboard HTML/session-token discovery and dashboard API routes.

**Fields**:
- `htmlFixture`: dashboard bootstrap with or without session token.
- `apiRoute`: skills, toolsets, schedules, plugins, MCP servers, sessions, history search, raw config, or WebSocket ticket route.
- `tokenState`: valid, missing, expired, refreshed, or unauthorized.
- `responseFixture`: JSON, raw config, or error fixture.

**Validation rules**:
- Missing/expired token cases must produce user-visible failures or retries.
- Token values in fixtures must be redacted in logs and failures.

## Local Runtime Fixture

**Purpose**: Temporary Hermes home and repository tree for local profiles, model config, MCP YAML, installation/update, Git/SSH, and utility behavior.

**Fields**:
- `rootURL`: temporary directory.
- `profiles`: profile config fixtures.
- `configYAML`: runtime model/tool/MCP/schedule/plugin fixture data.
- `repositoryState`: clean, dirty, ahead/behind, conflict, missing remote, or SSH remote.
- `cleanupPolicy`: remove on test completion.

**Validation rules**:
- Fixture must not resolve inside Laurent's real Hermes home or code repositories.
- Git/SSH tests must use temporary repos and fake keys.
- Process execution must be bounded and output-redacted.

## Security Fixture

**Purpose**: Fake inputs for endpoint validation, redaction, retention encryption, TLS pins, filesystem approvals, and secret cleanup.

**Fields**:
- `secretKind`: API key, dashboard token, SSH key, prompt, response, clipboard item, certificate fingerprint.
- `input`: fake secret-bearing value.
- `expectedVisibleOutput`: redacted or encrypted representation.
- `approvalState`: pending, approved, denied, reset, or not required.

**Validation rules**:
- Must use fake values only.
- Assertions must prove the raw secret does not appear in visible output, files, or failure messages.

## Live Smoke Configuration

**Purpose**: Optional developer-provided configuration for real Hermes services and macOS permissions.

**Fields**:
- `apiBaseURL`: optional Hermes API endpoint.
- `dashboardURL`: optional dashboard endpoint.
- `tuiGatewayEnabled`: whether WebSocket smoke checks are enabled.
- `whisperEnabled`: whether remote STT smoke checks are enabled.
- `requiresPermission`: microphone, speech recognition, SSH, TLS approval, or filesystem approval.

**Validation rules**:
- Must be opt-in.
- Must skip with a clear reason when configuration is absent.
- Must validate sensitive destinations before sending secrets.
