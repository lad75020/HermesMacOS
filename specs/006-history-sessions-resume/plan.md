# Implementation Plan: History and Session Resume

> ⚠️ **STALE**: spec.md was refined on 2026-06-27. Run `/speckit.refine.propagate` to update this plan.

**Branch**: `feature/time-machine-history-sessions-resume` | **Date**: 2026-06-27 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/006-history-sessions-resume/spec.md`

## Summary

Retroactively specify and verify the existing History and Sessions surfaces: dashboard full-text conversation search, profile filtering, expandable result summaries, resume actions for Ask/Chat/TUI, stored session pagination, non-cron filtering, details loading/caching, and dashboard token retry behavior.

## Technical Context

**Language/Version**: Swift, SwiftUI, Foundation URLSession; project sets `SWIFT_VERSION: 5.0`  
**Primary Dependencies**: Hermes Dashboard `api/sessions/search/conversations`, `api/sessions`, `api/sessions/{session_id}/messages`, dashboard session token extraction via `HermesDashboardClient`  
**Storage**: In-memory search/session state and per-session detail cache; no new durable storage  
**Testing**: Xcode build plus dashboard-backed live smoke checks  
**Target Platform**: macOS 26+ native app  
**Project Type**: Desktop app / native Hermes Agent control surface  
**Performance Goals**: Keep UI responsive while searching, paging, and loading details; support cancellation; avoid unbounded detail refetches through cache  
**Constraints**: Preserve dashboard token handling, 401 refresh retry, non-cron session filtering, target-runtime busy-state gating, and flexible payload decoding  
**Scale/Scope**: Existing files `HermesHistoryView.swift`, `HermesDashboardHistorySearch.swift`, and `docs/reference-api-and-storage.md`

## Constitution Check

- **Native control surface**: Pass. History and Sessions are native SwiftUI surfaces.
- **Integration contracts**: Pass. Uses documented dashboard search/session/message endpoints.
- **Security guardrails**: Pass. Dashboard session tokens are extracted centrally and sent via header using shared network/session helpers.
- **Verification**: Pass with build plus live dashboard smoke checks; no automated test target exists.
- **Maintainability**: Pass. This pass adds SDD artifacts only.

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

## Phase 0: Research

See [research.md](./research.md).

## Phase 1: Design

See [data-model.md](./data-model.md), [contracts/dashboard-history-sessions-api.md](./contracts/dashboard-history-sessions-api.md), and [quickstart.md](./quickstart.md).

## Phase 2: Tasks

See [tasks.md](./tasks.md).
