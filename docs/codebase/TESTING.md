# HermesMacOS testing

## Native test target

HermesMacOS declares a native macOS unit-test target named `HermesMacOSTest` in `project.yml`. Regenerate the Xcode project before relying on target membership:

```bash
xcodegen generate
xcodebuild -list -project HermesMacOS.xcodeproj
```

The project list should include targets and schemes for both `HermesMacOS` and `HermesMacOSTest`.

## Default verification path

Build the app target:

```bash
xcodebuild \
  -project HermesMacOS.xcodeproj \
  -scheme HermesMacOS \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/HermesMacOSBuildDerivedData \
  build
```

Run the deterministic fixture-backed test suite:

```bash
xcodebuild \
  -project HermesMacOS.xcodeproj \
  -scheme HermesMacOSTest \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/HermesMacOSTestDerivedData \
  test
```

Default tests must not require a running Hermes API, Dashboard, TUI Gateway, Whisper service, microphone permission, SSH host, writable real Hermes home, or real repository mutation.

## Test organization

- `HermesMacOSTest/Functional/`: user-facing workflow coverage for tabs, Settings surfaces, dashboard-backed panels, local runtime utilities, and accessibility labels.
- `HermesMacOSTest/Technical/`: endpoint/request construction, streaming parsers, attachment encoding, YAML mutation, security guardrails, retention, and async lifecycle contracts.
- `HermesMacOSTest/Coverage/`: coverage inventory and contract-verifier tests tied to `specs/013-hermesmacos-test-target/contracts/test-coverage-contract.md`.
- `HermesMacOSTest/Fixtures/`: deterministic fake API, dashboard, runtime, stream, and security fixtures.
- `HermesMacOSTest/LiveSmoke/`: skip-by-default live smoke configuration and tests.
- `HermesMacOSTest/Support/`: shared fixture loading, mock URL protocol, temporary runtime, bounded async, and redaction assertions.

## Live smoke policy

Live checks are opt-in only. Configure them with explicit environment variables documented in `HermesMacOSTest/LiveSmoke/LiveSmokeConfiguration.md`. Do not put live endpoints, dashboard tokens, API keys, SSH keys, real prompts, real clipboard entries, or real certificate pins in fixtures or committed logs.

Suggested live smoke areas after the default suite passes:

- Ask Hermes and Chat with Hermes against a disposable Hermes API profile.
- TUI Gateway WebSocket connection against a known dashboard session.
- Dashboard-backed History, Sessions, Skills, Schedules, Plugins, Toolsets, MCP Servers, and raw config.
- Approvals Inbox and Kanban against a controlled local fixture/plugin environment.
- Speech-to-text only after microphone and speech-recognition permission are intentionally granted.
- TLS pinning only with disposable fixture hosts/fingerprints.
- SSH/repository operations only against temporary repositories or explicit throwaway remotes.

## Final implementation evidence

- `xcodegen generate` completed successfully and generated `HermesMacOS.xcodeproj` with `HermesMacOSTest` target membership.
- `xcodebuild -list -project HermesMacOS.xcodeproj` reported targets `HermesMacOS` and `HermesMacOSTest`, and schemes `HermesMacOS` and `HermesMacOSTest`.
- `xcodebuild -project HermesMacOS.xcodeproj -scheme HermesMacOS -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/HermesMacOSBuildDerivedData build` succeeded.
- `xcodebuild -project HermesMacOS.xcodeproj -scheme HermesMacOSTest -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/HermesMacOSTestDerivedData test` succeeded with 54 tests and 0 failures.
- Optional live-smoke checks were not run; the suite currently verifies skip-by-default behavior.
