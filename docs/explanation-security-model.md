# HermesMacOS security model

HermesMacOS intentionally has broad local capabilities. It manages local Hermes installs, profile files, model configuration, skills, MCP servers, schedules, repository updates, attachments, SSH workflows, pasteboard history, and speech input. The security model is therefore app-level guardrails plus macOS Keychain and authentication, not App Sandbox isolation.

## The problem
A sandboxed app would break many expected workflows: reading Hermes home files, editing YAML config, importing local skill files, running Hermes CLI probes, updating a git repository, using SSH keys, and scanning knowledge files. But an unsandboxed app can also access more than a normal single-purpose client should.

HermesMacOS addresses that by narrowing sensitive operations in code and making risky decisions visible.

## Guardrail layers

### Endpoint security
`HermesEndpointSecurity` blocks sensitive remote plaintext HTTP. Loopback HTTP is allowed for local development. API keys are only attached after URL validation.

### Keychain for secrets
API keys, SSH private keys, local retention keys, and TLS certificate pins use Keychain-backed helpers. Values migrate from older non-data-protection lookups into data-protection Keychain where the code supports it.

### Startup unlock
`HermesSecretUnlockGate` uses LocalAuthentication with device-owner authentication. If secrets cannot unlock, the app shows an unlock failure view instead of silently proceeding.

### Encrypted local retention
Prompt history, response history, and clipboard history are retained only after redaction and AES-GCM encryption. The AES key is stored in Keychain. Legacy plaintext UserDefaults values are migrated and removed after successful encrypted storage.

### Redaction before retention
`HermesSecretRedactor` replaces private key blocks, data URLs, bearer tokens, common key/password/token lines, OpenAI keys, GitHub tokens, Slack tokens, JWT-like values, and generic bearer/token values.

### TLS pinning approval
When self-signed certificate support is enabled, an untrusted certificate is not automatically trusted. HermesMacOS computes the leaf certificate SHA-256 fingerprint, queues a local approval, and only pins after approval.

### Filesystem approvals
`SECURITY.md` states that Settings includes an allowed-folder list and unsupported local filesystem access outside the allowlist queues a local approval where practical.

### Temporary SSH key files
SSH private keys stay in Keychain. For SSH commands, the app creates a private temporary identity file with `0600` permissions and cleans stale files on launch and before new key creation.

## What this protects
- API keys are not persisted in regular settings JSON.
- Clipboard and prompt/response history are not kept as plaintext UserDefaults after migration.
- Remote sensitive traffic does not silently downgrade to HTTP.
- Self-signed TLS trust requires an explicit fingerprint decision.
- Repository update workflows can use SSH without storing private keys on disk permanently.

## What it does not protect
- The macOS sandbox is disabled, so OS-level containment is not the security boundary.
- A user-approved local action still runs with the app process privileges.
- Raw debug logs and visible UI state can still contain sensitive prompt/model output and should be treated as sensitive.
- Dashboard token extraction depends on dashboard HTML and the token's own server-side authorization behavior.

## Trade-offs
The app chooses capability over sandbox containment because its job includes local runtime management. The cost is higher review burden: every new local file, process, token, or network path must explicitly fit the guardrail model.

## Review checklist for future changes
- Does this change send a secret? Validate the URL first and block remote HTTP.
- Does this change store sensitive data? Use Keychain or encrypted retention, not plaintext UserDefaults.
- Does this change read or mutate local files? Respect allowlists and local approvals.
- Does this change trust TLS? Use fingerprint approval and pinning.
- Does this change run a process? Use bounded process runner behavior and show output safely.
- Does this change log data? Redact secrets and avoid retaining raw prompt/tool output unless the user asked for it.
