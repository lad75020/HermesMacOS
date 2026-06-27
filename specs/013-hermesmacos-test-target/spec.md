# Feature Specification: HermesMacOS Test Target

**Feature Branch**: `013-hermesmacos-test-target`  
**Created**: 2026-06-27  
**Status**: Draft  
**Input**: User description: "Add an Xcode target « HermesMacOSTest », and write Swift functional and technical tests for the complete scope of HermesMacOS functionalities"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Run a native test target for the app (Priority: P1)

A maintainer opens or regenerates the HermesMacOS Xcode project and finds a dedicated native test target named `HermesMacOSTest` that can be run from Xcode or the command line to validate the application without launching unrelated tooling.

**Why this priority**: The repository currently has no automated test target, so the first value is a repeatable local quality gate that future changes can use before build/manual smoke checks.

**Independent Test**: Regenerate the project, list targets/schemes, and run the dedicated test target to confirm it is discoverable, builds, and executes at least one smoke test.

**Acceptance Scenarios**:

1. **Given** the project is regenerated from the project definition, **When** the target list is inspected, **Then** `HermesMacOSTest` appears as a separate test target associated with HermesMacOS source.
2. **Given** the test target is selected, **When** tests are run, **Then** the app target builds and the test bundle executes without requiring live Hermes services by default.
3. **Given** tests are run from command line automation, **When** the test command finishes, **Then** it returns a clear pass/fail result and records failures with actionable test names.

---

### User Story 2 - Cover every user-facing HermesMacOS workflow (Priority: P1)

A maintainer gets functional coverage for the complete documented HermesMacOS surface: app shell, Settings, Ask Hermes, Chat with Hermes, History, Sessions, Approvals Inbox, Kanban, Dashboard embedding, Configuration panels, Utilities, speech-to-text, local retention, reachability, TLS approvals, and repository maintenance.

**Why this priority**: The test target is valuable only if it protects the complete app scope rather than a few helpers.

**Independent Test**: Review the test inventory against the documented app surface and run mock-backed functional tests for each tab or workflow group.

**Acceptance Scenarios**:

1. **Given** a maintainer reviews the test suite, **When** they compare it with `docs/README.md` and `docs/codebase/STRUCTURE.md`, **Then** every main tab and Settings surface has at least one named functional test or documented live-smoke companion.
2. **Given** mock API/dashboard responses are available, **When** Ask and Chat workflows are exercised, **Then** profile selection, streaming/non-streaming output, attachments, cancellation, and session continuation behavior are covered without exposing secrets.
3. **Given** dashboard-backed fixtures are used, **When** History, Sessions, Skills, Schedules, Plugins, Toolsets, MCP Servers, Approvals, and Kanban flows are exercised, **Then** loading, empty, success, token-refresh, mutation, and error states are covered.
4. **Given** local-runtime fixtures are used, **When** profile/model/config/YAML/installation utility flows are exercised, **Then** file edits, process previews, and unsafe states are validated without mutating a real Hermes installation by default.

---

### User Story 3 - Protect technical contracts and security guardrails (Priority: P2)

A maintainer gets focused technical tests for pure logic, request construction, parsing, retention, redaction, endpoint safety, TLS pin decisions, local approvals, process execution bounds, and asynchronous cancellation so regressions are caught before manual review.

**Why this priority**: HermesMacOS is unsandboxed by design and talks to sensitive local and remote services; technical guardrail regressions are high-impact even when UI still renders.

**Independent Test**: Run unit-level suites with deterministic fixtures and verify failure messages identify the broken contract or guardrail.

**Acceptance Scenarios**:

1. **Given** endpoint or credential settings exist, **When** technical tests validate request construction, **Then** sensitive requests include required headers only after destination validation and never leak API keys in failures.
2. **Given** local data retention is enabled in fixtures, **When** tests cover prompt, response, and clipboard retention, **Then** data is encrypted/redacted at rest and migration/clear paths are verified.
3. **Given** YAML/config fixtures include existing profile, model, MCP, toolset, schedule, and plugin data, **When** mutation helpers run, **Then** unrelated settings, comments where practical, disabled states, and ordering-sensitive fields are preserved.
4. **Given** long-running operations are started, **When** cancellation or timeout is requested, **Then** tests confirm the user-visible state is updated and no unbounded background loop remains.

---

### User Story 4 - Keep tests maintainable as HermesMacOS evolves (Priority: P3)

A future contributor can add new feature tests by following naming, fixture, and coverage conventions without increasing flakiness or relying on Laurent's live services.

**Why this priority**: Complete scope coverage must remain sustainable as new Hermes API, Dashboard, and local-runtime panels are added.

**Independent Test**: Add a small representative test using the documented fixture and naming conventions and confirm it runs with the rest of the suite.

**Acceptance Scenarios**:

1. **Given** a new app feature is introduced, **When** a contributor updates tests, **Then** the coverage map identifies the correct functional and technical suite location.
2. **Given** live Hermes services are unavailable, **When** default tests run, **Then** mock-backed tests still pass or produce explicit skip reasons for optional live smoke checks.
3. **Given** a test fails, **When** the failure is reported, **Then** the name and assertion identify the affected tab, integration contract, or security guardrail.

### Edge Cases

- The project is regenerated from `project.yml`; the `HermesMacOSTest` target and test scheme membership must persist.
- Default test execution must not require a running Hermes API, Dashboard, TUI Gateway, Whisper endpoint, microphone permission, SSH access, or a writable real Hermes home.
- Live smoke tests, if added, must be opt-in and must clearly report missing endpoint, token, permission, or host configuration.
- Tests that exercise secrets must use deterministic fake values and must assert redaction in logs, raw stream debug output, errors, and retained history.
- Tests must cover remote plaintext HTTP blocking for sensitive traffic while preserving loopback development paths.
- Self-signed TLS approval tests must use fixture fingerprints and must not pin real certificates unless a live smoke mode is explicitly enabled.
- Filesystem, process, Git, and SSH tests must operate in temporary fixtures and must not mutate the user's actual Hermes installation or repositories by default.
- Streaming and WebSocket tests must cover partial chunks, unknown events, malformed events, interruption, cancellation, and reconnection/resume outcomes.
- Dashboard token extraction tests must cover missing token, expired token, token refresh, authorization failure, and malformed dashboard HTML.
- Localization and accessibility smoke tests must detect missing critical labels or strings for primary navigation and controls.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The project MUST declare a dedicated Xcode test target named exactly `HermesMacOSTest` that is generated from the project source of truth and can be run from Xcode and command-line workflows.
- **FR-002**: The test target MUST compile against the HermesMacOS application code without adding external runtime dependencies unless explicitly justified in the plan.
- **FR-003**: The test suite MUST include a coverage map that ties every documented main tab, Settings surface, integration, local utility, and security guardrail to at least one functional test, technical test, or opt-in live-smoke check.
- **FR-004**: Functional tests MUST cover app shell navigation, per-window endpoint/profile state, Settings persistence, saved endpoint pairs, theme/language/font settings, and reachability indicators.
- **FR-005**: Functional tests MUST cover Ask Hermes flows including profile loading, prompt submission, streaming and non-streaming output, reasoning settings, attachments, cancellation, previous-response continuation, multi-workspace behavior, retained history, and user-visible errors.
- **FR-006**: Functional tests MUST cover Chat with Hermes flows including optional system prompts, streaming and non-streaming output, attachments, cancellation, session continuation headers, retained history, and user-visible errors.
- **FR-007**: Functional tests MUST cover TUI Gateway flows including WebSocket authentication, workspace create/activate/resume/close, prompt submission, attachment input, interrupt, request-response bubbles, event grouping, background completion, and unknown/error event handling.
- **FR-008**: Functional tests MUST cover dashboard-backed History, Sessions, Approvals, Kanban, embedded Dashboard, Skills, Schedules, Plugins, Toolsets, MCP Servers, and raw Configuration operations with loading, empty, success, mutation, token-refresh, authorization-failure, and service-unavailable states.
- **FR-009**: Functional tests MUST cover local runtime workflows for profiles, model/provider settings, MCP YAML editing, Hermes CLI refresh/add operations, repository status/preview/update review, and unsafe dirty/conflict states through temporary fixtures.
- **FR-010**: Functional tests MUST cover Utilities workflows for clipboard retention, prompt/response retention, raw stream debugging, knowledge eraser scan/review/archive/erase, speech-to-text engine selection, recording stop/cancel, and reachability monitoring.
- **FR-011**: Technical tests MUST cover endpoint normalization, request URL construction, required Hermes headers, cancellation IDs, session continuation headers, dashboard token extraction/cache/refresh, response/error classification, and streaming/SSE/WebSocket event parsing.
- **FR-012**: Technical tests MUST cover attachment validation, MIME inference, size/count limits, image/file/document payload encoding, and visible error states for unsupported or oversized inputs.
- **FR-013**: Technical tests MUST cover YAML/config mutation helpers for profiles, local runtime models, MCP servers, toolsets, schedules, plugins, and raw configuration preservation using representative fixtures.
- **FR-014**: Technical tests MUST cover security helpers for sensitive URL validation, bearer-token redaction, dashboard-token redaction, API/SSH Keychain storage, encrypted retention, TLS pin approval/reset, filesystem allowlist/approval decisions, bounded process execution, and temporary SSH key cleanup.
- **FR-015**: Technical tests MUST cover asynchronous cancellation, timeout, retry, background polling, auto-refresh, and cleanup behavior for network, WebSocket, speech, reachability, approvals, Kanban live updates, clipboard monitoring, and repository operations where testable.
- **FR-016**: Tests MUST use mock services, temporary directories, fake credentials, fixture dashboard HTML, fixture event streams, and deterministic clocks/data where practical so default execution is repeatable and does not depend on live services.
- **FR-017**: Optional live smoke checks MUST be separated from default tests, require explicit endpoint/permission configuration, and never send real secrets to unvalidated destinations.
- **FR-018**: Failure output MUST identify the affected user-facing workflow, technical contract, fixture, or security guardrail clearly enough for a maintainer to triage without reading the whole app.
- **FR-019**: Project and test-target settings MUST use Swift 6 language mode with the currently installed latest Apple Swift toolchain, verified as Apple Swift 6.3.3 with Xcode 26.6, while retaining macOS 26.0 as the minimum supported platform.
- **FR-SEC**: System MUST preserve HermesMacOS security guardrails for endpoint validation, Keychain/encrypted retention, redaction, TLS pin approval, local filesystem approvals, and bounded process execution where applicable.
- **FR-INT**: System MUST preserve documented Hermes API, Dashboard, TUI Gateway, local runtime, speech-to-text, and repository maintenance contracts, including headers, tokens, streaming events, cancellation IDs, attachments, retries, and user-visible error states.

### Key Entities

- **HermesMacOSTest Target**: Native Xcode test target that builds and runs Swift tests for HermesMacOS.
- **Coverage Map**: Maintainer-readable inventory linking app tabs, settings panels, integrations, local utilities, and security guardrails to tests or live-smoke checks.
- **Functional Test Suite**: Mock-backed tests that validate user-facing workflows and observable states across the complete app surface.
- **Technical Test Suite**: Unit-level tests for pure logic, request/response contracts, parsers, storage, security helpers, and async lifecycle behavior.
- **Mock Hermes API**: Deterministic fixture service or URL-loading substitute for `/v1/responses`, `/v1/chat/completions`, profiles, approvals, and cancellation routes.
- **Mock Dashboard**: Deterministic fixture service or URL-loading substitute for dashboard HTML/session-token discovery and dashboard API routes.
- **Local Runtime Fixture**: Temporary Hermes home/repository/config tree used to test local profile, model, MCP, config, Git, SSH, and utility workflows without touching real user data.
- **Live Smoke Configuration**: Optional environment or scheme settings that enable manually approved checks against real Hermes services.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: `xcodebuild -list` or the Xcode project navigator reports exactly one new test target named `HermesMacOSTest` in addition to the existing HermesMacOS application target.
- **SC-002**: Default test execution completes without requiring live Hermes API, Dashboard, TUI Gateway, Whisper, microphone, SSH, or real Hermes-home access.
- **SC-003**: The coverage map accounts for 100% of documented main tabs and Settings surfaces listed in the app documentation.
- **SC-004**: The coverage map accounts for 100% of documented Hermes API, Dashboard, TUI Gateway, local runtime, speech-to-text, Keychain/retention, TLS, filesystem, process, Git, and SSH integration categories.
- **SC-005**: Each coverage category has at least one executable functional test, executable technical test, or explicit opt-in live-smoke check with a skip reason for default runs.
- **SC-006**: Security tests demonstrate that representative fake API keys, dashboard tokens, SSH keys, prompts, responses, and clipboard values are redacted or encrypted and do not appear in test failure output.
- **SC-007**: Mock-backed streaming tests validate partial, complete, malformed, interrupted, cancelled, and unknown-event paths for relevant response and gateway streams.
- **SC-008**: Local-runtime tests run only against temporary fixtures and leave no changes in the user's actual Hermes home, repositories, Keychain items, or certificate pins.
- **SC-009**: The `HermesMacOSTest` suite produces actionable failures whose names identify the affected workflow or guardrail in at least 95% of failing test cases reviewed during implementation.
- **SC-BUILD**: The `HermesMacOS` scheme builds successfully with Xcode or command-line `xcodebuild` after adding the test target.
- **SC-SMOKE**: The primary test-run journey can be validated independently with documented command-line and Xcode smoke checks.

## Assumptions

- The user explicitly requires the target name `HermesMacOSTest`; the singular spelling is intentional and should be preserved.
- The user explicitly requires the latest installed Swift toolchain, Xcode 26.6, and macOS 26.0 and above; local toolchain verification reported Apple Swift 6.3.3 targeting arm64-apple-macosx26.0, with Swift 6 language mode planned for project settings.
- The project remains generated from `project.yml`, so project membership changes should be made there and regenerated into the checked-in `.xcodeproj`.
- Default automated tests should be deterministic and mock-backed; live Hermes service checks should be opt-in because endpoints, tokens, permissions, and services vary by machine.
- Adding a test target may require exposing selected pure logic or injecting URL/session/filesystem dependencies, but production behavior should remain unchanged.
- This specification defines the testing feature scope; implementation planning will decide exact test file names, fixtures, and any required code seams.
