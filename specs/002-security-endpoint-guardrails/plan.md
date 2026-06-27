# Implementation Plan: Security and Endpoint Guardrails

**Branch**: `feature/time-machine-security-endpoint-guardrails` | **Date**: 2026-06-27 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/002-security-endpoint-guardrails/spec.md`

## Summary

Retroactively specify and verify the existing HermesMacOS security guardrail layer. The feature is implemented by `HermesSecurityUtilities.swift`, `HermesModelsAPI.swift`, `SECURITY.md`, and related security-model docs. The work adds SDD traceability and build/ad-hoc verification without weakening or refactoring the existing security implementation.

## Technical Context

**Language/Version**: Swift, SwiftUI, Foundation, Security, CryptoKit, LocalAuthentication; project sets `SWIFT_VERSION: 5.0` in `project.yml`  
**Primary Dependencies**: Apple Security framework, CryptoKit AES-GCM/SHA-256, LocalAuthentication, URLSession challenge handling, UserDefaults/AppStorage, Keychain generic-password APIs  
**Storage**: Keychain for API keys, SSH keys, TLS pins, and AES retention key; encrypted UserDefaults for retained prompt/response/clipboard/debug data; UserDefaults for non-secret allowed-folder metadata  
**Testing**: Xcode build plus ad-hoc artifact checks; manual/runtime smoke checks for Keychain, LocalAuthentication, TLS pinning, filesystem approvals, and process cleanup  
**Target Platform**: macOS 26+ native app  
**Project Type**: Desktop app / native Hermes Agent control surface  
**Performance Goals**: Security checks should be synchronous and cheap where possible; approval and network paths must not block the main actor except for UI approval queue operations  
**Constraints**: App sandbox is intentionally disabled; guardrails are application-level and must fail closed for secrets, TLS trust, and local approvals  
**Scale/Scope**: One shared security utility file plus API settings integration; this feature does not alter downstream API/Dashboard/TUI contracts

## Constitution Check

- **Native control surface**: Pass. Guardrails support the native app shell, Settings, Approvals Inbox, local runtime utilities, and network feature tabs without moving workflows out of SwiftUI.
- **Integration contracts**: Pass. Hermes API/Dashboard/TUI methods remain unchanged; this feature controls URL validation, tokens, TLS sessions, local approvals, and process helpers used by those contracts.
- **Security guardrails**: Pass. This is the guardrail feature: endpoint validation, Keychain secrets, encrypted retention, redaction, TLS pin approval, filesystem approvals, temporary SSH key cleanup, and bounded process execution are in scope.
- **Verification**: Pass with build plus ad-hoc artifact checks; runtime security behavior requires manual or future unit/integration tests because no test target exists.
- **Maintainability**: Pass. No new source files are introduced; SDD artifacts document the existing shared security layer and identify future automated-test seams.

## Project Structure

### Documentation (this feature)

```text
specs/002-security-endpoint-guardrails/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── security-guardrails.md
└── tasks.md
```

### Source Code (repository root)

```text
SECURITY.md
docs/explanation-security-model.md
docs/reference-api-and-storage.md
HermesMacOS/
├── HermesSecurityUtilities.swift
└── HermesModelsAPI.swift
```

**Structure Decision**: Keep the existing shared security utility module and add only Spec Kit artifacts under `specs/002-security-endpoint-guardrails/`.

## Complexity Tracking

No constitution violations or additional complexity are introduced.

## Phase 0: Research

See [research.md](./research.md).

## Phase 1: Design

See [data-model.md](./data-model.md), [contracts/security-guardrails.md](./contracts/security-guardrails.md), and [quickstart.md](./quickstart.md).

## Phase 2: Tasks

See [tasks.md](./tasks.md).
