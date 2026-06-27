# Contract: Security and Endpoint Guardrails

## Endpoint Validation Contract

- `HermesEndpointSecurity.validateSensitiveURL(_:)` MUST throw `HermesSecurityError.insecureTransport` for non-loopback `http://` URLs.
- Loopback hosts (`localhost`, `127.0.0.1`, `::1`, `[::1]`, or empty local defaults) remain allowed for local development.
- API and dashboard clients MUST call validation before adding secret-bearing headers or dashboard tokens.

## Secret Storage Contract

- `HermesAPISettings.encode(to:)` MUST encode non-secret settings only and omit the raw API key.
- `HermesAPIKeychain` MUST save API keys in the `HermesMacOS.APIKeys` Keychain service and support migration from legacy lookup where available.
- `HermesSSHKeychain` MUST save per-host SSH private keys in the `HermesMacOS.SSHPrivateKeys` Keychain service and avoid durable plaintext files.
- Keychain values SHOULD use data-protection Keychain with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` where set by source.

## Local Retention Contract

- Retained strings MUST pass through `HermesSecretRedactor` before encrypted storage.
- Retained data MUST be encrypted with AES-GCM and an AES key stored in Keychain.
- Legacy plaintext UserDefaults values MUST be removed after successful encrypted migration.
- Debug buffers MUST redact secret-looking values and stay under the configured byte limit.

## TLS Pinning Contract

- When self-signed certificate support is off, default system trust handling applies.
- When it is on and platform trust fails, the app MUST compute the leaf certificate SHA-256 fingerprint.
- If no matching pin exists, the app MUST queue a certificate-pin approval and cancel the current challenge.
- If a matching pin exists, the app MAY trust the certificate for that host.
- If a pin exists but does not match, the app MUST cancel the challenge.

## Local Filesystem Approval Contract

- Allowed folders include configured folders plus standard Hermes runtime roots and the user home default.
- Guarded operations outside the allowed folders MUST enqueue a filesystem approval and wait for resolution.
- Denied approvals MUST throw `HermesSecurityError.localApprovalDenied` and avoid partial local mutation.

## Process/SSH Contract

- Process helpers MUST capture output, report timeout status, and avoid unbounded command execution where timeouts are supplied.
- SSH private keys MUST be materialized only as private temporary files for command execution and stale temporary files should be cleaned up.
