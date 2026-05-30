# HermesMacOS Security Notes

HermesMacOS intentionally keeps the macOS app sandbox disabled. The app manages local Hermes agent installs, profile files, model configuration, skills, MCP servers, schedules, repositories, imported attachments, and SSH-based remote workflows. Those workflows need broad filesystem and process access that the sandbox would otherwise break.

## Filesystem Access

Settings includes an allowed-folder list. Common Hermes paths are allowed by default. When HermesMacOS is about to perform supported local filesystem reads or mutations outside the allowlist, it queues a local approval in the Approvals Inbox and waits for the user to approve or deny before continuing where practical.

This approval flow is a guardrail, not a sandbox boundary. A user-approved action still runs with the app process privileges.

## Local Retention

Retained prompts, responses, drafts, response titles, chat titles, and clipboard history are stored with AES-GCM using a symmetric key kept in Keychain. Existing plaintext UserDefaults values are migrated on load and removed after successful encrypted storage.

Before retention, HermesMacOS redacts common secrets including bearer tokens, API key/password/token lines, JWT-like values, private-key blocks, OpenAI/GitHub/Slack-style tokens, and data URLs.

## TLS Trust

Public CA certificates use the platform trust store. Self-signed or otherwise untrusted certificates are not silently trusted. HermesMacOS computes the leaf certificate SHA-256 fingerprint, queues a pending approval in the Approvals Inbox, and rejects the connection until the user explicitly approves the fingerprint. Approved per-host pins are stored in Keychain.

Settings provides a reset action for the current host pin so a changed certificate can be reviewed again.

## SSH Temporary Keys

SSH private keys are stored in Keychain. When an SSH command needs an identity file, HermesMacOS creates a private temporary directory, writes the key file with `0600` permissions at creation time, and removes stale temporary key files on launch and before new key creation.
