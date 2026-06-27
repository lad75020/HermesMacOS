# New HermesMacOS feature test template

1. Add or update a category in `HermesMacOSTest/Coverage/HermesMacOSTestCoverageMap.swift`.
2. Add a functional test under `HermesMacOSTest/Functional/` when the change affects a tab, Settings surface, or user-visible workflow.
3. Add a technical test under `HermesMacOSTest/Technical/` when the change affects endpoint construction, parsing, storage, redaction, security, YAML/config mutation, attachments, or async lifecycle.
4. Use fixtures under `HermesMacOSTest/Fixtures/` and temporary directories from `HermesTemporaryRuntimeFixture` instead of Laurent's real Hermes home or services.
5. Live Hermes API, Dashboard, TUI Gateway, microphone, TLS, SSH, and repository checks must live behind explicit opt-in live-smoke configuration.
6. Name failing tests so the workflow or guardrail is obvious, for example `SecurityGuardrailTests.remotePlaintextHTTPWithBearerTokenIsBlocked`.
