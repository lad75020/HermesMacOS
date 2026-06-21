# Feature Specification: Security and Local Access

**Feature Branch**: `feature/time-machine-security-and-local-access`

**Created**: 2026-06-21

**Status**: Draft

**Input**: User description: "Feature: Security and Local Access. Description: Protects API keys, SSH keys, retained local data, TLS trust decisions, and local filesystem/process access for sensitive Hermes operations. Relevant files: SECURITY.md, HermesMacOS/HermesSecurityUtilities.swift, HermesMacOS/HermesModelsAPI.swift, HermesMacOS/SettingsView.swift, HermesMacOS/HermesApprovalsInboxView.swift. Focus on this feature only; do not modify other features."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Keep credentials protected (Priority: P1)

A user configures API and SSH credentials while expecting secrets to be stored outside ordinary preferences and unavailable until the app has passed its startup unlock gate.

**Why this priority**: Credential exposure would compromise every Hermes workflow that authenticates to API, dashboard, Git, or SSH-backed targets.

**Independent Test**: Can be tested by saving, loading, and clearing API/SSH credentials, verifying they route through protected storage, and verifying unlock failure prevents normal shell access.

**Acceptance Scenarios**:

1. **Given** a user saves an API key, **When** the app persists settings, **Then** the raw key is stored in protected secret storage rather than regular preferences.
2. **Given** a user saves an SSH private key, **When** an SSH command needs a key file, **Then** the app materializes a temporary private identity file and cleans it after use where practical.
3. **Given** startup secrets cannot be unlocked, **When** the app launches, **Then** the normal shell is not shown.

---

### User Story 2 - Protect sensitive network traffic and TLS trust (Priority: P2)

A user connects HermesMacOS to local or remote Hermes services while the app prevents sensitive remote plaintext transport and requires explicit trust decisions for untrusted certificates.

**Why this priority**: API keys, dashboard tokens, prompts, files, and tool outputs must not be silently sent over unsafe transport or to unreviewed certificate identities.

**Independent Test**: Can be tested by attempting loopback HTTP, remote HTTP, normal HTTPS, and self-signed HTTPS connections and verifying allowed, blocked, or approval-required outcomes.

**Acceptance Scenarios**:

1. **Given** a sensitive request targets a remote HTTP endpoint, **When** the request is prepared, **Then** the app blocks or omits sensitive credentials rather than sending them remotely in plaintext.
2. **Given** a HTTPS endpoint uses a public CA certificate, **When** the app connects, **Then** platform trust is used without unnecessary custom approval.
3. **Given** a self-signed or untrusted certificate appears, **When** the user has not approved its fingerprint, **Then** the app queues an approval and rejects the connection until approval.

---

### User Story 3 - Retain local history safely (Priority: P3)

A user optionally keeps prompt, response, draft, and clipboard history while the app redacts common secrets and encrypts retained content.

**Why this priority**: Local history can contain private prompts, file contents, tokens, and tool outputs, so retention needs guardrails even on a personal Mac.

**Independent Test**: Can be tested by storing entries with secret-like content and verifying redaction, encrypted persistence, migration from legacy plaintext values, and clear/delete actions.

**Acceptance Scenarios**:

1. **Given** text contains common token or private-key patterns, **When** the app retains it, **Then** secret-like content is redacted before storage.
2. **Given** retained prompt, response, draft, title, or clipboard data is persisted, **When** it is written to disk-backed preferences, **Then** the persisted value is encrypted.
3. **Given** legacy plaintext retained data exists, **When** the app loads it successfully, **Then** it migrates to encrypted storage and removes the plaintext value.

---

### User Story 4 - Gate local filesystem and process access (Priority: P4)

A user performs local Hermes runtime operations while the app uses allowlists, local approvals, scoped process execution, and visible approval resolution for sensitive access.

**Why this priority**: HermesMacOS intentionally has broad local capability; users need clear guardrails for file, config, approval, and subprocess actions.

**Independent Test**: Can be tested by attempting allowed and outside-allowlist local operations, reviewing pending approvals, resolving them, and verifying subprocess helpers enforce bounded execution behavior.

**Acceptance Scenarios**:

1. **Given** a local operation targets an allowed Hermes folder, **When** the operation runs, **Then** it proceeds without unnecessary prompts.
2. **Given** a local operation targets a path outside the allowlist, **When** approval is practical, **Then** the app queues a local approval and waits for the user decision.
3. **Given** a pending approval exists, **When** the user approves or denies it in the Approvals Inbox, **Then** the app records the decision and the requesting workflow can continue or fail safely.

### Edge Cases

- If protected storage is unavailable, the app fails closed for secret-dependent flows and communicates the problem clearly.
- If a certificate fingerprint changes for a previously approved host, the app requires a new approval rather than silently reusing old trust.
- If a remote plaintext endpoint is configured for a sensitive request, the app does not attach bearer tokens or session credentials.
- If legacy plaintext retained data cannot be migrated safely, the app avoids duplicating it into new plaintext storage.
- If a temporary SSH identity file cannot be created with private permissions, the SSH operation fails instead of writing an unsafe key file.
- If an approval request is malformed, expired, or already resolved, the Approvals Inbox shows a recoverable state and avoids double-applying a decision.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The app MUST store API keys, SSH private keys, local retention keys, and certificate pins in protected secret storage rather than ordinary app preferences.
- **FR-002**: The app MUST require a startup unlock gate before exposing normal flows that depend on protected secrets.
- **FR-003**: The app MUST block sensitive remote plaintext requests or avoid attaching sensitive credentials to them.
- **FR-004**: The app MUST allow loopback HTTP for local development while still treating non-loopback plaintext endpoints as unsafe for sensitive traffic.
- **FR-005**: The app MUST use platform trust for normal public CA certificates.
- **FR-006**: The app MUST require explicit user approval before trusting self-signed or otherwise untrusted certificate fingerprints.
- **FR-007**: The app MUST support resetting a pinned certificate decision so changed certificates can be reviewed again.
- **FR-008**: The app MUST redact common secret patterns before retaining prompt, response, draft, title, or clipboard content.
- **FR-009**: The app MUST encrypt retained local history and migrate supported legacy plaintext entries after successful encrypted storage.
- **FR-010**: The app MUST maintain an allowed-folder model for local filesystem access and request local approval for outside-allowlist operations where practical.
- **FR-011**: The Approvals Inbox MUST list pending approval requests and allow users to approve or deny them with visible outcome feedback.
- **FR-012**: Subprocess and SSH helper flows MUST use bounded execution, private temporary key material, cleanup, and clear failure reporting.

### Key Entities *(include if feature involves data)*

- **Protected Secret**: API key, SSH key, retention key, or TLS pin stored through protected secret storage and unlocked for app use.
- **Sensitive Endpoint**: A URL target that may carry credentials, session identifiers, prompts, files, or tool results.
- **Certificate Pin**: A host-scoped approved certificate fingerprint used for self-signed or untrusted TLS connections.
- **Retained Local Item**: Prompt, response, draft, title, or clipboard content that has been redacted and encrypted before persistence.
- **Allowed Folder**: A local filesystem root the user or app policy permits without an additional local approval.
- **Approval Request**: A pending decision shown to the user for local access or certificate trust, with approve/deny resolution state.
- **Process Execution Request**: A bounded command or SSH operation that may require temporary files, output capture, timeout, and cleanup.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In 100% of credential-save tests, raw API keys and SSH private keys are absent from ordinary preference storage after saving.
- **SC-002**: In 100% of tested sensitive remote plaintext requests, credentials are blocked or omitted before network transmission.
- **SC-003**: In 100% of untrusted-certificate tests, first connection is rejected until the user explicitly approves the fingerprint.
- **SC-004**: In 100% of retained-history tests with common secret patterns, stored content is redacted and encrypted.
- **SC-005**: In 100% of outside-allowlist local access tests where approval is practical, a visible approval request is created before the action proceeds.
- **SC-006**: Users can review and resolve a pending approval from the Approvals Inbox in under 30 seconds.

## Assumptions

- The app remains intentionally unsandboxed because it manages local Hermes files, repositories, skills, MCP servers, schedules, attachments, and SSH workflows.
- The security boundary is a combination of app-level guardrails, Keychain, LocalAuthentication, endpoint validation, explicit approvals, and encrypted retention rather than App Sandbox isolation.
- Loopback HTTP remains acceptable for local Hermes development; non-loopback plaintext is unsafe for sensitive traffic.
- Workflow-specific security behavior outside the listed files is covered by separate features unless it depends on the shared helpers in this feature.
