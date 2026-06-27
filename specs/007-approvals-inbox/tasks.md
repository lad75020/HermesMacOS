# Tasks: Approvals Inbox

**Input**: Design documents from `/specs/007-approvals-inbox/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/approvals-api.md, quickstart.md

**Tests/Verification**: Build verification and live/local smoke checks are mandatory. Automated approval API fixture tests should be added when a test target exists.

## Phase 1: Setup (Shared Infrastructure)

- [x] T001 Create feature artifact directory `specs/007-approvals-inbox/`
- [x] T002 Write feature specification in `specs/007-approvals-inbox/spec.md`
- [x] T003 Write implementation plan and research in `specs/007-approvals-inbox/plan.md` and `specs/007-approvals-inbox/research.md`
- [x] T004 Write design artifacts in `specs/007-approvals-inbox/data-model.md`, `specs/007-approvals-inbox/contracts/approvals-api.md`, and `specs/007-approvals-inbox/quickstart.md`

## Phase 2: Foundational (Blocking Prerequisites)

- [x] T005 Confirm Approvals Inbox UI/store exists in `HermesMacOS/HermesApprovalsInboxView.swift`
- [x] T006 Confirm approvals endpoint URLs exist in `HermesMacOS/HermesModelsAPI.swift`
- [x] T007 Confirm endpoint security/local approval helpers exist in `HermesMacOS/HermesSecurityUtilities.swift`

## Phase 3: User Story 1 - Review pending approvals (Priority: P1) 🎯 MVP

- [x] T008 [US1] Trace remote fetch, local fallback, merge/sort, status, and count behavior in `HermesMacOS/HermesApprovalsInboxView.swift`
- [x] T009 [US1] Document review smoke checks in `specs/007-approvals-inbox/quickstart.md`

## Phase 4: User Story 2 - Resolve remote and local approvals (Priority: P2)

- [x] T010 [US2] Trace remote resolve body/API behavior and local resolve routing in `HermesMacOS/HermesApprovalsInboxView.swift`
- [x] T011 [US2] Trace duplicate resolve guard behavior in `HermesMacOS/HermesApprovalsInboxView.swift`
- [x] T012 [US2] Document resolve smoke checks in `specs/007-approvals-inbox/quickstart.md`

## Phase 5: User Story 3 - Keep the inbox current and secure (Priority: P3)

- [x] T013 [US3] Trace auto-refresh loop, sensitive URL validation, and JSON response validation in source
- [x] T014 [US3] Document auto-refresh/security smoke checks in `specs/007-approvals-inbox/quickstart.md`

## Phase 6: Polish & Cross-Cutting Concerns

- [x] T015 Run XcodeMCP build for the `HermesMacOS` scheme
- [x] T016 Run ad-hoc artifact verification for queue/spec/task structure and referenced paths
- [ ] T017 Perform live/local approvals smoke checks from `specs/007-approvals-inbox/quickstart.md` when pending approvals are available

## Dependencies & Execution Order

- Phase 1 creates traceability artifacts.
- Phase 2 confirms implementation anchors.
- US1 is the MVP and should be validated before resolution/autorefresh checks.
- Phase 6 verification must run before marking the queue feature complete.
