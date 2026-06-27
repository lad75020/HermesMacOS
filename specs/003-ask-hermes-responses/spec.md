# Feature Specification: Ask Hermes Responses

**Feature Branch**: `feature/time-machine-ask-hermes-responses`  
**Created**: 2026-06-27  
**Status**: Draft  
**Input**: User description: "Feature: Ask Hermes Responses. Description: Lets users send prompts to the Hermes Responses API with streaming, cancellation, profiles, reasoning controls, attachments, session continuation, and multiple workspaces. Relevant files: HermesMacOS/HermesViews.swift, HermesMacOS/HermesModelsAPI.swift, HermesMacOS/HermesAskWorkspacesView.swift, docs/how-to-use-ask-and-chat.md. Focus on this feature only; do not modify other features."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Send a prompt and receive a streamed Responses answer (Priority: P1)

A user opens Ask Hermes, selects a profile, enters a prompt, and receives assistant text from `/v1/responses` with streaming status, events, elapsed time, and token usage when available.

**Why this priority**: Sending and reading a response is the core value of Ask Hermes.

**Independent Test**: Configure a reachable Hermes API gateway, open Ask Hermes, send a prompt in streaming mode, and verify assistant output appears with final status.

**Acceptance Scenarios**:

1. **Given** the API base URL is reachable, **When** the user sends a prompt, **Then** the app posts to `/v1/responses` with the selected profile and displays streamed assistant output.
2. **Given** streaming is disabled, **When** the user sends a prompt, **Then** the app decodes the final JSON response and appends the assistant message.
3. **Given** token usage or event counts are returned, **When** the response completes, **Then** status cards reflect the returned metrics.

---

### User Story 2 - Control profile, reasoning, cancellation, and continuation (Priority: P2)

A user selects a Hermes profile, adjusts reasoning when supported, cancels active work, and continues or resets the current stored response session.

**Why this priority**: These controls make Ask Hermes reliable for longer agent work and different model/profile configurations.

**Independent Test**: Fetch profiles, select one, send a prompt, cancel a second prompt, then send a follow-up and verify session continuation headers/previous response behavior.

**Acceptance Scenarios**:

1. **Given** `/v1/profiles` returns profiles, **When** the user selects a profile, **Then** outgoing requests include `X-Hermes-Profile` and profile-specific reasoning controls are clamped.
2. **Given** a request is streaming, **When** the user presses Cancel, **Then** the local stream stops and `/v1/requests/{request_id}/cancel` is attempted.
3. **Given** a stored response/session is active, **When** the user sends a follow-up, **Then** the request includes continuation context and the UI keeps one coherent workspace conversation.

---

### User Story 3 - Use attachments and prompt assistance (Priority: P3)

A user attaches supported files/images or uses slash/path suggestions while composing an Ask prompt.

**Why this priority**: Attachments and suggestions improve productivity but depend on the core request/session path.

**Independent Test**: Attach an image and a UTF-8 text file, verify request preparation succeeds, then attach an oversized/unsupported file and verify a clear error.

**Acceptance Scenarios**:

1. **Given** a supported image attachment is selected, **When** the prompt is sent, **Then** the request includes input image content as a data URL.
2. **Given** a supported text/source/config attachment is selected, **When** the prompt is sent, **Then** text is inlined with documented truncation behavior.
3. **Given** an unsupported or oversized file is selected, **When** import/request preparation runs, **Then** the app shows an attachment error and does not send an invalid request.

---

### User Story 4 - Work across multiple independent Ask workspaces (Priority: P4)

A user creates multiple Ask workspaces, each with independent draft, session state, output, streaming/completion attention, and reset behavior.

**Why this priority**: Multi-workspace support is a power-user capability layered on top of the single Ask session.

**Independent Test**: Create two Ask workspaces, send different prompts, switch between them, and verify drafts/session outputs remain isolated.

**Acceptance Scenarios**:

1. **Given** multiple workspaces exist, **When** the user switches workspace, **Then** draft text, response session, and output match the selected workspace.
2. **Given** a non-selected workspace completes or fails, **When** the user views workspace controls, **Then** an attention state signals completion or failure until acknowledged.

### Edge Cases

- If `/v1/profiles` fails, the composer remains usable with a default profile and displays the profile refresh error.
- If the selected model does not support reasoning controls, the reasoning picker is hidden or clamped to off.
- If streaming stalls or emits malformed SSE/JSON, the app must surface a failure state without corrupting existing messages.
- If cancellation cannot reach the backend, local cancellation still stops UI streaming and the user sees a coherent status.
- If API key traffic targets remote plaintext HTTP, endpoint security blocks the request before attaching credentials.
- If attachments are too large, unsupported, inaccessible, or binary-only, request construction fails safely with a user-visible error.
- If retained drafts/prompts include secrets, saved drafts/history use redaction/encrypted retention helpers.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide an Ask Hermes console backed by `/v1/responses`.
- **FR-002**: System MUST support streaming SSE and non-streaming response decoding.
- **FR-003**: System MUST fetch and display profiles from `/v1/profiles`, falling back to `default` when needed.
- **FR-004**: System MUST send selected profile via `X-Hermes-Profile`.
- **FR-005**: System MUST expose reasoning controls only when the selected profile/model supports them and include a reasoning effort only when enabled.
- **FR-006**: System MUST generate a Hermes request ID for cancellable work and attempt `/v1/requests/{request_id}/cancel` on cancel.
- **FR-007**: System MUST preserve response/session continuation through previous response ID and Hermes session headers where available.
- **FR-008**: System MUST support image, UTF-8 text/source/config, PDF, and Office attachments according to existing request conversion rules.
- **FR-009**: System MUST provide user-visible status, event count, token usage, elapsed time, and errors.
- **FR-010**: System MUST support multiple independent Ask workspaces with isolated drafts, sessions, attachments, and attention states.
- **FR-011**: System MUST preserve optional stream-output bubbles without mixing tool/event output into assistant answer text.
- **FR-SEC**: System MUST preserve endpoint validation, redaction, encrypted retention, and attachment safety guardrails.
- **FR-INT**: System MUST preserve Hermes API contracts for `/v1/responses`, `/v1/profiles`, and `/v1/requests/{id}/cancel`.

### Key Entities *(include if feature involves data)*

- **HermesResponsesConsoleView**: SwiftUI Ask console for profile/reasoning controls, transcript, composer, attachments, and status.
- **HermesResponsesSession**: Observable Responses API session state, streaming/non-streaming request orchestration, cancellation, continuation, output parsing, and errors.
- **HermesRequestDraft**: Persisted Ask draft containing profile, prompt, stream mode, and reasoning level.
- **HermesPromptAttachment**: Attachment model and conversion rules for images, text/config/source files, PDFs, and Office documents.
- **HermesAPIProfile**: Profile metadata returned from `/v1/profiles`, including model/provider and supported parameters.
- **HermesAskWorkspace**: Independent Ask workspace state containing draft, response session, attachment, and attention status.
- **HermesStreamOutputBubble**: Optional concise representation of streamed tool/event output separate from assistant response text.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user can send a streaming Ask prompt and see assistant text start rendering within the active workspace.
- **SC-002**: A user can cancel an active Ask request and the UI leaves streaming state without losing previous messages.
- **SC-003**: Profile selection changes outgoing request profile headers and invalid/unsupported reasoning choices are clamped.
- **SC-004**: Supported image/text attachments produce valid request content and unsupported/oversized attachments produce clear errors.
- **SC-005**: Two Ask workspaces preserve independent drafts, sessions, outputs, and attention states.
- **SC-BUILD**: The `HermesMacOS` scheme builds successfully with Xcode or command-line `xcodebuild`.
- **SC-SMOKE**: The primary Ask user journey can be validated independently with documented live-service smoke checks.

## Assumptions

- This pass documents and verifies the existing Ask Hermes implementation; it does not add new API capabilities.
- Live prompt verification requires a reachable Hermes API gateway and optional dashboard host.
- No automated test target exists yet; build and documented live-service/manual checks are the current verification path.

## Clarifications

### Session 2026-06-27

- No critical product questions were generated; source and docs define the Ask Hermes behavior boundaries for this retroactive feature.
