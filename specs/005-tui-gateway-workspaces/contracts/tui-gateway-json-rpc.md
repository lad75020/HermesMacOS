# Contract: TUI Gateway JSON-RPC

## Transport
- Resolve Dashboard base URL, validate sensitive URL, obtain dashboard session token, request `api/auth/ws-ticket` when available, convert `http`/`https` to `ws`/`wss`, and connect to `api/ws`.

## Requests
- Outgoing JSON-RPC requests include `jsonrpc: "2.0"`, generated `id`, method, and params.
- Responses are matched by `id`; errors surface `error.message` where available.
- Pending responses must timeout/fail on disconnect.

## Methods
- `session.create`, `prompt.submit`, `input.detect_drop`, `session.interrupt`, `session.close`, `session.active_list`, `session.activate`, `session.resume`, `approval.respond`, `clarify.respond`, `sudo.respond`, `secret.respond`.

## Events
- Notifications use `method: "event"` with params containing `type`, optional `session_id`, and payload.
- `message.*`, reasoning/thinking deltas, tool events, request events, status updates, background completion, errors, and unknown events render as transcript bubbles.

## Security
- Prefer ticket auth, reuse TLS/self-signed policy from configured API settings, keep sudo/secret input in secure fields, and avoid logging secrets into transcript text.
