# HermesMacOS

HermesMacOS is a native SwiftUI macOS control surface for Hermes Agent APIs, dashboard data, local utilities, and repository maintenance workflows.

## Highlights

- Ask Hermes client for `/v1/responses` with streaming, cancellation, profile selection, reasoning controls, session continuation, multi-workspace tabs, and file/image attachments.
- Chat with Hermes client for `/v1/chat/completions` with optional system prompts, streaming or non-streaming responses, session resume, and attachments.
- Dashboard-backed History search, skill suggestions, configuration panels, schedules, plugins, toolsets, MCP servers, and runtime model/profile views.
- Local utilities for clipboard history, prompt/response history, raw stream debugging, knowledge-erasure helpers, speech-to-text prompts, and Hermes repository updates.
- Per-window endpoint settings so multiple windows can target different Hermes API/dashboard hosts.

## Repository layout

```text
.
├── project.yml                    # XcodeGen project definition
├── HermesMacOS.xcodeproj/         # Generated Xcode project
├── HermesMacOS/                   # SwiftUI app source, resources, entitlements
├── HermesMacOSTest/               # Native macOS unit tests, fixtures, coverage map
├── docs/                          # App docs and source maps
└── README.md
```

Key source files include `ContentView.swift`, `HermesViews.swift`, `HermesChatView.swift`, `HermesModelsAPI.swift`, `HermesChatCompletionsAPI.swift`, `HermesHistoryView.swift`, `HermesConfigurationView.swift`, `HermesUtilitiesView.swift`, and `HermesInstallationView.swift`.

## Documentation

Start with [`docs/README.md`](docs/README.md). It links to:

- A getting-started tutorial for building the app and sending the first Ask Hermes prompt.
- How-to guides for endpoints, Ask/Chat workflows, and runtime management.
- Reference docs for the application surface, APIs, storage, and local files.
- Explanations of the architecture and security model.
- Codebase maps in `docs/codebase/` for stack, structure, architecture, conventions, integrations, testing, and concerns.

## Prerequisites

- macOS 26.0 or newer.
- Xcode with SwiftUI, AppKit, WebKit, AVFoundation, and Speech support.
- XcodeGen when regenerating `HermesMacOS.xcodeproj` from `project.yml`.
- A reachable Hermes API gateway exposing `/v1/profiles`, `/v1/responses`, and `/v1/chat/completions`.
- A reachable Hermes dashboard for history search, skills, configuration, schedules, plugins, and related dashboard APIs.
- Microphone and speech-recognition permission for dictation.

## Setup

From the repository root:

```bash
xcodegen generate
open HermesMacOS.xcodeproj
```

Build and run the `HermesMacOS` scheme in Xcode.

Command-line build:

```bash
xcodegen generate
xcodebuild \
  -project HermesMacOS.xcodeproj \
  -scheme HermesMacOS \
  -destination 'generic/platform=macOS' \
  build
```

If DerivedData is locked by another Xcode build, add an isolated DerivedData path:

```bash
xcodebuild \
  -project HermesMacOS.xcodeproj \
  -scheme HermesMacOS \
  -destination 'generic/platform=macOS' \
  -derivedDataPath /tmp/HermesMacOSDerivedData \
  build
```

## Running and configuration

Open Settings in the app and configure:

- Hermes API Base URL, normally including `/v1`.
- Optional Hermes API key, sent as a bearer token.
- Dashboard URL used by History, Skills, Configuration, and other dashboard-backed panels.
- Self-signed certificate allowance for trusted local or Tailscale deployments.
- Saved API/dashboard endpoint pairs for multi-window setups.

## Testing and checks

Regenerate the project, build the app, and run the native fixture-backed test target:

```bash
xcodegen generate
xcodebuild \
  -project HermesMacOS.xcodeproj \
  -scheme HermesMacOSTest \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/HermesMacOSTestDerivedData \
  test
```

The default `HermesMacOSTest` suite uses fake fixtures and temporary directories only. For live backend smoke checks, configure explicit disposable endpoints and run simple checks such as:

```bash
curl -i https://your-host.example:8642/v1/profiles
curl -i https://your-host.example:9120/
```

For dashboard-backed live features, the dashboard must provide a session token in its HTML and expose the expected API routes.

## Security notes

- Keep API keys, dashboard tokens, raw stream logs, captured prompts, and clipboard history out of commits.
- The app stores local preferences in UserDefaults; treat shared Macs accordingly.
- The Hermes Installation helper runs git commands against the configured local repository path, so review the target path before updating.
