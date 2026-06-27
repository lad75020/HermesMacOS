# Feature Specification: Approvals Inbox

**Feature Branch**: `feature/time-machine-approvals-inbox`  
**Created**: 2026-06-27  
**Status**: Draft  
**Input**: User description: "Feature: Approvals Inbox. Description: Lets users review and resolve pending Hermes approvals for local access, certificate trust, and other gated workflows. Relevant files: HermesMacOS/HermesApprovalsInboxView.swift, HermesMacOS/HermesModelsAPI.swift, HermesMacOS/HermesSecurityUtilities.swift. Focus on this feature only; do not modify other features."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Review pending approvals (Priority: P1)

A user opens Approvals Inbox and sees pending remote gateway approvals plus local filesystem/TLS approvals in one sorted list with clear status and age.

**Why this priority**: Reviewing pending approvals is the core inbox function.

**Independent Test**: Configure pending remote/local approvals, open the inbox, and verify refresh status, count, sorting, local fallback, and error messaging.

**Acceptance Scenarios**:

1. **Given** the API gateway returns approvals JSON, **When** the inbox refreshes, **Then** remote approvals are decoded and displayed with count, kind, title, command, description, session key, and age.
2. **Given** local approval requests exist, **When** remote refresh succeeds or fails, **Then** local approvals are included with `local-` identifiers and HermesMacOS surface metadata.
3. **Given** remote refresh fails, **When** local approvals exist, **Then** the inbox remains usable and reports local pending approvals plus the remote error.

---

### User Story 2 - Resolve remote and local approvals (Priority: P2)

A user approves, denies, or otherwise resolves an approval and sees the list refresh without duplicate resolution.

**Why this priority**: The inbox must safely unblock or deny gated workflows.

**Independent Test**: Resolve one local and one remote approval, verify request bodies/callbacks and that resolving state prevents duplicate taps.

**Acceptance Scenarios**:

1. **Given** a remote approval is selected, **When** the user approves or denies it, **Then** the app posts to `/v1/approvals/resolve` with choice, `resolve_all: false`, and session key.
2. **Given** a local approval is selected, **When** the user resolves it, **Then** `HermesLocalApprovalCenter` receives the decision and remote APIs are not called.
3. **Given** an approval is resolving, **When** the user taps again, **Then** duplicate resolution is prevented by the resolving ID set.

---

### User Story 3 - Keep the inbox current and secure (Priority: P3)

A user can manually refresh or rely on auto-refresh, while API-key traffic remains protected by endpoint validation and content-type checks.

**Why this priority**: Approval queues change while agents run and involve sensitive trust decisions.

**Independent Test**: Enable auto-refresh, verify periodic refresh, toggle it off, test unsafe remote HTTP with API key, and verify JSON content-type validation.

**Acceptance Scenarios**:

1. **Given** auto-refresh is enabled, **When** five seconds pass, **Then** the store refreshes unless the task is cancelled.
2. **Given** the user disables auto-refresh, **When** the loop ticks, **Then** no refresh is started until it is re-enabled or manually requested.
3. **Given** an API key is configured for remote plaintext HTTP, **When** approval fetch/resolve would send credentials, **Then** endpoint security blocks the request.
4. **Given** `/v1/approvals` returns non-JSON content, **When** refresh validates the response, **Then** a restart/actionable error is shown.

### Edge Cases

- The API base URL may not construct approvals endpoints; show invalid URL errors.
- Empty approval list should show a no-pending state rather than an error.
- Remote and local approvals may share session ordering; sort by session key then queue position.
- TLS certificate and filesystem local approvals must retain fingerprint/pattern metadata.
- Resolving an approval may fail; the approval should remain visible and an error should be displayed.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide an Approvals Inbox UI backed by `/v1/approvals` and local approval center state.
- **FR-002**: System MUST decode approval item metadata including id, session key, queue position, kind, title, command, description, pattern metadata, created timestamp, surface, and scope options.
- **FR-003**: System MUST merge remote approvals and local approvals, then sort by session key and queue position.
- **FR-004**: System MUST support manual refresh and auto-refresh loop behavior.
- **FR-005**: System MUST resolve remote approvals through `/v1/approvals/resolve` with choice, session key, and `resolve_all` set false.
- **FR-006**: System MUST resolve local approvals through `HermesLocalApprovalCenter` without calling remote endpoints.
- **FR-007**: System MUST prevent duplicate resolution for an already resolving approval.
- **FR-008**: System MUST display status, errors, pending count, last update, approval age, and user-friendly approval kind labels.
- **FR-SEC**: System MUST validate sensitive URLs before adding API key authorization and must validate JSON content type for approval list responses.
- **FR-INT**: System MUST preserve Hermes approval endpoint contracts and local approval center semantics.

### Key Entities *(include if feature involves data)*

- **HermesApprovalItem**: Unified remote/local approval row with kind, command, pattern metadata, session key, queue position, age, and scope options.
- **HermesApprovalsInboxStore**: Observable approval list state, refresh/resolve logic, local fallback, auto-refresh loop, loading/resolving flags, and errors.
- **HermesApprovalResolveBody**: Encoded remote approval resolution payload.
- **HermesApprovalsInboxView**: SwiftUI inbox UI with header, status, pending rows, refresh controls, auto-refresh toggle, and resolve actions.
- **HermesLocalApprovalCenter**: Local filesystem/TLS approval source and resolution target.
- **HermesEndpointSecurity**: Sensitive URL validation before secret-bearing approval requests.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user can refresh and see pending remote/local approvals with counts and friendly metadata.
- **SC-002**: A user can approve or deny a remote approval and the list refreshes afterward.
- **SC-003**: A user can resolve local filesystem/TLS approvals without remote API calls.
- **SC-004**: Auto-refresh updates the inbox while enabled and stops when disabled or cancelled.
- **SC-005**: Unsafe secret-bearing remote HTTP and non-JSON approval responses produce clear errors.
- **SC-BUILD**: The `HermesMacOS` scheme builds successfully with Xcode or command-line `xcodebuild`.
- **SC-SMOKE**: The primary approvals inbox flow can be validated independently with documented API/local approval smoke checks.

## Assumptions

- This pass documents the existing Approvals Inbox implementation and does not add new approval kinds or backend endpoints.
- Live verification requires a reachable Hermes API gateway or locally pending approvals.
- No automated test target exists yet.

## Clarifications

### Session 2026-06-27

- No critical product questions were generated; existing source defines the approvals behavior boundaries.
