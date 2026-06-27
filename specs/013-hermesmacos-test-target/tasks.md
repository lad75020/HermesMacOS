# Tasks: HermesMacOS Test Target

**Input**: Design documents from `specs/013-hermesmacos-test-target/`

**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`, `contracts/test-coverage-contract.md`, `quickstart.md`

**Tests/Verification**: This feature adds the native test target, so test-first tasks are mandatory. Default tests must be deterministic, mock-backed, and safe without live Hermes services or real user secrets.

**Organization**: Tasks are grouped by user story so the target can ship as an MVP first, then expand to full functional, technical, and maintainability coverage.

## Summary

- Total tasks: 56
- Setup tasks: 5
- Foundational tasks: 13
- User Story 1 tasks: 5
- User Story 2 tasks: 11
- User Story 3 tasks: 10
- User Story 4 tasks: 5
- Polish tasks: 7
- Parallel tasks: 42

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Establish project configuration and the empty test-target layout.

- [x] T001 Update Swift language mode to Swift 6 and preserve macOS 26.0 deployment in ./project.yml
- [x] T002 Add native macOS test target `HermesMacOSTest` and shared test scheme settings in ./project.yml
- [x] T003 Create initial test target support entry point in HermesMacOSTest/Support/HermesTestAssertions.swift
- [x] T004 [P] Create fixture directory guide in HermesMacOSTest/Fixtures/README.md
- [x] T005 [P] Create opt-in live smoke configuration guide in HermesMacOSTest/LiveSmoke/LiveSmokeConfiguration.md

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core test harness, fixtures, and minimal seams required before user-story tests can compile.

**Critical**: Complete this phase before implementing user-story test files.

- [x] T006 [P] Implement deterministic fixture loading helpers in HermesMacOSTest/Support/HermesFixtureLoader.swift
- [x] T007 [P] Implement mock URL loading and request capture in HermesMacOSTest/Support/HermesMockURLProtocol.swift
- [x] T008 [P] Implement temporary Hermes home and repository fixtures in HermesMacOSTest/Support/HermesTemporaryRuntimeFixture.swift
- [x] T009 [P] Implement bounded async clock, timeout, and fake process helpers in HermesMacOSTest/Support/HermesAsyncTestSupport.swift
- [x] T010 Implement shared redaction, secret-leak, and failure-message assertions in HermesMacOSTest/Support/HermesTestAssertions.swift
- [x] T011 [P] Add dashboard HTML and dashboard API fixtures in HermesMacOSTest/Fixtures/Dashboard/dashboard-fixtures.json
- [x] T012 [P] Add Hermes API profile, approval, response, and chat fixtures in HermesMacOSTest/Fixtures/HermesAPI/api-fixtures.json
- [x] T013 [P] Add SSE and TUI Gateway event stream fixtures in HermesMacOSTest/Fixtures/Streams/stream-fixtures.ndjson
- [x] T014 [P] Add local runtime YAML and profile fixtures in HermesMacOSTest/Fixtures/LocalRuntime/runtime-fixtures.yaml
- [x] T015 [P] Add fake secret, fake token, and TLS fingerprint fixtures in HermesMacOSTest/Fixtures/Security/security-fixtures.json
- [x] T016 [P] Extract or expose minimal request, stream, and attachment seams for tests in HermesMacOS/HermesModelsAPI.swift
- [x] T017 [P] Extract or expose minimal TUI Gateway event parsing seams for tests in HermesMacOS/HermesTUIGatewayView.swift
- [x] T018 [P] Extract or expose minimal dashboard token, redaction, and security seams for tests in HermesMacOS/HermesSecurityUtilities.swift

**Checkpoint**: Test harness and fixtures are ready; user-story implementation can begin.

---

## Phase 3: User Story 1 - Run a native test target for the app (Priority: P1) MVP

**Goal**: `HermesMacOSTest` appears in Xcode and command-line workflows, builds against HermesMacOS, and executes a minimal deterministic smoke test.

**Independent Test**: Run `xcodegen generate`, inspect `xcodebuild -list -project HermesMacOS.xcodeproj`, build `HermesMacOS`, and run `HermesMacOSTest` using the command in `specs/013-hermesmacos-test-target/quickstart.md`.

### Tests for User Story 1

- [x] T019 [P] [US1] Add target discovery and smoke execution tests in HermesMacOSTest/Functional/HermesMacOSTestTargetTests.swift
- [x] T020 [P] [US1] Add command-contract assertions for build and test command strings in HermesMacOSTest/Technical/BuildCommandContractTests.swift

### Implementation for User Story 1

- [x] T021 [US1] Regenerate and check in the Xcode project changes in HermesMacOS.xcodeproj/project.pbxproj
- [x] T022 [US1] Document `HermesMacOSTest` build and test commands in docs/codebase/TESTING.md
- [x] T023 [US1] Verify target listing, app build, and minimal test run using specs/013-hermesmacos-test-target/quickstart.md

**Checkpoint**: The MVP test target is discoverable and runnable independently.

---

## Phase 4: User Story 2 - Cover every user-facing HermesMacOS workflow (Priority: P1)

**Goal**: Functional tests and a coverage map account for every documented tab, Settings surface, integration panel, utility, and live-smoke-only category.

**Independent Test**: Run functional suites and compare `HermesMacOSTest/Coverage/HermesMacOSTestCoverageMap.swift` against `specs/013-hermesmacos-test-target/contracts/test-coverage-contract.md`.

### Tests for User Story 2

- [x] T024 [P] [US2] Create complete functional coverage inventory in HermesMacOSTest/Coverage/HermesMacOSTestCoverageMap.swift
- [x] T025 [P] [US2] Add app shell, tab navigation, window state, and Settings tests in HermesMacOSTest/Functional/AppShellAndSettingsTests.swift
- [x] T026 [P] [US2] Add Ask Hermes profile, streaming, attachment, cancellation, continuation, and history tests in HermesMacOSTest/Functional/AskHermesWorkflowTests.swift
- [x] T027 [P] [US2] Add Chat with Hermes system prompt, streaming, attachment, cancellation, continuation, and history tests in HermesMacOSTest/Functional/ChatHermesWorkflowTests.swift
- [x] T028 [P] [US2] Add TUI Gateway workspace, prompt, attachment, request bubble, interrupt, resume, and malformed event tests in HermesMacOSTest/Functional/TUIGatewayWorkflowTests.swift
- [x] T029 [P] [US2] Add dashboard-backed history, sessions, skills, schedules, plugins, toolsets, MCP server, raw config, token refresh, and error tests in HermesMacOSTest/Functional/DashboardBackedWorkflowTests.swift
- [x] T030 [P] [US2] Add approvals and Kanban loading, mutation, live update, and unavailable-state tests in HermesMacOSTest/Functional/ApprovalsAndKanbanWorkflowTests.swift
- [x] T031 [P] [US2] Add local profiles, model settings, MCP YAML, Hermes CLI, repository preview, dirty-state, Git, and SSH fixture tests in HermesMacOSTest/Functional/LocalRuntimeWorkflowTests.swift
- [x] T032 [P] [US2] Add clipboard retention, message retention, raw debug, knowledge eraser, speech-to-text, and reachability tests in HermesMacOSTest/Functional/UtilitiesWorkflowTests.swift
- [x] T033 [P] [US2] Add localization and accessibility label smoke tests in HermesMacOSTest/Functional/LocalizationAndAccessibilityTests.swift

### Implementation for User Story 2

- [x] T034 [US2] Add coverage-map consistency checks against the contract in HermesMacOSTest/Coverage/HermesMacOSTestCoverageMapTests.swift

**Checkpoint**: Functional coverage accounts for the complete documented app surface.

---

## Phase 5: User Story 3 - Protect technical contracts and security guardrails (Priority: P2)

**Goal**: Focused technical tests protect request construction, parsers, storage, redaction, endpoint policy, TLS, filesystem/process guardrails, and async cleanup.

**Independent Test**: Run technical suites and confirm failures name the broken route, helper, fixture, or security guardrail.

### Tests for User Story 3

- [x] T035 [P] [US3] Add endpoint normalization, URL construction, Hermes headers, cancellation ID, session continuation, token, and error classification tests in HermesMacOSTest/Technical/EndpointAndRequestContractTests.swift
- [x] T036 [P] [US3] Add Responses SSE, Chat streaming, dashboard token HTML, and TUI Gateway WebSocket event parser tests in HermesMacOSTest/Technical/StreamingAndGatewayEventTests.swift
- [x] T037 [P] [US3] Add attachment MIME, size, count, payload encoding, unsupported input, and oversized input tests in HermesMacOSTest/Technical/AttachmentPayloadTests.swift
- [x] T038 [P] [US3] Add YAML and raw configuration mutation preservation tests in HermesMacOSTest/Technical/YAMLConfigurationMutationTests.swift
- [x] T039 [P] [US3] Add sensitive URL, redaction, Keychain label, encrypted retention, TLS pin, filesystem approval, process, and SSH cleanup tests in HermesMacOSTest/Technical/SecurityGuardrailTests.swift
- [x] T040 [P] [US3] Add timeout, retry, cancellation, polling, auto-refresh, clipboard monitoring, speech cleanup, and repository-operation lifecycle tests in HermesMacOSTest/Technical/AsyncLifecycleTests.swift
- [x] T041 [P] [US3] Add retained prompt, response, and clipboard encryption and clear-path tests in HermesMacOSTest/Technical/RetentionAndKeychainContractTests.swift
- [x] T042 [P] [US3] Add failure-output redaction regression tests in HermesMacOSTest/Technical/FailureRedactionTests.swift

### Implementation for User Story 3

- [x] T043 [US3] Harden any security helper behavior revealed by failing tests in HermesMacOS/HermesSecurityUtilities.swift
- [x] T044 [US3] Harden any request, stream, or attachment contract behavior revealed by failing tests in HermesMacOS/HermesModelsAPI.swift

**Checkpoint**: High-impact technical contracts and unsandboxed-app guardrails are protected.

---

## Phase 6: User Story 4 - Keep tests maintainable as HermesMacOS evolves (Priority: P3)

**Goal**: Future contributors can add tests using documented naming, fixture, live-smoke, and coverage-map conventions.

**Independent Test**: Add or review a representative new-feature example and confirm the coverage verifier identifies its expected suite location.

### Tests for User Story 4

- [x] T045 [P] [US4] Add live-smoke skip behavior tests in HermesMacOSTest/LiveSmoke/LiveSmokeSkipTests.swift
- [x] T046 [P] [US4] Add coverage-contract verifier tests in HermesMacOSTest/Coverage/HermesCoverageContractVerifierTests.swift

### Implementation for User Story 4

- [x] T047 [P] [US4] Document test naming, fixture, and coverage conventions in HermesMacOSTest/README.md
- [x] T048 [P] [US4] Add a new-feature test template guide in HermesMacOSTest/Support/NewFeatureTestTemplate.md
- [x] T049 [US4] Update maintainer testing guidance and live-smoke skip policy in docs/codebase/TESTING.md

**Checkpoint**: The test suite has maintainable extension points for future HermesMacOS features.

---

## Phase N: Polish & Cross-Cutting Concerns

**Purpose**: Final verification, documentation, and security review across the completed feature.

- [x] T050 Run `xcodegen generate` from ./project.yml and inspect generated membership in HermesMacOS.xcodeproj/project.pbxproj
- [x] T051 Build the app target with the command documented in specs/013-hermesmacos-test-target/quickstart.md
- [x] T052 Run the `HermesMacOSTest` suite with the command documented in specs/013-hermesmacos-test-target/quickstart.md
- [x] T053 [P] Update repository-level test instructions in ./README.md
- [x] T054 [P] Review final security expectations and secret-redaction notes in ./SECURITY.md
- [x] T055 [P] Validate that coverage categories match specs/013-hermesmacos-test-target/contracts/test-coverage-contract.md
- [x] T056 [P] Record final implementation evidence and optional live-smoke results in docs/codebase/TESTING.md

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 Setup**: No dependencies; start immediately.
- **Phase 2 Foundational**: Depends on Phase 1; blocks all story phases.
- **Phase 3 User Story 1**: Depends on Phase 2; delivers the MVP runnable test target.
- **Phase 4 User Story 2**: Depends on Phase 3 because functional suites require the runnable target.
- **Phase 5 User Story 3**: Depends on Phase 3 because technical suites require the runnable target; can run in parallel with Phase 4 after target MVP is stable.
- **Phase 6 User Story 4**: Depends on Phases 4 and 5 because maintainability guidance must reflect final suite organization.
- **Polish**: Depends on selected story phases and must run before completion.

### User Story Dependencies

- **US1 (P1)**: No dependency on other stories after foundation; MVP scope.
- **US2 (P1)**: Depends on US1 target availability; independently validates user-facing functional scope.
- **US3 (P2)**: Depends on US1 target availability; independently validates technical and security scope.
- **US4 (P3)**: Depends on US2 and US3 suite layout; independently validates maintainability conventions.

### Within Each User Story

- Write story tests first and verify they fail or are skipped for the expected missing implementation.
- Implement the minimal production seam only when a test cannot reach behavior safely.
- Run the story-specific suite before moving to the next phase.

---

## Parallel Execution Examples

### User Story 1

```bash
Task: "T019 Add target discovery and smoke execution tests in HermesMacOSTest/Functional/HermesMacOSTestTargetTests.swift"
Task: "T020 Add command-contract assertions in HermesMacOSTest/Technical/BuildCommandContractTests.swift"
```

### User Story 2

```bash
Task: "T025 Add app shell and Settings tests in HermesMacOSTest/Functional/AppShellAndSettingsTests.swift"
Task: "T026 Add Ask Hermes tests in HermesMacOSTest/Functional/AskHermesWorkflowTests.swift"
Task: "T027 Add Chat with Hermes tests in HermesMacOSTest/Functional/ChatHermesWorkflowTests.swift"
Task: "T028 Add TUI Gateway tests in HermesMacOSTest/Functional/TUIGatewayWorkflowTests.swift"
Task: "T029 Add dashboard-backed workflow tests in HermesMacOSTest/Functional/DashboardBackedWorkflowTests.swift"
```

### User Story 3

```bash
Task: "T035 Add endpoint and request contract tests in HermesMacOSTest/Technical/EndpointAndRequestContractTests.swift"
Task: "T036 Add streaming and gateway event tests in HermesMacOSTest/Technical/StreamingAndGatewayEventTests.swift"
Task: "T039 Add security guardrail tests in HermesMacOSTest/Technical/SecurityGuardrailTests.swift"
Task: "T040 Add async lifecycle tests in HermesMacOSTest/Technical/AsyncLifecycleTests.swift"
```

### User Story 4

```bash
Task: "T045 Add live-smoke skip tests in HermesMacOSTest/LiveSmoke/LiveSmokeSkipTests.swift"
Task: "T047 Document conventions in HermesMacOSTest/README.md"
Task: "T048 Add new-feature template guide in HermesMacOSTest/Support/NewFeatureTestTemplate.md"
```

---

## Implementation Strategy

### MVP First: User Story 1 Only

1. Complete Phase 1 and Phase 2.
2. Complete Phase 3.
3. Stop and validate with `xcodebuild -list`, app build, and the minimal `HermesMacOSTest` run from `specs/013-hermesmacos-test-target/quickstart.md`.

### Incremental Delivery

1. Add runnable target and smoke test through US1.
2. Add complete functional coverage through US2.
3. Add technical and security guardrail coverage through US3.
4. Add maintainability conventions through US4.
5. Finish with full build, test, docs, and security evidence.

### Parallel Team Strategy

- One engineer can own `./project.yml` and `HermesMacOS.xcodeproj/project.pbxproj` sequencing.
- Functional tests in `HermesMacOSTest/Functional/` can be split by workflow after support fixtures exist.
- Technical tests in `HermesMacOSTest/Technical/` can run in parallel by contract category after support fixtures exist.
- Documentation and live-smoke guidance can be finalized after the suite layout stabilizes.
