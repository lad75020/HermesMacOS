# Tasks: Dashboard Configuration Management

**Input**: Design documents from `/specs/009-dashboard-configuration-management/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/dashboard-configuration-api.md, quickstart.md

## Phase 1: Setup
- [x] T001 Create feature artifact directory `specs/009-dashboard-configuration-management/`
- [x] T002 Write feature specification and plan artifacts
- [x] T003 Write research, data model, contract, quickstart, and tasks artifacts

## Phase 2: Foundational
- [x] T004 Confirm top-level Configuration view exists in `HermesMacOS/HermesConfigurationView.swift`
- [x] T005 Confirm dashboard/local configuration section and store files exist

## Phase 3: User Story 1 - Refresh and inspect configuration sections (Priority: P1) 🎯 MVP
- [x] T006 [US1] Trace top-level refresh orchestration and section rendering

## Phase 4: User Story 2 - Manage dashboard resources (Priority: P2)
- [x] T007 [US2] Trace supported resource filters and actions through stores/sections

## Phase 5: User Story 3 - Preserve safety and usability (Priority: P3)
- [x] T008 [US3] Trace AppStorage disclosure, validation messages, and delete confirmation

## Phase 6: Polish & Cross-Cutting Concerns
- [x] T009 Run XcodeMCP build for the `HermesMacOS` scheme
- [x] T010 Run ad-hoc artifact verification for queue/spec/task structure and referenced paths
- [ ] T011 Perform dashboard/local configuration smoke checks from `specs/009-dashboard-configuration-management/quickstart.md` when services are available
