# Feature Specification: TUI Gateway Workspaces

**Feature Branch**: `feature/time-machine-tui-gateway-workspaces`  
**Created**: 2026-06-27  
**Status**: Draft  
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

---

### User Story 2 - Send prompts, attachments, and receive streamed events (Priority: P2)
A user submits prompts and attachments through JSON-RPC and sees assistant, reasoning, thinking, tool, status, background, and error events rendered as distinct transcript bubbles.

**Why this priority**: This is the core TUI execution experience inside HermesMacOS.

**Independent Test**: Send a prompt, observe `message.start`, deltas, `message.complete`, and attachment event bubbles.

**Acceptance Scenarios**:
1. **Given** a live session exists, **When** the user submits a prompt, **Then** the app sends `prompt.submit` and renders streamed events.
2. **Given** an image attachment with a local path is selected, **When** the user sends it, **Then** `input.detect_drop` runs before `prompt.submit` and an attachment bubble appears.
3. **Given** consecutive deltas change event type, **When** the transcript renders, **Then** assistant, reasoning, thinking, and tool/status output remain separate bubbles.

---

### User Story 3 - Manage multiple TUI workspaces and sessions (Priority: P3)
A user creates, switches, deletes, activates, interrupts, closes, and resumes TUI workspaces without mixing transcript/session state.

**Why this priority**: Workspace isolation makes concurrent long-running TUI work practical.

**Independent Test**: Create two workspaces, connect/send in one, switch/delete/resume where allowed, and verify state isolation and attention indicators.

**Acceptance Scenarios**:
1. **Given** two TUI workspaces exist, **When** the user switches, **Then** draft, attachment, live session, transcript, and WebSocket state are preserved per workspace.
2. **Given** a workspace is connecting/streaming/resuming, **When** the user attempts deletion, **Then** deletion is disabled until the risky state ends.
3. **Given** a stored History/Sessions row is resumed, **When** `session.resume` succeeds, **Then** messages, title, live ID, stored key, and running state restore into the selected workspace.

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
- **FR-SEC**: System MUST validate dashboard URLs, reuse TLS/self-signed certificate policy, prefer one-time tickets, and protect secret/sudo input.
- **FR-INT**: System MUST preserve the documented dashboard WebSocket JSON-RPC protocol.

### Key Entities *(include if feature involves data)*
- **HermesTUIGatewayStore**: WebSocket connection, JSON-RPC request/response matching, event routing, session state, transcript, pending continuations, and failures.
- **HermesTUIWorkspace**: Per-workspace store plus draft, request-response drafts, attachment state, and attention acknowledgements.
- **HermesTUIGatewayMessage**: Transcript bubble for user, assistant, reasoning, tools, status, attachments, requests, errors, and background events.
- **HermesTUILiveSession**: Live session menu row returned from `session.active_list`.
- **JSONValue**: Shared value type for JSON-RPC params and event payload summaries.

## Success Criteria *(mandatory)*
### Measurable Outcomes
- **SC-001**: Connect creates a live TUI session and reaches `Session ready`.
- **SC-002**: A submitted prompt renders streamed assistant output and completion state.
- **SC-003**: Image attachment flow runs `input.detect_drop` and adds an attachment event bubble.
- **SC-004**: Two workspaces preserve independent connection, draft, attachment, and transcript state.
- **SC-005**: Approval/clarify/sudo/secret requests can be answered and marked resolved.
- **SC-BUILD**: The `HermesMacOS` scheme builds successfully with Xcode or command-line `xcodebuild`.
- **SC-SMOKE**: The primary TUI Gateway journey can be validated independently with documented dashboard smoke checks.

## Assumptions
- This pass documents the existing TUI Gateway implementation and does not add new WebSocket methods.
- Live verification requires a reachable Hermes Dashboard exposing `api/ws` and auth routes.
- No automated test target exists yet.

## Clarifications
### Session 2026-06-27
- No critical product questions were generated; existing source and docs define the TUI Gateway behavior boundaries.
