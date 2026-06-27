# Implementation Plan: History and Session Resume

**Branch**: `feature/time-machine-history-sessions-resume` | **Date**: 2026-06-27 | **Spec**: [spec.md](./spec.md)

**Propagated**: 2026-06-27 — Updated from spec.md refinement for Sessions-tab local_memory persistence.

**Input**: Feature specification from `/specs/006-history-sessions-resume/spec.md`

## Summary

Retroactively specify and verify the existing History and Sessions surfaces: dashboard full-text conversation search, profile filtering, expandable result summaries, resume actions for Ask/Chat/TUI, stored session pagination, non-cron filtering, details loading/caching, Sessions-tab local_memory persistence for user prompts and assistant final answers, duplicate raw-turn prevention, and dashboard token retry behavior.

## Technical Context

**Language/Version**: Swift, SwiftUI, Foundation URLSession; project sets `SWIFT_VERSION: 5.0`
**Primary Dependencies**: Hermes Dashboard `api/sessions/search/conversations`, `api/sessions`, `api/sessions/{session_id}/messages`, dashboard session token extraction via `HermesDashboardClient`, Hermes Agent `plugins.memory.local_memory.LocalMemoryProvider`
**Storage**: In-memory search/session state, per-session detail cache, per-session local_memory persistence UI state, and local_memory raw-turn storage through the configured provider
**Testing**: Xcode build plus dashboard-backed live smoke checks
**Target Platform**: macOS 26+ native app
**Project Type**: Desktop app / native Hermes Agent control surface
**Performance Goals**: Keep UI responsive while searching, paging, and loading details; support cancellation; avoid unbounded detail refetches through cache
**Constraints**: Preserve dashboard token handling, 401 refresh retry, non-cron session filtering, target-runtime busy-state gating, flexible payload decoding, user/assistant-only persistence, and idempotent local_memory writes
**Scale/Scope**: Existing files `HermesHistoryView.swift`, `HermesDashboardHistorySearch.swift`, Hermes Agent local_memory provider integration, and `docs/reference-api-and-storage.md`

## Constitution Check

- **Native control surface**: Pass. History and Sessions are native SwiftUI surfaces.
- **Integration contracts**: Pass. Uses documented dashboard search/session/message endpoints.
- **Security guardrails**: Pass. Dashboard session tokens are extracted centrally and sent via header using shared network/session helpers; local_memory persistence excludes system/tool/internal messages and sends only user prompts plus assistant final answers.
- **Verification**: Pass with build plus live dashboard smoke checks; no automated test target exists.
- **Maintainability**: Pass. The refinement keeps local_memory persistence state in the Sessions store and reuses lazy session-detail loading instead of adding a second message-fetch path.

## Project Structure

### Documentation (this feature)

```text
specs/006-history-sessions-resume/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── dashboard-history-sessions-api.md
└── tasks.md
```

### Source Code (repository root)

```text
HermesMacOS/
├── HermesHistoryView.swift
└── HermesDashboardHistorySearch.swift

docs/
└── reference-api-and-storage.md
```

**Structure Decision**: Keep existing source files and add only Spec Kit artifacts under `specs/006-history-sessions-resume/`.

## Complexity Tracking

No constitution violations or additional complexity are introduced.

The local_memory refinement adds a local Python helper invocation from `HermesHistoryView.swift` so the macOS app can use the configured Hermes Agent provider without introducing a new dashboard API. The helper is bounded by timeout, runs off the main actor, and checks the raw-turn idempotency key before calling `sync_turn`.

## Phase 0: Research

See [research.md](./research.md).

## Phase 1: Design

See [data-model.md](./data-model.md), [contracts/dashboard-history-sessions-api.md](./contracts/dashboard-history-sessions-api.md), and [quickstart.md](./quickstart.md).

## Phase 2: Tasks

See [tasks.md](./tasks.md).
