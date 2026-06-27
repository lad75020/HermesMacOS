# Data Model: Approvals Inbox

## HermesApprovalItem

- **Attributes**: id, sessionKey, queuePosition, kind, title, command, description, patternKey, patternKeys, createdAt, surface, scopeOptions.
- **Relationships**: decoded from remote API or synthesized from local approval center requests; rendered as inbox rows.
- **Validation**: display kind maps known approval kinds to friendly labels; age handles missing timestamps as Pending.

## HermesApprovalsResponse

- **Attributes**: approvals, count.
- **Relationships**: decoded from `/v1/approvals`.

## HermesApprovalResolveBody

- **Attributes**: choice, resolveAll, sessionKey.
- **Relationships**: encoded for `/v1/approvals/resolve`.
- **Validation**: `resolveAll` is false for single-row resolution.

## HermesApprovalsInboxStore

- **Attributes**: approvals, status, lastErrorMessage, isLoading, resolvingIDs, lastUpdated, autoRefresh.
- **Relationships**: drives `HermesApprovalsInboxView` and calls remote/local resolution targets.
- **Validation**: skips refresh while loading; skips resolve when id is already resolving; local ids route locally.

## HermesApprovalsInboxView

- **Attributes**: API settings, dashboard URL, store, connected host/window labels.
- **Relationships**: displays store state and invokes refresh/resolve actions.

## HermesLocalApprovalCenter

- **Attributes**: pending local filesystem/TLS requests with id, kind, command, description, fingerprint, createdAt.
- **Relationships**: supplies local approval rows and resolves local decisions.
