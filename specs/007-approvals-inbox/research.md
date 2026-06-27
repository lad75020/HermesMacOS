# Research: Approvals Inbox

## Decision 1: Merge remote and local approvals in one inbox

**Decision**: Display `/v1/approvals` items and `HermesLocalApprovalCenter` pending items together.

**Rationale**: Users should not need to know whether a trust decision originated from the gateway, local filesystem policy, or TLS certificate approval.

## Decision 2: Preserve local fallback on remote refresh failure

**Decision**: If remote refresh fails, keep local approvals visible and report the remote error.

**Rationale**: Local certificate/filesystem decisions may still unblock the app even when the gateway is unavailable.

## Decision 3: Validate secret-bearing approval requests

**Decision**: Reuse `HermesEndpointSecurity.validateSensitiveURL` before adding Authorization headers.

**Rationale**: Approval APIs may carry credentials and trust decisions; remote plaintext HTTP must be blocked.

## Decision 4: Verify with build plus live/local smoke checks

**Decision**: Use Xcode build and documented smoke checks.

**Rationale**: Full behavior depends on live pending approvals or local approval center state and no test target exists.
