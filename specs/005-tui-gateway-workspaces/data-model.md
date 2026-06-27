# Data Model: TUI Gateway Workspaces

## HermesTUIGatewayStore
- **Attributes**: connection state, WebSocket task, pending responses, session IDs, messages, event count, status/error, streaming/resuming flags.
- **Relationships**: owned by one TUI workspace and drives the SwiftUI transcript.
- **Validation**: pending requests fail on timeout/disconnect; event envelopes route by id/method/type.

## HermesTUIWorkspace
- **Attributes**: id/title, store, prompt draft, request-response drafts, selected attachment/path, attention acknowledgements.
- **Relationships**: managed by workspace controls and selected by ContentView.
- **Validation**: deletion disabled while connecting/streaming/resuming.

## HermesTUIGatewayMessage
- **Attributes**: role/type, title, text, timestamps, request metadata, resolved state.
- **Relationships**: rendered as transcript bubbles for text, events, attachments, errors, and interactive requests.

## HermesTUILiveSession
- **Attributes**: live session id, title/model/running state where returned.
- **Relationships**: shown in live-session menu and used by `session.activate`.

## JSONValue
- **Attributes**: JSON scalar/array/object representation.
- **Relationships**: encodes request params and decodes/summarizes event payloads.
