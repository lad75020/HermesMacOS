# HermesMacOS Security Notes

HermesMacOS intentionally keeps the macOS app sandbox disabled. The app manages local Hermes agent installs, profile files, model configuration, skills, MCP servers, schedules, repositories, imported attachments, and SSH-based remote workflows. Those workflows need broad filesystem and process access that the sandbox would otherwise break.

## Startup Unlock and Secret Storage

Secret-dependent flows are gated by a single app-session LocalAuthentication unlock before the normal shell is exposed. API keys, SSH private keys, local retention keys, and host-scoped TLS pins are stored in the macOS Keychain using data-protection queries and are cached only in memory for the current app session.

## Filesystem Access

Settings includes an allowed-folder list. Common Hermes paths are allowed by default. When HermesMacOS is about to perform supported local filesystem reads or mutations outside the allowlist, it queues a local approval in the Approvals Inbox and waits for the user to approve or deny before continuing where practical.

This approval flow is a guardrail, not a sandbox boundary. A user-approved action still runs with the app process privileges.

## Local Retention

Retained prompts, responses, drafts, response titles, chat titles, and clipboard history are stored with AES-GCM using a symmetric key kept in Keychain. Existing plaintext UserDefaults values are migrated on load and removed after successful encrypted storage.

Before retention, HermesMacOS redacts common secrets including bearer tokens, API key/password/token lines, JWT-like values, private-key blocks, OpenAI/GitHub/Slack-style tokens, and data URLs.

## TLS Trust

Public CA certificates use the platform trust store. Self-signed or otherwise untrusted certificates are not silently trusted. HermesMacOS computes the leaf certificate SHA-256 fingerprint, queues a pending approval in the Approvals Inbox, and rejects the connection until the user explicitly approves the fingerprint. Approved per-host pins are stored in Keychain.

Remote plaintext HTTP is blocked before sensitive Hermes credentials are attached to API or dashboard requests. Loopback HTTP remains allowed for local development, and reachability probes omit API keys when checking remote plaintext endpoints.

Settings provides a reset action for the current host pin so a changed certificate can be reviewed again.

## SSH Temporary Keys

SSH private keys are stored in Keychain. When an SSH command needs an identity file, HermesMacOS creates a private temporary directory, writes the key file with `0600` permissions at creation time, and removes stale temporary key files on launch and before new key creation.

Imported SSH private keys must be non-empty and no larger than the app's safety limit before they are read into memory for Keychain storage.

## Bounded Local Processes

Local subprocess helpers drain stdout and stderr while the child runs, enforce configured timeouts, and terminate timed-out children before returning diagnostic output. User-facing debug buffers are bounded and redacted for common credential patterns.
