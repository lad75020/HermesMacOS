# Tasks: App Shell and Settings

**Input**: Design documents from `/specs/001-app-shell-settings/`
**Propagated**: 2026-08-20 — Added the memory/GPU sidebar-resource monitor work from the refined specification.

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/app-shell-settings.md, quickstart.md

**Tests/Verification**: XCTest coverage, build/test verification, and manual shell/resource-gauge smoke checks are mandatory. `HermesMacOSTest` is the repository's macOS unit-test target.

**Organization**: Tasks are grouped by user story so each story can be validated independently.

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Establish traceability for the existing app shell/settings feature.

- [x] T001 Create feature artifact directory `specs/001-app-shell-settings/`
- [x] T002 Write feature specification in `specs/001-app-shell-settings/spec.md`
- [x] T003 Write implementation plan and research artifacts in `specs/001-app-shell-settings/plan.md` and `specs/001-app-shell-settings/research.md`
- [x] T004 Write design artifacts in `specs/001-app-shell-settings/data-model.md`, `specs/001-app-shell-settings/contracts/app-shell-settings.md`, and `specs/001-app-shell-settings/quickstart.md`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Confirm the existing source files that form the app shell/settings feature remain in place.

- [x] T005 Confirm project target/app identity source exists in `project.yml`
- [x] T006 Confirm app entry point exists in `HermesMacOS/HermesMacOSApp.swift`
- [x] T007 Confirm main shell/tab composition exists in `HermesMacOS/ContentView.swift`
- [x] T008 Confirm Settings surface exists in `HermesMacOS/SettingsView.swift`
- [x] T009 Confirm typography, splash, localization, and entitlements resources exist in `HermesMacOS/HermesTypography.swift`, `HermesMacOS/SplashView.swift`, `HermesMacOS/Localizable.xcstrings`, and `HermesMacOS/HermesMacOS.entitlements`

**Checkpoint**: Existing source locations for shell/settings are present.

---

## Phase 3: User Story 1 - Launch into the native control surface (Priority: P1) 🎯 MVP

**Goal**: Users can launch HermesMacOS and reach the main tabbed control surface.

**Independent Test**: Build the scheme and manually launch/switch tabs.

- [x] T010 [US1] Verify `HermesMacOS/HermesMacOSApp.swift` owns the app scene and root view selection
- [x] T011 [US1] Verify `HermesMacOS/ContentView.swift` defines the side-tab shell and top-level destinations
- [x] T012 [US1] Document manual launch/tab smoke flow in `specs/001-app-shell-settings/quickstart.md`

**Checkpoint**: User Story 1 is documented and ready for build/manual verification.

---

## Phase 4: User Story 2 - Configure endpoint, appearance, and local app preferences (Priority: P2)

**Goal**: Users can configure endpoints, saved pairs, credentials, allowed folders, theme, language, and font sizing.

**Independent Test**: Open Settings, change non-sensitive values, close/reopen, and verify persistence.

- [x] T013 [US2] Verify `HermesMacOS/SettingsView.swift` is the settings surface for endpoints, credentials, folders, theme/language, and fonts
- [x] T014 [US2] Verify security-sensitive settings are represented by Keychain-backed helpers in `HermesMacOS/HermesModelsAPI.swift` and `HermesMacOS/HermesSecurityUtilities.swift`
- [x] T015 [US2] Document settings persistence smoke flow in `specs/001-app-shell-settings/quickstart.md`

**Checkpoint**: User Story 2 is documented and ready for manual verification.

---

## Phase 5: User Story 3 - Preserve localization, resources, and app identity (Priority: P3)

**Goal**: Users see native app identity, localized strings, custom typography, and splash behavior.

**Independent Test**: Build app and confirm resources/localization load without missing-resource failures.

- [x] T016 [US3] Verify app identity and permission strings are declared in `project.yml`
- [x] T017 [US3] Verify typography/splash resource entry points exist in `HermesMacOS/HermesTypography.swift` and `HermesMacOS/SplashView.swift`
- [x] T018 [US3] Verify localization resources exist in `HermesMacOS/Localizable.xcstrings`

**Checkpoint**: User Story 3 is documented and ready for build/manual verification.

---

## Phase 6: User Story 4 - Monitor local Mac resource use from navigation (Priority: P4)

**Goal**: Show validated, accessible Memory and GPU percentages in compact pie-chart-styled gauges at the bottom of the existing left navigation bar without degrading navigation responsiveness.

**Independent Test**: Run the `HermesMacOSTest` scheme with deterministic valid, malformed, out-of-range, and process-failure utility results; then launch the app and verify two gauges update from a live `GPUUsage` sample while tabs remain responsive.

- [X] T022 [US4] Add `HermesResourceUsageSnapshot` and a main-actor-owned `HermesResourceUsageMonitor` in `HermesMacOS/HermesResourceUsageMonitor.swift`; poll `/Volumes/WDBlack4TB/Code/NodeMLX/utils/GPUUsage` every five seconds, execute it without a shell or user arguments, bound its runtime, strictly parse `GPU Usage` and `Memory Usage`, validate finite `0...100` percentages, and expose only safe fresh/stale/unavailable state.
- [X] T023 [P] [US4] Add `HermesResourceUsageGauge` in `HermesMacOS/HermesResourceUsageGauge.swift` with a compact pie-chart-style fill, visible Memory/GPU label and percentage, unavailable/stale presentation, and dedicated localized accessibility label/value.
- [X] T024 [P] [US4] Add deterministic `HermesResourceUsageMonitorTests` in `HermesMacOSTest/Technical/HermesResourceUsageMonitorTests.swift` for valid parsing, decimal values, malformed/missing/out-of-range values, unsuccessful/timed-out utility execution, and cancellation without leaking raw process output.
- [X] T025 [US4] Integrate one monitor and both gauges into `HermesSideTabSwitcher` in `HermesMacOS/ContentView.swift`, placing them below the tab controls after its spacer and using lifecycle-bound tasks so polling cancels when the switcher disappears.
- [X] T026 [US4] Add the Memory, GPU, unavailable/stale, and accessibility-facing strings to `HermesMacOS/Localizable.xcstrings`; extend `HermesMacOSTest/Functional/LocalizationAndAccessibilityTests.swift` with the resource-gauge label/value contract.
- [ ] T027 [US4] Run `xcodebuild -project HermesMacOS.xcodeproj -scheme HermesMacOSTest -destination 'platform=macOS' test`, then manually confirm a live `GPUUsage` sample updates both bottom-sidebar gauges and that forced utility failure leaves side-tab selection responsive.

**Checkpoint**: User Story 4 satisfies FR-009 through FR-013 and SC-006 through SC-007 without changing top-level navigation behavior.

**Requirement Traceability**:
- **FR-009**: T023 and T025
- **FR-010**: T022 and T024
- **FR-011**: T022, T023, and T024
- **FR-012**: T022, T024, and T025
- **FR-013**: T022, T024, and T027

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Preserve prior shell/settings verification and complete the final manual smoke journey after the resource-gauge work.

- [x] T019 Run XcodeMCP build for the `HermesMacOS` scheme
- [x] T020 Run ad-hoc artifact verification for queue/spec/task structure and referenced paths
- [ ] T021 Perform manual shell/settings smoke checks from `specs/001-app-shell-settings/quickstart.md` when a GUI session is available

---

## Dependencies & Execution Order

- Phase 1 must complete before generated artifacts can be reviewed.
- Phase 2 confirms the existing implementation anchors all user stories.
- User Story 1 is the MVP and should be validated before relying on Settings or resource-specific behavior.
- User Stories 2 and 3 can be reviewed independently after the foundational source files are confirmed.
- User Story 4 can start after Phase 2; T022/T023/T024 can proceed in parallel, while T025 depends on T022 and T023 and T026 depends on T023.
- T027 follows T022-T026. Phase 7's final manual smoke check must include the resource gauges before marking the Time Machine queue feature complete.

## Parallel Opportunities

- T005-T009 can be checked in parallel because they reference different files.
- T010-T018 are read-only traceability checks and can be reviewed in parallel.
- T019 and T020 can run independently; T021 requires a GUI-capable manual session.
- T022, T023, and T024 can run in parallel. T025 and T026 follow their respective monitor/gauge prerequisites; T027 is the converging verification step.
