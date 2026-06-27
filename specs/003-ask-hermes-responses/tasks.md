# Tasks: Ask Hermes Responses

**Input**: Design documents from `/specs/003-ask-hermes-responses/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/responses-api.md, quickstart.md

**Tests/Verification**: Build verification and live-service/manual smoke checks are mandatory. Automated endpoint/stream parser tests should be added when a test target exists.

## Phase 1: Setup (Shared Infrastructure)

- [x] T001 Create feature artifact directory `specs/003-ask-hermes-responses/`
- [x] T002 Write feature specification in `specs/003-ask-hermes-responses/spec.md`
- [x] T003 Write implementation plan and research in `specs/003-ask-hermes-responses/plan.md` and `specs/003-ask-hermes-responses/research.md`
- [x] T004 Write design artifacts in `specs/003-ask-hermes-responses/data-model.md`, `specs/003-ask-hermes-responses/contracts/responses-api.md`, and `specs/003-ask-hermes-responses/quickstart.md`

## Phase 2: Foundational (Blocking Prerequisites)

- [x] T005 Confirm Ask UI exists in `HermesMacOS/HermesViews.swift`
- [x] T006 Confirm Responses API models/session helpers exist in `HermesMacOS/HermesModelsAPI.swift`
- [x] T007 Confirm workspace shell exists in `HermesMacOS/HermesAskWorkspacesView.swift`
- [x] T008 Confirm usage documentation exists in `docs/how-to-use-ask-and-chat.md`

## Phase 3: User Story 1 - Send a prompt and receive a streamed Responses answer (Priority: P1) 🎯 MVP

- [x] T009 [US1] Trace streaming/non-streaming request behavior to `HermesResponsesSession` in `HermesMacOS/HermesModelsAPI.swift`
- [x] T010 [US1] Trace transcript/status rendering to `HermesResponsesConsoleView` in `HermesMacOS/HermesViews.swift`
- [x] T011 [US1] Document live prompt smoke check in `specs/003-ask-hermes-responses/quickstart.md`

## Phase 4: User Story 2 - Control profile, reasoning, cancellation, and continuation (Priority: P2)

- [x] T012 [US2] Trace profile/reasoning draft behavior in `HermesMacOS/HermesModelsAPI.swift` and `HermesMacOS/HermesViews.swift`
- [x] T013 [US2] Trace cancellation helper in `HermesMacOS/HermesModelsAPI.swift`
- [x] T014 [US2] Document cancel/continuation smoke checks in `specs/003-ask-hermes-responses/quickstart.md`

## Phase 5: User Story 3 - Use attachments and prompt assistance (Priority: P3)

- [x] T015 [US3] Trace attachment import/conversion behavior in `HermesMacOS/HermesViews.swift` and `HermesMacOS/HermesModelsAPI.swift`
- [x] T016 [US3] Document attachment smoke checks in `specs/003-ask-hermes-responses/quickstart.md`

## Phase 6: User Story 4 - Work across multiple independent Ask workspaces (Priority: P4)

- [x] T017 [US4] Trace workspace isolation in `HermesMacOS/HermesAskWorkspacesView.swift`
- [x] T018 [US4] Document workspace smoke checks in `specs/003-ask-hermes-responses/quickstart.md`

## Phase 7: Polish & Cross-Cutting Concerns

- [x] T019 Run XcodeMCP build for the `HermesMacOS` scheme
- [x] T020 Run ad-hoc artifact verification for queue/spec/task structure and referenced paths
- [ ] T021 Perform live Ask Hermes smoke checks from `specs/003-ask-hermes-responses/quickstart.md` when a reachable Hermes API gateway is available

## Dependencies & Execution Order

- Phase 1 creates traceability artifacts.
- Phase 2 confirms existing implementation anchors.
- US1 is the MVP and should be validated before relying on profile/cancel/attachment/workspace enhancements.
- Phase 7 verification must run before marking the queue feature complete.
