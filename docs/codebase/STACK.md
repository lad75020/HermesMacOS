# HermesMacOS codebase stack

## Summary
HermesMacOS is a native macOS application written in Swift and SwiftUI. The repository is a single Xcode project generated from XcodeGen `project.yml`, with one application target named `HermesMacOS` and no separate package manifest.

## Languages and runtimes
- Primary language: Swift. The project sets `SWIFT_VERSION: 5.0` in `project.yml`.
- Platform: macOS application target. `project.yml` sets `platform: macOS` and deployment target `26.0`.
- UI runtime: SwiftUI, with AppKit bridges where needed.
- Native frameworks observed in source: SwiftUI, Foundation, Observation, Security, LocalAuthentication, CryptoKit, WebKit, AVFoundation, Speech, AppKit, UniformTypeIdentifiers.
- The generated Xcode project contains one target and one scheme, both named `HermesMacOS`.

## Build and project tooling
- XcodeGen is the source-of-truth project generator through `project.yml`.
- The checked-in `.xcodeproj` exists and defines the `HermesMacOS` scheme.
- Command-line build documented by the repo uses `xcodebuild -project HermesMacOS.xcodeproj -scheme HermesMacOS -destination 'generic/platform=macOS' build`.
- Code signing is automatic with `Apple Development`, development team `RJYVGK9S3F`, hardened runtime enabled, and entitlements at `HermesMacOS/HermesMacOS.entitlements`.

## Dependencies
No external Swift Package Manager, CocoaPods, npm, Python, Go, or other dependency manifest is present in the repository root. The application uses Apple platform frameworks and runtime services exposed by Hermes Agent and Hermes Dashboard.

## Runtime services the app expects
- Hermes API gateway, defaulting to `http://localhost:8642/v1`.
- Hermes Dashboard, defaulting to `http://localhost:9119`.
- Optional Whisper WebSocket endpoint at `wss://whisper.dubertrand.fr` for remote speech-to-text.
- Local Hermes Agent installation paths under the user home directory for configuration editing, profile management, and repository update workflows.

## Tooling not present
- No CI/CD pipeline file was detected.
- No container or orchestration config was detected.
- No lint or formatter config was detected.
- No test target or separate test runner is declared in the Xcode project list.

## [TODO]
- [TODO] Confirm the team policy for Swift language mode, because `project.yml` sets Swift 5.0 even though the app targets macOS 26 and uses newer platform frameworks.
- [ASK USER] Should this repo add CI for `xcodegen generate` plus `xcodebuild` on every push?

## Evidence
- `project.yml`: bundle prefix, deployment target, Swift version, target, code signing, entitlements, Info.plist keys.
- `HermesMacOS.xcodeproj/xcshareddata/xcschemes/HermesMacOS.xcscheme`: checked-in scheme.
- `README.md`: prerequisites and documented build commands.
- `HermesMacOS/HermesModelsAPI.swift`: default API host and `/v1` endpoint construction.
- `HermesMacOS/HermesReachabilityMonitor.swift`: default local API and dashboard probes.
- `HermesMacOS/HermesSpeechToText.swift`: Whisper WebSocket URL.
- Terminal evidence: `xcodebuild -list -project HermesMacOS.xcodeproj` reported target and scheme `HermesMacOS`.
