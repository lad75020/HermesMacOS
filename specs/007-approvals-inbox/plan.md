# Implementation Plan: Approvals Inbox

**Branch**: `feature/time-machine-approvals-inbox` | **Date**: 2026-06-27 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/007-approvals-inbox/spec.md`

## Summary

Retroactively specify and verify the existing Approvals Inbox: remote `/v1/approvals` list, `/v1/approvals/resolve`, local filesystem/TLS approval fallback and resolution, auto-refresh, resolving-state guards, JSON response validation, and sensitive URL protection before adding API credentials.

## Technical Context

**Language/Version**: Swift, SwiftUI, Observation, Foundation URLSession; project sets `SWIFT_VERSION: 5.0`  
**Primary Dependencies**: Hermes API gateway `/v1/approvals` and `/v1/approvals/resolve`; `HermesLocalApprovalCenter`; endpoint security helpers  
**Storage**: In-memory approval store plus local approval center state; no new durable storage  
**Testing**: Xcode build plus live/local approval smoke checks  
**Target Platform**: macOS 26+ native app  
**Project Type**: Desktop app / native Hermes Agent control surface  
**Performance Goals**: Refresh without blocking UI, poll every five seconds only while auto-refresh is enabled, prevent duplicate resolve calls  
**Constraints**: Preserve endpoint validation before Authorization headers, JSON content-type validation, local approval fallback, and secure trust-decision wording  
**Scale/Scope**: Existing files `HermesApprovalsInboxView.swift`, `HermesModelsAPI.swift`, and `HermesSecurityUtilities.swift`

## Constitution Check

- **Native control surface**: Pass. Approvals Inbox is a native SwiftUI panel.
- **Integration contracts**: Pass. Uses documented Hermes approvals endpoints plus local approval center state.
- **Security guardrails**: Pass. Sensitive URLs are validated before API keys are attached; local TLS/filesystem decisions remain explicit.
- **Verification**: Pass with build plus live/local smoke checks; no automated test target exists.
- **Maintainability**: Pass. This pass adds SDD artifacts only.

## Project Structure

```text
specs/007-approvals-inbox/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── approvals-api.md
└── tasks.md
```

```text
HermesMacOS/HermesApprovalsInboxView.swift
HermesMacOS/HermesModelsAPI.swift
HermesMacOS/HermesSecurityUtilities.swift
```

**Structure Decision**: Keep existing source files and add only Spec Kit artifacts under `specs/007-approvals-inbox/`.

## Complexity Tracking

No constitution violations or additional complexity are introduced.
