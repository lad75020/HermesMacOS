# Feature Specification: Chat Completions Console

**Feature Branch**: `feature/time-machine-chat-completions-console`  
**Created**: 2026-06-27  
**Status**: Draft  
**Input**: User description: "Feature: Chat Completions Console. Description: Lets users chat through the Hermes Chat Completions API with streaming or non-streaming replies, system prompts, attachments, cancellation, and session resume. Relevant files: HermesMacOS/HermesChatView.swift, HermesMacOS/HermesChatCompletionsAPI.swift, docs/how-to-use-ask-and-chat.md. Focus on this feature only; do not modify other features."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Send a chat prompt and receive an answer (Priority: P1)
A user opens Chat with Hermes, enters a prompt, and receives a conversational assistant reply through `/v1/chat/completions`.

**Why this priority**: Chat send/receive is the core value of the feature.

**Independent Test**: Configure a reachable Hermes API gateway, send a streaming and non-streaming chat prompt, and verify user/assistant messages appear.

**Acceptance Scenarios**:
1. **Given** the API base URL is reachable, **When** the user sends a chat prompt, **Then** the app posts to `/v1/chat/completions` and appends an assistant message.
2. **Given** streaming is enabled, **When** SSE deltas arrive, **Then** the live assistant bubble updates until completion.
3. **Given** streaming is disabled, **When** the final response envelope arrives, **Then** the assistant message, elapsed time, status, and usage are shown.

---

### User Story 2 - Use profiles, system prompt, cancellation, and resume (Priority: P2)
A user selects a profile, optionally enters a system prompt, cancels active work, resets chat, or resumes a previous chat session.

**Why this priority**: These controls make conversational work reliable across profiles and sessions.

**Independent Test**: Fetch/select a profile, set a system prompt, send a prompt, cancel a second prompt, and resume a stored chat session.

**Acceptance Scenarios**:
1. **Given** a profile is selected, **When** a chat request is sent, **Then** `X-Hermes-Profile` and session continuation headers reflect the active profile/session.
2. **Given** the system prompt is non-empty, **When** the request body is encoded, **Then** a system role message precedes user/assistant conversation content.
3. **Given** a request is active, **When** Cancel is pressed, **Then** local streaming stops and `/v1/requests/{request_id}/cancel` is attempted.

---

### User Story 3 - Attach files/images to chat prompts (Priority: P3)
A user attaches a supported image or file and sends a chat request that includes the attachment content or metadata safely.

**Why this priority**: Attachments extend chat usefulness but depend on the core chat request path.

**Independent Test**: Attach an image and a text file in separate chat prompts, then verify unsupported or oversized attachments produce clear errors.

**Acceptance Scenarios**:
1. **Given** an image attachment is selected, **When** chat content is encoded, **Then** the user message uses text plus `image_url` content parts.
2. **Given** a text/source/config attachment is selected, **When** chat content is encoded, **Then** the text attachment block is appended to the prompt.
3. **Given** an unsupported attachment is selected, **When** the user tries to send, **Then** the app displays an error and does not send invalid content.

### Edge Cases
- If `/v1/profiles` fails, chat remains usable with default profile and shows the profile refresh error.
- If the selected profile changes during a conversation, the conversation resets to avoid mixing incompatible profile state.
- If streaming emits malformed data, the UI reports failure without losing prior messages.
- If the configured URL is unsafe for secrets, endpoint validation blocks credentials before sending.
- If drafts/system prompts include secrets, saved drafts use redaction/encrypted retention.

## Requirements *(mandatory)*

### Functional Requirements
- **FR-001**: System MUST provide a Chat with Hermes console backed by `/v1/chat/completions`.
- **FR-002**: System MUST support streaming SSE and non-streaming chat response decoding.
- **FR-003**: System MUST include an optional system role message when the system prompt is non-empty.
- **FR-004**: System MUST support profile selection and send `X-Hermes-Profile`.
- **FR-005**: System MUST preserve chat session continuation and resume where session IDs are available.
- **FR-006**: System MUST support cancellation through generated request IDs and `/v1/requests/{id}/cancel`.
- **FR-007**: System MUST support image and text/document attachment conversion for chat content.
- **FR-008**: System MUST persist chat drafts through redacted/encrypted storage.
- **FR-009**: System MUST display chat status, events, elapsed time, token usage, and errors.
- **FR-SEC**: System MUST preserve endpoint validation, attachment limits, redaction, and encrypted retention.
- **FR-INT**: System MUST preserve Hermes Chat Completions, Profiles, and Cancel endpoint contracts.

### Key Entities *(include if feature involves data)*
- **HermesChatConsoleView**: SwiftUI chat console for profile/system prompt/composer/transcript/status/attachments.
- **HermesChatSession**: Observable chat state, request execution, streaming parse, cancellation, resume, and errors.
- **HermesChatDraft**: Persisted chat draft with profile, system prompt, user prompt, and stream flag.
- **HermesChatMessage**: Transcript message with role, content, and optional token usage.
- **HermesChatCompletionsRequestBody**: Encoded `/v1/chat/completions` request body.
- **HermesChatMessageContentPayload**: Text or content-part payload that handles attachments.

## Success Criteria *(mandatory)*
### Measurable Outcomes
- **SC-001**: A user can send streaming and non-streaming chat prompts and see assistant replies.
- **SC-002**: A non-empty system prompt appears as system context in the request body.
- **SC-003**: Cancel exits streaming state and attempts backend cancellation.
- **SC-004**: Supported image/text attachments encode successfully and unsupported attachments fail clearly.
- **SC-BUILD**: The `HermesMacOS` scheme builds successfully with Xcode or command-line `xcodebuild`.
- **SC-SMOKE**: The primary Chat user journey can be validated independently with documented live-service smoke checks.

## Assumptions
- This pass documents the existing Chat implementation and does not add new backend capabilities.
- Live verification requires a reachable Hermes API gateway.
- No automated test target exists yet.

## Clarifications
### Session 2026-06-27
- No critical product questions were generated; existing source and docs define the Chat Completions behavior boundaries.
