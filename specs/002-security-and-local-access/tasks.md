# Tasks: Security and Local Access

**Input**: Design documents from `/specs/002-security-and-local-access/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/security-local-access-contract.md, quickstart.md

**Tests**: Security scenario checks and deterministic source/build validation are required by this feature's success criteria.

**Organization**: Tasks are grouped by user story so each story remains independently testable.

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Finish planning context and establish validation inputs.

- [x] T001 Validate planning artifacts in specs/002-security-and-local-access/plan.md and specs/002-security-and-local-access/contracts/security-local-access-contract.md
- [x] T002 Update agent context in AGENTS.md to point at specs/002-security-and-local-access/plan.md
- [x] T003 [P] Confirm security notes scope in ./SECURITY.md covers unsandboxed local access and protected retention
- [x] T004 [P] Inspect existing source coverage in HermesMacOS/HermesSecurityUtilities.swift for endpoint, Keychain, TLS, retention, approval, and process helpers

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core verification and guardrail fixes that all stories depend on.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [x] T005 Confirm .gitignore contains Swift/Xcode build output exclusions for /tmp/HermesMacOSDerived and DerivedData/
- [x] T006 Add or update standalone source-validation coverage for HermesMacOS/HermesSecurityUtilities.swift security helper symbols
- [x] T007 Add or update standalone source-validation coverage for HermesMacOS/HermesModelsAPI.swift secret persistence and SSH temporary identity behavior
- [x] T008 Add or update standalone source-validation coverage for HermesMacOS/SettingsView.swift and HermesMacOS/HermesApprovalsInboxView.swift security UI surfaces

**Checkpoint**: Security primitives are documented and source-validation inputs are ready.

---

## Phase 3: User Story 1 - Keep credentials protected (Priority: P1) 🎯 MVP

**Goal**: Ensure API keys and SSH keys stay out of ordinary preferences and depend on protected storage/unlock behavior.

**Independent Test**: Save, load, and clear API/SSH credentials; verify protected storage paths and startup unlock use.

- [x] T009 [US1] Verify HermesAPISettings encoding omits raw API keys in HermesMacOS/HermesModelsAPI.swift
- [x] T010 [US1] Verify HermesAPIKeychain uses data-protection Keychain queries and legacy migration in HermesMacOS/HermesSecurityUtilities.swift
- [x] T011 [US1] Harden SSH private-key import size and empty-data handling in HermesMacOS/SettingsView.swift
- [x] T012 [US1] Verify HermesSSHKeychain stores per-host private keys and creates 0600 temporary identities in HermesMacOS/HermesModelsAPI.swift
- [x] T013 [US1] Verify startup and settings unlock gate usage in HermesMacOS/HermesMacOSApp.swift, HermesMacOS/ContentView.swift, and HermesMacOS/SettingsView.swift

---

## Phase 4: User Story 2 - Protect sensitive network traffic and TLS trust (Priority: P2)

**Goal**: Prevent credentialed remote plaintext traffic and require explicit self-signed certificate trust.

**Independent Test**: Exercise loopback HTTP, remote HTTP, HTTPS platform trust, and local TLS pin approvals.

- [x] T014 [US2] Verify remote plaintext detection and sensitive URL validation in HermesMacOS/HermesSecurityUtilities.swift
- [x] T015 [US2] Verify bearer-token request paths call validation before attaching Authorization in HermesMacOS/HermesModelsAPI.swift and HermesMacOS/HermesApprovalsInboxView.swift
- [x] T016 [US2] Verify dashboard session-token paths validate dashboard URLs before using X-Hermes-Session-Token in HermesMacOS/HermesSecurityUtilities.swift
- [x] T017 [US2] Verify reachability checks omit API keys for remote plaintext probes in HermesMacOS/HermesReachabilityMonitor.swift
- [x] T018 [US2] Verify TLS fingerprint approval and reset behavior in HermesMacOS/HermesSecurityUtilities.swift and HermesMacOS/SettingsView.swift

---

## Phase 5: User Story 3 - Retain local history safely (Priority: P3)

**Goal**: Redact and encrypt retained prompts, responses, drafts, titles, and clipboard content.

**Independent Test**: Store secret-like values and verify redaction, encrypted storage, legacy migration, and clearing behavior.

- [x] T019 [US3] Verify HermesSecretRedactor covers bearer tokens, API keys, private keys, data URLs, JWTs, and common provider tokens in HermesMacOS/HermesSecurityUtilities.swift
- [x] T020 [US3] Verify HermesEncryptedRetentionStore encrypts, migrates, and removes legacy values in HermesMacOS/HermesSecurityUtilities.swift
- [x] T021 [US3] Verify draft, title, prompt history, response history, and clipboard persistence routes through redacted encrypted storage in HermesMacOS/HermesModelsAPI.swift and HermesMacOS/HermesUtilitiesView.swift

---

## Phase 6: User Story 4 - Gate local filesystem and process access (Priority: P4)

**Goal**: Keep local filesystem/process authority visible, approved where practical, and bounded.

**Independent Test**: Attempt allowed/outside-allowlist operations, resolve approvals, and run bounded process scenarios.

- [x] T022 [US4] Fix duplicate local approval waiters so all pending continuations resolve in HermesMacOS/HermesSecurityUtilities.swift
- [x] T023 [US4] Verify filesystem allowlist standardization and approval failures in HermesMacOS/HermesSecurityUtilities.swift and HermesMacOS/SettingsView.swift
- [x] T024 [US4] Verify Approvals Inbox merges local and remote approvals with approve/deny feedback in HermesMacOS/HermesApprovalsInboxView.swift
- [x] T025 [US4] Verify bounded subprocess capture, timeout, and termination behavior in HermesMacOS/HermesSecurityUtilities.swift

---

## Phase N: Polish & Cross-Cutting Concerns

**Purpose**: Final documentation, task tracking, and build validation.

- [x] T026 Update ./SECURITY.md with startup unlock, remote plaintext, TLS approval, and bounded process notes
- [x] T027 Run Spec Kit task validation for specs/002-security-and-local-access/tasks.md
- [x] T028 Run Xcode build validation for HermesMacOS/HermesMacOS.xcodeproj scheme HermesMacOS
- [x] T029 Mark completed task checkboxes in specs/002-security-and-local-access/tasks.md after verified implementation
- [x] T030 Update Time Machine queue status in .specify/extensions/time-machine/features-queue.yml after implementation and push decision

## Dependencies

- Phase 1 must complete before Phase 2.
- Phase 2 must complete before user-story validation.
- US1 is MVP because credential protection underpins the rest of the feature.
- US2 can run after foundational checks and independently from US3 and US4.
- US3 can run after foundational checks and independently from US2 and US4.
- US4 can run after foundational checks and independently from US2 and US3.
- Polish depends on all selected user stories.

## Parallel Execution Examples

- After T005, T006 through T008 can validate separate source surfaces in parallel.
- T014 through T018 can be validated independently from T019 through T021.
- T023 through T025 can be validated in parallel after T022 is fixed.

## Implementation Strategy

1. Complete setup and foundational source validation.
2. Deliver MVP credential protection checks and harden SSH key import.
3. Validate transport/TLS and local-retention guardrails.
4. Fix local approval continuation handling and verify process/filesystem behavior.
5. Finish with task validation and a successful HermesMacOS Xcode build.
