# Implementation Plan: TUI Gateway Workspaces

**Branch**: `feature/time-machine-tui-gateway-workspaces` | **Date**: 2026-06-27 | **Spec**: [spec.md](./spec.md)

**Propagated**: 2026-07-17 — Updated from spec.md refinement
**Propagated**: 2026-08-20 — Updated from spec.md refinements for `/skill` substring matching, sanitized `session.usage` summaries, and sidebar session token totals (FR-011–FR-013, SC-008–SC-010).

## Summary
Retroactively specify and verify the existing native TUI Gateway: dashboard WebSocket setup, JSON-RPC request/response matching, streamed event rendering, attachments, request bubbles, session lifecycle, resume, and multi-workspace isolation. Refined work adds live `usage.context_used` occupancy to the active assistant bubble, selected-model reasoning controls that use `model.options`, `reasoning_effort`, and session-scoped `config.set`, `/skill` substring autocomplete, sanitized `session.usage` transcript summaries, and cumulative input/output token totals above the sidebar resource gauges without enabling unsupported models.

## Technical Context
**Language/Version**: Swift, SwiftUI, Foundation URLSessionWebSocketTask; project sets `SWIFT_VERSION: 5.0`

**Primary Dependencies**: Hermes Dashboard `api/ws`, `api/auth/ws-ticket`, dashboard session token extraction, JSON-RPC 2.0, `model.options` capability metadata

**Storage**: UI state per workspace, including selected reasoning effort, assistant-bubble current-context usage, sanitized `session.usage` summary values, and latest valid cumulative input/output token totals; no durable secret storage beyond shared dashboard/API settings and secure request fields

**Testing**: `HermesMacOSTest` coverage plus Xcode build and dashboard-backed live smoke checks

**Target Platform**: macOS 26+ native app

**Project Type**: Desktop app / native Hermes Agent control surface
**Constraints**: Preserve endpoint/TLS validation, token/ticket auth, request timeouts, transcript separation of assistant/reasoning/tool/status output, session/turn boundaries for context usage, selected-model reasoning capability precedence over profile fallback, the `session.usage` payload shape, cumulative snapshot semantics, active-session filtering, and the sidebar token display order/color requirements

## Constitution Check
- **Native control surface**: Pass. TUI Gateway is a native SwiftUI workspace tab.
- **Integration contracts**: Pass. Preserves dashboard WebSocket JSON-RPC methods and event envelopes while adding forward-compatible `reasoning_effort` params and session-scoped `config.set`.
- **Security guardrails**: Pass. Dashboard URL validation, TLS policy reuse, token/ticket auth, and secure request inputs remain in place.
- **Verification**: Pass with focused `HermesMacOSTest` coverage, build, and live dashboard smoke checks.
- **Maintainability**: Pass. Current-context parsing, reasoning capability selection, `/skill` matching, sanitized session-usage parsing, and token-total presentation remain isolated helpers with focused workflow tests.

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
HermesMacOS/HermesDashboardSkills.swift
HermesMacOS/ContentView.swift
HermesMacOSTest/Functional/TUIGatewayWorkflowTests.swift
HermesMacOSTest/Technical/StreamingAndGatewayEventTests.swift
docs/reference-tui-gateway-websocket.md
docs/how-to-use-tui-gateway.md
```

**Structure Decision**: Keep the TUI Gateway implementation centered in `HermesTUIGatewayView.swift`; decode optional profile reasoning metadata in `HermesModelsAPI.swift`, keep `/skill` matching in `HermesDashboardSkills.swift`, persist per-workspace selection and expose the active workspace's token totals to the sidebar in `ContentView.swift`, and cover usage parsing, bubble association, capability precedence, payloads, token snapshot replacement, and workspace defaults in `HermesMacOSTest`.

## Refined Implementation Details
- **Current-context occupancy (FR-009, SC-006)**: Parse positive integral `usage.context_used` plus optional `context_max` and `context_percent` from `message.complete` and `session.info`. Associate it only with the active/current-turn assistant message, preserve the final value after completion, clear pending state at session and turn boundaries, and never substitute cumulative token totals.
- **Reasoning configuration (FR-010, SC-007)**: Resolve selected-model reasoning support from `model.options` before conservative profile/model fallback; expose only canonical valid efforts; include `reasoning_effort` in supported `session.create` and forward-compatible `prompt.submit` params; apply idle live changes with session-scoped `config.set` using key `reasoning`; restore only supported values from session/resume info.
- **`/skill` matching (FR-011, SC-008)**: Filter known skill names case-insensitively by contained query characters, order prefix matches before other substring matches, show all skills for an empty query, and retain an explicit no-match state.
- **Session usage summary (FR-012, SC-009)**: Read the `session.usage` payload safely and keep the transcript bubble limited to `active_subagents`, `compressions`, and `context_percent`, using placeholders for invalid values instead of exposing raw metadata.
- **Session token totals (FR-013, SC-010)**: Parse nonnegative finite cumulative `payload.usage.input` and `payload.usage.output` counters for the active session, replace snapshots rather than summing them, clear stale values when the session identity changes, preserve totals per workspace, and render compact thousands values above the Memory/GPU gauges with green input and blue output text.

## Complexity Tracking
One additional workspace-scoped token snapshot and sidebar binding are required; no backend WebSocket method changes, constitution violations, or durable secret storage are introduced.
