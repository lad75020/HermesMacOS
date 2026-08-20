# Feature Specification: Chat Completions Console

**Feature Branch**: `feature/time-machine-chat-completions-console`  
**Created**: 2026-06-27  
**Status**: Refined
**Refined**: 2026-08-20 — Added in-place English translation for selected Chat bubble text using Apple's native macOS 26 translation library.
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

---

### User Story 4 - Translate selected bubble text into English (Priority: P4)
A user selects text in a visible Chat with Hermes message bubble, opens the selection context popup with a right-click, chooses «Translate to English», and sees the selected text replaced in that same bubble by Apple's native macOS 26 translation result.

**Why this priority**: Translation improves comprehension without leaving the conversation and is independent of the Hermes chat service once bubble text is available.

**Independent Test**: Open Chat with Hermes with a message bubble containing non-English text, select part of the text, right-click the selection, choose «Translate to English», and verify that only the selected range is replaced while the surrounding bubble text remains unchanged.

**Acceptance Scenarios**:
1. **Given** a completed Chat message bubble contains selectable text, **When** the user selects a non-empty range and right-clicks it, **Then** a context popup appears with a clickable action labeled «Translate to English».
2. **Given** a valid text selection and the translation action is clicked, **When** Apple's native macOS 26 translation library translates the selection to English, **Then** the translated result replaces only that selected range in the original bubble and unselected text, message order, and bubble identity remain unchanged.
3. **Given** the native translation library is unavailable, cannot identify the source language, or returns an error, **When** translation is attempted, **Then** the original bubble text remains intact and the user sees a recoverable translation error without a new Hermes chat request.

### Edge Cases
- If `/v1/profiles` fails, chat remains usable with default profile and shows the profile refresh error.
- If the selected profile changes during a conversation, the conversation resets to avoid mixing incompatible profile state.
- If streaming emits malformed data, the UI reports failure without losing prior messages.
- If the configured URL is unsafe for secrets, endpoint validation blocks credentials before sending.
- If drafts/system prompts include secrets, saved drafts use redaction/encrypted retention.
- If a selection spans multiple bubbles, is empty, or belongs to a still-streaming bubble, the translation action is unavailable and no message content changes.
- If translated text has different length or formatting, replacement is bounded to the selected range and the bubble remains safely renderable.
- If the user translates a message that is later used for session continuation, the updated bubble content follows the existing chat-session state and retention rules.

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
- **FR-010**: System MUST allow text selection within rendered Chat with Hermes message bubbles.
- **FR-011**: System MUST present a context popup after a right-click on a non-empty text selection with a clickable action labeled «Translate to English».
- **FR-012**: System MUST translate the selected text to English through Apple's native macOS 26 translation library rather than the Hermes chat API or another chat request.
- **FR-013**: System MUST replace only the selected range in the original bubble while preserving unselected text, message identity, message order, and the rest of the transcript.
- **FR-014**: System MUST preserve the original bubble text and show a recoverable user-facing error when native translation is unavailable, the source language cannot be identified, or translation fails.
- **FR-SEC**: System MUST preserve endpoint validation, attachment limits, redaction, and encrypted retention.
- **FR-INT**: System MUST preserve Hermes Chat Completions, Profiles, and Cancel endpoint contracts.

### Key Entities *(include if feature involves data)*
- **HermesChatConsoleView**: SwiftUI chat console for profile/system prompt/composer/transcript/status/attachments.
- **HermesChatSession**: Observable chat state, request execution, streaming parse, cancellation, resume, and errors.
- **HermesChatDraft**: Persisted chat draft with profile, system prompt, user prompt, and stream flag.
- **HermesChatMessage**: Transcript message with stable identity, role, mutable content, and optional token usage; translated text is updated in place.
- **HermesChatCompletionsRequestBody**: Encoded `/v1/chat/completions` request body.
- **HermesChatMessageContentPayload**: Text or content-part payload that handles attachments.
- **HermesChatTranslationSelection**: Selected message identity and text range, English target, in-flight state, translated result, and recoverable error state.
- **HermesNativeTranslationService**: Adapter around Apple's native macOS 26 translation library for availability checks, English translation, and failure reporting.

## Success Criteria *(mandatory)*
### Measurable Outcomes
- **SC-001**: A user can send streaming and non-streaming chat prompts and see assistant replies.
- **SC-002**: A non-empty system prompt appears as system context in the request body.
- **SC-003**: Cancel exits streaming state and attempts backend cancellation.
- **SC-004**: Supported image/text attachments encode successfully and unsupported attachments fail clearly.
- **SC-005**: A user can select text in a completed Chat bubble and see a context popup containing the «Translate to English» action.
- **SC-006**: A successful translation replaces the selected bubble substring with English while leaving unselected text and transcript ordering unchanged.
- **SC-007**: Translation unavailability or failure leaves the original bubble content unchanged and produces a recoverable user-facing error.
- **SC-BUILD**: The `HermesMacOS` scheme builds successfully with Xcode or command-line `xcodebuild`.
- **SC-SMOKE**: The primary Chat user journey can be validated independently with documented live-service smoke checks.

## Assumptions
- This pass documents the existing Chat implementation and does not add new backend capabilities.
- Live verification requires a reachable Hermes API gateway.
- No automated test target exists yet.
- The app targets macOS 26 or later, so Apple's native translation library is an available platform dependency for this feature.
- Translation targets English; source-language detection and translation availability are delegated to Apple's native macOS 26 translation library.
- Translation changes the displayed and retained content of the selected chat message according to the existing chat-session and draft-retention rules; it does not create a separate Hermes API request.

## Clarifications
### Session 2026-06-27
- No critical product questions were generated; existing source and docs define the Chat Completions behavior boundaries.

### Session 2026-08-20
- Added the requested right-click «Translate to English» action for selected text in completed Chat with Hermes bubbles.
- The translation uses Apple's native macOS 26 translation library and replaces only the selected range while preserving the original bubble on failure.
