# Implementation Plan: Security and Local Access

**Branch**: `feature/time-machine-security-and-local-access` | **Date**: 2026-06-21 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/002-security-and-local-access/spec.md`

## Summary

Validate and preserve the security guardrails that protect HermesMacOS credentials, transport, TLS trust, retained local data, local filesystem access, approvals, and subprocess/SSH workflows. The implementation approach is to keep secrets in Keychain-backed helpers, enforce sensitive URL validation before credentialed traffic, require explicit fingerprint approval for untrusted TLS, redact/encrypt local retention, and use local approvals plus bounded process helpers for privileged local operations.

## Technical Context

**Language/Version**: Swift using the Xcode project setting `SWIFT_VERSION: 5.0`

**Primary Dependencies**: Foundation, Security, LocalAuthentication, CryptoKit, SwiftUI/Observation, URLSession, Keychain services, AES-GCM, local approval stores, process helpers

**Storage**: Keychain for API keys, SSH private keys, retention keys, and TLS pins; encrypted UserDefaults-backed retention for prompts/responses/drafts/clipboard entries; UserDefaults for non-secret settings only

**Testing**: Static source validation, security-focused scenario checks, checklist verification, and `xcodebuild -project HermesMacOS.xcodeproj -scheme HermesMacOS -destination 'generic/platform=macOS' build`

**Target Platform**: macOS 26.0 or newer desktop application

**Project Type**: Native macOS desktop app / local Hermes Agent control surface

**Performance Goals**: Security guardrails should add no noticeable delay to normal Settings interactions; approval resolution should be possible in under 30 seconds; URL validation and redaction must complete synchronously for normal request sizes

**Constraints**: App remains intentionally unsandboxed; loopback HTTP remains allowed for local development; remote plaintext must not carry sensitive credentials; self-signed trust must remain host/fingerprint scoped; local approvals are guardrails rather than OS isolation

**Scale/Scope**: Shared security utilities plus Settings and Approvals Inbox surfaces that protect all security-sensitive HermesMacOS operations

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

The project constitution is still template-only. Apply default security gates for this feature:

- **Secret Storage Gate**: PASS — secrets route through Keychain-backed helpers and startup unlock.
- **Transport Safety Gate**: PASS — sensitive remote plaintext is blocked or stripped of credentials.
- **TLS Trust Gate**: PASS — untrusted certificates require explicit fingerprint approval.
- **Retention Privacy Gate**: PASS — retained local content is redacted and encrypted.
- **Local Authority Gate**: PASS — local filesystem/process access uses allowlists, approvals, and bounded helpers where practical.
- **Build Readiness Gate**: PASS — feature tasks must finish with successful Xcode build validation.

## Project Structure

### Documentation (this feature)

```text
specs/002-security-and-local-access/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── security-local-access-contract.md
├── checklists/
│   └── requirements.md
└── tasks.md
```

### Source Code (repository root)

```text
SECURITY.md
HermesMacOS/
├── HermesSecurityUtilities.swift
├── HermesModelsAPI.swift
├── SettingsView.swift
└── HermesApprovalsInboxView.swift
```

**Structure Decision**: Use the existing shared security-helper architecture. No new source directory is required for this feature; the security model is cross-cutting and already centralized in shared helpers plus user-facing Settings and Approvals surfaces.

## Phase 0 Research

Research decisions are recorded in [research.md](./research.md).

## Phase 1 Design

Design artifacts are recorded in:

- [data-model.md](./data-model.md)
- [contracts/security-local-access-contract.md](./contracts/security-local-access-contract.md)
- [quickstart.md](./quickstart.md)

## Complexity Tracking

No constitution or design violations require complexity justification.

## Post-Design Constitution Check

- **Secret Storage Gate**: PASS — data model separates Protected Secret from non-secret settings.
- **Transport Safety Gate**: PASS — contract covers loopback vs remote plaintext behavior.
- **TLS Trust Gate**: PASS — contract covers untrusted fingerprint approval and pin reset.
- **Retention Privacy Gate**: PASS — quickstart includes redaction/encryption verification.
- **Local Authority Gate**: PASS — approval and process entities are represented.
- **Build Readiness Gate**: PASS — quickstart and tasks require Xcode build validation.
