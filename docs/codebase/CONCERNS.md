# HermesMacOS concerns

## Current risks and maintenance hotspots

### Automated test target is new
The repo now includes `HermesMacOSTest`, a native macOS unit-test target with fixture-backed functional, technical, coverage, and live-smoke-skip tests.

Impact: keep the coverage map and fixtures current as the app evolves so the new fast local signal does not drift from the product surface.

### Large feature files
Several files exceed 500 lines and mix UI, state orchestration, parsing, and network or local operations:
- `HermesMacOS/HermesModelsAPI.swift`: 1571 lines.
- `HermesMacOS/HermesKanbanView.swift`: 1552 lines.
- `HermesMacOS/HermesViews.swift`: 1324 lines.
- `HermesMacOS/HermesHistoryView.swift`: 1152 lines.
- `HermesMacOS/HermesChatCompletionsAPI.swift`: 1090 lines.
- `HermesMacOS/HermesSecurityUtilities.swift`: 857 lines.
- `HermesMacOS/ContentView.swift`: 756 lines.

Impact: these files are harder to review and should be the first candidates for extraction when adding behavior.

### High-churn hotspots
The last-90-day churn scan identified the highest churn in `HermesViews.swift`, `ContentView.swift`, `HermesConfigurationView.swift`, `HermesModelsAPI.swift`, `project.pbxproj`, `HermesHistoryView.swift`, `HermesChatView.swift`, `HermesUtilitiesView.swift`, and `HermesAskWorkspacesView.swift`.

Impact: these areas are most likely to contain hidden coupling and should get extra review and smoke testing.

### Hardcoded service endpoints
The Whisper endpoint is hardcoded as `wss://whisper.dubertrand.fr`. Default Hermes API and dashboard ports are hardcoded as localhost 8642 and 9119, though the UI lets users configure API/dashboard endpoints.

Impact: remote STT changes require code changes unless a setting is added.

### Sandbox disabled by design
`SECURITY.md` states the app intentionally keeps the macOS sandbox disabled because it manages local installs, profiles, model config, skills, MCP servers, schedules, repositories, attachments, and SSH workflows.

Impact: guardrails are implemented in app code, not enforced by the OS sandbox. Security reviews should focus on local file/process boundaries and approval bypasses.

### Dashboard token scraping coupling
`HermesDashboardClient` extracts `window.__HERMES_SESSION_TOKEN__` from dashboard HTML. This couples the app to the dashboard bootstrap script shape.

Impact: dashboard frontend changes can break configuration, skills, schedules, plugins, and history without any compiler signal.

### TODO/FIXME/HACK scan result
The only scan hit was a prompt string containing the word `TODOs` inside `HermesConfigurationSchedulesSection.swift`, not a production TODO marker.

## Security concerns to keep reviewing
- Ensure every sensitive request path continues to call `HermesEndpointSecurity.validateSensitiveURL` before sending secrets.
- Confirm local approval checks cover all future filesystem mutation surfaces.
- Keep redaction patterns current for new token formats.
- Keep Keychain migration paths intact when changing API key, SSH key, certificate pin, or retention encryption code.
- Treat raw debug stream logs as sensitive because they can include prompts, tool output, or model responses.

## Performance concerns
- Multiple background loops run while the app is open: reachability, approvals refresh, Kanban live updates, clipboard monitoring, speech capture, and tab blinking. They should remain cancellable and bound to view/task lifetime.
- `HermesDashboardClient` token fetches require downloading dashboard HTML. Frequent token cache invalidation can increase dashboard load.
- Large in-memory histories, raw JSON stream buffers, and rendered images should continue to be bounded.

## [TODO]
- [TODO] Keep `HermesMacOSTest/Coverage/HermesMacOSTestCoverageMap.swift` synchronized with new app surfaces.
- [TODO] Extend mock/live-smoke fixtures when new Hermes API or Dashboard contracts are added.
- [ASK USER] Decide whether hardcoded Whisper service should become a Settings field.
- [ASK USER] Decide whether dashboard session-token extraction should move to a stable dashboard API endpoint.

## Evidence
- Terminal scan output generated during this documentation pass: churn, code metrics, TODO/FIXME/HACK result, no CI, no test config.
- `README.md`, `docs/codebase/TESTING.md`: native `HermesMacOSTest` commands and live backend requirements.
- `SECURITY.md`: sandbox disabled by design and guardrail model.
- `HermesMacOS/HermesSecurityUtilities.swift`: sensitive URL validation, dashboard token scraping, redaction, encrypted retention, Keychain.
- `HermesMacOS/HermesSpeechToText.swift`: hardcoded Whisper URL.
- Terminal evidence: Swift file line counts from repository source.
