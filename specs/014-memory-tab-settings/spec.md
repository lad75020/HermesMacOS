# Feature Specification: Memory Tab and Tab Settings

**Feature Branch**: `014-memory-tab-settings`  
**Created**: 2026-06-28  
**Status**: Draft  
**Input**: User description: "In HermesMacOS application /skill speckit-specify 1. Allow the user to enable /disable « Ask Hermes » and « Chat with Hermes » tabs from the Settings window. 2. Add a new « Memory » tab that allows the user to visualize the content of Hindsight memory provider in a paginated list of readable memories. The user can filter using a text field. The user can delete pieces of memory"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Choose which prompt tabs are visible (Priority: P1)

A HermesMacOS user opens Settings and decides whether the main navigation should show Ask Hermes, Chat with Hermes, both, or neither, without affecting the rest of the app.

**Why this priority**: The requested Settings controls let users simplify the app surface immediately and must not break navigation or existing prompt workflows.

**Independent Test**: Open Settings, disable Ask Hermes, verify the Ask Hermes tab disappears from the side navigation while Chat with Hermes remains available, then re-enable it and repeat for Chat with Hermes.

**Acceptance Scenarios**:

1. **Given** Ask Hermes and Chat with Hermes are visible by default, **When** the user disables Ask Hermes in Settings, **Then** Ask Hermes is removed from the main tab list and the user remains on or is moved to an enabled tab.
2. **Given** Chat with Hermes is disabled, **When** the user reopens Settings and enables Chat with Hermes, **Then** Chat with Hermes returns to the main tab list without requiring an app restart.
3. **Given** both prompt tabs are disabled, **When** the user uses the main app, **Then** non-disabled tabs remain reachable and Settings still lets the user restore either prompt tab.

---

### User Story 2 - Browse Hindsight memories from a native Memory tab (Priority: P2)

A user opens a new Memory tab and reviews readable memory entries from the configured Hindsight memory provider in manageable pages.

**Why this priority**: The Memory tab is the core visibility surface for understanding what the current Hermes memory provider retains.

**Independent Test**: With a Hindsight provider containing more memories than one page, open Memory, move between pages, and verify each row shows readable memory content plus enough metadata to identify the item.

**Acceptance Scenarios**:

1. **Given** Hindsight memory provider data is available, **When** the user opens the Memory tab, **Then** the tab displays the first page of readable memories and pagination status.
2. **Given** additional pages exist, **When** the user selects Next or Previous, **Then** the Memory tab updates the visible rows and page range without losing the current filter text.
3. **Given** no memories exist or the provider is unavailable, **When** the tab loads, **Then** the user sees an empty or error state with a retry path rather than a blank panel or crash.

---

### User Story 3 - Filter and delete individual memories (Priority: P3)

A user narrows the Memory list with a text filter and deletes specific memory entries they no longer want retained.

**Why this priority**: Filtering makes the list usable at scale, and deletion gives users direct control over retained memories.

**Independent Test**: Enter a filter term that matches a subset of memories, delete one visible result after confirmation, and verify it disappears from the filtered list while other results remain.

**Acceptance Scenarios**:

1. **Given** the Memory tab shows many memories, **When** the user types in the filter field, **Then** the list updates to memories matching the filter and resets or clamps pagination to a valid page.
2. **Given** a visible memory row has a delete action, **When** the user confirms deletion, **Then** that memory is removed from the provider and no longer appears after refresh.
3. **Given** deletion fails or the provider is unreachable, **When** the delete action completes, **Then** the memory remains visible and the user sees a clear failure message.

### Edge Cases

- If a disabled Ask Hermes or Chat with Hermes tab is currently selected, selection must move to an enabled tab without losing that prompt tab's existing workspace state.
- If Settings changes tab visibility while another window is open, each window must apply the preference without corrupting per-window endpoint/profile state.
- If the Memory provider is configured as Hindsight but its local service, files, index, or runtime dependencies are unavailable, the Memory tab must show a recoverable status and retry control.
- If the Hindsight provider returns malformed, partially missing, or very long memory content, rows must remain readable, bounded, and safe to render.
- If a filter returns zero matches, the list must show an intentional empty result state and keep the filter editable.
- If a memory is deleted while pagination points beyond the new result count, the list must clamp to the last valid page.
- If deletion is requested for sensitive or unexpected content, the UI must require explicit confirmation and avoid logging raw memory text in errors.
- If endpoint, dashboard token, or local runtime settings are unavailable, unrelated non-memory tabs must remain usable.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide Settings controls that enable or disable visibility of the Ask Hermes tab and the Chat with Hermes tab independently.
- **FR-002**: System MUST persist each prompt-tab visibility preference and apply it when the app launches and when Settings changes during a running session.
- **FR-003**: System MUST default Ask Hermes and Chat with Hermes to visible for existing and new users unless the user changes the preference.
- **FR-004**: System MUST keep Settings reachable and keep all other enabled tabs navigable even when one or both prompt tabs are disabled.
- **FR-005**: System MUST preserve existing Ask Hermes and Chat with Hermes workspace, draft, profile, attachment, and session state while a tab is hidden, so re-enabling the tab restores the previous in-memory state for that window when still available.
- **FR-006**: System MUST add a Memory tab to the main navigation that presents readable memories from the configured Hindsight memory provider.
- **FR-007**: System MUST display memories in pages with clear current range, total or known-count status, Refresh, Previous, and Next controls.
- **FR-008**: System MUST provide a text filter in the Memory tab that narrows visible memory rows by user-entered text and preserves the filter while paging or refreshing.
- **FR-009**: System MUST show each memory row with readable content and enough non-sensitive metadata to distinguish entries, such as source/profile/date/status when available.
- **FR-010**: Users MUST be able to delete an individual memory entry from the Memory tab after an explicit confirmation step.
- **FR-011**: System MUST refresh or update the list after deletion so the removed memory no longer appears and pagination remains valid.
- **FR-012**: System MUST surface loading, empty, filtered-empty, provider-unavailable, and deletion-failed states in user-facing language.
- **FR-013**: System MUST avoid rendering raw provider debug output, stack traces, credentials, tokens, or unredacted sensitive logs inside memory rows or assistant chat bubbles.
- **FR-SEC**: System MUST preserve HermesMacOS security guardrails for endpoint validation, Keychain/encrypted retention, redaction, TLS pin approval, local filesystem approvals, and bounded process execution where applicable.
- **FR-INT**: System MUST preserve documented Hermes API/Dashboard/TUI Gateway contracts for existing tabs and must isolate Memory-provider access so it does not change Ask Hermes, Chat with Hermes, or dashboard request behavior.

### Key Entities *(include if feature involves data)*

- **Tab Visibility Preference**: User-controlled setting indicating whether Ask Hermes and Chat with Hermes appear in the main side-tab navigation.
- **Memory Tab**: Main navigation destination that loads, filters, pages, refreshes, and deletes Hindsight memory entries.
- **Memory Entry**: A readable retained memory item with stable identity, human-readable content, and available metadata needed for display and deletion.
- **Memory Filter**: User-entered text used to narrow memory entries by readable content or available display metadata.
- **Memory Page State**: Current page, page size, known total or continuation state, loading status, and last error for the Memory tab.
- **Memory Deletion Request**: A confirmed user action targeting one memory entry, with success or failure status surfaced in the list.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user can hide and restore Ask Hermes and Chat with Hermes independently from Settings in under 30 seconds without restarting the app.
- **SC-002**: With both prompt tabs hidden, at least one non-prompt tab remains selectable and Settings can restore either prompt tab.
- **SC-003**: The Memory tab displays a page of readable Hindsight memories within 3 seconds when the provider is reachable and contains existing data.
- **SC-004**: A user can move between memory pages and keep an active filter applied across page changes.
- **SC-005**: Filtering by text updates the visible results and clearly distinguishes no-provider, no-memory, and no-filter-match states.
- **SC-006**: Deleting one memory removes it from the refreshed Memory list while leaving unrelated memories visible.
- **SC-007**: Provider errors and deletion failures produce actionable user-facing messages without exposing raw secrets or stack traces.
- **SC-BUILD**: The `HermesMacOS` scheme builds successfully with Xcode or command-line `xcodebuild`.
- **SC-SMOKE**: The primary Settings and Memory user journeys can be validated independently with documented manual, mock-backed, or live-service smoke checks.

## Assumptions

- Ask Hermes and Chat with Hermes visibility controls hide or show the side-tab entries; they do not uninstall features, delete stored workspaces, or change API availability.
- The Memory tab is always present because it is the requested visibility surface for retained memories.
- Hindsight is the target memory provider for this feature; other memory providers are out of scope unless they can be represented through the same user-facing memory entry behavior later.
- Deletion targets individual memory entries, not bulk deletion or provider-wide reset.
- Memory content can be sensitive; list rendering, errors, and deletion confirmation must avoid unnecessary raw-content exposure beyond the selected row the user is intentionally viewing.
- Existing HermesMacOS test target and live-smoke policy are available for planning verification.
- Planning targets the latest installed Apple Swift toolchain observed for this workspace, Apple Swift 6.3.3 with Xcode 26.6, and keeps the app deployment floor at macOS 26.0 or above.

## Clarifications

### Session 2026-06-28

- No critical product questions were generated; the request and existing HermesMacOS/Hindsight context provide sufficient behavior boundaries for planning.
