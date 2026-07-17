# Implementation Plan: TUI Gateway Workspaces

**Branch**: `feature/time-machine-tui-gateway-workspaces` | **Date**: 2026-06-27 | **Spec**: [spec.md](./spec.md)

**Propagated**: 2026-07-17 — Updated from spec.md refinement

## Summary
Retroactively specify and verify the existing native TUI Gateway: dashboard WebSocket setup, JSON-RPC request/response matching, streamed event rendering, attachments, request bubbles, session lifecycle, resume, and multi-workspace isolation. Refined work adds live `usage.context_used` occupancy to the active assistant bubble and selected-model reasoning controls that use `model.options`, `reasoning_effort`, and session-scoped `config.set` without enabling unsupported models.

## Technical Context
**Language/Version**: Swift, SwiftUI, Foundation URLSessionWebSocketTask; project sets `SWIFT_VERSION: 5.0`

**Primary Dependencies**: Hermes Dashboard `api/ws`, `api/auth/ws-ticket`, dashboard session token extraction, JSON-RPC 2.0, `model.options` capability metadata

**Storage**: UI state per workspace, including selected reasoning effort and assistant-bubble current-context usage; no durable secret storage beyond shared dashboard/API settings and secure request fields

**Testing**: `HermesMacOSTest` coverage plus Xcode build and dashboard-backed live smoke checks

**Target Platform**: macOS 26+ native app

**Project Type**: Desktop app / native Hermes Agent control surface
**Constraints**: Preserve endpoint/TLS validation, token/ticket auth, request timeouts, transcript separation of assistant/reasoning/tool/status output, session/turn boundaries for context usage, and selected-model reasoning capability precedence over profile fallback

## Constitution Check
- **Native control surface**: Pass. TUI Gateway is a native SwiftUI workspace tab.
- **Integration contracts**: Pass. Preserves dashboard WebSocket JSON-RPC methods and event envelopes while adding forward-compatible `reasoning_effort` params and session-scoped `config.set`.
- **Security guardrails**: Pass. Dashboard URL validation, TLS policy reuse, token/ticket auth, and secure request inputs remain in place.
- **Verification**: Pass with focused `HermesMacOSTest` coverage, build, and live dashboard smoke checks.
- **Maintainability**: Pass. Current-context parsing and reasoning capability selection remain isolated helpers with focused workflow tests.

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
HermesMacOS/HermesModelsAPI.swift
HermesMacOS/ContentView.swift
HermesMacOSTest/Functional/TUIGatewayWorkflowTests.swift
HermesMacOSTest/Technical/StreamingAndGatewayEventTests.swift
docs/reference-tui-gateway-websocket.md
docs/how-to-use-tui-gateway.md
```

**Structure Decision**: Keep the TUI Gateway implementation centered in `HermesTUIGatewayView.swift`; decode optional profile reasoning metadata in `HermesModelsAPI.swift`, persist per-workspace selection in `ContentView.swift`, and cover usage parsing, bubble association, capability precedence, payloads, and workspace defaults in `HermesMacOSTest`.

## Refined Implementation Details
- **Current-context occupancy (FR-009, SC-006)**: Parse positive integral `usage.context_used` plus optional `context_max` and `context_percent` from `message.complete` and `session.info`. Associate it only with the active/current-turn assistant message, preserve the final value after completion, clear pending state at session and turn boundaries, and never substitute cumulative token totals.
- **Reasoning configuration (FR-010, SC-007)**: Resolve selected-model reasoning support from `model.options` before conservative profile/model fallback; expose only canonical valid efforts; include `reasoning_effort` in supported `session.create` and forward-compatible `prompt.submit` params; apply idle live changes with session-scoped `config.set` using key `reasoning`; restore only supported values from session/resume info.

## Complexity Tracking
No constitution violations or additional complexity are introduced.
