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

### History
Files: `HermesHistoryView.swift`, `HermesDashboardHistorySearch.swift`.

Purpose: search dashboard conversations, browse sessions, inspect messages, filter by profile, and resume compatible sessions into Ask or Chat.

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

## App resources
- Localizations: `Localizable.xcstrings` and localized InfoPlist strings in `*.lproj` directories.
- Fonts: JetBrains Mono, Mondwest, and Rules Expanded WOFF2 files.
- Splash video: `Resources/HermesSplash.mp4`.
- App icon: `Assets.xcassets/AppIcon.appiconset`.

## Public behavior boundaries
HermesMacOS is a client/control surface. It depends on live Hermes API and Dashboard services for agent execution, dashboard management data, schedules, skills, toolsets, plugins, and session history.
