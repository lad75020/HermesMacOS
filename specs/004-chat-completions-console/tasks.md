# Tasks: Chat Completions Console

**Input**: Design documents from `/specs/004-chat-completions-console/`

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
