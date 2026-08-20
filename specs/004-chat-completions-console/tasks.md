# Tasks: Chat Completions Console

**Input**: Design documents from `/specs/004-chat-completions-console/`

**Propagated**: 2026-08-20 — Updated from spec.md refinement for selected Chat bubble translation.

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/chat-completions-api.md, quickstart.md

## Phase 1: Setup
- [x] T001 Create feature artifact directory `specs/004-chat-completions-console/`
- [x] T002 Write feature specification and plan artifacts
- [x] T003 Write research, data model, contract, quickstart, and tasks artifacts

## Phase 2: Foundational
- [x] T004 Confirm Chat UI exists in `HermesMacOS/HermesChatView.swift`
- [x] T005 Confirm Chat API/session helpers exist in `HermesMacOS/HermesChatCompletionsAPI.swift`
- [x] T006 Confirm usage documentation exists in `docs/how-to-use-ask-and-chat.md`

## Phase 3: User Story 1 - Send a chat prompt and receive an answer (Priority: P1) 🎯 MVP
- [x] T007 [US1] Trace streaming/non-streaming request behavior in `HermesMacOS/HermesChatCompletionsAPI.swift`
- [x] T008 [US1] Trace transcript/status rendering in `HermesMacOS/HermesChatView.swift`

## Phase 4: User Story 2 - Use profiles, system prompt, cancellation, and resume (Priority: P2)
- [x] T009 [US2] Trace profile/system prompt/cancel/resume behavior in `HermesMacOS/HermesChatView.swift` and `HermesMacOS/HermesChatCompletionsAPI.swift`

## Phase 5: User Story 3 - Attach files/images to chat prompts (Priority: P3)
- [x] T010 [US3] Trace attachment conversion behavior in `HermesMacOS/HermesChatCompletionsAPI.swift`

## Phase 6: Polish & Cross-Cutting Concerns
- [x] T011 Run XcodeMCP build for the `HermesMacOS` scheme
- [x] T012 Run ad-hoc artifact verification for queue/spec/task structure and referenced paths
- [ ] T013 Perform live Chat smoke checks from `specs/004-chat-completions-console/quickstart.md` when a reachable Hermes API gateway is available

## Phase 7: User Story 4 - Translate selected bubble text into English (Priority: P4)
**Goal**: Let users translate a selected range in a completed Chat with Hermes bubble to English through Apple's native macOS 26 translation framework without changing unrelated transcript content or issuing a new Hermes request.

**Independent Test**: Open Chat with Hermes with a non-English message, select a range in one completed bubble, right-click, choose «Translate to English», and verify the selected range is replaced while surrounding text remains unchanged; repeat with unavailable/failing translation and verify the original text remains.

- [x] T014 [US4] Implement `HermesNativeTranslationService` around Apple's native macOS 26 `Translation` framework for English targeting, availability/source-language checks, and recoverable errors in `HermesMacOS/HermesNativeTranslationService.swift`
- [x] T015 [US4] Add the right-click context action labeled «Translate to English» for non-empty selections in completed `HermesCopyableBubbleContent` text in `HermesMacOS/HermesViews.swift`
- [x] T016 [US4] Track `HermesChatTranslationSelection` for one bubble, disable translation for empty/cross-bubble/still-streaming content, and expose accessible loading/error states in `HermesMacOS/HermesViews.swift` and `HermesMacOS/HermesChatView.swift` [(depends on T015)]
- [x] T017 [US4] Apply the translated result to only the selected range of `HermesChatMessage.content`, preserving stable identity/order and session retention without creating a new Chat Completions request in `HermesMacOS/HermesChatCompletionsAPI.swift` [(depends on T014, T016)]
- [x] T018 [US4] Preserve original bubble content and surface non-sensitive recoverable failures for unavailable, unknown-source, or failed native translation in `HermesMacOS/HermesNativeTranslationService.swift` and `HermesMacOS/HermesViews.swift` [(depends on T014, T017)]
- [x] T019 [P] [US4] Document right-click translation, selected-range replacement, and failure-preservation smoke checks in `specs/004-chat-completions-console/quickstart.md` [(depends on T017, T018)]
- [ ] T020 [US4] Run the `HermesMacOS` XcodeMCP build and the macOS 26 translation smoke checks documented in `specs/004-chat-completions-console/quickstart.md` [(depends on T018, T019)]

## Dependencies
- The original Chat tracing and environment-dependent live smoke check remain in T004-T013.
- T014 → T015 → T016 → T017 → T018 covers the native translation implementation and selected-range safety.
- T019 follows the completed behavior and can run independently of T020; T020 follows implementation, documentation, and failure handling.

## Requirement Traceability
| Requirement family | Tasks |
|---|---|
| FR-001–FR-009 | T004–T013 |
| FR-010–FR-011 / SC-005 | T015–T016 |
| FR-012–FR-013 / SC-006 | T014, T017 |
| FR-014 / SC-007 / FR-SEC | T018 |
| FR-INT | T004–T013, T017 |
| SC-001–SC-004 | T007–T013 |
| SC-BUILD / SC-SMOKE | T013, T019, T020 |
