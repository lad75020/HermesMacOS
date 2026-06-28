# Data Model: Memory Tab and Tab Settings

## TabVisibilityPreference

Represents whether optional prompt tabs are shown in the main side navigation.

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `askHermesVisible` | Boolean | Yes | Defaults to `true` for existing and new users. |
| `chatHermesVisible` | Boolean | Yes | Defaults to `true` for existing and new users. |
| `updatedAt` | Date/time | No | Useful for diagnostics; not required for behavior. |

**Validation rules**:
- Missing values are treated as `true` for backward compatibility.
- The Settings UI must remain reachable regardless of both values.
- Hiding a tab must not destroy its existing in-memory workspace/session state.

**State transitions**:
- `visible -> hidden`: side-tab entry is removed; current selection moves if needed.
- `hidden -> visible`: side-tab entry returns and existing in-memory state is reused if still available.

## MemoryTabState

Window-owned state for the native Memory tab.

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `filterText` | String | Yes | Empty string means unfiltered list. |
| `pageIndex` | Integer | Yes | Zero-based page index, clamped after refresh/delete. |
| `pageSize` | Integer | Yes | Fixed default page size for v1; must be greater than zero. |
| `totalCount` | Integer or unknown | No | Provider may return an exact total or only a known page. |
| `entries` | Array of `MemoryEntry` | Yes | Current visible page. |
| `isLoading` | Boolean | Yes | True while list operation is in progress. |
| `deleteInFlightID` | Memory entry ID or none | No | Set while one row delete is active. |
| `statusMessage` | String or none | No | Concise user-facing state. |
| `errorMessage` | String or none | No | Sanitized user-facing error. |
| `requestToken` | Stable request token | No | Guards stale asynchronous responses. |

**Validation rules**:
- `pageIndex` must never be negative.
- `pageSize` must be bounded and non-zero.
- Filter changes reset or clamp to a valid page.
- Stale list/delete responses must not overwrite newer state.

**State transitions**:
- `idle -> loading -> loaded` for refresh/list success.
- `idle/loading -> failed` for provider unavailable or malformed result.
- `loaded -> deleting -> loaded` for successful delete and refresh.
- `loaded -> deleting -> deleteFailed` for failed delete with row retained.

## MemoryEntry

Readable item shown in the Memory tab.

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `id` | String | Yes | Stable provider identity used for deletion. |
| `content` | String | Yes | Readable memory text. |
| `preview` | String | Yes | Bounded display preview derived from content. |
| `kind` | String | No | Example: world, experience, or provider-defined type. |
| `source` | String | No | Provider/source hint if available. |
| `profile` | String | No | Hermes profile/bank hint if available. |
| `createdAt` | Date/time | No | Display metadata if provider returns it. |
| `updatedAt` | Date/time | No | Display metadata if provider returns it. |
| `confidence` | Number | No | Optional score/relevance returned by provider. |
| `metadataSummary` | String | No | Redacted, non-sensitive metadata for row subtitle. |

**Validation rules**:
- `id` and non-empty `content` are required for display/delete.
- Very long content is bounded in row previews and optionally expanded by the user.
- Provider debug output, credentials, tokens, and stack traces must not be displayed as row metadata.

## MemoryFilter

User-entered filter criteria for the Memory tab.

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `text` | String | Yes | Trimmed text used to search readable memory content and metadata. |
| `isActive` | Boolean | Yes | Derived from non-empty trimmed text. |

**Validation rules**:
- Empty or whitespace-only text means no filter.
- Filter text is not persisted unless a later feature explicitly requests it.
- Filter text is never sent to unrelated Ask/Chat/Hermes API requests.

## MemoryDeletionRequest

Confirmed destructive operation against one memory.

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `entryID` | String | Yes | Matches `MemoryEntry.id`. |
| `confirmationAccepted` | Boolean | Yes | Must be true before deletion starts. |
| `reason` | String | No | Default can identify user-initiated Memory tab deletion. |
| `startedAt` | Date/time | No | For diagnostics/status. |
| `result` | Success/failure/skipped | No | Set after provider response. |

**Validation rules**:
- Delete cannot run without explicit confirmation.
- Only one row delete should be active at a time in v1.
- Failure keeps the entry visible and presents a sanitized error.
