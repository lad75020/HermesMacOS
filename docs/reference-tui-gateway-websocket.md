# TUI Gateway WebSocket reference

The TUI Gateway tab is a native SwiftUI client for the dashboard WebSocket JSON-RPC protocol. It is implemented mainly in `HermesTUIGatewayView.swift` through `HermesTUIGatewayStore`, `HermesTUIWorkspace`, and `HermesTUIGatewayWorkspacesView`.

## Transport setup

The selected workspace connects with this sequence:

1. Resolve the dashboard base URL with `HermesDashboardClient.shared.resolvedBaseURL(dashboardBaseURL:apiBaseURL:)`.
2. Validate the resolved URL with `HermesEndpointSecurity.validateSensitiveURL`.
3. Extract or reuse the dashboard session token with `HermesDashboardClient.shared.sessionToken(baseURL:apiSettings:)`.
4. Try to request a one-time WebSocket ticket from `POST api/auth/ws-ticket` with the dashboard session token in `X-Hermes-Session-Token`.
5. Build the WebSocket URL for `api/ws` by converting `http` to `ws` and `https` to `wss`.
6. Prefer a query parameter named `ticket` when the ticket route succeeds. Fall back to a query parameter named `token` when no ticket is available.
7. Open `URLSessionWebSocketTask` using `HermesNetworkSessionFactory.session(for:)` so configured TLS behavior is reused.
8. Start a receive loop that reads both text and binary WebSocket messages as UTF-8 JSON.

A normal **Connect** action passes `createSessionIfMissing: true`, so a new live TUI session is created after the WebSocket opens when the workspace has no current session. Resume flows pass `createSessionIfMissing: false` so they do not create a blank session before `session.resume`.

## JSON-RPC request envelope

Outgoing requests use JSON-RPC 2.0:

```json
{
  "jsonrpc": "2.0",
  "id": "macos-1",
  "method": "session.create",
  "params": {}
}
```

`HermesTUIGatewayStore.request(_:params:timeoutSeconds:)` generates IDs as `macos-<counter>`, encodes params as `JSONValue`, sends a string WebSocket message, then waits for a response with the same ID.

Pending responses are stored by request ID in `pendingResponses`. Each request races the WebSocket response against a timeout. On timeout, disconnect, or cancellation, the continuation is failed and removed.

## JSON-RPC response envelope

Responses are matched by `id`:

```json
{
  "jsonrpc": "2.0",
  "id": "macos-1",
  "result": {
    "session_id": "live-session-id"
  }
}
```

Errors are decoded from the envelope `error` object. The app surfaces `error.message` when present and otherwise displays a generic JSON-RPC error code.

## Event envelope

Gateway events arrive as JSON-RPC notifications with `method` set to `event`:

```json
{
  "jsonrpc": "2.0",
  "method": "event",
  "params": {
    "type": "message.delta",
    "session_id": "live-session-id",
    "payload": {
      "text": "partial assistant text"
    }
  }
}
```

`HermesTUIGatewayStore.handleWebSocketText(_:)` treats messages with an `id` as request responses. Messages whose method is `event` are counted in `eventCount` and routed to `handle(_:)`.

## Request methods used by HermesMacOS

| Method | When sent | Important params | Result handling |
| --- | --- | --- | --- |
| `model.options` | After connecting, selecting a profile, or refreshing models | `profile`, optional `session_id`, `refresh` | Reads the selected provider row, including per-model `capabilities` metadata such as `fast` and `reasoning`. |
| `session.create` | Connect creates a new session, or the user presses **New session** | profile/model/provider fields, optional `fast`, optional `reasoning_effort` | Stores `session_id`, optional `stored_session_id`, clears messages, marks `Session ready`, refreshes live sessions. |
| `config.set` | The user changes the reasoning pill on an idle live session | `session_id`, `key: "reasoning"`, `value` | Applies the session-scoped effort before the next inference. |
| `prompt.submit` | The user sends a prompt | `session_id`, `text`, optional `reasoning_effort` | Starts streaming state before the call; response success changes status to `Streaming`. The effort field is forward-compatible metadata; the live setting comes from `session.create` or `config.set`. |
| `input.detect_drop` | Image attachment with a local path | `session_id`, `text` containing quoted path plus prompt | Requires `matched: true`; returned `text` becomes the prompt submitted through `prompt.submit`. |
| `session.interrupt` | User presses **Interrupt** | `session_id` | Clears local streaming state and appends an interrupt event. |
| `session.close` | User presses **Close session** | `session_id` | Clears live/stored IDs, resets the title, and refreshes live sessions. |
| `session.active_list` | After connect/session changes or **Refresh live sessions** | `current_session_id` | Rebuilds the live-session menu from returned `sessions`. |
| `session.activate` | User picks a live session from the menu | `session_id` for an already-live TUI session | Restores live ID, stored key, title, running state, and messages. |
| `session.resume` | History or Sessions resumes a stored session into TUI Gateway | stored `session_id` | Restores live ID, stored key from `resumed`, `stored_session_id`, or `session_key`, messages, title, and running state. |
| `approval.respond` | User answers an approval bubble | `session_id`, `choice`, `all` | Marks the request bubble resolved. |
| `clarify.respond` | User answers a clarification bubble | `request_id`, `answer` | Marks the request bubble resolved or skipped. |
| `sudo.respond` | User answers a sudo-password bubble | `request_id`, `password` | Marks the request bubble resolved or skipped. |
| `secret.respond` | User answers a secret-value bubble | `request_id`, `value` | Marks the request bubble resolved or skipped. |

`session.activate` and `session.resume` are intentionally separate. Activate switches to an already-live TUI Gateway session. Resume rehydrates a stored dashboard/session database entry into a live TUI session.

## Reasoning capability and effort

`model.options` provider rows expose `capabilities` keyed by model ID. HermesMacOS uses the currently selected model's `reasoning` value first; an explicit `false` disables the reasoning control even if the selected profile's default model supports reasoning. When the selected model has no capability row, the profile's `reasoning` object (`supported`, `effort_levels`) and the established model-support helper provide a conservative fallback.

The reasoning menu uses only valid Hermes values: `none`, `minimal`, `low`, `medium`, `high`, `xhigh`, `max`, and `ultra` (shown as Off, Minimal, Low, Medium, High, Extra High, Max, and Ultra). A new live session receives `reasoning_effort` only when its selected model supports reasoning. Changing the menu on an existing idle session immediately sends session-scoped `config.set`; a resumed `session.info`/resume `info` value updates the workspace only when it remains supported by the selected model.

## Event types handled by the transcript

| Event type | UI behavior |
| --- | --- |
| `gateway.ready` | Updates status to `Gateway ready`. |
| `session.info` | Updates the session title with the short session ID and model when available. When `payload.usage.context_used` is present, updates the active assistant bubble's context counter, or the latest assistant bubble only while the current turn is safely active. |
| `message.start` | Marks the workspace streaming, resets stream grouping, and sets status to `Hermes is responding`. |
| `message.delta` | Appends assistant text to the active assistant bubble, creating a new bubble when the stream type changes. |
| `message.complete` | Finalizes assistant text, attaches `payload.usage.context_used` to that response before stream grouping resets, then stops streaming. If no deltas arrived, creates an assistant bubble from final text. If one contiguous message segment exists, replaces it with final text. |
| `reasoning.delta` | Appends or creates a `Reasoning` event bubble. |
| `thinking.delta` | Appends or creates a `Thinking` event bubble. |
| Any other `*.delta` | Appends or creates an event bubble titled from the event type. |
| `tool.start` | Appends a `Tool started` event and updates status with the tool name. |
| `tool.progress`, `tool.generating` | Appends `Tool progress` events and status previews. |
| `tool.complete` | Appends a `Tool complete` event. |
| `approval.request` | Appends an interactive approval request bubble. |
| `clarify.request` | Appends an interactive clarification request bubble. |
| `sudo.request` | Appends an interactive secure sudo request bubble. |
| `secret.request` | Appends an interactive secure secret request bubble. |
| `status.update` | Appends a status event and shortens the visible status card text. |
| `background.complete` | Appends a background completion event. |
| `error` | Stops streaming, clears stream grouping, stores the error message, and appends a gateway error event. |
| Unknown event type | Appends a generic event bubble with a compact payload summary. |

## Stream grouping rules

The store groups consecutive delta chunks by event/content type with these fields:

- `activeStreamMessageID`
- `activeStreamContentType`
- `currentTurnReceivedMessageDelta`
- `currentTurnMessageDeltaSegmentCount`

Consecutive chunks of the same type append to one bubble. When the type changes, a new bubble is created. Non-stream events reset the active stream group so later deltas do not merge across tool/status/request boundaries.

This keeps assistant text, reasoning, thinking, and tool output readable while preserving the backend event contract.

## Current context token counter

Assistant response headers show a compact counter beside **Hermes**, for example `Context 12.3K`, when the gateway reports real current-window occupancy. The only accepted used-token source is `payload.usage.context_used` on `message.complete` or `session.info`; JSON numbers and numeric strings are accepted. Optional `context_max` and `context_percent` enrich the accessibility label.

The counter never falls back to `usage.total` or another cumulative session total. If `context_used` is absent, invalid, or zero, no counter is shown. Readings update an existing assistant response in place and never create transcript bubbles. Session identity, active-turn, user-turn, disconnect, create, activate, resume, and close boundaries prevent a reading from being attached to a response from another session or turn.

## Workspace model

`HermesTUIWorkspace` wraps one `HermesTUIGatewayStore` plus UI-only composer state:

- draft prompt text
- request-response drafts keyed by transcript message ID
- selected `HermesPromptAttachment`
- selected local attachment path
- selected reasoning effort (default `medium`)
- acknowledged completion and failure tokens for numbered-button attention state

`ContentView` owns the workspace array and selected workspace ID. `HermesTUIGatewayWorkspacesView` injects the selected workspace into `HermesTUIGatewayView` and renders the plus and numbered selectors beside the tab title.

## Attachment flow

Attachments are prepared before `prompt.submit`:

1. The file picker loads a `HermesPromptAttachment` from the selected file and stores the local path.
2. Sending calls `HermesTUIGatewayStore.submitPrompt(_:attachment:attachmentPath:)`.
3. `promptPayload` transforms the prompt text according to attachment type.
4. If an attachment was included, the transcript appends an `input.attachment` event bubble.
5. The final text is appended as the user message and sent through `prompt.submit`.

Native image attachments are the only case that perform a WebSocket call before `prompt.submit`: `input.detect_drop` is used to let the gateway attach the local image path natively.

## Security and failure behavior

- The WebSocket base URL passes the same sensitive-URL validation used by other sensitive dashboard operations.
- TLS and self-signed certificate behavior come from `HermesNetworkSessionFactory.session(for:)` and the configured `HermesAPISettings`.
- Dashboard session tokens are not hardcoded into source. They are extracted from the dashboard HTML and cached per dashboard base URL by `HermesDashboardClient`.
- The app prefers one-time WebSocket tickets over long-lived dashboard session tokens when the dashboard supports ticket issuance.
- Disconnect cancels the receive loop, closes the WebSocket with normal closure, clears streaming/resuming flags, and fails all pending JSON-RPC continuations.
- Receive-loop errors mark the workspace disconnected, stop streaming, store the localized error, and fail pending calls.

## Source map

| Source | Responsibility |
| --- | --- |
| `HermesTUIGatewayView.swift` | TUI Gateway store, JSON-RPC envelopes, event routing, workspace model, view, composer, bubbles, and request controls. |
| `ContentView.swift` | Owns TUI workspace array, selected workspace binding, History/Sessions resume callbacks, and tab switching. |
| `HermesSecurityUtilities.swift` | Dashboard token extraction, endpoint security validation, network session factory, and response validation used during setup. |
| `HermesModelsAPI.swift` | Shared `JSONValue` and attachment model used by the TUI Gateway prompt preparation path. |
| `HermesHistoryView.swift` | History and Sessions row actions that can invoke Resume to TUI Gateway through callbacks. |
