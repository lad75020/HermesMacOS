# Implementation Plan: Ask Hermes Responses

**Branch**: `feature/time-machine-ask-hermes-responses` | **Date**: 2026-06-27 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/003-ask-hermes-responses/spec.md`

## Summary

Retroactively specify and verify the existing Ask Hermes `/v1/responses` client: profile/reasoning controls, streaming and non-streaming output, cancellation, continuation, attachments, stream-output bubbles, prompt persistence, and multi-workspace isolation. No source redesign is required unless verification finds a defect.

## Technical Context

**Language/Version**: Swift, SwiftUI, Foundation URLSession/SSE parsing; project sets `SWIFT_VERSION: 5.0`  
**Primary Dependencies**: Hermes API gateway `/v1/responses`, `/v1/profiles`, `/v1/requests/{id}/cancel`; dashboard-backed skill/path suggestions where available  
**Storage**: Encrypted retention for Ask drafts and session titles/IDs; UserDefaults/AppStorage for non-secret display preferences  
**Testing**: Xcode build plus live-service/manual smoke checks for prompt, streaming, cancellation, attachments, and workspace isolation  
**Target Platform**: macOS 26+ native app  
**Project Type**: Desktop app / native Hermes Agent control surface  
**Performance Goals**: Keep streaming responsive, bound raw/debug/stream output, avoid blocking UI while profiles or suggestions load  
**Constraints**: Preserve endpoint validation before secret-bearing requests; keep tool/event output separate from assistant text; do not render debug logs as assistant answer text  
**Scale/Scope**: Existing files `HermesViews.swift`, `HermesModelsAPI.swift`, `HermesAskWorkspacesView.swift`, and `docs/how-to-use-ask-and-chat.md`

## Constitution Check

- **Native control surface**: Pass. Ask Hermes is a native SwiftUI tab/workspace surface.
- **Integration contracts**: Pass. Uses documented `/v1/responses`, `/v1/profiles`, and `/v1/requests/{id}/cancel` contracts with profile/session headers and SSE handling.
- **Security guardrails**: Pass. API keys require URL validation; drafts/history use redaction/encrypted retention; attachments enforce supported types and limits.
- **Verification**: Pass with build plus live-service smoke checks; no automated test target exists.
- **Maintainability**: Pass. This pass adds SDD artifacts only and does not further grow already-large source files.

## Project Structure

### Documentation (this feature)

```text
specs/003-ask-hermes-responses/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── responses-api.md
└── tasks.md
```

### Source Code (repository root)

```text
HermesMacOS/
├── HermesViews.swift
├── HermesModelsAPI.swift
└── HermesAskWorkspacesView.swift

docs/
└── how-to-use-ask-and-chat.md
```

**Structure Decision**: Keep existing Ask source files and add only Spec Kit artifacts under `specs/003-ask-hermes-responses/`.

## Complexity Tracking

No constitution violations or additional complexity are introduced.

## Phase 0: Research

See [research.md](./research.md).

## Phase 1: Design

See [data-model.md](./data-model.md), [contracts/responses-api.md](./contracts/responses-api.md), and [quickstart.md](./quickstart.md).

## Phase 2: Tasks

See [tasks.md](./tasks.md).
