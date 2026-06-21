# Research: Security and Local Access

## Decision: Keep all raw secrets in Keychain-backed helpers

**Rationale**: API keys, SSH private keys, local retention keys, and TLS pins are high-impact secrets. Keychain-backed helpers keep raw values out of regular preferences and align with the startup unlock model.

**Alternatives considered**:

- Persist raw secrets in UserDefaults for simplicity: rejected because preferences are inappropriate for credentials.
- Require re-entry on every launch: rejected because it weakens usability without addressing temporary in-memory exposure during a session.

## Decision: Treat loopback plaintext differently from remote plaintext

**Rationale**: Local Hermes development commonly uses loopback HTTP, while remote HTTP can expose bearer tokens, session identifiers, prompts, files, and tool output. The guardrail must preserve local development but block or strip sensitive credentials for non-loopback plaintext.

**Alternatives considered**:

- Ban all HTTP endpoints: rejected because it would break common local Hermes workflows.
- Allow all user-configured endpoints: rejected because it would silently transmit sensitive material over remote plaintext.

## Decision: Require explicit fingerprint approval for untrusted TLS

**Rationale**: Users may operate trusted local or Tailscale services with self-signed certificates, but silent trust of arbitrary certificates would defeat TLS identity. Host-scoped fingerprint approval keeps the decision visible and reviewable.

**Alternatives considered**:

- Blindly trust self-signed certificates when a setting is enabled: rejected as too broad.
- Reject all self-signed certificates permanently: rejected because it blocks legitimate local deployments.

## Decision: Redact then encrypt retained local content

**Rationale**: Prompt, response, draft, title, and clipboard history can contain secrets and private data. Redaction reduces accidental retained secrets, while encryption protects persisted history at rest.

**Alternatives considered**:

- Retain plaintext with a warning: rejected because secrets frequently appear unintentionally.
- Disable all retention: rejected because retention is useful when explicitly enabled and guarded.

## Decision: Use local approvals as guardrails for broad local capability

**Rationale**: The app remains unsandboxed to manage Hermes runtime files and processes. Local approvals, allowlists, and visible outcome reporting narrow high-risk operations without breaking intended workflows.

**Alternatives considered**:

- Re-enable App Sandbox: rejected for this feature because current Hermes runtime management would break.
- Allow all filesystem/process operations silently: rejected because it hides high-risk local authority from users.
