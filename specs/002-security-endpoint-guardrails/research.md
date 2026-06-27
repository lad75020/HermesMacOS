# Research: Security and Endpoint Guardrails

## Decision 1: Keep guardrails in shared Swift helpers

**Decision**: Continue centralizing endpoint validation, Keychain storage, redaction, encrypted retention, TLS pinning, filesystem approvals, runtime paths, debug buffering, YAML quoting, and process execution in `HermesSecurityUtilities.swift`.

**Rationale**: These concerns are cross-cutting and used by Settings, API clients, Dashboard clients, local runtime utilities, approvals, and installation workflows. Centralization reduces inconsistent security behavior.

**Alternatives considered**:
- Duplicate guardrails per feature: rejected because duplicated URL/secret/TLS rules drift quickly.
- Move all local operations behind a server API immediately: rejected because the current app intentionally manages local files/processes directly.

## Decision 2: Fail closed for secret transport and storage

**Decision**: Sensitive non-loopback HTTP is blocked, API keys are attached only after URL validation, and Keychain/encrypted retention failures surface as errors rather than plaintext fallback.

**Rationale**: HermesMacOS is unsandboxed and handles high-value API keys, dashboard tokens, SSH keys, prompt history, and clipboard history. Silent fallback to plaintext would violate the documented security model.

**Alternatives considered**:
- Warn but allow remote HTTP: rejected because warnings are easy to ignore and traffic exposure is immediate.
- Store encrypted data with a hardcoded key if Keychain fails: rejected because it does not protect user secrets.

## Decision 3: Use explicit approval for trust and filesystem exceptions

**Decision**: Self-signed certificate trust and outside-allowlist filesystem operations require local approvals.

**Rationale**: These operations are legitimate in local/Tailscale Hermes deployments but high impact. Approval records make risk visible and give the user a chance to deny.

**Alternatives considered**:
- Trust all certificates when a toggle is enabled: rejected because it enables silent MITM risk.
- Allow all home-directory access without approval: rejected because app-level guardrails are the only boundary when sandboxing is disabled.

## Decision 4: Defer automated helper tests to a test-target feature

**Decision**: Verify this Time Machine pass with build and ad-hoc artifact checks, while documenting helper test seams for future coverage.

**Rationale**: The repository currently has no test target. Adding one is valuable but affects project configuration and belongs in a dedicated testing/spec feature.

**Alternatives considered**:
- Claim security unit coverage exists: rejected because it would be inaccurate.
- Add an ad-hoc Swift executable test harness in this feature: rejected because Keychain/LocalAuthentication/TLS challenge behavior is best tested in an app/test target context.
