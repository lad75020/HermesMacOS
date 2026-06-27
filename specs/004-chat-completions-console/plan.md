# Implementation Plan: Chat Completions Console

**Branch**: `feature/time-machine-chat-completions-console` | **Date**: 2026-06-27 | **Spec**: [spec.md](./spec.md)

## Summary
Retroactively specify and verify the existing Chat with Hermes `/v1/chat/completions` client: streaming/non-streaming replies, profile selection, optional system prompt, attachments, cancellation, session resume, and chat draft retention.

## Technical Context
**Language/Version**: Swift, SwiftUI, Foundation URLSession/SSE parsing; project sets `SWIFT_VERSION: 5.0`  
**Primary Dependencies**: Hermes API gateway `/v1/chat/completions`, `/v1/profiles`, `/v1/requests/{id}/cancel`  
**Storage**: Encrypted retention for chat drafts and last chat session metadata  
**Testing**: Xcode build plus live-service/manual smoke checks  
**Target Platform**: macOS 26+ native app  
**Project Type**: Desktop app / native Hermes Agent control surface  
**Constraints**: Preserve endpoint validation, redaction, attachment safety, and profile/session header contracts

## Constitution Check
- **Native control surface**: Pass. Chat is a native SwiftUI tab.
- **Integration contracts**: Pass. Uses documented Chat Completions/Profile/Cancel endpoints.
- **Security guardrails**: Pass. URL validation, redacted encrypted drafts, and attachment limits remain in place.
- **Verification**: Pass with build plus live-service smoke checks; no automated test target exists.
- **Maintainability**: Pass. Adds SDD artifacts only.

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
docs/how-to-use-ask-and-chat.md
```

**Structure Decision**: Keep existing Chat source files and add only Spec Kit artifacts under `specs/004-chat-completions-console/`.

## Complexity Tracking
No constitution violations or additional complexity are introduced.
