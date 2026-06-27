# Feature Specification: Security and Endpoint Guardrails

**Feature Branch**: `feature/time-machine-security-endpoint-guardrails`  
**Created**: 2026-06-27  
**Status**: Draft  
**Input**: User description: "Feature: Security and Endpoint Guardrails. Description: Protects users with endpoint validation, Keychain-backed secrets, encrypted local retention, certificate pinning, approvals, filesystem policy, and process helpers. Relevant files: SECURITY.md, HermesMacOS/HermesSecurityUtilities.swift, HermesMacOS/HermesModelsAPI.swift. Focus on this feature only; do not modify other features."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Block unsafe sensitive network traffic (Priority: P1)

A user configures Hermes endpoints and expects API keys, dashboard tokens, and request payloads to be sent only to safe URLs. Remote plaintext HTTP is rejected, while loopback HTTP remains available for local development.

**Why this priority**: Network transport mistakes can expose API keys and session tokens before any other guardrail matters.

**Independent Test**: Configure a non-loopback `http://` Hermes API or dashboard URL for a secret-bearing flow and verify the app blocks it with a user-visible security error; configure loopback HTTP and verify local development remains possible.

**Acceptance Scenarios**:

1. **Given** a sensitive request targets `http://example.com`, **When** the request is prepared, **Then** HermesMacOS rejects it with an insecure transport error.
2. **Given** a sensitive request targets `http://localhost` or `http://127.0.0.1`, **When** the request is prepared, **Then** HermesMacOS allows the request to proceed to normal network handling.
3. **Given** an API key is configured, **When** a request URL fails endpoint validation, **Then** the API key is not attached to the outgoing request.

---

### User Story 2 - Store and unlock secrets safely (Priority: P2)

A user stores API keys, SSH private keys, TLS pins, and local retention keys without those secrets being persisted in plaintext UserDefaults or source files.

**Why this priority**: HermesMacOS is intentionally unsandboxed and manages powerful local workflows, so secret storage must remain defensive by default.

**Independent Test**: Save or migrate an API key/SSH key, relaunch, and confirm the app can use it after unlock while plaintext app preferences do not contain the raw secret.

**Acceptance Scenarios**:

1. **Given** an API key is saved, **When** settings are encoded, **Then** the key is omitted from Codable settings output and stored in Keychain.
2. **Given** a legacy API key or retention key exists in an older storage location, **When** it is loaded successfully, **Then** the value is migrated to data-protection Keychain where supported.
3. **Given** the app starts and secrets are needed, **When** LocalAuthentication fails, **Then** protected app state remains unavailable and a bounded unlock failure is shown.

---

### User Story 3 - Protect retained local content and debug output (Priority: P3)

A user opts into prompt, response, clipboard, or debug retention and expects secrets, private keys, data URLs, bearer tokens, and long raw output to be redacted, encrypted, and bounded.

**Why this priority**: Retention and debug features create high accidental-disclosure risk, but they are secondary to transport and credential storage.

**Independent Test**: Save retained text containing representative secrets and verify saved content is redacted/encrypted and debug buffers are truncated to the configured maximum.

**Acceptance Scenarios**:

1. **Given** retained text contains a private key block, data URL, bearer token, JWT, or common API key line, **When** it is saved, **Then** the sensitive value is replaced by a redaction marker before or during storage.
2. **Given** retained prompt/response/clipboard data is stored, **When** UserDefaults is inspected, **Then** encrypted keys under the encrypted prefix are used instead of plaintext legacy keys after migration.
3. **Given** raw debug output exceeds the configured byte limit, **When** it is appended, **Then** older output is truncated and the retained suffix remains redacted.

---

### User Story 4 - Gate local filesystem and TLS trust decisions (Priority: P4)

A user performs a local file operation outside allowed folders or connects to a self-signed TLS endpoint and expects an explicit approval decision before the app trusts the path or certificate.

**Why this priority**: Local file and TLS trust decisions are high impact but occur in narrower workflows than core transport and secret storage.

**Independent Test**: Trigger a filesystem operation outside the allowlist and a self-signed certificate connection; verify each queues an approval and denies the action until approved.

**Acceptance Scenarios**:

1. **Given** a path is outside the configured allowlist, **When** a guarded operation requests access, **Then** a filesystem approval appears and the operation waits for approval.
2. **Given** self-signed certificate handling is enabled and an untrusted host presents a certificate, **When** the connection is attempted, **Then** the app computes a leaf SHA-256 fingerprint, queues a certificate approval, and cancels the first challenge.
3. **Given** an approved TLS pin no longer matches the host certificate, **When** the host is contacted, **Then** the challenge is rejected.

### Edge Cases

- If Keychain is unavailable, secret unlock/encryption must fail closed with a user-visible error rather than falling back to plaintext storage.
- If LocalAuthentication is unavailable or canceled, protected secret-dependent state must remain locked.
- If a URL has an empty or malformed host, endpoint validation must treat it consistently and avoid accidentally allowing remote plaintext sensitive traffic.
- If a dashboard session token is missing from HTML, dashboard calls must fail with a token-missing error and not retry with unauthenticated sensitive state.
- If a certificate approval is pending, duplicate approval rows for the same host/fingerprint should not accumulate.
- If a filesystem approval is denied, the guarded operation must throw a local-approval-denied error and avoid partial mutation.
- If temporary SSH key material is needed for a process, the file must be private, short-lived, and cleaned up.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST block sensitive non-loopback HTTP requests and permit loopback HTTP for local development.
- **FR-002**: System MUST validate sensitive URLs before attaching API keys, dashboard tokens, or other secret-bearing headers.
- **FR-003**: System MUST store API keys, SSH private keys, TLS certificate pins, and local retention keys in Keychain-backed storage where supported.
- **FR-004**: System MUST omit API keys from Codable settings output and migrate legacy stored API keys to Keychain when encountered.
- **FR-005**: System MUST require startup secret unlock through LocalAuthentication before exposing protected secret-dependent app state.
- **FR-006**: System MUST redact common secret formats before local retention or debug-buffer persistence.
- **FR-007**: System MUST encrypt retained prompt, response, and clipboard data with AES-GCM using a Keychain-stored symmetric key.
- **FR-008**: System MUST migrate readable legacy plaintext retention values into encrypted retention and remove the plaintext legacy value after successful migration.
- **FR-009**: System MUST queue explicit certificate-pin approval for untrusted self-signed certificates and persist approved fingerprints in Keychain.
- **FR-010**: System MUST reject certificate challenges when a stored pin does not match the presented leaf certificate fingerprint.
- **FR-011**: System MUST maintain an allowed-folder policy for local filesystem operations and queue approvals for guarded operations outside that policy.
- **FR-012**: System MUST bound and redact debug log buffers before storing or displaying retained debug output.
- **FR-013**: System MUST use bounded process execution helpers for local commands and avoid permanent plaintext SSH key files.
- **FR-SEC**: System MUST preserve HermesMacOS security guardrails for endpoint validation, Keychain/encrypted retention, redaction, TLS pin approval, local filesystem approvals, and bounded process execution where applicable.
- **FR-INT**: System MUST preserve documented Hermes API/Dashboard/TUI Gateway contracts, including headers, tokens, streaming events, cancellation IDs, attachments, retries, and user-visible error states where applicable.

### Key Entities *(include if feature involves data)*

- **HermesEndpointSecurity**: URL validation policy that distinguishes loopback HTTP from unsafe remote plaintext HTTP.
- **HermesSecurityError**: User-visible error taxonomy for insecure transport, encryption failure, approval denial, authentication failure, and dashboard-token failures.
- **HermesAPIKeychain**: Keychain-backed API key load/save/migration service.
- **HermesSSHKeychain**: Keychain-backed SSH private-key load/save/delete service scoped by normalized host.
- **HermesEncryptedRetentionStore**: AES-GCM encrypted retention store with redaction and legacy plaintext migration.
- **HermesPinnedCertificateTrust**: Self-signed TLS fingerprint computation, approval, pin persistence, reset, and challenge handling.
- **HermesLocalApprovalCenter**: In-app queue and continuation manager for filesystem and certificate-pin approval decisions.
- **HermesFilesystemAccessPolicy**: Allowed-folder persistence and access-check helper for local filesystem guardrails.
- **HermesDebugLogBuffer**: Redacting and size-bounding helper for retained debug output.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Representative non-loopback `http://` sensitive URLs are rejected while loopback HTTP URLs are accepted by endpoint policy.
- **SC-002**: Codable encoding of `HermesAPISettings` does not include an API key field value.
- **SC-003**: Redaction replaces representative private-key blocks, bearer tokens, data URLs, API key lines, GitHub/Slack/OpenAI tokens, and JWT-like values.
- **SC-004**: Retention writes encrypted data under the encrypted prefix and removes legacy plaintext keys after successful migration.
- **SC-005**: Untrusted certificate handling queues approval before trust and rejects mismatched pins.
- **SC-006**: Filesystem operations outside the allowed-folder list require approval and denial prevents mutation.
- **SC-BUILD**: The `HermesMacOS` scheme builds successfully with Xcode or command-line `xcodebuild`.
- **SC-SMOKE**: The primary user journey can be validated independently with documented manual, mock-backed, or live-service smoke checks.

## Assumptions

- This is a retroactive specification of the existing guardrail implementation; no security weakening or redesign is intended.
- Full Keychain, LocalAuthentication, and TLS challenge behavior require app/runtime or manual integration checks beyond the current build-only automated setup.
- No automated test target exists yet; pure helper coverage should be added in a future testing feature or when a test target is introduced.

## Clarifications

### Session 2026-06-27

- No critical product questions were generated for this retroactive feature; existing `SECURITY.md`, security-model docs, and implementation files define the expected guardrail behavior.
