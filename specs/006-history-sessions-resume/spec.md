# Feature Specification: History and Session Resume

**Feature Branch**: `feature/time-machine-history-sessions-resume`  
**Created**: 2026-06-27  
**Status**: Draft  
**Input**: User description: "Feature: History and Session Resume. Description: Lets users search conversations, browse stored sessions, inspect messages, filter by profile, and resume compatible Ask, Chat, or TUI sessions. Relevant files: HermesMacOS/HermesHistoryView.swift, HermesMacOS/HermesDashboardHistorySearch.swift, docs/reference-api-and-storage.md. Focus on this feature only; do not modify other features."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Search dashboard conversation history (Priority: P1)

A user searches all dashboard conversations using natural language or SQLite FTS-style syntax, optionally filters by profile, and sees matching conversations with initial/final messages.

**Why this priority**: Search is the primary discovery path for prior conversations.

**Independent Test**: Configure a reachable dashboard, enter a query, run search, and verify results, match counts, profile filtering, cancellation, and error states.

**Acceptance Scenarios**:

1. **Given** a dashboard URL and session token are available, **When** the user searches, **Then** HermesMacOS requests `api/sessions/search/conversations` with `q`, `limit`, `role`, and optional `profile` query items.
2. **Given** results contain messages and matches, **When** the search completes, **Then** the UI shows matched message/session counts and conversation summaries.
3. **Given** a non-all profile filter is selected, **When** results are returned, **Then** only conversations matching the normalized profile remain visible.
4. **Given** the dashboard token is stale, **When** a 401 occurs, **Then** the app refreshes the token and retries once.

---

### User Story 2 - Inspect and resume a search result (Priority: P2)

A user expands a result, reviews selected messages, then resumes the conversation into Ask Hermes, Chat with Hermes, or TUI Gateway where supported.

**Why this priority**: Search is valuable when it can restore useful work into the right runtime surface.

**Independent Test**: Expand a search result, verify displayed initial/final messages, invoke each resume option, and verify disabled states while target runtimes are busy.

**Acceptance Scenarios**:

1. **Given** a result is expanded, **When** the disclosure content renders, **Then** the user sees the initial user prompt and final assistant response when present.
2. **Given** Ask or Chat is streaming, **When** resume controls render, **Then** the matching resume button is disabled with explanatory help.
3. **Given** TUI Gateway is busy, **When** resume controls render, **Then** Resume to TUI Gateway is disabled.
4. **Given** a compatible result is resumed, **When** the user chooses a target, **Then** the corresponding resume callback receives the conversation result.

---

### User Story 3 - Browse stored sessions with pagination and details (Priority: P3)

A user opens Sessions, pages through non-cron stored sessions, changes display order, loads a session’s messages, and resumes it.

**Why this priority**: Browsing complements search for users who remember time/order rather than keywords.

**Independent Test**: Load the sessions list, page forward/back, switch display order, expand a session to fetch messages, and resume to Ask or TUI.

**Acceptance Scenarios**:

1. **Given** sessions exist, **When** the sessions view loads, **Then** it fetches `api/sessions`, excludes cron-initiated sessions, and shows a stable page range.
2. **Given** a session is expanded, **When** details are not cached, **Then** the app fetches `api/sessions/{session_id}/messages`, caches the result, and renders messages.
3. **Given** the user changes display order, **When** the list reloads, **Then** sessions are ordered chronologically or reverse chronologically as selected.
4. **Given** a stored session should resume to TUI, **When** the user chooses that action, **Then** the selected session summary is forwarded to the TUI resume flow.

### Edge Cases

- Empty search input must not send a network request and should prompt the user to enter a query.
- Search or sessions network cancellation must leave loading flags and dashboard HTTP activity flags cleared.
- Dashboard 401 responses should refresh the session token and retry once.
- Dashboard URL construction failures must surface a clear invalid-dashboard error.
- Conversation/message payloads may contain flexible content as strings, arrays, or objects; readable text extraction must be resilient.
- Cron/scheduled sessions should be hidden from the stored Sessions browser.
- A session summary may lack title/model/profile metadata; display must fall back to preview or id without crashing.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide a History search UI backed by dashboard `api/sessions/search/conversations`.
- **FR-002**: System MUST support profile filtering and normalize empty profiles to `default`.
- **FR-003**: System MUST display matched message and session counts for completed searches.
- **FR-004**: System MUST decode conversation/session/message payloads with flexible title, profile, id, and content shapes.
- **FR-005**: System MUST support search cancellation and clear active request state.
- **FR-006**: System MUST allow expanded results to resume to Ask Hermes, Chat with Hermes, or TUI Gateway with target busy-state disabling.
- **FR-007**: System MUST provide a Sessions browser backed by dashboard `api/sessions` and `api/sessions/{session_id}/messages`.
- **FR-008**: System MUST filter cron-initiated sessions from the Sessions browser.
- **FR-009**: System MUST support pagination and chronological/reverse chronological display order for stored sessions.
- **FR-010**: System MUST cache loaded session conversation details by session id and surface per-session load errors.
- **FR-SEC**: System MUST obtain dashboard session tokens through `HermesDashboardClient`, send them only in `X-Hermes-Session-Token`, and reuse endpoint/TLS validation through shared network helpers.
- **FR-INT**: System MUST preserve dashboard history/search/session API contracts documented in `docs/reference-api-and-storage.md`.

### Key Entities *(include if feature involves data)*

- **HermesHistoryView**: Search UI with query, profile filter, result disclosure, resume actions, and status/error reporting.
- **HermesDashboardHistorySearchSession**: Observable search state, token handling, search request orchestration, cancellation, filtering, and status.
- **HermesDashboardConversationResult**: Search/detail result containing session metadata, matches, messages, and display title fallback.
- **HermesDashboardConversationMessage**: Flexible decoded conversation message with role, content, timestamp, and tool metadata.
- **HermesSessionsStore**: Stored session pagination, filtering, detail fetching, caching, cancellation, and status/error state.
- **HermesAgentSessionSummary**: Stored session row metadata used for browsing, filtering, display, and resume.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user can search dashboard history and see matching conversations with counts.
- **SC-002**: Profile filtering narrows search results to the selected normalized profile.
- **SC-003**: Expanded search results show readable initial/final messages and offer valid resume targets.
- **SC-004**: A user can browse non-cron stored sessions, change display order, page results, and load details.
- **SC-005**: 401 token refresh retry, cancellation, empty search, and invalid dashboard failures produce stable UI states.
- **SC-BUILD**: The `HermesMacOS` scheme builds successfully with Xcode or command-line `xcodebuild`.
- **SC-SMOKE**: The primary History/Sessions flows can be validated independently with documented dashboard smoke checks.

## Assumptions

- This pass documents the existing History and Sessions implementation and does not add new dashboard API capabilities.
- Live verification requires a reachable Hermes Dashboard with session history data.
- No automated test target exists yet.

## Clarifications

### Session 2026-06-27

- No critical product questions were generated; existing source and docs define the History/Sessions behavior boundaries.
