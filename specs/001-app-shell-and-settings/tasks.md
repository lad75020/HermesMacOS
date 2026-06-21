# Tasks: App Shell and Settings

**Input**: Design documents from `/specs/001-app-shell-and-settings/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/app-shell-settings-contract.md, quickstart.md

**Tests**: The repository currently has no dedicated automated test target. Validation tasks use source inspection, contract checks, and an Xcode build.

**Organization**: Tasks are grouped by user story to enable independent implementation and verification.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3, US4)
- Each task names exact repository paths

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Verify the project and feature scaffolding needed for implementation work.

- [x] T001 Verify Xcode project configuration for the macOS app shell target in ./project.yml
- [x] T002 Verify generated scheme availability for the shell build in HermesMacOS.xcodeproj/xcshareddata/xcschemes/HermesMacOS.xcscheme
- [x] T003 [P] Verify feature specification artifacts exist in specs/001-app-shell-and-settings/spec.md and specs/001-app-shell-and-settings/plan.md
- [x] T004 [P] Verify app entitlements remain aligned with shell and Settings capabilities in HermesMacOS/HermesMacOS.entitlements

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Confirm shared shell, endpoint, security, and reachability infrastructure before story-level validation.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [x] T005 Verify app startup and root-view composition paths in HermesMacOS/HermesMacOSApp.swift
- [x] T006 Verify shared tab, workspace, and window state composition in HermesMacOS/ContentView.swift
- [x] T007 [P] Verify endpoint model and per-window connection helpers in HermesMacOS/HermesModelsAPI.swift
- [x] T008 [P] Verify secret, approval, and endpoint security helpers used by Settings in HermesMacOS/HermesSecurityUtilities.swift
- [x] T009 [P] Verify reachability polling states and default endpoint handling in HermesMacOS/HermesReachabilityMonitor.swift

**Checkpoint**: Foundation ready - user story verification can now proceed.

---

## Phase 3: User Story 1 - Launch into the Hermes control surface (Priority: P1) 🎯 MVP

**Goal**: The app launches into a stable shell, restores valid startup state, and shows a safe failure state when startup secrets cannot unlock.

**Independent Test**: Launch/read startup paths and verify valid default/restored shell states and unlock failure handling.

### Implementation for User Story 1

- [x] T010 [US1] Verify startup unlock and fallback behavior in HermesMacOS/HermesMacOSApp.swift
- [x] T011 [US1] Verify persisted startup value loading and default tab fallback in HermesMacOS/ContentView.swift
- [x] T012 [US1] Verify app identity and startup settings from ./project.yml align with specs/001-app-shell-and-settings/spec.md

**Checkpoint**: User Story 1 is verified independently.

---

## Phase 4: User Story 2 - Navigate between Hermes workflows (Priority: P2)

**Goal**: Users can switch tabs and manage workspaces while preserving valid workflow state and attention indicators.

**Independent Test**: Inspect and exercise tab/workspace selection paths for state preservation and valid fallbacks.

### Implementation for User Story 2

- [x] T013 [US2] Verify top-level tab definitions and navigation routing in HermesMacOS/ContentView.swift
- [x] T014 [US2] Verify Ask workspace creation, selection, deletion, and fallback paths in HermesMacOS/ContentView.swift
- [x] T015 [US2] Verify TUI workspace creation, selection, deletion, and fallback paths in HermesMacOS/ContentView.swift
- [x] T016 [US2] Verify background attention and blink state behavior in HermesMacOS/ContentView.swift

**Checkpoint**: User Story 2 is verified independently.

---

## Phase 5: User Story 3 - Configure endpoint and preference defaults (Priority: P3)

**Goal**: Users can manage selected-window endpoints, saved endpoint pairs, security-facing settings, folder access, theme, language, and fonts.

**Independent Test**: Inspect Settings persistence and selected-window application paths for endpoint and preference changes.

### Implementation for User Story 3

- [x] T017 [US3] Verify Settings load, apply, save, and remove flows in HermesMacOS/SettingsView.swift
- [x] T018 [US3] Verify saved endpoint pair application and selected-window isolation in HermesMacOS/SettingsView.swift
- [x] T019 [US3] Verify SSH credential, folder access, and self-signed certificate controls route through shared helpers in HermesMacOS/SettingsView.swift and HermesMacOS/HermesSecurityUtilities.swift
- [x] T020 [US3] Verify theme, language, and font preference persistence in HermesMacOS/SettingsView.swift

**Checkpoint**: User Story 3 is verified independently.

---

## Phase 6: User Story 4 - Understand service reachability (Priority: P4)

**Goal**: Users can see API and dashboard availability without blocking local navigation.

**Independent Test**: Inspect reachability monitor and shell indicator paths for current endpoint usage and non-blocking updates.

### Implementation for User Story 4

- [x] T021 [US4] Verify API and dashboard reachability loops in HermesMacOS/HermesReachabilityMonitor.swift
- [x] T022 [US4] Verify reachability indicator rendering and non-blocking shell behavior in HermesMacOS/ContentView.swift
- [x] T023 [US4] Verify Settings endpoint changes feed reachability checks through selected-window state in HermesMacOS/SettingsView.swift and HermesMacOS/ContentView.swift

**Checkpoint**: User Story 4 is verified independently.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Validate contracts, documentation, and build readiness across all stories.

- [x] T024 [P] Validate shell and Settings behavior contract in specs/001-app-shell-and-settings/contracts/app-shell-settings-contract.md
- [x] T025 [P] Validate manual smoke scenario coverage in specs/001-app-shell-and-settings/quickstart.md
- [x] T026 Verify README shell and Settings description remains aligned with README.md
- [x] T027 Run macOS build validation for HermesMacOS.xcodeproj/project.pbxproj
- [x] T028 Record implementation evidence and mark completed checklist items in specs/001-app-shell-and-settings/tasks.md

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately.
- **Foundational (Phase 2)**: Depends on Setup completion - blocks all user stories.
- **User Stories (Phase 3+)**: Depend on Foundational completion; execute P1 through P4 for clear validation order.
- **Polish (Phase 7)**: Depends on all selected user stories being complete.

### User Story Dependencies

- **User Story 1 (P1)**: Depends on foundational app/root-view inspection only.
- **User Story 2 (P2)**: Depends on shell composition from User Story 1 but can be verified without Settings changes.
- **User Story 3 (P3)**: Depends on endpoint/window model verification from foundational tasks.
- **User Story 4 (P4)**: Depends on endpoint state from User Story 3 and reachability monitor verification.

### Parallel Opportunities

- T003 and T004 can run in parallel after T001/T002 start.
- T007, T008, and T009 can run in parallel because they inspect different support files.
- T024 and T025 can run in parallel during polish because they validate different feature documents.

---

## Parallel Example: Foundational Support Files

```bash
Task: "Verify endpoint model and per-window connection helpers in HermesMacOS/HermesModelsAPI.swift"
Task: "Verify secret, approval, and endpoint security helpers used by Settings in HermesMacOS/HermesSecurityUtilities.swift"
Task: "Verify reachability polling states and default endpoint handling in HermesMacOS/HermesReachabilityMonitor.swift"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup.
2. Complete Phase 2: Foundational verification.
3. Complete Phase 3: User Story 1.
4. Validate launch/root-shell behavior independently.

### Incremental Delivery

1. Verify launch shell and startup fallback.
2. Verify navigation/workspace behavior.
3. Verify Settings endpoint and preference behavior.
4. Verify reachability indicators.
5. Run contract, quickstart, README, and Xcode build validation.


---

## Implementation Evidence

- T001-T026 validated by static/source checks against project.yml, HermesMacOSApp.swift, ContentView.swift, SettingsView.swift, HermesReachabilityMonitor.swift, HermesModelsAPI.swift, HermesSecurityUtilities.swift, README.md, and this feature's Spec Kit artifacts.
- Implemented a reachability gap discovered during T023: HermesReachabilityMonitor now checks configured selected-window API/dashboard endpoints instead of only hardcoded localhost defaults, and it avoids sending API keys to remote plaintext HTTP endpoints.
- T027 build validation passed with `xcodebuild -project HermesMacOS.xcodeproj -scheme HermesMacOS -destination 'generic/platform=macOS' -derivedDataPath /tmp/HermesMacOSDerivedData build`.
- Build log: `/tmp/HermesMacOS-app-shell-build.log` contains `** BUILD SUCCEEDED **` and no compiler errors.
- T028 completed by recording this evidence and marking all tasks complete.
