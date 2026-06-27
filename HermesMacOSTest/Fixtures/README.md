# HermesMacOSTest fixtures

Fixtures are deterministic, fake, and safe to commit. They must never contain Laurent's real prompts, responses, clipboard entries, API keys, dashboard tokens, SSH keys, certificate pins, repository paths, or Hermes profile data.

- `Dashboard/`: dashboard HTML, session-token, and dashboard API responses.
- `HermesAPI/`: `/v1/profiles`, `/v1/responses`, `/v1/chat/completions`, approvals, and cancellation fixtures.
- `Streams/`: SSE and TUI Gateway WebSocket event streams.
- `LocalRuntime/`: temporary Hermes home, YAML, profile, model, MCP, Git, and SSH examples.
- `Security/`: fake secret, token, TLS fingerprint, and redaction fixtures.

Default tests must run only against these fixtures or temporary directories. Real-service coverage belongs in the opt-in live-smoke path.
