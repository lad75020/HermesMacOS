# HermesMacOS integrations

## Hermes API gateway
Default: `http://localhost:8642/v1`.

Used endpoints:
- `POST /v1/responses`: Ask Hermes. Supports streaming and non-streaming operation, stored responses, previous response continuation, reasoning effort, and attachments.
- `POST /v1/chat/completions`: Chat with Hermes. Supports streaming and non-streaming operation, system prompts, attachments, and session continuation headers.
- `POST /v1/requests/{request_id}/cancel`: cancellation for active requests.
- `GET /v1/profiles`: profile list for Ask/Chat profile selectors.
- `GET /v1/approvals`: pending approval list.
- `POST /v1/approvals/resolve`: approval decisions.

Headers observed:
- `Authorization: Bearer <api key>` when an API key is configured.
- `X-Hermes-Profile` for selected profile.
- `X-Hermes-Request-Id` for cancellable requests.
- `X-Hermes-Session-Id` and `x-openclaw-session-key` for session continuation.

## Hermes Dashboard
Default: `http://localhost:9119`.

The app fetches the dashboard HTML and extracts `window.__HERMES_SESSION_TOKEN__`, then uses it for dashboard API calls.

Dashboard API paths observed:
- `api/config/raw`: raw YAML config GET/PUT.
- `api/auth/ws-ticket`: optional one-time ticket for TUI Gateway WebSocket authentication.
- `api/ws`: TUI Gateway WebSocket JSON-RPC transport after `http` to `ws` or `https` to `wss` scheme conversion.
- `api/sessions/search/conversations`: dashboard conversation search.
- `api/sessions`: paged session list.
- `api/sessions/{session_id}/messages`: per-session messages.
- `api/skills` and `api/skills/toggle`: skills listing and enable/disable.
- `api/tools/toolsets`: toolset listing and enable/disable workflow.
- `api/cron/jobs`, `api/cron/jobs/{id}`, `api/cron/jobs/{id}/trigger`, and pause/resume paths: schedules.
- `api/dashboard/plugins/hub`: plugin hub list.

## Hermes local installation
Local workflows inspect and mutate Hermes Agent files under Hermes runtime paths. Observed files and paths include:
- `config.yaml`
- profile `config.yaml`
- profile `.env`
- profile `SOUL.md`
- profile `skills/*/SKILL.md`
- `active_profile`
- `gateway.pid`
- logs: `logs/mcp-stderr.log`, `logs/errors.log`, `logs/agent.log`
- CLI candidates: `venv/bin/hermes`, `venv/bin/python3`

## Git and SSH
`HermesInstallationSession` manages local or SSH-backed git workflows for a Hermes Agent repository. It can ensure an upstream remote, inspect status, preview merge, and update from upstream. SSH private keys are stored in Keychain and materialized into temporary `0600` files only for command execution.

Observed upstream URLs:
- `https://github.com/NousResearch/hermes-agent.git`
- `https://github.com/lad75020/hermes-agent.git`

## Speech-to-text
Two speech-to-text paths are implemented:
- Apple local speech recognition using AVFoundation/Speech framework permissions.
- Whisper WebSocket transcription through `wss://whisper.dubertrand.fr`.

## TUI Gateway JSON-RPC
`HermesTUIGatewayStore` uses the dashboard `api/ws` WebSocket route to send JSON-RPC methods and receive gateway events. The app sends `session.create`, `prompt.submit`, `input.detect_drop`, `session.interrupt`, `session.close`, `session.active_list`, `session.activate`, `session.resume`, and request-response methods for approvals, clarifications, sudo, and secrets.

Events with `method: event` update the native transcript. The app handles `message.*`, `reasoning.delta`, `thinking.delta`, `tool.*`, `approval.request`, `clarify.request`, `sudo.request`, `secret.request`, `status.update`, `background.complete`, `error`, and unknown event types. Consecutive delta chunks are grouped by event type so assistant text, reasoning, and tool output remain separate bubbles.

## macOS platform services
- Keychain: API keys, SSH keys, certificate pins, AES retention key.
- LocalAuthentication: startup unlock for app secrets.
- NSPasteboard: opt-in clipboard history capture.
- WebKit: embedded Hermes Dashboard views.
- AVFoundation/Speech: speech input.
- CryptoKit: AES-GCM local retention encryption and certificate fingerprint hashing.

## Security constraints on integrations
- Remote plaintext HTTP is blocked for sensitive traffic; loopback HTTP is allowed.
- Self-signed certificate trust is not automatic. The app computes the leaf SHA-256 fingerprint, queues a local approval, and pins approved fingerprints.
- Dashboard session tokens are cached per base URL and refreshed on selected authorization failure flows.

## [TODO]
- [TODO] Document the exact Kanban plugin backend route names from the matching server/plugin implementation.
- [ASK USER] Should the Whisper endpoint be configurable instead of hardcoded to `wss://whisper.dubertrand.fr`?

## Evidence
- `HermesMacOS/HermesModelsAPI.swift`: Hermes API endpoint builders, headers, request bodies, attachment handling.
- `HermesMacOS/HermesChatCompletionsAPI.swift`: Chat Completions request and streaming logic.
- `HermesMacOS/HermesTUIGatewayView.swift`: dashboard WebSocket setup, TUI JSON-RPC methods, event routing, multi-workspace state, native TUI attachments, and transcript rendering.
- `HermesMacOS/HermesSecurityUtilities.swift`: dashboard token extraction, raw config API, endpoint security, Keychain, process runner.
- `HermesMacOS/HermesDashboardHistorySearch.swift`, `HermesHistoryView.swift`: session search/list/messages paths.
- `HermesMacOS/HermesDashboardSkills.swift`, `HermesDashboardToolsets.swift`, `HermesDashboardSchedules.swift`, `HermesDashboardPluginsStore.swift`: dashboard API integrations.
- `HermesMacOS/HermesLocalProfiles.swift`, `HermesLocalRuntimeModels.swift`, `HermesLocalConfigurationRuntime.swift`, `HermesMCPServersYAML.swift`: local Hermes config/profile integrations.
- `HermesMacOS/HermesInstallationView.swift`: Git/SSH integration.
- `HermesMacOS/HermesSpeechToText.swift`: Apple and Whisper speech-to-text paths.
