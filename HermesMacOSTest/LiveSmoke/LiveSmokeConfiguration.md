# Live smoke configuration

Default `HermesMacOSTest` execution is fixture-only. Live checks must be explicitly enabled by environment variables or Xcode scheme arguments on a developer machine that is safe to use.

Suggested variables:

- `HERMESMACOS_LIVE_API_BASE_URL`: optional Hermes API base URL including `/v1`.
- `HERMESMACOS_LIVE_DASHBOARD_URL`: optional Hermes Dashboard URL.
- `HERMESMACOS_LIVE_TUI_GATEWAY=1`: enable TUI Gateway WebSocket smoke checks.
- `HERMESMACOS_LIVE_WHISPER=1`: enable optional Whisper WebSocket checks.
- `HERMESMACOS_LIVE_MUTATION_OK=1`: allow non-destructive live mutation checks.

Rules:

1. Skip with a clear reason when configuration is missing.
2. Validate sensitive destinations before sending credentials.
3. Never print raw API keys, dashboard tokens, SSH private keys, prompts, responses, clipboard history, or raw stream secrets.
4. Use temporary repositories or explicitly approved paths for Git/SSH checks.
