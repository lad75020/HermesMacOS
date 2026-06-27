# Research: History and Session Resume

## Decision 1: Keep search on dashboard conversation endpoint

**Decision**: Use `api/sessions/search/conversations` for full-text History search.

**Rationale**: The endpoint returns complete conversation result structures, matches, messages, totals, and session metadata needed by the native results view.

**Alternatives considered**:
- Search local files directly: rejected because dashboard holds the indexed/session database and handles cross-channel conversation search.
- Use the Sessions list endpoint for keyword search: rejected because it lacks full-text match context.

## Decision 2: Filter profile client-side after search response

**Decision**: Include profile in query items where available and also normalize/filter returned results client-side.

**Rationale**: Client-side normalization provides stable behavior when profiles are missing, empty, or represented under alternate metadata keys.

## Decision 3: Hide cron-initiated sessions in Sessions browser

**Decision**: Sessions browser filters cron/scheduled sessions before pagination display.

**Rationale**: User-facing resume workflows should focus on interactive sessions and avoid noisy scheduled jobs.

## Decision 4: Verify with build plus live dashboard smoke checks

**Decision**: Use Xcode build and documented live checks against a dashboard with history data.

**Rationale**: No automated test target exists and full behavior depends on dashboard API state/token/session data.
