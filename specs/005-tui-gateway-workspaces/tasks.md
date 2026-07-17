> ⚠️ **STALE**: spec.md was refined on 2026-07-17. Run `/speckit.refine.propagate` to update this plan.

# Tasks: TUI Gateway Workspaces

**Input**: Design documents from `/specs/005-tui-gateway-workspaces/`

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
