# Implementation Plan: Chat Completions Console

**Branch**: `feature/time-machine-chat-completions-console` | **Date**: 2026-06-27 | **Spec**: [spec.md](./spec.md)

**Propagated**: 2026-08-20 — Updated from spec.md refinement for selected Chat bubble translation.

## Summary
Retroactively specify and verify the existing Chat with Hermes `/v1/chat/completions` client: streaming/non-streaming replies, profile selection, optional system prompt, attachments, cancellation, session resume, chat draft retention, and in-place English translation of selected completed bubble text.

## Technical Context
**Language/Version**: Swift, SwiftUI, Foundation URLSession/SSE parsing; project sets `SWIFT_VERSION: 5.0`  
**Primary Dependencies**: Hermes API gateway `/v1/chat/completions`, `/v1/profiles`, `/v1/requests/{id}/cancel`, and Apple's native macOS 26 `Translation` framework
**Storage**: Encrypted retention for chat drafts and last chat session metadata; in-place translated message content plus transient selection/translation error state
**Testing**: Xcode build plus live-service/manual smoke checks, including native translation availability, selection replacement, and failure preservation
**Target Platform**: macOS 26+ native app  
**Project Type**: Desktop app / native Hermes Agent control surface  
**Constraints**: Preserve endpoint validation, redaction, attachment safety, profile/session header contracts, selected-range boundaries, and the rule that translation does not create a new Hermes chat request

## Constitution Check
- **Native control surface**: Pass. Chat is a native SwiftUI tab.
- **Native translation**: Pass. Translation uses Apple's native macOS 26 `Translation` framework rather than a new Hermes or third-party chat service.
- **Integration contracts**: Pass. Existing Chat Completions/Profile/Cancel endpoints remain unchanged; translation is outside the request path.
- **Security guardrails**: Pass. URL validation, redacted encrypted drafts, attachment limits, and non-sensitive translation errors remain in place.
- **Verification**: Pass with build plus live-service smoke checks; no automated test target exists.
- **Maintainability**: Pass. The native translation adapter and selection replacement remain isolated from Chat API encoding.

## Project Structure
```text
specs/004-chat-completions-console/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/chat-completions-api.md
└── tasks.md
```

```text
HermesMacOS/HermesChatView.swift
HermesMacOS/HermesChatCompletionsAPI.swift
HermesMacOS/HermesNativeTranslationService.swift
HermesMacOS/HermesViews.swift
docs/how-to-use-ask-and-chat.md
```

**Structure Decision**: Keep the Chat UI and session state in the existing source files, add a focused `HermesNativeTranslationService` adapter for Apple's macOS 26 `Translation` framework, and keep translation selection/replacement outside the Hermes API request encoder.

## Refined Implementation Details
- **Bubble selection and context action (FR-010, FR-011, SC-005)**: Keep completed bubble text selectable, scope the selection to one bubble, and expose a right-click context action labeled «Translate to English» from the shared bubble content view.
- **Selection state (`HermesChatTranslationSelection`)**: Track the selected message identity, selected range/text, English target, in-flight state, translated result, and recoverable error without changing the Chat API request model.
- **Native translation and range replacement (FR-012, FR-013, SC-006)**: Translate the selected text through the macOS 26 `Translation` framework with English as the target, then update only the selected range in the stable `HermesChatMessage` while preserving unselected text, message order, and session state.
- **Failure and streaming safety (FR-014, SC-007)**: Disable translation for empty, cross-bubble, or still-streaming selections; preserve the original content and surface a recoverable, non-sensitive error when availability, source-language detection, or translation fails.

## Complexity Tracking
The refinement adds one native translation adapter and selection-aware message mutation, without changing Hermes endpoint contracts or introducing a remote translation dependency.
