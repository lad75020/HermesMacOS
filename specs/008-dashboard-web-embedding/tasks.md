# Tasks: Dashboard Web Embedding

**Input**: Design documents from `/specs/008-dashboard-web-embedding/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/dashboard-web-embedding.md, quickstart.md

## Phase 1: Setup
- [x] T001 Create feature artifact directory `specs/008-dashboard-web-embedding/`
- [x] T002 Write feature specification and plan artifacts
- [x] T003 Write research, data model, contract, quickstart, and tasks artifacts

## Phase 2: Foundational
- [x] T004 Confirm WebKit embed exists in `HermesMacOS/HermesDashboardWebView.swift`
- [x] T005 Confirm app surface docs describe dashboard embedding in `docs/reference-app-surface.md`

## Phase 3: User Story 1 - Load a dashboard page in native WebKit (Priority: P1) 🎯 MVP
- [x] T006 [US1] Trace URL normalization, empty state, and WebView load behavior

## Phase 4: User Story 2 - Apply native theme and reload behavior (Priority: P2)
- [x] T007 [US2] Trace theme query/script and reload token behavior

## Phase 5: User Story 3 - Keep embedded navigation secure and reusable (Priority: P3)
- [x] T008 [US3] Trace remote plaintext rejection, gestures, and store reuse

## Phase 6: Polish & Cross-Cutting Concerns
- [x] T009 Run XcodeMCP build for the `HermesMacOS` scheme
- [x] T010 Run ad-hoc artifact verification for queue/spec/task structure and referenced paths
- [ ] T011 Perform dashboard embed smoke checks from `specs/008-dashboard-web-embedding/quickstart.md` when a reachable dashboard is available
