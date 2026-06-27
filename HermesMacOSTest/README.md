# HermesMacOSTest

`HermesMacOSTest` is the native macOS test target for HermesMacOS.

## Conventions

- Functional tests live in `HermesMacOSTest/Functional/` and are named after user-facing workflows.
- Technical tests live in `HermesMacOSTest/Technical/` and are named after contracts or guardrails.
- Coverage metadata lives in `HermesMacOSTest/Coverage/HermesMacOSTestCoverageMap.swift`.
- Support utilities live in `HermesMacOSTest/Support/`.
- Default tests use fixtures and temporary directories only.
- Live Hermes services, microphone, TLS, SSH, and repository checks are opt-in and must skip by default.

## Commands

```bash
xcodegen generate
xcodebuild -project HermesMacOS.xcodeproj -scheme HermesMacOSTest -destination 'platform=macOS' -derivedDataPath /tmp/HermesMacOSTestDerivedData test
```
