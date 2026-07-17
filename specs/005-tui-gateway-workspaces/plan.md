> ⚠️ **STALE**: spec.md was refined on 2026-07-17. Run `/speckit.refine.propagate` to update this plan.

# Implementation Plan: TUI Gateway Workspaces

**Branch**: `feature/time-machine-tui-gateway-workspaces` | **Date**: 2026-06-27 | **Spec**: [spec.md](./spec.md)

## Summary
Retroactively specify and verify the existing native TUI Gateway: dashboard WebSocket setup, JSON-RPC request/response matching, streamed event rendering, attachments, request bubbles, session lifecycle, resume, and multi-workspace isolation.

## Technical Context
**Language/Version**: Swift, SwiftUI, Foundation URLSessionWebSocketTask; project sets `SWIFT_VERSION: 5.0`  
**Primary Dependencies**: Hermes Dashboard `api/ws`, `api/auth/ws-ticket`, dashboard session token extraction, JSON-RPC 2.0  
**Storage**: UI state per workspace; no durable secret storage beyond shared dashboard/API settings and secure request fields  
**Testing**: Xcode build plus dashboard-backed live smoke checks  
**Target Platform**: macOS 26+ native app  
**Project Type**: Desktop app / native Hermes Agent control surface  
**Constraints**: Preserve endpoint/TLS validation, token/ticket auth, request timeouts, and transcript separation of assistant/reasoning/tool/status output

## Constitution Check
- **Native control surface**: Pass. TUI Gateway is a native SwiftUI workspace tab.
- **Integration contracts**: Pass. Preserves dashboard WebSocket JSON-RPC methods and event envelopes.
- **Security guardrails**: Pass. Dashboard URL validation, TLS policy reuse, token/ticket auth, and secure request inputs remain in place.
- **Verification**: Pass with build plus live dashboard smoke checks; no automated test target exists.
- **Maintainability**: Pass. Adds SDD artifacts only.

## Project Structure
```text
specs/005-tui-gateway-workspaces/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/tui-gateway-json-rpc.md
└── tasks.md
```

```text
HermesMacOS/HermesTUIGatewayView.swift
docs/reference-tui-gateway-websocket.md
docs/how-to-use-tui-gateway.md
```

**Structure Decision**: Keep existing TUI Gateway source and docs, adding only Spec Kit artifacts.

## Complexity Tracking
No constitution violations or additional complexity are introduced.
