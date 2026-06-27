# Tasks: History and Session Resume

**Propagated**: 2026-06-27 — Updated from spec.md refinement for Sessions-tab local_memory persistence.

**Input**: Design documents from `/specs/006-history-sessions-resume/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/dashboard-history-sessions-api.md, quickstart.md

**Tests/Verification**: Build verification, focused ad-hoc local_memory idempotency verification, and live dashboard/manual smoke checks are mandatory. Automated dashboard API fixture tests should be added when a test target exists.

## Phase 1: Setup (Shared Infrastructure)

- [x] T001 Create feature artifact directory `specs/006-history-sessions-resume/`
- [x] T002 Write feature specification in `specs/006-history-sessions-resume/spec.md`
- [x] T003 Write implementation plan and research in `specs/006-history-sessions-resume/plan.md` and `specs/006-history-sessions-resume/research.md`
- [x] T004 Write design artifacts in `specs/006-history-sessions-resume/data-model.md`, `specs/006-history-sessions-resume/contracts/dashboard-history-sessions-api.md`, and `specs/006-history-sessions-resume/quickstart.md`

## Phase 2: Foundational (Blocking Prerequisites)

- [x] T005 Confirm History search UI exists in `HermesMacOS/HermesHistoryView.swift`
- [x] T006 Confirm dashboard search/session models exist in `HermesMacOS/HermesDashboardHistorySearch.swift`
- [x] T007 Confirm dashboard API/storage reference exists in `docs/reference-api-and-storage.md`

## Phase 3: User Story 1 - Search dashboard conversation history (Priority: P1) 🎯 MVP

- [x] T008 [US1] Trace search request, token refresh retry, cancellation, counts, and profile filtering in `HermesMacOS/HermesDashboardHistorySearch.swift`
- [x] T009 [US1] Trace History query/profile/result UI in `HermesMacOS/HermesHistoryView.swift`
- [x] T010 [US1] Document search smoke checks in `specs/006-history-sessions-resume/quickstart.md`

## Phase 4: User Story 2 - Inspect and resume a search result (Priority: P2)

- [x] T011 [US2] Trace result disclosure, message display, and Ask/Chat/TUI resume callbacks in `HermesMacOS/HermesHistoryView.swift`
- [x] T012 [US2] Document result inspection and resume smoke checks in `specs/006-history-sessions-resume/quickstart.md`

## Phase 5: User Story 3 - Browse stored sessions with pagination and details (Priority: P3)

- [x] T013 [US3] Trace session pagination, non-cron filtering, ordering, detail loading, and detail caching in `HermesMacOS/HermesHistoryView.swift`
- [x] T014 [US3] Document Sessions browse/detail/resume smoke checks in `specs/006-history-sessions-resume/quickstart.md`

## Phase 5A: User Story 3 refinement - Persist sessions to local_memory (Priority: P3)

- [x] T018 [US3] Add a per-session Sessions-tab button and per-row storing/stored/error state in `HermesMacOS/HermesHistoryView.swift`
- [x] T019 [US3] Build a user/assistant-only local_memory persistence payload from cached or lazy-loaded session messages in `HermesMacOS/HermesHistoryView.swift`
- [x] T020 [US3] Check the local_memory raw-turn idempotency key before syncing so repeat actions report already stored instead of inserting duplicates in `HermesMacOS/HermesHistoryView.swift`
- [x] T021 [US3] Verify the embedded local_memory helper with focused ad-hoc duplicate-prevention coverage

## Phase 6: Polish & Cross-Cutting Concerns

- [x] T015 Run XcodeMCP build for the `HermesMacOS` scheme
- [x] T016 Run ad-hoc artifact verification for queue/spec/task structure and referenced paths
- [ ] T017 Perform live dashboard smoke checks from `specs/006-history-sessions-resume/quickstart.md` when a reachable Hermes Dashboard with history data is available

## Dependencies & Execution Order

- Phase 1 creates traceability artifacts.
- Phase 2 confirms implementation anchors.
- US1 is the MVP and should be validated before result resume or Sessions browse flows.
- Phase 5A depends on Phase 5 because local_memory persistence reuses lazy-loaded session messages and per-session detail cache state.
- Phase 6 verification must run before marking the queue feature complete.
