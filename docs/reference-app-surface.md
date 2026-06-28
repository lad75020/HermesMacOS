# HermesMacOS application surface reference

## Main tabs

### Ask Hermes
Files: `HermesViews.swift`, `HermesModelsAPI.swift`, `HermesAskWorkspacesView.swift`, `ContentView.swift`.

Purpose: send prompts to `/v1/responses` with streaming, cancellation, reasoning controls, profile selection, response continuation, attachments, and independent workspaces.

Key capabilities:
- Multiple Ask workspaces, each with independent draft and `HermesResponsesSession`.
- Profile selector from `/v1/profiles`.
- Reasoning level controls through `HermesReasoningLevel` and request reasoning effort.
- Image and file attachments through `HermesPromptAttachment`.
- Streaming SSE parser, raw debug JSON, status cards, token usage, elapsed time, and optional stream-output bubble.
- Session resume from History.

### Chat with Hermes
Files: `HermesChatView.swift`, `HermesChatCompletionsAPI.swift`.

Purpose: send chat prompts to `/v1/chat/completions` with streaming/non-streaming modes, optional system prompt, attachments, cancellation, and history resume.

### Memory
Files: `HermesMemoryView.swift`, `HermesMemoryStore.swift`, `HermesHindsightMemoryClient.swift`, `ContentView.swift`.

Purpose: browse readable Hindsight memories from a native tab, page through provider-backed results, filter by text, refresh, and delete one memory after confirmation. Provider access stays behind the Hermes Agent Python/Hindsight boundary, uses bounded helper execution, and displays only sanitized user-facing errors.

Key capabilities:
- Hindsight-backed Memory rows with bounded previews and non-sensitive metadata summaries.
- Refresh, Previous, Next, and range text for deterministic pagination.
- Text filtering that resets to the first page and distinguishes filtered-empty, provider-empty, and provider-error states.
- Row-specific delete confirmation with provider invalidation and page clamping after success.

### TUI Gateway
Files: `HermesTUIGatewayView.swift`, `ContentView.swift`, `HermesHistoryView.swift`.

Purpose: run Hermes through the dashboard `api/ws` WebSocket JSON-RPC protocol from a native SwiftUI tab. This mirrors the live TUI execution path while keeping the transcript, composer, attachments, session controls, and request prompts inside HermesMacOS.

Key capabilities:
- Connects to the dashboard WebSocket route with a one-time WebSocket ticket when available, falling back to the dashboard session token query parameter.
- Creates, activates, interrupts, closes, lists, and resumes TUI sessions with JSON-RPC methods such as `session.create`, `session.active_list`, `session.activate`, and `session.resume`.
- Multiple TUI workspaces, each with its own `HermesTUIGatewayStore`, live WebSocket/session state, prompt draft, request-response drafts, selected attachment, local attachment path, and attention state.
- Ask-style `+` and numbered workspace buttons beside the TUI Gateway title. Numbered buttons show streaming, completed, failed, and selected state.
- File upload through the composer paperclip using `HermesPromptAttachment`. Images use native TUI image attachment via `input.detect_drop`; UTF-8 text is inlined; binary documents include metadata and local path instructions.
- Streamed transcript bubbles for assistant text, reasoning, thinking, tool progress, status updates, background completions, and generic gateway events.
- Interactive request bubbles for approvals, clarifications, sudo password requests, and secret requests.
- Resume to TUI Gateway actions from History and Sessions restore stored dashboard sessions through `session.resume` into the selected TUI workspace.

See [TUI Gateway WebSocket reference](reference-tui-gateway-websocket.md) for protocol details.

### History
Files: `HermesHistoryView.swift`, `HermesDashboardHistorySearch.swift`.

Purpose: search dashboard conversations, browse sessions, inspect messages, filter by profile, and resume compatible sessions into Ask, Chat, or TUI Gateway.

### Sessions
File: `HermesHistoryView.swift`.

Purpose: paged dashboard session browsing through `HermesSessionsStore`.

### Approvals Inbox
File: `HermesApprovalsInboxView.swift`.

Purpose: list and resolve pending approvals for local access and certificate trust workflows.

### Kanban
File: `HermesKanbanView.swift`.

Purpose: manage Hermes Kanban boards, tasks, comments, task actions, dispatch, logs, profiles, and live updates.

### Hermes Dashboard
File: `HermesDashboardWebView.swift`.

Purpose: embed dashboard pages in a native WebKit view with themed URL handling.

### Configuration
Files: `HermesConfigurationView.swift` and `HermesConfiguration*Section.swift`.

Sections:
- Runtime summary.
- Profiles.
- Runtime models.
- MCP servers.
- Skills.
- Schedules.
- Plugins.
- Toolsets.

### Utilities
Files: `HermesUtilitiesView.swift`, `HermesInstallationView.swift`, `HermesKnowledgeEraserUtility.swift`, `HermesSpeechToText.swift`.

Utilities:
- Clipboard history, off by default.
- Prompt and response history.
- Raw Responses stream debugging.
- Hermes Agent repository status/update workflow.
- Knowledge eraser helper for `memory.md`, `USER.md`, and skills.
- Speech-to-text prompt input.

## Settings
File: `SettingsView.swift`.

Settings include:
- API base URL.
- Dashboard URL.
- API key.
- Allow self-signed certificate mode and host pin reset.
- Saved API/dashboard endpoint pairs.
- SSH username and private key import/removal for hosts.
- Allowed folders for local filesystem access.
- Theme, app language, title font, label font, prompt font size, and chat bubble font size.
- Optional side-tab visibility controls for Ask Hermes and Chat with Hermes. Hiding these tabs removes their side-rail entries without clearing current drafts, attachments, workspaces, or sessions.

## App resources
- Localizations: `Localizable.xcstrings` and localized InfoPlist strings in `*.lproj` directories.
- Fonts: JetBrains Mono, Mondwest, and Rules Expanded WOFF2 files.
- Splash video: `Resources/HermesSplash.mp4`.
- App icon: `Assets.xcassets/AppIcon.appiconset`.

## Public behavior boundaries
HermesMacOS is a client/control surface. It depends on live Hermes API and Dashboard services for agent execution, dashboard management data, schedules, skills, toolsets, plugins, and session history.
