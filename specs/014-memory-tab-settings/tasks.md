# Tasks: Memory Tab and Tab Settings

**Input**: Design documents from `/specs/014-memory-tab-settings/`

**Prerequisites**: `specs/014-memory-tab-settings/plan.md`, `specs/014-memory-tab-settings/spec.md`, `specs/014-memory-tab-settings/research.md`, `specs/014-memory-tab-settings/data-model.md`, `specs/014-memory-tab-settings/contracts/memory-tab-ui-contract.md`, `specs/014-memory-tab-settings/quickstart.md`

**Tests/Verification**: Deterministic `HermesMacOSTest` coverage is required by the plan and contract before implementation tasks. Default tests must not require a live Hindsight provider. Build and test commands come from `specs/014-memory-tab-settings/quickstart.md`.

**Organization**: Tasks are grouped by user story so each story is independently implementable and testable.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel because it touches different files and has no dependency on another incomplete task in the same phase.
- **[Story]**: Maps to the user story from `specs/014-memory-tab-settings/spec.md`.
- Every task names an exact file path.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Prepare implementation surfaces and keep existing app/test structure visible.

- [x] T001 Inspect current tab enum, tab selection, and view composition in HermesMacOS/ContentView.swift before editing navigation behavior
- [x] T002 Inspect current Settings sections and app preference patterns in HermesMacOS/SettingsView.swift before adding tab visibility controls
- [x] T003 [P] Inspect current Hindsight provider helper patterns in HermesMacOS/HermesKnowledgeEraserUtility.swift before creating Memory provider helpers
- [x] T004 [P] Inspect current test coverage map categories in HermesMacOSTest/Coverage/HermesMacOSTestCoverageMap.swift before adding Memory and tab visibility coverage

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Shared types, provider boundary, and coverage registry that all Memory stories depend on.

**Critical**: Complete this phase before any user story implementation.

- [x] T005 [P] Add Memory coverage entries and tab visibility subcategory names in HermesMacOSTest/Coverage/HermesMacOSTestCoverageMap.swift
- [x] T006 [P] Add localized keys for Memory tab labels, pagination controls, empty states, delete confirmation, and Settings toggles in HermesMacOS/Localizable.xcstrings
- [x] T007 Create MemoryEntry, MemoryPage, MemoryListRequest, MemoryDeletionResult, and sanitized error value types in HermesMacOS/HermesHindsightMemoryClient.swift
- [x] T008 Define the HindsightMemoryProviding protocol and fixture-friendly client interface in HermesMacOS/HermesHindsightMemoryClient.swift
- [x] T009 Implement shared MemoryTabState defaults, page-size bounds, preview truncation, and metadata summary helpers in HermesMacOS/HermesMemoryStore.swift
- [x] T010 Add deterministic fixture data for Hindsight Memory rows and provider errors in HermesMacOSTest/Fixtures/HindsightMemoryFixtures.swift

**Checkpoint**: Foundation ready; user story phases can start.

---

## Phase 3: User Story 1 - Choose which prompt tabs are visible (Priority: P1) 🎯 MVP

**Goal**: Users can hide or restore Ask Hermes and Chat with Hermes independently from Settings without losing their in-memory prompt tab state.

**Independent Test**: Toggle Ask Hermes and Chat with Hermes visibility from Settings, verify side-tab entries update immediately, verify selection falls back when the selected tab is hidden, and verify toggles can restore both tabs without restart.

### Tests for User Story 1

- [x] T011 [P] [US1] Add tests for default Ask Hermes and Chat with Hermes visibility preferences in HermesMacOSTest/Functional/AppShellAndSettingsTests.swift
- [x] T012 [P] [US1] Add tests for visible tab filtering and selected-tab fallback when Ask Hermes or Chat with Hermes is hidden in HermesMacOSTest/Functional/AppShellAndSettingsTests.swift
- [x] T013 [P] [US1] Add a contract assertion for Settings tab visibility controls in HermesMacOSTest/Functional/LocalizationAndAccessibilityTests.swift

### Implementation for User Story 1

- [x] T014 [US1] Add non-sensitive UserDefaults-backed keys for Ask Hermes and Chat with Hermes tab visibility in HermesMacOS/SettingsView.swift
- [x] T015 [US1] Add Ask Hermes tab and Chat with Hermes tab toggles to the Settings UI in HermesMacOS/SettingsView.swift
- [x] T016 [US1] Add visible tab filtering helpers for HermesMacOSTab in HermesMacOS/ContentView.swift
- [x] T017 [US1] Add selected-tab fallback logic that moves away from hidden Ask Hermes or Chat with Hermes tabs in HermesMacOS/ContentView.swift
- [x] T018 [US1] Preserve existing Ask Hermes and Chat with Hermes workspace/session objects while hidden by limiting changes to navigation visibility in HermesMacOS/ContentView.swift
- [x] T019 [US1] Run the AppShell and Settings focused test class using xcodebuild from specs/014-memory-tab-settings/quickstart.md

**Checkpoint**: User Story 1 is functional and testable independently.

---

## Phase 4: User Story 2 - Browse Hindsight memories from a native Memory tab (Priority: P2)

**Goal**: Users can open a native Memory tab and browse readable Hindsight memories in paginated rows with clear loading, empty, and provider-error states.

**Independent Test**: With fixture-backed provider data containing more rows than one page, open Memory, navigate pages, and verify readable row content, metadata, range text, Refresh, Previous, and Next behavior.

### Tests for User Story 2

- [x] T020 [P] [US2] Add Memory tab first-page, empty-state, and provider-error workflow tests in HermesMacOSTest/Functional/MemoryTabWorkflowTests.swift
- [x] T021 [P] [US2] Add pagination range, previous, next, and page clamping tests in HermesMacOSTest/Functional/MemoryTabWorkflowTests.swift
- [x] T022 [P] [US2] Add Hindsight list JSON decoding tests for optional metadata and malformed rows in HermesMacOSTest/Technical/HindsightMemoryClientTests.swift

### Implementation for User Story 2

- [x] T023 [US2] Add the Memory case, title, system image, and default ordering to HermesMacOSTab in HermesMacOS/ContentView.swift
- [x] T024 [US2] Wire the Memory tab destination into the main view composition in HermesMacOS/ContentView.swift
- [x] T025 [US2] Implement Hindsight list helper execution, JSON parsing, timeout handling, and sanitized list errors in HermesMacOS/HermesHindsightMemoryClient.swift
- [x] T026 [US2] Implement Memory tab loading, refresh, stale-response guard, pagination, and provider-empty states in HermesMacOS/HermesMemoryStore.swift
- [x] T027 [US2] Implement the Memory tab SwiftUI list, row preview, metadata subtitle, range text, Refresh, Previous, and Next controls in HermesMacOS/HermesMemoryView.swift
- [x] T028 [US2] Run the Memory tab workflow and Hindsight client focused tests using xcodebuild from specs/014-memory-tab-settings/quickstart.md

**Checkpoint**: User Stories 1 and 2 work independently.

---

## Phase 5: User Story 3 - Filter and delete individual memories (Priority: P3)

**Goal**: Users can filter visible memories by text and delete a single memory after confirmation while preserving safe error behavior.

**Independent Test**: Enter a filter term, verify the filtered page and zero-result state, delete one visible memory after confirmation, and verify deletion success removes that row while deletion failure keeps the row visible with a sanitized error.

### Tests for User Story 3

- [x] T029 [P] [US3] Add filter text, filtered-empty, and page reset tests in HermesMacOSTest/Functional/MemoryTabWorkflowTests.swift
- [x] T030 [P] [US3] Add successful delete, failed delete, and pagination-after-delete tests in HermesMacOSTest/Functional/MemoryTabWorkflowTests.swift
- [x] T031 [P] [US3] Add Hindsight delete JSON decoding and secret-redaction tests in HermesMacOSTest/Technical/HindsightMemoryClientTests.swift

### Implementation for User Story 3

- [x] T032 [US3] Implement filter text normalization, provider query propagation, and page reset behavior in HermesMacOS/HermesMemoryStore.swift
- [x] T033 [US3] Add the Memory tab filter field and filtered-empty state to HermesMacOS/HermesMemoryView.swift
- [x] T034 [US3] Implement row-specific delete confirmation UI and in-flight delete state in HermesMacOS/HermesMemoryView.swift
- [x] T035 [US3] Implement Hindsight memory delete or invalidation helper execution and sanitized delete errors in HermesMacOS/HermesHindsightMemoryClient.swift
- [x] T036 [US3] Refresh the current filtered page and clamp pagination after successful delete in HermesMacOS/HermesMemoryStore.swift
- [x] T037 [US3] Run the filter and delete focused tests using xcodebuild from specs/014-memory-tab-settings/quickstart.md

**Checkpoint**: All user stories are independently functional.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Documentation, accessibility, security review, and final verification across all stories.

- [x] T038 [P] Update app-surface documentation for Memory tab and Settings tab visibility controls in docs/reference-app-surface.md
- [x] T039 [P] Update Ask Hermes and Chat with Hermes usage documentation for optional tab visibility in docs/how-to-use-ask-and-chat.md
- [x] T040 [P] Add accessibility labels and VoiceOver-friendly delete confirmation text for Memory and Settings controls in HermesMacOS/HermesMemoryView.swift
- [x] T041 Review Memory provider helper output redaction, raw text logging, and bounded process execution in HermesMacOS/HermesHindsightMemoryClient.swift
- [x] T042 Run xcodegen generate if source membership or project settings changed and inspect HermesMacOS.xcodeproj/project.pbxproj
- [x] T043 Build the HermesMacOS scheme using the xcodebuild command documented in specs/014-memory-tab-settings/quickstart.md
- [x] T044 Run the HermesMacOSTest scheme using the xcodebuild test command documented in specs/014-memory-tab-settings/quickstart.md
- [x] T045 Perform the manual Settings and Memory smoke checklist from specs/014-memory-tab-settings/quickstart.md
- [x] T046 [P] Update final implementation evidence and any changed contracts in specs/014-memory-tab-settings/quickstart.md

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies; can start immediately.
- **Foundational (Phase 2)**: Depends on Setup completion; blocks all user story phases.
- **User Story 1 (Phase 3)**: Depends on Foundational completion; MVP scope.
- **User Story 2 (Phase 4)**: Depends on Foundational completion and can be developed after or alongside User Story 1, but final navigation wiring must account for User Story 1 filtering.
- **User Story 3 (Phase 5)**: Depends on Memory list/store/client surfaces from User Story 2.
- **Polish (Phase 6)**: Depends on whichever user stories are implemented for the delivery increment.

### User Story Dependencies

- **User Story 1 (P1)**: No dependency on other user stories after Foundation.
- **User Story 2 (P2)**: Depends on Foundation; final tab ordering touches the same navigation file as User Story 1.
- **User Story 3 (P3)**: Depends on User Story 2 Memory store, view, and Hindsight client surfaces.

### Within Each User Story

- Write focused tests first and confirm they fail before implementation.
- Add or update models and provider/client contracts before SwiftUI integration.
- Complete store behavior before wiring complex view interactions.
- Run focused tests at the story checkpoint before moving to the next story.

### Parallel Opportunities

- Setup inspections T003 and T004 can run alongside T001 and T002.
- Foundational coverage, localization, and fixture tasks T005, T006, and T010 can run in parallel with client/store type work.
- User Story 1 test tasks T011, T012, and T013 can run in parallel.
- User Story 2 test tasks T020, T021, and T022 can run in parallel before implementation.
- User Story 3 test tasks T029, T030, and T031 can run in parallel before implementation.
- Documentation and accessibility polish tasks T038, T039, T040, and T046 can run in parallel after relevant implementation surfaces exist.

---

## Parallel Example: User Story 1

```bash
Task: "T011 [P] [US1] Add tests for default Ask Hermes and Chat with Hermes visibility preferences in HermesMacOSTest/Functional/AppShellAndSettingsTests.swift"
Task: "T012 [P] [US1] Add tests for visible tab filtering and selected-tab fallback when Ask Hermes or Chat with Hermes is hidden in HermesMacOSTest/Functional/AppShellAndSettingsTests.swift"
Task: "T013 [P] [US1] Add a contract assertion for Settings tab visibility controls in HermesMacOSTest/Functional/LocalizationAndAccessibilityTests.swift"
```

## Parallel Example: User Story 2

```bash
Task: "T020 [P] [US2] Add Memory tab first-page, empty-state, and provider-error workflow tests in HermesMacOSTest/Functional/MemoryTabWorkflowTests.swift"
Task: "T021 [P] [US2] Add pagination range, previous, next, and page clamping tests in HermesMacOSTest/Functional/MemoryTabWorkflowTests.swift"
Task: "T022 [P] [US2] Add Hindsight list JSON decoding tests for optional metadata and malformed rows in HermesMacOSTest/Technical/HindsightMemoryClientTests.swift"
```

## Parallel Example: User Story 3

```bash
Task: "T029 [P] [US3] Add filter text, filtered-empty, and page reset tests in HermesMacOSTest/Functional/MemoryTabWorkflowTests.swift"
Task: "T030 [P] [US3] Add successful delete, failed delete, and pagination-after-delete tests in HermesMacOSTest/Functional/MemoryTabWorkflowTests.swift"
Task: "T031 [P] [US3] Add Hindsight delete JSON decoding and secret-redaction tests in HermesMacOSTest/Technical/HindsightMemoryClientTests.swift"
```

---

## Implementation Strategy

### MVP First: User Story 1 Only

1. Complete Phase 1 setup inspections.
2. Complete Phase 2 shared coverage, localization, Memory DTO, provider protocol, store defaults, and fixtures.
3. Complete Phase 3 User Story 1 tests and implementation.
4. Stop and validate Settings toggles, visible tab filtering, selected-tab fallback, and prompt state preservation.

### Incremental Delivery

1. Deliver User Story 1 so users can simplify the app tab surface.
2. Deliver User Story 2 so users can browse Hindsight memories in a native Memory tab.
3. Deliver User Story 3 so users can filter and delete individual memories safely.
4. Complete cross-cutting documentation, accessibility, security review, build, test, and manual smoke tasks.

### Verification Commands

Use the commands from `specs/014-memory-tab-settings/quickstart.md`:

```bash
cd /Volumes/WDBlack4TB/Code/HermesMacOS && xcodegen generate
cd /Volumes/WDBlack4TB/Code/HermesMacOS && xcodebuild -project HermesMacOS.xcodeproj -scheme HermesMacOS -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/HermesMacOSBuildDerivedData build
cd /Volumes/WDBlack4TB/Code/HermesMacOS && xcodebuild -project HermesMacOS.xcodeproj -scheme HermesMacOSTest -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/HermesMacOSTestDerivedData test
```

---

## Task Summary

- **Total tasks**: 46
- **Setup**: 4 tasks
- **Foundational**: 6 tasks
- **User Story 1**: 9 tasks
- **User Story 2**: 9 tasks
- **User Story 3**: 9 tasks
- **Polish**: 9 tasks
- **Parallel tasks**: 17
- **MVP scope**: Phase 1, Phase 2, and User Story 1
