# Data Model: Security and Endpoint Guardrails

## HermesSecurityError

User-visible security error taxonomy.

- **Attributes**: insecure transport host, encryption unavailable, local approval denied path, authentication failure reason, dashboard token/config errors.
- **Relationships**: thrown by endpoint security, encryption, local approvals, dashboard client, and startup unlock paths.
- **Validation**: localized descriptions must avoid exposing secrets.

## HermesEndpointSecurity

Transport validation policy for sensitive URLs.

- **Attributes**: loopback host recognizer, remote plaintext detector.
- **Relationships**: called before API keys or dashboard tokens are attached to requests.
- **Validation**: loopback hosts are allowed for local development; remote `http` is blocked.

## HermesAPIKeychain / HermesSSHKeychain

Keychain-backed secret stores.

- **Attributes**: Keychain service, account, optional in-memory cache, data-protection Keychain mode.
- **Relationships**: Settings and API clients load/save API keys; SSH-backed git workflows load/save per-host private keys.
- **Validation**: empty values delete/clear; legacy non-data-protection values migrate to data-protection Keychain where supported.

## HermesEncryptedRetentionStore

Encrypted local retention helper.

- **Attributes**: encrypted key prefix, AES-GCM version byte, Keychain-stored symmetric key.
- **Relationships**: Utilities and conversation retention use it for retained prompt/response/clipboard strings and data.
- **Validation**: redacts before saving strings, encrypts data, migrates legacy plaintext, removes plaintext after successful encrypted write.

## HermesPinnedCertificateTrust

TLS pinning helper for self-signed certificate workflows.

- **Attributes**: normalized host, leaf certificate SHA-256 fingerprint, Keychain pin service.
- **Relationships**: URLSession challenge delegate uses it; Approvals Inbox resolves certificate pin approvals.
- **Validation**: untrusted certificates require approval; existing pins must match exactly.

## HermesLocalApprovalCenter / HermesLocalApprovalRequest

In-app approval queue for local risky decisions.

- **Attributes**: request id, kind, title, command, description, timestamp, host, fingerprint.
- **Relationships**: Approvals Inbox displays and resolves pending requests; filesystem policy and TLS pinning enqueue requests.
- **Validation**: duplicate certificate approvals for the same host/fingerprint are suppressed; continuations resume exactly once.

## HermesFilesystemAccessPolicy

Allowed-folder policy for local filesystem guardrails.

- **Attributes**: persisted allowed-folder key, default Hermes paths and user home, standardized path helpers.
- **Relationships**: local runtime/config utilities call `requireAccess` before guarded mutations.
- **Validation**: standardized target must equal or be inside an allowed folder; denial throws a local approval error.

## HermesDebugLogBuffer

Redacting, bounded debug text retention helper.

- **Attributes**: maximum byte limit, redaction patterns, truncation prefix.
- **Relationships**: raw stream/debug output retention and display paths.
- **Validation**: output is redacted before size limiting and old content is dropped when over limit.
