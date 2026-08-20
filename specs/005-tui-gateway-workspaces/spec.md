# Feature Specification: TUI Gateway Workspaces

**Feature Branch**: `feature/time-machine-tui-gateway-workspaces`  
**Created**: 2026-06-27  
**Status**: Refined
**Refined**: 2026-07-17 — Added live current-context token counts beside TUI assistant response bubble titles.
**Refined**: 2026-07-17 — Added selected-model reasoning effort controls and session-scoped TUI Gateway inference configuration.
**Refined**: 2026-08-17 — In the TUI Gateway prompt area, the `/skill` popover now filters to every known skill whose name *contains* the characters typed after `/skill` (case-insensitive substring, prefix matches first), instead of the previous anchored-prefix-only match (US5, FR-011, SC-008).
**Refined**: 2026-08-17 — `session.usage` transcript events now render only a compact agents/compressions/context summary instead of raw usage metadata (US2, FR-012, SC-009).
**Refined**: 2026-08-20 — Added cumulative session input/output token totals from streamed `Session.Usage` (`session.usage`) events to the TUI Gateway left navigation panel above the Memory/GPU gauges, with green input and blue output values (US2, FR-013, SC-010).
**Input**: User description: "Feature: TUI Gateway Workspaces. Description: Mirrors live Hermes TUI sessions inside the native app with WebSocket JSON-RPC, multiple workspaces, attachments, streaming transcript events, and interactive requests. Relevant files: HermesMacOS/HermesTUIGatewayView.swift, docs/reference-tui-gateway-websocket.md, docs/how-to-use-tui-gateway.md. Focus on this feature only; do not modify other features."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Connect to the live TUI Gateway (Priority: P1)
A user connects a TUI Gateway workspace to the dashboard WebSocket, obtains a live session, and sees status cards confirm readiness.

**Why this priority**: WebSocket connection and session creation are prerequisites for every TUI workflow.

**Independent Test**: Configure a reachable dashboard, press Connect, and verify token/ticket auth, `api/ws` connection, `session.create`, and `Session ready` status.

**Acceptance Scenarios**:
1. **Given** the dashboard is reachable, **When** the user connects, **Then** the app resolves dashboard URL, validates it, obtains a session token/ticket, opens `api/ws`, and creates a live session.
2. **Given** the dashboard does not support tickets, **When** the user connects, **Then** the app falls back to a token query parameter.
3. **Given** the connection fails, **When** setup errors occur, **Then** the workspace reports disconnected/error state and pending calls fail cleanly.
4. **Given** the gateway returns selected-model reasoning capability metadata, **When** the user creates a live session, **Then** the selected valid effort is included as `reasoning_effort` only when that model supports reasoning.

---

### User Story 2 - Send prompts, attachments, and receive streamed events (Priority: P2)
A user submits prompts and attachments through JSON-RPC and sees assistant, reasoning, thinking, tool, status, background, and error events rendered as distinct transcript bubbles. Assistant response bubble headers show the live current-context token occupancy reported by Hermes. The left navigation panel also shows the active session's cumulative input/output token totals above the Memory and GPU resource gauges, refreshed from streamed `Session.Usage` (`session.usage`) events.

**Why this priority**: This is the core TUI execution experience inside HermesMacOS.

**Independent Test**: Send a prompt, observe `message.start`, deltas, `message.complete`, and attachment event bubbles.

**Acceptance Scenarios**:
1. **Given** a live session exists, **When** the user submits a prompt, **Then** the app sends `prompt.submit` and renders streamed events.
2. **Given** an image attachment with a local path is selected, **When** the user sends it, **Then** `input.detect_drop` runs before `prompt.submit` and an attachment bubble appears.
3. **Given** consecutive deltas change event type, **When** the transcript renders, **Then** assistant, reasoning, thinking, and tool/status output remain separate bubbles.
4. **Given** Hermes reports `usage.context_used` for a response, **When** the usage arrives in `message.complete` or `session.info`, **Then** the current assistant response bubble shows a compact live context-token count immediately beside its title.
5. **Given** Hermes does not report current-window context occupancy, **When** a response bubble renders, **Then** the app omits the context counter rather than substituting cumulative session token totals.
6. **Given** Hermes emits `session.usage`, **When** its event bubble renders, **Then** it shows only `AGENTS : <active_subagents>, COMPRESSIONS: <compressions>, CONTEXT: <context_percent>` and never the raw usage payload or unrelated fields.
7. **Given** Hermes emits `session.usage` for the active session with cumulative counters under `payload.usage.input` and `payload.usage.output`, **When** the event is received, **Then** the app refreshes the selected workspace's input/output totals, displays two clearly labeled compact values in thousands directly above the Memory and GPU gauges, renders input in green and output in blue, and keeps those values separate from the compact transcript summary.

---

### User Story 3 - Manage multiple TUI workspaces and sessions (Priority: P3)
A user creates, switches, deletes, activates, interrupts, closes, and resumes TUI workspaces without mixing transcript/session state.

**Why this priority**: Workspace isolation makes concurrent long-running TUI work practical.

**Independent Test**: Create two workspaces, connect/send in one, switch/delete/resume where allowed, and verify state isolation and attention indicators.

**Acceptance Scenarios**:
1. **Given** two TUI workspaces exist, **When** the user switches, **Then** draft, attachment, live session, transcript, and WebSocket state are preserved per workspace.
2. **Given** a workspace is connecting/streaming/resuming, **When** the user attempts deletion, **Then** deletion is disabled until the risky state ends.
3. **Given** a stored History/Sessions row is resumed, **When** `session.resume` succeeds, **Then** messages, title, live ID, stored key, and running state restore into the selected workspace.
4. **Given** an idle live session supports reasoning, **When** the user changes its reasoning effort, **Then** the app sends session-scoped `config.set` before the next inferred turn and preserves the selection per workspace.

---

### User Story 5 - `/skill` autocomplete popover matches skill names by contained characters (Priority: P5)
While composing a prompt in the TUI Gateway tab, a user types `/skill` followed by characters, and a popover lists every known Hermes skill whose name *contains* those characters (a case-insensitive substring match, not just a leading prefix), so the intended skill can be found even when the typed characters are not at the start of the name.

**Why this priority**: The `/skill` command is how a user loads a specific skill into the live TUI Gateway session; the popover must surface a skill by any substring of its name, otherwise skills whose names do not begin with the typed characters stay hidden and the command feels broken.

**Independent Test**: In a connected TUI Gateway workspace, type `/skill` then a partial token, and verify the popover lists and can select every known skill whose name contains the typed characters case-insensitively, with prefix matches ordered first and the empty query showing all skills.

**Acceptance Scenarios**:
1. **Given** a skill named `macos-vnc-black-screen-debugging` exists, **When** the user types `/skill screen`, **Then** the popover lists that skill (the characters `screen` occur in the middle of the name) and selecting it replaces the token with `/skill macos-vnc-black-screen-debugging `.
2. **Given** a connected TUI Gateway workspace, **When** the user types `/skill` with no trailing characters, **Then** the popover shows the full alphabetized list of known skills.
3. **Given** a connected TUI Gateway workspace, **When** the user types `/skill` with no matching characters, **Then** the popover reports "No matching skills" instead of hiding the picker.
4. **Given** multiple skills contain the typed characters, **When** the popover renders, **Then** skills whose names begin with the characters appear before other containing skills, each group alphabetical by name.

---

### User Story 4 - Respond to live gateway requests (Priority: P4)
A user answers approval, clarification, sudo, and secret request bubbles directly in the transcript.

**Why this priority**: Agent runs often require interactive decisions; without this, the native TUI mirror stalls.

**Independent Test**: Trigger each request type and verify the matching JSON-RPC response method resolves the bubble.

**Acceptance Scenarios**:
1. **Given** an `approval.request` arrives, **When** the user chooses an action, **Then** `approval.respond` is sent and the bubble is marked resolved.
2. **Given** a `clarify.request`, `sudo.request`, or `secret.request` arrives, **When** the user responds or skips, **Then** the appropriate response method is sent and local request state resolves.

### Edge Cases
- Dashboard URL must be `http` or `https`; unsupported schemes fail as invalid WebSocket URLs.
- Disconnection cancels receive loops and fails all pending JSON-RPC continuations.
- `session.activate` applies only to live sessions; stored sessions use `session.resume`.
- Prompt submit without a live session should fail clearly and direct the user to connect/create a session.
- Secret/sudo inputs must use secure fields and avoid leaking values into transcript text.
- Attachment-only sends are allowed, but unsupported attachments must fail safely.
- A selected-model capability value of `reasoning: false` disables reasoning even when the selected profile's default model supports it.
- `session.usage` input/output values are cumulative session snapshots: a later event replaces the prior valid totals rather than being added to them; missing, negative, non-finite, or malformed token fields do not overwrite the last valid value.
- A `session.usage` event from a different or stale session must not change the selected workspace's totals; creating, activating, resuming, closing, or disconnecting a session clears stale totals, while switching workspaces preserves each workspace's own session totals.

## Requirements *(mandatory)*

### Functional Requirements
- **FR-001**: System MUST connect to dashboard `api/ws` via WebSocket using ticket auth when available and token fallback otherwise.
- **FR-002**: System MUST create, activate, close, interrupt, list, and resume TUI sessions through documented JSON-RPC methods.
- **FR-003**: System MUST send prompts via `prompt.submit` and image path attachments via `input.detect_drop` before submit.
- **FR-004**: System MUST render `message.*`, reasoning, thinking, tool, status, background, error, and unknown events as readable transcript bubbles.
- **FR-005**: System MUST group consecutive deltas by event/content type without merging unrelated stream types.
- **FR-006**: System MUST support multiple independent TUI workspaces with isolated store, draft, attachment, request-response drafts, session, transcript, and attention state.
- **FR-007**: System MUST support interactive approval, clarify, sudo, and secret request bubbles and send matching response methods.
- **FR-008**: System MUST fail pending JSON-RPC requests on timeout, disconnect, or cancellation.
- **FR-009**: System MUST parse current-window context occupancy from TUI Gateway usage payloads, associate the latest non-empty value with the active assistant response bubble, and render a compact monospaced context-token count beside the bubble title without using cumulative lifetime token totals as a fallback.
- **FR-010**: System MUST use selected-model `model.options` reasoning capability metadata before profile fallback, render only valid available effort levels, carry supported efforts in `session.create` and forward-compatible `prompt.submit` payloads, apply live changes through session-scoped `config.set`, and restore valid effort from session/resume info.
- **FR-011**: In the TUI Gateway prompt area, when the user types `/skill` followed by characters, the system MUST filter the known Hermes skills to those whose **name contains those characters** (a case-insensitive substring match anywhere in the name, not only a leading prefix), present the matches in an autocomplete popover (prefix matches ordered first, then remaining matches alphabetical by name, empty query shows all skills, no matches reports "No matching skills"), and on selection replace the typed token with `/skill <skill-name> `.
- **FR-012**: System MUST render the `session.usage` transcript event as exactly one compact summary containing only `active_subagents`, `compressions`, and `context_percent` in the form `AGENTS : <active_subagents>, COMPRESSIONS: <compressions>, CONTEXT: <context_percent>`; absent, malformed, or non-finite selected values MUST use a placeholder rather than exposing the raw payload.
- **FR-013**: System MUST read nonnegative finite cumulative input/output token counters from `payload.usage.input` and `payload.usage.output` in each active-session `session.usage` (`Session.Usage`) event, refresh the selected workspace's latest totals on every valid event without double-counting repeated snapshots, and expose two clearly labeled compact values expressed in thousands directly above the Memory and GPU gauges in the left navigation panel, with input rendered green and output rendered blue.
- **FR-SEC**: System MUST validate dashboard URLs, reuse TLS/self-signed certificate policy, prefer one-time tickets, and protect secret/sudo input.
- **FR-INT**: System MUST preserve the documented dashboard WebSocket JSON-RPC protocol.

### Key Entities *(include if feature involves data)*
- **HermesTUIGatewayStore**: WebSocket connection, JSON-RPC request/response matching, event routing, session state, transcript, pending continuations, failures, and the latest session token totals.
- **HermesTUIWorkspace**: Per-workspace store plus draft, request-response drafts, attachment state, and attention acknowledgements.
- **HermesTUIModelCapabilities**: Per-model FAST/reasoning booleans returned by `model.options` for the selected provider.
- **HermesSkillQueryMatching**: Pure helper that filters the known `HermesDashboardSkill` set to names containing the typed `/skill` characters (case-insensitive substring, prefix matches first) for the TUI Gateway prompt popover.
- **HermesTUIWorkspace selected reasoning effort**: Canonical Hermes effort value, defaulting to `medium`, copied for new/replacement workspaces and constrained by the selected model's capability.
- **HermesTUIGatewayMessage**: Transcript bubble for user, assistant, reasoning, tools, status, attachments, requests, errors, and background events, including optional current-context token metadata for assistant responses.
- **HermesTUISessionUsageSummary**: Sanitized, finite-only values for the transcript-only `session.usage` agents, compressions, and context-percent display.
- **HermesTUISessionTokenTotals**: Per-workspace, active-session cumulative input/output token counters sourced from `payload.usage.input` and `payload.usage.output`, with compact thousands formatting and input/output presentation colors for the left navigation panel.
- **HermesTUILiveSession**: Live session menu row returned from `session.active_list`.
- **JSONValue**: Shared value type for JSON-RPC params and event payload summaries.

## Success Criteria *(mandatory)*
### Measurable Outcomes
- **SC-001**: Connect creates a live TUI session and reaches `Session ready`.
- **SC-002**: A submitted prompt renders streamed assistant output and completion state.
- **SC-003**: Image attachment flow runs `input.detect_drop` and adds an attachment event bubble.
- **SC-004**: Two workspaces preserve independent connection, draft, attachment, and transcript state.
- **SC-005**: Approval/clarify/sudo/secret requests can be answered and marked resolved.
- **SC-006**: When the gateway emits `usage.context_used`, the corresponding assistant response bubble displays the compact context-token count beside `Hermes`, updates without creating a duplicate bubble, and preserves the final value after streaming completes.
- **SC-007**: A reasoning-capable selected model presents only valid effort choices, passes the chosen effort to a new/live TUI session, and restores a supported resumed effort without enabling an unsupported model.
- **SC-008**: Typing `/skill` plus characters in the TUI Gateway prompt area surfaces every known skill whose name contains those characters (case-insensitive substring; prefix matches first, others alphabetical), an empty query lists all skills, a non-matching query reports "No matching skills", and selecting a match replaces the token with `/skill <skill-name> `.
- **SC-009**: A `session.usage` event with extra usage fields produces one event bubble whose content is only the specified three-field summary; extra fields such as model, calls, token totals, or prompts are absent from that bubble while the sidebar token values remain a separate UI surface.
- **SC-010**: For an active session, a stream event with `payload.usage.input = 12,000` and `payload.usage.output = 8,000` shows labeled `12K` input in green and `8K` output in blue above the two resource gauges; a later event with `input = 24,000` and `output = 10,000` replaces those values with `24K` and `10K` rather than `36K` and `18K`, and workspace/session switching does not mix the totals.
- **SC-BUILD**: The `HermesMacOS` scheme builds successfully with Xcode or command-line `xcodebuild`.
- **SC-SMOKE**: The primary TUI Gateway journey can be validated independently with documented dashboard smoke checks.

## Assumptions
- This pass uses the installed Hermes Agent's existing `model.options`, `session.create`, `config.set`, and `session.info` reasoning contract; it does not add backend WebSocket methods.
- Capability rows describe model-level support; absent rows may use profile metadata and the existing model-support helper as a conservative fallback.
- The TUI Gateway `session.usage` event wraps the live usage snapshot under `payload.usage`; its `input` and `output` fields are cumulative session counters, not per-event deltas.
- Live verification requires a reachable Hermes Dashboard exposing `api/ws` and auth routes.
- ~~No automated test target exists yet.~~ Superseded: `HermesMacOSTest` now provides automated coverage for TUI Gateway event parsing and workflow contracts.

## Clarifications
### Session 2026-06-27
- No critical product questions were generated; existing source and docs define the TUI Gateway behavior boundaries.

### Session 2026-08-20
- The native TUI Gateway consumes the protocol event type `session.usage` (referred to as `Session.Usage` in the request) and reads cumulative `payload.usage.input` and `payload.usage.output` counters.
- Token totals are maintained per active workspace/session and displayed immediately above the existing Memory and GPU gauges; the transcript's `session.usage` bubble remains limited to its three-field agents/compressions/context summary.
