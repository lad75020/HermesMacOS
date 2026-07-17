# Tasks: TUI Gateway Workspaces

**Input**: Design documents from `/specs/005-tui-gateway-workspaces/`

**Propagated**: 2026-07-17 — Updated from spec.md refinement

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/tui-gateway-json-rpc.md, quickstart.md

## Phase 1: Setup
- [x] T001 Create feature artifact directory `specs/005-tui-gateway-workspaces/`
- [x] T002 Write feature specification and plan artifacts
- [x] T003 Write research, data model, contract, quickstart, and tasks artifacts

## Phase 2: Foundational
- [x] T004 Confirm TUI Gateway implementation exists in `HermesMacOS/HermesTUIGatewayView.swift`
- [x] T005 Confirm WebSocket reference exists in `docs/reference-tui-gateway-websocket.md`
- [x] T006 Confirm user guide exists in `docs/how-to-use-tui-gateway.md`

## Phase 3: User Story 1 - Connect to the live TUI Gateway (Priority: P1) 🎯 MVP
- [x] T007 [US1] Trace WebSocket/token/ticket/session.create setup in source/docs

## Phase 4: User Story 2 - Send prompts, attachments, and receive streamed events (Priority: P2)
- [x] T008 [US2] Trace prompt.submit, input.detect_drop, and event rendering in source/docs

## Phase 5: User Story 3 - Manage multiple TUI workspaces and sessions (Priority: P3)
- [x] T009 [US3] Trace workspace isolation, activate, close, interrupt, and resume flows in source/docs

## Phase 6: User Story 4 - Respond to live gateway requests (Priority: P4)
- [x] T010 [US4] Trace approval/clarify/sudo/secret request-response bubbles in source/docs

## Phase 7: Polish & Cross-Cutting Concerns
- [x] T011 Run XcodeMCP build for the `HermesMacOS` scheme
- [x] T012 Run ad-hoc artifact verification for queue/spec/task structure and referenced paths
- [ ] T013 Perform live TUI Gateway smoke checks from `specs/005-tui-gateway-workspaces/quickstart.md` when a reachable Hermes Dashboard is available

## Phase 8: Refined TUI Context and Reasoning Controls
- [x] T014 [US2] Parse positive integral `usage.context_used` and optional `context_max`/`context_percent` from `message.complete` and `session.info` in `HermesMacOS/HermesTUIGatewayView.swift` [(depends on T008)]
- [x] T015 [US2] Associate current-context usage with only the active/current-turn assistant bubble, preserve its final value, clear pending usage at session/turn boundaries, and omit cumulative-token fallback in `HermesMacOS/HermesTUIGatewayView.swift` [(depends on T014)]
- [x] T016 [P] [US2] Verify usage parsing, safe numeric conversion, session/turn isolation, in-place bubble updates, and compact accessibility formatting in `HermesMacOSTest/Functional/TUIGatewayWorkflowTests.swift` and `HermesMacOSTest/Technical/StreamingAndGatewayEventTests.swift` [(depends on T014, T015)]
- [x] T017 [US1] Decode selected-model FAST/reasoning capability metadata from `model.options`, prefer explicit model capability over profile fallback, and expose only canonical valid effort levels in `HermesMacOS/HermesTUIGatewayView.swift` and `HermesMacOS/HermesModelsAPI.swift` [(depends on T007)]
- [x] T018 [US3] Persist a valid selected reasoning effort per `HermesTUIWorkspace`, default replacement workspaces to `medium`, and disable reasoning controls for unsupported selected models in `HermesMacOS/ContentView.swift` and `HermesMacOS/HermesTUIGatewayView.swift` [(depends on T017)]
- [x] T019 [US1] Include supported `reasoning_effort` in `session.create` and forward-compatible `prompt.submit`, apply idle live changes through session-scoped `config.set` with key `reasoning`, and restore supported effort from session/resume info in `HermesMacOS/HermesTUIGatewayView.swift` [(depends on T017, T018)]
- [x] T020 [P] [US1] Verify canonical effort values, selected-model capability precedence, optional profile metadata, workspace copy/default behavior, and session-scoped reasoning payloads in `HermesMacOSTest/Functional/TUIGatewayWorkflowTests.swift` [(depends on T017, T018, T019)]
- [x] T021 [P] [US1] Update `docs/reference-tui-gateway-websocket.md` and `docs/how-to-use-tui-gateway.md` for `usage.context_used`, `reasoning_effort`, selected-model support, and `config.set` behavior [(depends on T015, T019)]

## Dependencies
- Phase 8 builds on the original US1/US2/US3 tracing in T007-T009 and does not block the environment-dependent live smoke check T013.
- T014 → T015 → T016 covers FR-009/SC-006; T017 → T018 → T019 → T020 covers FR-010/SC-007; T021 follows both implementation paths.
- T016 and T020 may run in parallel after their respective implementation dependencies; T021 may run alongside those focused tests.

## Requirement Traceability
| Requirement family | Tasks |
|---|---|
| FR-001–FR-008, FR-SEC, FR-INT | T004–T013 |
| FR-009 / SC-006 | T014–T016 |
| FR-010 / SC-007 | T017–T021 |
| SC-001–SC-005 | T007–T013 |
| SC-BUILD / SC-SMOKE | T011, T013 |
