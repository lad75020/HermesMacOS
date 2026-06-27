# Data Model: Chat Completions Console

## HermesChatDraft
- **Attributes**: profile, systemPrompt, userPrompt, stream flag.
- **Relationships**: edited by Chat composer and persisted by settings store.
- **Validation**: legacy model field is ignored; default profile is used when empty; saved prompts are redacted/encrypted.

## HermesChatSession
- **Attributes**: entries, streamed text, event count, active profile/session, request ID, status/error state, token usage.
- **Relationships**: owned by the Chat tab and updated by streaming/non-streaming requests.
- **Validation**: cancellation leaves prior transcript intact.

## HermesChatMessage
- **Attributes**: role, content, optional token usage.
- **Relationships**: rendered by chat transcript bubbles and included in follow-up request context.

## HermesChatCompletionsRequestBody
- **Attributes**: model, messages, stream flag, optional user/session metadata.
- **Relationships**: encoded for `/v1/chat/completions`.

## HermesChatMessageContentPayload
- **Attributes**: text payload or content parts.
- **Relationships**: converts prompt plus optional attachment into chat message content.
- **Validation**: image attachments become `image_url` parts; non-image attachments append safe text blocks.
