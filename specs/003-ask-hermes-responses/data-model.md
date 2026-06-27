# Data Model: Ask Hermes Responses

## HermesRequestDraft

- **Attributes**: profile, userPrompt, stream flag, reasoningLevel.
- **Relationships**: edited by Ask composer, persisted by settings store, locked to active response profile during continuation.
- **Validation**: empty profile falls back to `default`; prompt text is redacted before secure persistence.

## HermesResponsesSession

- **Attributes**: entries, streamed text, event count, token usage, active profile/session IDs, request ID, output bubbles, status/error state.
- **Relationships**: consumed by `HermesResponsesConsoleView` and owned per Ask workspace.
- **Validation**: active streaming can be cancelled; endpoint security runs before secret-bearing requests.

## HermesAPIProfile

- **Attributes**: id, name, default flag, model, provider, supported parameters.
- **Relationships**: loaded from `/v1/profiles`, drives profile selector and reasoning control visibility.
- **Validation**: unsupported reasoning is hidden/clamped.

## HermesPromptAttachment

- **Attributes**: URL/path, filename, MIME type, kind, byte count, converted content.
- **Relationships**: selected in composer and converted into Responses input content.
- **Validation**: supported content types and size limits are enforced before request construction.

## HermesAskWorkspace

- **Attributes**: workspace id/title, draft, response session, selected attachment, attention state.
- **Relationships**: managed by workspace controls and selected by `ContentView`.
- **Validation**: switching workspaces must not leak draft/session state between workspaces.

## HermesStreamOutputBubble

- **Attributes**: id, associated user message, text, completion state.
- **Relationships**: optionally rendered after the user prompt that triggered streamed tool/event output.
- **Validation**: text must be concise, user-visible status output, not raw debug noise.
