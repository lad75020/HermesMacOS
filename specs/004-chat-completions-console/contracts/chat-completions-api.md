# Contract: Chat Completions API

## Profiles
- `GET /v1/profiles` populates the profile selector.
- Selected profile is sent through `X-Hermes-Profile`.

## Chat Request
- `POST /v1/chat/completions` sends ordered messages, stream flag, selected profile headers, optional system prompt, and attachment content.
- Streaming requests parse SSE deltas into the live assistant bubble.
- Non-streaming requests decode the final completion envelope.

## Cancellation and Resume
- Active requests use generated request IDs.
- Cancel attempts `POST /v1/requests/{request_id}/cancel` and stops local streaming.
- Session IDs are persisted for compatible resume flows.

## Attachments
- Images encode as chat content parts with `image_url` data URLs.
- Text/source/config files append text attachment blocks.
- Unsupported/oversized attachments fail before sending.

## Security
- URL validation precedes `Authorization` headers.
- Chat drafts/system prompts are redacted and encrypted when persisted.
