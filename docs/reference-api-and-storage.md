# HermesMacOS API and storage reference

## Hermes API gateway
Configured by `HermesAPISettings.baseURL`. Default is `http://localhost:8642/v1`.

| Purpose | Method/path | Source |
| --- | --- | --- |
| Ask Hermes | `POST /v1/responses` | `HermesAPISettings.responseURL`, `HermesResponsesSession` |
| Chat | `POST /v1/chat/completions` | `HermesAPISettings.chatCompletionsURL`, `HermesChatSession` |
| Cancel request | `POST /v1/requests/{request_id}/cancel` | `HermesAPISettings.requestCancelURL`, `HermesRequestCancellation` |
| Profiles | `GET /v1/profiles` | `HermesAPISettings.profilesURL` |
| Approvals list | `GET /v1/approvals` | `HermesAPISettings.approvalsURL` |
| Resolve approval | `POST /v1/approvals/resolve` | `HermesAPISettings.approvalResolveURL` |

## Request headers
- `Authorization: Bearer <api key>`: set when API key is configured.
- `X-Hermes-Profile`: selected profile, defaulting to `default` when empty.
- `X-Hermes-Request-Id`: generated cancellation request ID.
- `X-Hermes-Session-Id`: Hermes session continuation.
- `x-openclaw-session-key`: duplicate session key for OpenClaw compatibility.
- `Accept: text/event-stream` for streaming requests.
- `Content-Type: application/json` for JSON request bodies.

## Dashboard API
Dashboard base URL comes from Settings or fallback normalization from the API base URL. `HermesDashboardClient` extracts `window.__HERMES_SESSION_TOKEN__` from dashboard HTML before dashboard API calls.

| Purpose | Path | Source |
| --- | --- | --- |
| Raw config | `api/config/raw` | `HermesDashboardClient.rawConfig`, `updateRawConfig` |
| Conversation search | `api/sessions/search/conversations` | `HermesDashboardHistorySearchSession` |
| Sessions list | `api/sessions` | `HermesSessionsStore` |
| Session messages | `api/sessions/{session_id}/messages` | `HermesSessionsStore` |
| Skills | `api/skills` | `HermesDashboardSkillsStore` |
| Skill toggle | `api/skills/toggle` | `HermesDashboardSkillsStore` |
| Toolsets | `api/tools/toolsets` | `HermesDashboardToolsetsStore` |
| Cron jobs | `api/cron/jobs` | `HermesDashboardSchedulesStore` |
| Trigger cron job | `api/cron/jobs/{id}/trigger` | `HermesDashboardSchedulesStore` |
| Plugins hub | `api/dashboard/plugins/hub` | `HermesDashboardPluginsStore` |

## TUI Gateway WebSocket
The TUI Gateway tab uses the Dashboard base URL, not the `/v1` API base URL, for its WebSocket transport. `HermesTUIGatewayStore` resolves the dashboard URL, extracts a dashboard session token through `HermesDashboardClient`, requests a WebSocket ticket from `POST api/auth/ws-ticket` when possible, then opens `api/ws` with `URLSessionWebSocketTask`.

Scheme handling:
- Dashboard `http` becomes WebSocket `ws`.
- Dashboard `https` becomes WebSocket `wss`.
- Unsupported dashboard URL schemes fail with `invalidWebSocketURL`.

Authentication query handling:
- Preferred: query parameter named `ticket` with the value returned by `api/auth/ws-ticket`.
- Fallback: query parameter named `token` with the dashboard session token.

The WebSocket payloads use JSON-RPC 2.0. Outgoing requests include `jsonrpc`, generated `id`, `method`, and `params`. Incoming messages with a matching `id` resolve pending requests. Incoming notifications with `method: event` carry `type`, optional `session_id`, and `payload` and are rendered into the TUI transcript.

Primary JSON-RPC methods used by HermesMacOS:
- `session.create`
- `prompt.submit`
- `input.detect_drop`
- `session.interrupt`
- `session.close`
- `session.active_list`
- `session.activate`
- `session.resume`
- `approval.respond`
- `clarify.respond`
- `sudo.respond`
- `secret.respond`

See [TUI Gateway WebSocket reference](reference-tui-gateway-websocket.md) for the full method and event tables.

## Local files and paths
Observed local Hermes paths:
- Hermes root `config.yaml`.
- Profile `config.yaml`, `.env`, `SOUL.md`.
- Profile skills under `skills/*/SKILL.md`.
- Active profile marker `active_profile`.
- Gateway PID `gateway.pid`.
- Log files `logs/mcp-stderr.log`, `logs/errors.log`, and `logs/agent.log`.
- CLI candidates `venv/bin/hermes` and `venv/bin/python3`.
- Knowledge eraser targets `memory.md`, `USER.md`, and `skills` directories.

## Keychain storage
| Data | Service/source |
| --- | --- |
| API key | `HermesMacOS.APIKeys` through `HermesAPIKeychain` |
| SSH private keys | `HermesMacOS.SSHPrivateKeys` through `HermesSSHKeychain` |
| Local retention AES key | `HermesMacOS.LocalRetentionKey` through `HermesEncryptedRetentionStore` |
| TLS certificate pins | `HermesPinnedCertificateTrust` helpers |

Stored Keychain values use data-protection Keychain queries and `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` where set in source.

## UserDefaults and AppStorage
User-facing non-secret settings use UserDefaults or AppStorage. Observed keys include:
- `hermes.appTheme`
- `hermes.appLanguage`
- `hermes.macOS.promptFontSize`
- `hermes.macOS.chatBubbleFontSize`
- `hermes.macOS.titleFont`
- `hermes.macOS.labelFont`
- `hermes.macOS.askStreamOutputBubbleEnabled`
- Configuration and Utilities disclosure-state keys under `hermes.macOS.configuration.*` and `hermes.macOS.utilities.*`
- Dashboard URL storage key from `HermesDashboardHistorySearch.swift`
- Speech-to-text engine storage key from `HermesSpeechToText.swift`

Encrypted local retention stores data under keys prefixed by `hermes.macOS.encrypted.` and migrates legacy plaintext values on load.

## Attachments
`HermesPromptAttachment` supports image, UTF-8 text/source/config files, PDFs, and Office documents. Ask and Chat encode images as data URLs, inline text files with truncation, and describe binary documents with metadata. TUI Gateway reuses the same attachment model but prepares payloads for the WebSocket protocol: native image attachments call `input.detect_drop` with the local path, text attachments are inlined, and binary documents include filename, MIME type, byte count, and local path instructions.

## Network security behavior
- Sensitive non-loopback HTTP is rejected.
- Self-signed certificate handling requires explicit approval and fingerprint pinning.
- API keys are only added to requests after URL validation.
- Dashboard session tokens are cached per dashboard base URL.
