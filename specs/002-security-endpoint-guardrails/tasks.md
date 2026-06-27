# Tasks: Security and Endpoint Guardrails

**Input**: Design documents from `/specs/002-security-endpoint-guardrails/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/security-guardrails.md, quickstart.md

**Tests/Verification**: Build verification and applicable manual security smoke checks are mandatory. Automated helper tests should be added when a test target exists.

**Organization**: Tasks are grouped by user story so each guardrail can be validated independently.

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Establish traceability for the existing security guardrail feature.

- [x] T001 Create feature artifact directory `specs/002-security-endpoint-guardrails/`
- [x] T002 Write feature specification in `specs/002-security-endpoint-guardrails/spec.md`
- [x] T003 Write implementation plan and research artifacts in `specs/002-security-endpoint-guardrails/plan.md` and `specs/002-security-endpoint-guardrails/research.md`
- [x] T004 Write design artifacts in `specs/002-security-endpoint-guardrails/data-model.md`, `specs/002-security-endpoint-guardrails/contracts/security-guardrails.md`, and `specs/002-security-endpoint-guardrails/quickstart.md`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Confirm existing source files and docs for the security guardrail layer.

- [x] T005 Confirm security notes exist in `SECURITY.md`
- [x] T006 Confirm security model docs exist in `docs/explanation-security-model.md`
- [x] T007 Confirm API/storage reference exists in `docs/reference-api-and-storage.md`
- [x] T008 Confirm guardrail implementation exists in `HermesMacOS/HermesSecurityUtilities.swift`
- [x] T009 Confirm API settings integration exists in `HermesMacOS/HermesModelsAPI.swift`

**Checkpoint**: Existing security source/doc anchors are present.

---

## Phase 3: User Story 1 - Block unsafe sensitive network traffic (Priority: P1) 🎯 MVP

**Goal**: Remote plaintext sensitive traffic is blocked while loopback HTTP remains usable.

**Independent Test**: Exercise endpoint validation with remote HTTP and loopback HTTP URLs.

- [x] T010 [US1] Verify `HermesEndpointSecurity` loopback and remote plaintext policy in `HermesMacOS/HermesSecurityUtilities.swift`
- [x] T011 [US1] Verify `HermesAPISettings` omits API key serialization and routes endpoint URL construction in `HermesMacOS/HermesModelsAPI.swift`
- [x] T012 [US1] Document endpoint validation smoke checks in `specs/002-security-endpoint-guardrails/quickstart.md`

**Checkpoint**: User Story 1 is documented and ready for security smoke verification.

---

## Phase 4: User Story 2 - Store and unlock secrets safely (Priority: P2)

**Goal**: API keys, SSH keys, retention keys, and pins remain in Keychain-backed storage and protected by unlock flow.

**Independent Test**: Save/reload representative secrets and verify plaintext storage is avoided.

- [x] T013 [US2] Verify `HermesAPIKeychain` and `HermesSSHKeychain` Keychain services in `HermesMacOS/HermesSecurityUtilities.swift` and `HermesMacOS/HermesModelsAPI.swift`
- [x] T014 [US2] Verify `HermesSecretUnlockGate` LocalAuthentication flow in `HermesMacOS/HermesSecurityUtilities.swift`
- [x] T015 [US2] Document Keychain/unlock smoke checks in `specs/002-security-endpoint-guardrails/quickstart.md`

**Checkpoint**: User Story 2 is documented and ready for manual/runtime verification.

---

## Phase 5: User Story 3 - Protect retained local content and debug output (Priority: P3)

**Goal**: Retained content and debug buffers are redacted, encrypted, migrated, and bounded.

**Independent Test**: Save representative retained content and inspect encrypted/redacted storage behavior.

- [x] T016 [US3] Verify `HermesSecretRedactor`, `HermesEncryptedRetentionStore`, and `HermesDebugLogBuffer` behavior locations in `HermesMacOS/HermesSecurityUtilities.swift`
- [x] T017 [US3] Document retention/debug smoke checks in `specs/002-security-endpoint-guardrails/quickstart.md`

**Checkpoint**: User Story 3 is documented and ready for manual/runtime verification.

---

## Phase 6: User Story 4 - Gate local filesystem and TLS trust decisions (Priority: P4)

**Goal**: Filesystem and self-signed TLS exceptions require explicit approval.

**Independent Test**: Trigger filesystem and certificate approval paths in a controlled local setup.

- [x] T018 [US4] Verify `HermesPinnedCertificateTrust` queues certificate-pin approvals in `HermesMacOS/HermesSecurityUtilities.swift`
- [x] T019 [US4] Verify `HermesLocalApprovalCenter` and `HermesFilesystemAccessPolicy` approval behavior in `HermesMacOS/HermesSecurityUtilities.swift`
- [x] T020 [US4] Document TLS/filesystem approval smoke checks in `specs/002-security-endpoint-guardrails/quickstart.md`

**Checkpoint**: User Story 4 is documented and ready for manual/runtime verification.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Verify the feature without claiming unavailable automated suite coverage.

- [x] T021 Run XcodeMCP build for the `HermesMacOS` scheme
- [x] T022 Run ad-hoc artifact verification for queue/spec/task structure and referenced paths
- [ ] T023 Perform manual security smoke checks from `specs/002-security-endpoint-guardrails/quickstart.md` when a suitable runtime/test host is available

---

## Dependencies & Execution Order

- Phase 1 must complete before generated artifacts can be reviewed.
- Phase 2 confirms source/doc anchors.
- User Story 1 is the MVP because transport validation protects all secret-bearing network flows.
- User Stories 2-4 can be reviewed independently after Phase 2.
- Phase 7 verification must run before marking the Time Machine queue feature complete.

## Parallel Opportunities

- T005-T009 can be checked in parallel because they reference separate docs/source areas.
- T010-T020 are read-only traceability checks and can be reviewed in parallel.
- T021 and T022 can run independently; T023 requires live app/runtime setup.
