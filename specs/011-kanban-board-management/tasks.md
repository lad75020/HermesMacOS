# Tasks: Kanban Board Management

**Input**: Design documents from `/specs/011-kanban-board-management/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/kanban-api.md, quickstart.md

## Phase 1: Setup
- [x] T001 Create feature artifact directory `specs/011-kanban-board-management/`
- [x] T002 Write feature specification and plan artifacts
- [x] T003 Write research, data model, contract, quickstart, and tasks artifacts

## Phase 2: Foundational
- [x] T004 Confirm Kanban implementation exists in `HermesMacOS/HermesKanbanView.swift`
- [x] T005 Confirm app surface docs mention Kanban behavior

## Phase 3: User Story 1 - View boards, columns, and tasks (Priority: P1) 🎯 MVP
- [x] T006 [US1] Trace board/column/task/profile model decoding

## Phase 4: User Story 2 - Manage tasks, comments, and actions (Priority: P2)
- [x] T007 [US2] Trace task operations, comments/logs/actions behavior

## Phase 5: User Story 3 - Dispatch work with profiles and live updates (Priority: P3)
- [x] T008 [US3] Trace dispatch/profile/run/failure behavior

## Phase 6: Polish & Cross-Cutting Concerns
- [x] T009 Run XcodeMCP build for the `HermesMacOS` scheme
- [x] T010 Run ad-hoc artifact verification for queue/spec/task structure and referenced paths
- [ ] T011 Perform Kanban dashboard smoke checks from `specs/011-kanban-board-management/quickstart.md` when safe
