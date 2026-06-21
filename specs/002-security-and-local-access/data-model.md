# Data Model: Security and Local Access

## Protected Secret

Represents sensitive values that must not be stored in ordinary preferences.

**Fields / attributes**:

- Secret kind: API key, SSH private key, retention key, TLS pin
- Host or service scope when applicable
- Availability state for UI display without exposing raw value
- Migration state from legacy storage where supported

**Validation rules**:

- Raw secret values are read or written only through protected storage helpers.
- UI surfaces may show presence/status, not the raw secret.
- Secret-dependent normal shell flows require startup unlock success.

## Sensitive Endpoint

Represents a network target that may carry credentials, session identifiers, prompts, files, or tool output.

**Fields / attributes**:

- URL scheme, host, port, and path
- Loopback classification
- Credential attachment eligibility
- Validation outcome

**Validation rules**:

- Loopback HTTP may be used for local development.
- Non-loopback HTTP must not carry sensitive credentials.
- HTTPS endpoints rely on platform trust or scoped pin approval.

## Certificate Pin

Represents explicit user trust for an otherwise untrusted certificate.

**Fields / attributes**:

- Host scope
- Leaf certificate SHA-256 fingerprint
- Approval state
- Reset/rotation state

**Validation rules**:

- New or changed fingerprints require explicit approval.
- Approved pins are host-scoped.
- Resetting a pin requires future trust to be reviewed again.

## Retained Local Item

Represents prompt, response, draft, title, or clipboard content persisted by the app.

**Fields / attributes**:

- Item kind
- Redacted plaintext before encryption
- Encrypted payload
- Timestamp and display preview where applicable

**Validation rules**:

- Common secret patterns are redacted before persistence.
- Persisted content is encrypted.
- Legacy plaintext is removed after successful migration.

## Allowed Folder

Represents a local root allowed for Hermes runtime operations.

**Fields / attributes**:

- Standardized folder path
- Source of allowance: default Hermes path or user-selected folder
- Display label

**Validation rules**:

- File access checks use standardized/resolved paths.
- Operations outside allowed roots require local approval where practical.

## Approval Request

Represents a user-visible decision for local access or TLS trust.

**Fields / attributes**:

- Request identifier
- Kind: filesystem access, certificate trust, or local operation
- Summary and details
- Approval status: pending, approved, denied, expired, resolved
- Decision timestamp

**Validation rules**:

- Pending requests are visible in the Approvals Inbox.
- Decisions are applied once.
- Malformed or already resolved requests fail safely.

## Process Execution Request

Represents a bounded local command or SSH operation.

**Fields / attributes**:

- Executable and arguments
- Working directory
- Timeout/cancellation policy
- Temporary identity-file path when needed
- Captured output and exit status

**Validation rules**:

- Temporary SSH identity files are private and cleaned where practical.
- Commands have bounded execution and output capture.
- Failures return clear diagnostic state without exposing secrets unnecessarily.
