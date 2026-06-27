# Quickstart: HermesMacOS Test Target

## Prerequisites

- macOS 26.0 or newer.
- Xcode 26.6 selected by `xcode-select`.
- Apple Swift 6.3.3 available through `xcrun swift --version`.
- XcodeGen available (`xcodegen --version` verified as 2.45.4 during planning).

## Verify toolchain

```bash
xcodebuild -version
xcrun swift --version
xcodegen --version
```

Expected planning baseline:

```text
Xcode 26.6
Apple Swift version 6.3.3
macOS deployment target 26.0+
```

## Regenerate the project

```bash
xcodegen generate
```

Then confirm both targets/schemes are present:

```bash
xcodebuild -list -project HermesMacOS.xcodeproj
```

Expected after implementation:

```text
Targets:
    HermesMacOS
    HermesMacOSTest

Schemes:
    HermesMacOS
    HermesMacOSTest
```

## Build the app target

```bash
xcodebuild \
  -project HermesMacOS.xcodeproj \
  -scheme HermesMacOS \
  -destination 'generic/platform=macOS' \
  -derivedDataPath /tmp/HermesMacOSDerivedData \
  build
```

Expected: build succeeds.

## Run default automated tests

```bash
xcodebuild \
  -project HermesMacOS.xcodeproj \
  -scheme HermesMacOSTest \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/HermesMacOSTestDerivedData \
  test
```

One-line equivalent for automation:

```bash
xcodebuild -project HermesMacOS.xcodeproj -scheme HermesMacOSTest -destination 'platform=macOS' -derivedDataPath /tmp/HermesMacOSTestDerivedData test
```

Expected: default test suite passes without requiring live Hermes API, Dashboard, TUI Gateway, Whisper, microphone permission, SSH access, real API keys, real dashboard tokens, or real Hermes home access.

## Review coverage map

Open:

```text
HermesMacOSTest/Coverage/HermesMacOSTestCoverageMap.swift
specs/013-hermesmacos-test-target/contracts/test-coverage-contract.md
```

Confirm every category in the contract is mapped to an executable test or explicit opt-in live-smoke check.

## Optional live smoke checks

Only run live checks when intentionally configured. They should skip by default.

Suggested live areas:

1. Hermes API `/v1/profiles`, `/v1/responses`, `/v1/chat/completions`, and cancellation.
2. Dashboard HTML session-token discovery and dashboard API routes.
3. TUI Gateway WebSocket `api/ws` session create, prompt submit, interrupt, resume, and close.
4. Approvals, Kanban, schedules, plugins, skills, toolsets, and MCP dashboard panels.
5. Apple local speech recognition and optional Whisper WebSocket transcription.
6. TLS self-signed approval flow with fixture or intentionally approved local host.
7. SSH/repository preview using a temporary or explicitly approved repository.

Live checks must validate sensitive destinations before credentials are sent and must never print raw secrets.

## Expected completion evidence

Implementation is complete only when the final report includes:

- `xcodebuild -list` showing `HermesMacOSTest`.
- App build command output with success.
- Test command output with success.
- Coverage map summary showing 100% of documented app surfaces accounted for.
- Confirmation that default tests used mocks/temp fixtures and did not mutate real Hermes/user state.
