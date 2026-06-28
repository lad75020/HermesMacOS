# UI and Provider Contract: Memory Tab and Tab Settings

This contract describes the user-visible behavior and provider boundary for implementation. It is not an external HTTP API contract.

## Settings tab-visibility contract

### Defaults

- Ask Hermes is visible when no stored preference exists.
- Chat with Hermes is visible when no stored preference exists.
- Preferences are non-sensitive and may use app preference storage.

### Settings controls

- Settings presents two independent toggles:
  - `Ask Hermes tab`
  - `Chat with Hermes tab`
- Toggle changes apply without app restart.
- The controls must remain accessible even if both prompt tabs are hidden.

### Navigation behavior

- Hidden prompt tabs are removed from the main side-tab list.
- If the selected tab becomes hidden, the app selects the first available enabled tab using a deterministic fallback order.
- Hiding a prompt tab must not clear drafts, attachments, profile selections, transcripts, or workspace/session objects that are still held by the current window.
- Re-enabling a tab restores its side-tab entry and reuses existing in-memory state where available.

## Memory tab list contract

### Load request

Inputs:
- `filterText`: optional string.
- `pageIndex`: zero-based integer.
- `pageSize`: bounded positive integer.
- Active Hermes home/profile/provider context.

Expected result:
- A list of `MemoryEntry` rows for the requested page.
- A total count when available, or a known-count/has-more status when the provider cannot return exact totals.
- Sanitized status or error text.

### Row display

Each visible memory row shows:
- Bounded readable memory preview/content.
- Stable identity or short identifier.
- Non-sensitive metadata such as type, source, profile/bank, date, or score when available.
- A delete action.

Rows must not show:
- Raw stack traces.
- Provider debug dumps.
- API keys, dashboard tokens, Hindsight credentials, or unrelated prompt/debug logs.

### Pagination

- Controls: Refresh, Previous, Next.
- Status: current visible range and total/known count.
- Previous is disabled on the first page.
- Next is disabled when there is no known next page.
- Page index is clamped after filter changes, refreshes, and deletes.

### Filtering

- Empty filter text shows the unfiltered list.
- Non-empty filter text narrows rows by readable memory content or display metadata.
- Filtering preserves the text while paging and refreshing.
- A filtered zero-result state is distinct from no-provider and no-memory states.

## Memory delete contract

### Confirmation

Before deletion starts, the user must confirm a row-specific destructive prompt containing enough context to identify the target memory without dumping excessive sensitive content.

### Delete request

Inputs:
- `entryID`: provider memory identity.
- `reason`: user-initiated Memory tab deletion.

Expected success:
- Provider reports the memory removed or invalidated.
- The row disappears after refresh.
- Pagination remains valid.

Expected failure:
- The row remains visible.
- The user sees a concise sanitized error.
- No raw provider stack traces or credentials are logged or rendered.

## Hindsight provider boundary

- Swift must use a provider-level helper boundary for Hindsight memory operations.
- The helper initializes the configured Hindsight memory provider with the active Hermes home/profile context.
- List/filter/delete operations must not query or mutate provider storage internals directly from Swift.
- Provider operations must be bounded by timeout and cancellation/stale-response guards.
- Existing Ask Hermes, Chat with Hermes, Dashboard, TUI Gateway, and cancellation request contracts must remain unchanged.

## Test contract

Default deterministic tests must cover:
- Prompt-tab default visibility and toggling logic.
- Selection fallback when a selected tab is hidden.
- Preservation of in-memory prompt tab state while hidden.
- Memory page clamping after filter/delete.
- Filtered-empty vs provider-empty vs provider-error states.
- Successful delete removes one row from fixture state.
- Failed delete preserves row and sanitizes error text.
- Hindsight helper JSON decoding tolerates optional metadata and rejects missing id/content.

Live smoke checks are opt-in and must not run as part of default tests.
