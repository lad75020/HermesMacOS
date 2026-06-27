# Data Model: History and Session Resume

## HermesDashboardHistorySearchSession

- **Attributes**: query, results, loading/search flags, dashboard HTTP flag, status, last error, matched message/session counts, attention tokens.
- **Relationships**: owned by History tab and renders `HermesDashboardConversationResult` rows.
- **Validation**: empty queries do not send; cancellation clears request state; 401 refreshes token and retries once.

## HermesDashboardConversationResult

- **Attributes**: sessionID, session metadata, matches, messages, title.
- **Relationships**: displayed in search result disclosures and passed to Ask/Chat/TUI resume callbacks.
- **Validation**: title falls back through direct title, metadata, first user prompt, session id, and normalized text.

## HermesDashboardSessionInfo

- **Attributes**: id, source, userID, profile, model, title, startedAt, endedAt, messageCount.
- **Relationships**: nested in conversation results and summary rows.
- **Validation**: source drives icon; missing profile normalizes to default.

## HermesDashboardConversationMessage

- **Attributes**: id, role, content, timestamp, toolName.
- **Relationships**: displayed in result/message rows and used for initial/final response summaries.
- **Validation**: id accepts integer/string fallback; content decodes from string, array, or flexible object.

## HermesSessionsStore

- **Attributes**: sessions, total, pageIndex, displayOrder, loading/status/error state, detail cache, loading detail sets, per-session errors.
- **Relationships**: owned by Sessions view and fetches details into `HermesDashboardConversationResult`.
- **Validation**: excludes cron sessions, clamps requested pages, caches details, and cancels list/detail tasks safely.

## HermesAgentSessionSummary

- **Attributes**: id, source, model, title, timestamps, messageCount, preview, active flag, profile, endReason.
- **Relationships**: rendered in Sessions list and converted into conversation results for resume.
- **Validation**: display title falls back through title, preview, id; cron-like sources are filtered.
