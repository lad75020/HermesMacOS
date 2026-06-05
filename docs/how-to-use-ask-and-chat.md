# How to use Ask Hermes and Chat with Hermes

This guide covers the two HTTP prompt clients in HermesMacOS: Ask Hermes for `/v1/responses` and Chat with Hermes for `/v1/chat/completions`. For the native WebSocket-based TUI client, see [How to use the TUI Gateway tab](how-to-use-tui-gateway.md).

## Prerequisites
- API base URL is configured and reachable.
- Profiles endpoint `/v1/profiles` is reachable if you want profile selection.
- Optional: dashboard URL is configured if you want history resume and dashboard-backed suggestions.

## Ask Hermes

1. Open Ask Hermes.

2. Pick or keep a profile.

   The app sends the selected profile through the `X-Hermes-Profile` header. If no profile is selected, code falls back to `default`.

3. Choose a reasoning level when the selected model supports it.

   The Responses request includes a `reasoning` object only when the draft reasoning level maps to a request effort.

4. Add an attachment if needed.

   Supported attachment handling includes images, text files, JSON, YAML, TOML, Swift files, PDFs, and Office documents. Images are sent as input image data URLs. UTF-8 text files are inlined into the prompt with truncation. Binary documents are described rather than inlined.

5. Send the prompt.

   Streaming mode uses server-sent events. Non-streaming mode decodes the final JSON envelope.

6. Watch status and output.

   The assistant bubble shows response text. Optional stream-output bubbles summarize tool/event output without mixing it into the assistant text.

7. Continue or reset.

   Follow-up prompts continue the active stored response through `previous_response_id` and Hermes session headers. Starting a new session clears the workspace session state.

## Multi-workspace Ask Hermes

Use the workspace controls to create independent Ask sessions. Each workspace has its own draft, response session, completion/failure attention state, and output. The side rail and workspace buttons blink on streaming, completion, or failure until acknowledged.

## Chat with Hermes

1. Open Chat with Hermes.

2. Configure the optional system prompt.

   The Chat request body includes a system role message only when the system prompt is not empty.

3. Add attachments if needed.

   Chat supports text/image/document attachment conversion into chat content payloads.

4. Send the prompt.

   Streaming mode consumes chat SSE events. Non-streaming mode decodes the chat completion response envelope.

5. Resume a session from History when needed.

   The History tab can resume a compatible session into Chat with Hermes.

## Cancellation
Both Ask and Chat create a Hermes request ID for active work. Pressing Cancel stops the local task and asks the API gateway to cancel `/v1/requests/{request_id}/cancel`.

## Related TUI Gateway flow
TUI Gateway does not send prompts through `/v1/responses` or `/v1/chat/completions`. It opens the dashboard `api/ws` WebSocket and sends JSON-RPC methods such as `session.create`, `prompt.submit`, `input.detect_drop`, and `session.resume`. Use it when you want the native HermesMacOS UI around the same live protocol used by the terminal TUI.

## Verification
- Ask Hermes should show event count, token usage when returned, and final status.
- Chat should append user and assistant messages and show elapsed response time and token usage when returned.
- The Utilities tab should capture prompt/response history when persistence is enabled.

## Troubleshooting
- Attachment too large: choose a smaller file. Limits are enforced before request construction.
- Unsupported attachment type: choose one of the supported image, text, PDF, Office, JSON, YAML, TOML, or Swift file types.
- Streaming stalls: try non-streaming mode to distinguish SSE handling from backend response generation.
- Cancellation does not stop backend work: check whether the configured gateway supports the `/v1/requests/{id}/cancel` route.
