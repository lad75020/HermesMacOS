# HermesMacOS

HermesMacOS is a native SwiftUI macOS control surface for Hermes Agent. It brings the main Hermes workflows to the Mac in a lightweight companion app: Responses API chat, Chat Completions chat, dashboard history search, embedded configuration, local utilities, and repository update helpers.

The app does not run Hermes Agent itself. It connects to an existing Hermes API gateway and Hermes dashboard, then stores local preferences in UserDefaults.

## What it does

- Ask Hermes: chat through the `/v1/responses` endpoint with a native transcript, composer, profile picker, reasoning-level picker for supported profiles, SSE streaming, cancellation, session continuation, and file/image attachments.
- Multiple Ask workspaces: open independent Responses sessions with the `+` button, switch between numbered workspace pills, and delete idle workspaces.
- Workspace and tab attention indicators: Ask workspaces and the side tabs blink orange while streaming, turn green when a response completes, and turn red on failures where applicable. Selecting a workspace/tab acknowledges the status.
- Chat with Hermes: use `/v1/chat/completions` for a conversational flow with profile selection, optional system prompt, streaming/non-streaming requests, session resume, cancellation, and attachments.
- Speech-to-text prompts: dictate prompts from Ask Hermes or Chat with Hermes using the macOS Speech framework, microphone capture, progressive transcription, and on-demand speech model installation.
- Slash skill suggestions: typing a slash-style skill query in the composer fetches dashboard skills from `/api/skills` and inserts the selected skill name.
- Profile support: loads Hermes profiles from `/v1/profiles`, lets you choose a profile before a session starts, and locks the active profile while that session is running.
- Session continuation and resume: keeps Responses `previous_response_id`, chat session ids, and Hermes session headers so follow-up prompts continue the right conversation. The app stores the latest Responses and Chat sessions for quick resume.
- Attachments: supports image, PDF, Office, text, JSON, YAML, TOML, and Swift files. Images are sent as image inputs; text-like files are embedded as readable text; other supported files are passed as base64 data URLs.
- History: searches the Hermes dashboard conversation index through `/api/sessions/search/conversations`, supports profile filtering, shows matching full conversations, and can resume a result into either Ask Hermes or Chat with Hermes.
- Configuration: embeds the Hermes dashboard configuration page inside a themed WKWebView, using the dashboard URL from Settings.
- Utilities: local clipboard history, prompt/response history, raw stream debugging for Responses and Chat, plus a Hermes Installation helper for local git update workflows.
- Per-window connections: multiple Hermes windows can target different API/dashboard hosts. Settings can apply saved endpoint pairs to a selected window.
- Appearance and localization: supports system/light/dark theme selection, website-style title/label fonts, chat/prompt font sizing, and app language selection for English, French, Spanish, German, and Simplified Chinese.

## Main areas

### Ask Hermes

Ask Hermes is the Responses API client. It uses `/v1/responses` and mirrors the HermesiOS Responses workflow in a native macOS layout.

The header shows:

- connected host/window label
- profile selector loaded from `/v1/profiles`
- reasoning level selector when the selected profile supports it
- current session title
- request status
- SSE event count
- streaming activity
- workspace controls

The composer supports:

- `Command + Return` to send
- file attachment with the paperclip button
- microphone dictation into the prompt field
- slash skill suggestions from dashboard skills
- `Cancel` while a request is running
- `End Session` to clear the active conversation
- `Resume last` when a previous Responses session id is known

Each Ask workspace owns its own draft, transcript, active session, streaming state, response id, Hermes session id, raw stream log, output-bubble state, and error state. A Settings-controlled option can show streamed tool/output diagnostics as separate output bubbles; by default low-level stream details stay out of the main transcript.

### Chat with Hermes

Chat with Hermes is the Chat Completions client. It uses `/v1/chat/completions` for a conventional chat flow separate from Ask Hermes.

It supports:

- profile selection from `/v1/profiles`
- optional system prompt
- streaming or non-streaming output
- session continuation and `Resume last`
- `New Chat` and `Cancel`
- file/image attachments
- microphone dictation
- slash skill suggestions
- short status pills for Hermes tool progress, tool output, and reasoning events instead of dumping raw event payloads into chat bubbles

### History

The History tab queries the Mac-hosted Hermes dashboard rather than local app storage.

It:

- fetches the dashboard HTML
- extracts `window.__HERMES_SESSION_TOKEN__`
- calls `/api/sessions/search/conversations`
- retries once with a fresh dashboard token after a 401
- accepts natural-language and SQLite FTS-style queries
- supports profile filters based on `/v1/profiles`
- displays matching sessions as expandable rows
- shows message role, timestamps, source, profile, model, tool names, and content snippets
- reports matching message/session counts
- can resume a result into Ask Hermes or Chat with Hermes when the target is idle

### Configuration

The Configuration tab embeds the Hermes dashboard configuration UI in a native WKWebView.

It:

- uses the Dashboard URL from Settings
- appends a dashboard theme query based on the app color scheme
- injects a theme override before page load
- tracks dashboard theme API responses so the embedded page follows the selected light/dark appearance
- provides a reload control and unavailable-state message when no dashboard URL is configured

### Utilities

Utilities are local to HermesMacOS and use AppKit where needed.

Clipboard History:

- watches `NSPasteboard.general` while the app is active
- stores the last 10 text, image, or file clipboard entries
- fingerprints entries with SHA-256 to avoid duplicates
- can copy an older entry back to the clipboard
- can delete individual entries or clear the list

Messages History:

- stores the last 10 submitted prompts from Ask Hermes and Chat with Hermes
- stores the last 10 completed Hermes responses from both chat flows
- lets you switch between Prompt and Response history
- can copy or delete entries

Debugging:

- shows raw Responses API SSE/JSON events for the selected Ask workspace
- shows raw Chat Completions stream/debug events for Chat with Hermes
- includes event counts and clear controls
- keeps low-level stream diagnostics out of normal chat transcripts

Hermes Installation:

- defaults the local repository path to `~/.hermes/hermes-agent`
- runs git commands directly on this Mac; no companion host is required
- ensures the `upstream` remote points to `https://github.com/NousResearch/hermes-agent.git`
- refreshes lag/ahead counts against `upstream/main`
- shows current branch, HEAD revision, origin remote, dirty working-tree status, conflict files, and command output
- updates Hermes by fetching upstream main, creating/updating `upstream-latest`, switching local `main`, merging `upstream-latest`, stopping on conflicts, and pushing `main` to origin when successful
- can seed a new Ask Hermes workspace with an installation-review prompt

### Settings

Settings are persisted in UserDefaults.

Appearance:

- system/light/dark theme
- app language: Automatic, English, French, Spanish, German, or Simplified Chinese
- title and label font selectors, with website-font defaults
- chat bubble and prompt composer font-size controls

Hermes API:

- target window selector for multi-window setups
- saved API/dashboard endpoint pairs
- Base URL, usually ending in `/v1`
- API key, sent as `Authorization: Bearer ...` when present
- self-signed certificate toggle for local/Tailscale deployments
- save/remove saved connection buttons
- restore default endpoint button

Hermes Dashboard:

- Dashboard URL used by History and Configuration
- restore default dashboard button

Ask Hermes defaults:

- default profile
- streaming on/off
- default reasoning level
- default prompt draft

Chat with Hermes defaults:

- default profile
- streaming on/off
- optional common system prompt
- default prompt draft

## Requirements

- macOS 26.0 or newer
- Xcode with SwiftUI, AppKit, WebKit, AVFoundation, and Speech support
- XcodeGen, because the project is generated from `project.yml`
- A reachable Hermes Agent API gateway exposing:
  - `GET /v1/profiles`
  - `POST /v1/responses`
  - `POST /v1/chat/completions`
  - request cancellation endpoints when cancellation is used
- A reachable Hermes dashboard exposing:
  - dashboard HTML containing `window.__HERMES_SESSION_TOKEN__`
  - `GET /api/sessions/search/conversations`
  - `GET /api/skills`
  - dashboard configuration routes used by the embedded Configuration tab
- Microphone and speech recognition permission if using dictation

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

History, skill suggestions, and Configuration use this dashboard URL. History extracts the dashboard session token before calling the dashboard search endpoint.

5. Save current URLs

Use saved connections to store an API URL together with its matching dashboard URL. In multi-window setups, Settings can apply a saved connection to one selected Hermes window without changing the other open windows.

## Hermes backend checklist

Before using the app, verify the backend from the Mac:

```sh
curl -i https://your-host.ts.net:8642/v1/profiles
curl -i https://your-host.ts.net:9120/
```

If the API requires a key:

```sh
curl -i \
  -H 'Authorization: Bearer YOUR_KEY' \
  https://your-host.ts.net:8642/v1/profiles
```

For History search, the dashboard HTML must contain a session token:

```sh
curl -s https://your-host.ts.net:9120/ | grep __HERMES_SESSION_TOKEN__
```

For slash skill suggestions, the dashboard must expose skills:

```sh
curl -i https://your-host.ts.net:9120/api/skills
```

## Development notes

Project layout:

```text
project.yml                                      XcodeGen project definition
HermesMacOS/HermesMacOSApp.swift                 app entry point, language selection, commands
HermesMacOS/ContentView.swift                    root layout, side tabs, window connection coordinator
HermesMacOS/HermesAskWorkspacesView.swift        Ask Hermes workspace switcher
HermesMacOS/HermesViews.swift                    Ask Hermes UI, Settings, shared styling
HermesMacOS/HermesChatView.swift                 Chat with Hermes UI
HermesMacOS/HermesModelsAPI.swift                API models, settings, Responses session, host endpoints
HermesMacOS/HermesChatCompletionsAPI.swift       Chat Completions models/session and stream parsing
HermesMacOS/HermesHistoryView.swift              dashboard history UI
HermesMacOS/HermesDashboardHistorySearch.swift   dashboard search client
HermesMacOS/HermesConfigurationView.swift        embedded dashboard Configuration web view
HermesMacOS/HermesDashboardSkills.swift          dashboard skill loading and slash picker
HermesMacOS/HermesSpeechToText.swift             microphone dictation and SpeechTranscriber integration
HermesMacOS/HermesInstallationView.swift         local Hermes agent repository update workflow
HermesMacOS/HermesUtilitiesView.swift            clipboard/history/debug/installation utilities
HermesMacOS/HermesTypography.swift               website-style font helpers
HermesMacOS/SplashView.swift                     splash video/fallback view
```

When adding new Swift files, update or regenerate with XcodeGen:

```sh
xcodegen generate
```

Keep secrets out of commits. Do not commit API keys, dashboard session tokens, raw stream output, captured prompts, or clipboard history.

## Current scope

HermesMacOS is the native Mac companion app for day-to-day Hermes interaction. It currently focuses on Ask Hermes, Chat with Hermes, dashboard History, embedded Configuration, local Utilities, and the Hermes Installation repository helper. It still depends on an external Hermes API gateway/dashboard for backend execution and does not replace the Hermes agent, dashboard server, or macOS host services.

