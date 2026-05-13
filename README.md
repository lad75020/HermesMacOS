# HermesMacOS

HermesMacOS is a native SwiftUI macOS control surface for Hermes Agent. It brings the core HermesiOS desktop-style workflows back to the Mac: ask Hermes through the Responses API, search dashboard conversation history, resume previous sessions, and keep useful local debugging utilities nearby.

The app is intentionally small and focused. It does not run Hermes Agent itself; it connects to an existing Hermes gateway/API server and dashboard.

## What it does

- Ask Hermes: chat with Hermes through the `/v1/responses` endpoint using a native macOS transcript and composer.
- Multiple Ask workspaces: open independent Hermes sessions with the `+` button and switch between numbered workspace pills.
- Workspace state indicators: workspace buttons blink orange while streaming, turn green when a response completes, and turn red on failure. Clicking a workspace acknowledges and clears the indicator.
- Profile support: loads available Hermes profiles from `/v1/profiles`, lets you choose a profile before starting a session, and keeps the profile locked while that session is active.
- Streaming and non-streaming Responses API requests: stream SSE output live or send a single JSON request depending on the Ask Hermes setting.
- Session continuation: keeps `previous_response_id` and Hermes session headers so follow-up prompts continue the right conversation.
- Resume last: stores the most recent Responses session id in UserDefaults and can reopen it from the composer.
- Attachments: supports image, PDF, Office, text, JSON, YAML, TOML, and Swift files. Images are sent as Responses API image inputs; text-like files are embedded as readable text; other supported files are passed as base64 data URLs.
- History: searches the Hermes dashboard conversation index through `/api/sessions/search/conversations`, with profile filtering and full conversation result rows.
- Resume from History: loads a dashboard conversation into the currently selected Ask Hermes workspace when that workspace is idle.
- Utilities: local macOS clipboard history, prompt/response history, and raw Responses API stream debugging.
- Settings: stores Hermes API URL/API key, self-signed certificate behavior, dashboard URL, and default Ask Hermes draft/profile/streaming choices.

## Tabs

### Ask Hermes

The main tab is a chat-style Responses API client.

The header shows:

- profile selector
- current session title
- request status
- SSE event count
- streaming activity
- workspace controls

The composer supports:

- `Command + Return` to send
- file attachment with the paperclip button
- `Cancel` while a request is running
- `End Session` to clear the active conversation
- `Resume last` when a previous Responses session id is known

Each Ask workspace owns its own draft, transcript, active session, streaming state, response id, Hermes session id, raw stream log, and error state.

### History

The History tab queries the Mac-hosted Hermes dashboard rather than local app storage.

It:

- fetches the dashboard HTML
- extracts `window.__HERMES_SESSION_TOKEN__`
- calls `/api/sessions/search/conversations`
- retries once with a fresh dashboard token after a 401
- supports profile filters based on `/v1/profiles`
- displays matching sessions as expandable rows
- shows the initial user prompt and final assistant response for quick review
- can resume a result into Ask Hermes

### Utilities

Utilities are local to HermesMacOS and use AppKit where needed.

Clipboard History:

- watches `NSPasteboard.general` while the app is active
- stores the last 10 text, image, or file clipboard entries
- fingerprints entries with SHA-256 to avoid duplicates
- can copy an older entry back to the clipboard
- can delete individual entries or clear the list

Messages History:

- stores the last 10 submitted Ask Hermes prompts
- stores the last 10 completed Hermes responses
- lets you switch between Prompt and Response history
- can copy or delete entries

Debugging:

- shows raw Responses API SSE/JSON events for the selected Ask workspace
- includes an event count and clear button
- keeps low-level stream diagnostics out of the main chat transcript

### Settings

Settings are persisted in UserDefaults.

Hermes API:

- Base URL, usually ending in `/v1`
- API key, sent as `Authorization: Bearer TOKEN_PLACEHOLDER` when present
- self-signed certificate toggle for local/Tailscale deployments
- restore default endpoint button

Hermes Dashboard:

- Dashboard URL used by History search
- restore default dashboard button

Ask Hermes defaults:

- default profile
- streaming on/off
- default prompt draft

## Requirements

- macOS 14 or newer
- Xcode with SwiftUI/AppKit support
- XcodeGen, because the project is generated from `project.yml`
- A reachable Hermes Agent API gateway exposing:
  - `GET /v1/profiles`
  - `POST /v1/responses`
- A reachable Hermes dashboard for History search, exposing:
  - dashboard HTML containing `window.__HERMES_SESSION_TOKEN__`
  - `GET /api/sessions/search/conversations`

## Build and run

From the repository root:

```sh
xcodegen generate
open HermesMacOS.xcodeproj
```

Then build and run the `HermesMacOS` scheme in Xcode.

Command-line build:

```sh
xcodegen generate
xcodebuild \
  -project HermesMacOS.xcodeproj \
  -scheme HermesMacOS \
  -destination 'generic/platform=macOS' \
  build
```

If DerivedData is locked or a previous Xcode build is interfering, use an isolated DerivedData folder:

```sh
xcodebuild \
  -project HermesMacOS.xcodeproj \
  -scheme HermesMacOS \
  -destination 'generic/platform=macOS' \
  -derivedDataPath /tmp/HermesMacOSDerivedData \
  build
```

## Configure Hermes endpoints

Open Settings in the app and set:

1. Hermes API Base URL

Use the gateway URL that serves the OpenAI-compatible Hermes API. It should normally include `/v1`, for example:

```text
https://your-host.ts.net:8642/v1
```

2. Hermes API key

If your gateway requires authentication, paste the API key. HermesMacOS stores it in app UserDefaults and sends it as a bearer token.

3. Allow self-signed certificates

Enable this when using a trusted local or Tailscale deployment with a certificate chain macOS does not validate by default.

4. Hermes Dashboard URL

Use the dashboard root, not the `/v1` API URL, for example:

```text
https://your-host.ts.net:9120
```

History search needs this dashboard URL because it extracts the dashboard session token before calling the dashboard search endpoint.

## Hermes backend checklist

Before using the app, verify the backend from the Mac:

```sh
curl -i https://your-host.ts.net:8642/v1/profiles
curl -i https://your-host.ts.net:9120/
```

If the API requires a key:

```sh
curl -i \
  -H 'Authorization: Bearer TOKEN_PLACEHOLDER' \
  https://your-host.ts.net:8642/v1/profiles
```

For History search, the dashboard HTML must contain a session token:

```sh
curl -s https://your-host.ts.net:9120/ | grep __HERMES_SESSION_TOKEN__
```

## Development notes

Project layout:

```text
project.yml                              XcodeGen project definition
HermesMacOS/HermesMacOSApp.swift         app entry point
HermesMacOS/ContentView.swift            root tab and workspace coordinator
HermesMacOS/HermesAskWorkspacesView.swift Ask Hermes workspace switcher
HermesMacOS/HermesViews.swift            Ask Hermes UI, Settings, shared styling
HermesMacOS/HermesModelsAPI.swift        API models, networking, Responses session
HermesMacOS/HermesHistoryView.swift      dashboard history UI
HermesMacOS/HermesDashboardHistorySearch.swift dashboard search client
HermesMacOS/HermesUtilitiesView.swift    clipboard/history/debug utilities
```

When adding new Swift files, update or regenerate with XcodeGen:

```sh
xcodegen generate
```

Keep secrets out of commits. Do not commit API keys, dashboard session tokens, or captured raw stream output.

## Current scope

HermesMacOS is the native Mac companion app for day-to-day Hermes interaction. It currently focuses on Ask Hermes, dashboard History, and local Utilities. It does not include the broader HermesiOS-only tabs such as Chat Completions, Web, Terminal, Agent Runtime, or Host Companion management.
