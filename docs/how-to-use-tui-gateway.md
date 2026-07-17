# How to use the TUI Gateway tab

This guide shows how to use the native TUI Gateway tab to run Hermes through the same live WebSocket protocol used by the terminal TUI, without leaving HermesMacOS.

## Prerequisites

- Hermes Dashboard is reachable from the configured Dashboard URL.
- The dashboard exposes `api/ws` and the WebSocket ticket route `api/auth/ws-ticket`, or it accepts the dashboard session token as a WebSocket query parameter named `token`.
- The API settings in HermesMacOS are valid for the target host. They are reused for TLS policy, dashboard token extraction, and the URLSession used for the WebSocket.

## Connect and create a live session

1. Open **TUI Gateway**.

2. Press **Connect**.

   HermesMacOS resolves the dashboard base URL, obtains the dashboard session token, requests a one-time WebSocket ticket when the dashboard supports it, and opens the dashboard WebSocket route.

3. Wait for the status cards to update.

   A successful first connection creates a live TUI session automatically. The **Session** card shows the session title, the **Status** card changes from `Connecting` to `Session ready`, and the **Events** card increments as gateway events arrive.

4. Use **New session** when you want a fresh live TUI session in the selected workspace.

   This sends the JSON-RPC method `session.create` over the existing WebSocket and clears the selected workspace transcript. When the selected model supports it, the workspace's reasoning effort is sent as `reasoning_effort`.

## Choose reasoning effort

The compact **REASONING** menu sits directly below **FAST** in the TUI Gateway header. It is available only for the selected model when the gateway's `model.options` capability metadata reports reasoning support (with profile metadata used as a disconnected fallback).

Choose Off, Minimal, Low, Medium, High, Extra High, Max, or Ultra. The default for each new workspace is Medium. For a new session, the selection is sent in `session.create`; changing it on an idle live session applies it immediately to the next inferred turn. The control is unavailable while connecting, streaming, or resuming.

## Use multiple TUI workspaces

The TUI Gateway title row has Ask-Hermes-style workspace controls:

- Press **+** to create another TUI workspace.
- Press a numbered workspace button to switch workspaces.
- Right-click a numbered workspace button and choose **Delete Workspace** to remove it.

Each workspace owns its own `HermesTUIGatewayStore`, draft prompt, request-response fields, selected attachment, local attachment path, and reasoning effort. Switching workspaces preserves drafts, attachments, reasoning choices, live sessions, transcripts, and active WebSocket state for the other workspaces.

The numbered buttons show attention state:

- Orange blinking: the workspace is connecting, streaming, or resuming.
- Green: the workspace completed a turn and has not been acknowledged yet.
- Red: the workspace has an error or failed turn.
- Blue: the selected idle workspace.

Deleting a workspace is disabled while that workspace is connecting, streaming, or resuming. Deletion disconnects the workspace store before removing it.

## Send prompts and attachments

1. Connect the workspace.

2. Type a prompt.

3. Optional: press the paperclip button to attach a file.

   The TUI Gateway composer accepts the same `HermesPromptAttachment.supportedContentTypes` as the other prompt clients. The selected file appears as an attachment chip above the editor. Removing the chip clears both the attachment and its local path.

4. Press the send button or use **Command-Return**.

   The workspace sends the prompt through `prompt.submit`. Attachment-only sends are allowed.

Attachment behavior depends on file type:

- Images with a local path first call `input.detect_drop`. The app sends a quoted local path plus the prompt text so the gateway can populate its native image attachment state before `prompt.submit`.
- Images without a local path fall back to inline data URL text.
- UTF-8 text/source/config files are inlined with the `HermesPromptAttachment.textAttachmentBlock` format, plus the local path when available.
- Binary documents are represented with filename, MIME type, byte count, and local path so file-aware tools can inspect them.

Before the user prompt is appended, the transcript adds an `input.attachment` event bubble summarizing the attachment.

## Handle live gateway requests

The transcript can render more than assistant text. When Hermes asks for input, the app creates an interactive request bubble:

- `approval.request`: buttons for **Run once**, **Allow all**, and **Deny**. These answer with `approval.respond`.
- `clarify.request`: a text field plus **Respond** and **Skip**. These answer with `clarify.respond`.
- `sudo.request`: a secure field plus **Respond** and **Skip**. These answer with `sudo.respond`.
- `secret.request`: a secure field plus **Respond** and **Skip**. These answer with `secret.respond`.

Resolved request bubbles are marked as resolved in the transcript.

## Read current context usage

When Hermes reports current context-window occupancy, an assistant response header shows a compact value beside **Hermes**, such as `Context 12.3K`. It updates in place on the current response and remains visible after streaming completes. VoiceOver also announces the exact used-token count and, when supplied by the gateway, the context maximum and percentage.

The value comes only from `usage.context_used` in `message.complete` or `session.info` events. HermesMacOS accepts a JSON number or numeric string. It deliberately does not substitute cumulative `usage.total`; when the gateway does not report current-window occupancy, the counter is omitted.

## Interrupt, close, and switch sessions

- **Interrupt** sends `session.interrupt` for the current live session and stops local streaming state.
- **Close session** sends `session.close`, clears the live and stored session IDs, and refreshes the live-session menu.
- **Live sessions** shows `session.active_list`. Choosing a row sends `session.activate` for that already-live TUI session.

Use `session.activate` only for live in-memory TUI sessions. Stored dashboard/history sessions use `session.resume`, described below.

## Resume sessions into TUI Gateway

History and Sessions can reopen stored Hermes sessions in the selected TUI workspace with **Resume to TUI Gateway**.

The resume action:

1. Reads the selected stored session ID.
2. Connects the TUI Gateway WebSocket if the selected workspace is disconnected, without creating a blank live session first.
3. Sends `session.resume` with the stored session ID.
4. Restores the returned live TUI session ID, stored session key, transcript messages, title, and running state.
5. Switches the app to the TUI Gateway tab.

The resume action is disabled while the selected TUI workspace is connecting, streaming, or already resuming. This prevents racing two session transitions over one workspace WebSocket.

## Verification

A healthy TUI Gateway flow looks like this:

1. Press **Connect** and see `Session ready`.
2. Send a prompt and see `message.start`, one or more streamed bubbles, and then `Completed`.
3. Attach an image and confirm the transcript includes an `input.attachment` bubble before the user prompt.
4. Start another workspace with **+**, switch back, and confirm the first workspace kept its transcript and draft state.
5. Resume a stored History or Sessions item into TUI Gateway and confirm the tab switches and restored messages appear.

## Troubleshooting

- **The WebSocket URL is invalid**: verify the Dashboard URL uses `http` or `https`. HermesMacOS converts those schemes to `ws` or `wss` for `api/ws`.
- **Connection failed**: confirm the dashboard is running and that the app can fetch a dashboard session token from the dashboard HTML.
- **Prompt send says a session is missing**: press **Connect** or **New session** before sending. `prompt.submit` requires a live TUI session ID.
- **Image attachment failed**: make sure the selected image still exists at the local path. Native image attachment uses `input.detect_drop` with that path.
- **Resume failed**: make sure the selected item is a stored Hermes session and the gateway supports `session.resume`.
- **A workspace cannot be deleted**: wait for connecting, streaming, or resume state to finish, or interrupt/close the live session first.
