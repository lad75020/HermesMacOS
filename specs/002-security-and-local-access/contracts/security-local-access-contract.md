# Contract: Security and Local Access

This contract describes the observable behavior that HermesMacOS must preserve for credential storage, sensitive endpoint validation, TLS pin approvals, local retention, filesystem approvals, and subprocess/SSH execution.

## Protected secret storage

### API key settings contract

- **Surface**: `SettingsView` API key field and `HermesAPISettings` persistence.
- **Write behavior**:
  - Saving a non-empty API key writes the raw value through `HermesAPIKeychain.saveAPIKey(_:)`.
  - Encoded settings omit the raw `apiKey` value from regular preferences.
  - Clearing the API key removes the Keychain item and leaves no plaintext value in encoded settings.
- **Read behavior**:
  - Loading settings retrieves the API key from Keychain after the app-session unlock gate succeeds.
  - Supported legacy plaintext settings are migrated into Keychain and are not re-encoded.
- **Failure behavior**:
  - If secret unlock fails during launch, the normal Hermes shell does not appear.
  - UI may show presence/status for a secret, but must not reveal raw values except inside active user input controls.

### SSH private key contract

- **Surface**: `SettingsView` SSH key picker and remote-host command execution.
- **Write behavior**:
  - Imported private-key bytes are stored through `HermesSSHKeychain.savePrivateKey(_:displayName:forHost:)` with host scope.
  - Saved endpoint metadata stores only username and key display name, not key bytes.
- **Execution behavior**:
  - `HermesSSHKeychain.temporaryIdentityFile(forHost:)` creates a unique temporary key file with user-only permissions before SSH use.
  - Temporary identity files are cleaned where practical, including stale cleanup before new creation.
- **Failure behavior**:
  - Missing key data, unsafe temporary-file creation, or incomplete key writes fail the SSH operation with a clear error.

## Sensitive endpoint transport contract

### URL classification

- **Allowed plaintext**: `http://localhost`, `http://127.0.0.1`, and `http://[::1]` are allowed for local development.
- **Unsafe plaintext**: non-loopback `http://` URLs are remote plaintext.
- **Sensitive requests**: requests carrying `Authorization`, `X-Hermes-Session-Token`, Hermes/OpenClaw session identifiers, prompts, file content, tool output, or local data are sensitive.

### Request preparation

- Sensitive requests MUST call `HermesEndpointSecurity.validateSensitiveURL(_:)` before attaching credentials.
- If validation fails, credentialed requests MUST fail closed or omit credentials; they must not transmit bearer/session tokens to remote plaintext hosts.
- Reachability checks may probe remote plaintext endpoints only without attaching credentials.
- HTTPS requests use normal platform trust unless the trust challenge is untrusted and self-signed support is enabled.

## TLS trust and certificate pin contract

- Public-CA certificates use platform trust without custom approval.
- For otherwise untrusted certificates, `HermesPinnedCertificateTrust` computes the leaf certificate SHA-256 fingerprint.
- If a matching host-scoped pin exists in protected storage, the connection may proceed.
- If no matching pin exists, HermesMacOS queues a local TLS approval and rejects the current connection attempt.
- Approving the local TLS request stores the host-scoped fingerprint in Keychain.
- Resetting a host pin removes the protected pin so the next untrusted certificate must be reviewed again.
- A changed fingerprint for an approved host is rejected until the user explicitly approves the new fingerprint.

## Local retention contract

- Prompt history, response history, chat/response titles, drafts, and clipboard history pass through `HermesSecretRedactor` before persistence.
- Retained data is encrypted by `HermesEncryptedRetentionStore` with AES-GCM using a Keychain-backed symmetric key.
- Supported legacy plaintext values are migrated to encrypted storage on successful load and then removed from the legacy preference key.
- Failed encryption does not create a new plaintext copy.
- Clear/delete actions remove both encrypted and legacy plaintext preference keys for the retained item.

## Filesystem access contract

- Allowed folders are standardized paths from defaults plus user-selected folders.
- Operations targeting an allowed folder proceed without extra approval.
- Operations outside allowed folders call `HermesFilesystemAccessPolicy.requireAccess(to:operation:)` where practical.
- Outside-allowlist access creates a local approval request in the Approvals Inbox and waits for the user's decision.
- Denied requests fail with `HermesSecurityError.localApprovalDenied`.

## Approvals Inbox contract

- The inbox combines remote Hermes approvals with local HermesMacOS approvals.
- Local approval rows include kind, title, command, description, creation time, and approve/deny actions.
- Resolving a local filesystem approval resumes exactly one pending continuation.
- Resolving a local TLS approval may store the host-scoped certificate pin only when approved.
- Malformed, expired, missing, or already-resolved approval requests show recoverable status rather than crashing.

## Bounded process execution contract

- Local subprocess helpers use `HermesProcessRunner.run(...)` or an equivalent bounded runner.
- The runner captures stdout and stderr without waiting for pipes to fill indefinitely.
- When a timeout is configured, the runner terminates the process and escalates to SIGKILL after a short grace period.
- Results include exit code, captured output, and timeout state.
- Diagnostic output shown to users is redacted or bounded where it may contain sensitive values.
