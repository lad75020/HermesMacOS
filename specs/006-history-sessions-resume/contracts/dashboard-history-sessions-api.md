# Contract: Dashboard History and Sessions API

## Dashboard authentication

- Resolve dashboard base URL through `HermesDashboardClient`.
- Extract or refresh dashboard session token from dashboard HTML.
- Send token as `X-Hermes-Session-Token`.
- On 401, refresh token and retry the failing history/session request once.

## Conversation search

- `GET api/sessions/search/conversations`
- Query items:
  - `q`: search query text
  - `limit`: result limit
  - `role`: comma-separated roles, currently `user,assistant,tool`
  - `profile`: optional selected profile when not `all`
- Response shape includes `results`, `limit`, `offset`, `matched_messages`, and `matched_sessions`.
- Each result includes `session_id`, `session`, `matches`, `messages`, and optional title metadata.

## Sessions list

- `GET api/sessions?limit=<n>&offset=<n>`
- Response shape includes `sessions`, `total`, `limit`, and `offset`.
- HermesMacOS discovers visible total, filters cron/scheduled sessions, orders by selected display order, and displays fixed-size pages.

## Session messages

- `GET api/sessions/{session_id}/messages`
- Response shape includes `session_id` and `messages`.
- Loaded details are cached by session id and converted into `HermesDashboardConversationResult` for display/resume.

## Resume callbacks

- Search results may resume to Ask Hermes, Chat with Hermes, or TUI Gateway.
- Stored session summaries may resume to Ask Hermes or TUI Gateway after details are loaded where needed.
- Target runtime busy states disable incompatible resume actions.

## Security and failure behavior

- Dashboard token values are not embedded in URLs.
- Shared network session settings and response validation are reused.
- Cancellation clears loading flags and avoids stale response writes.
