# Implementation Plan: Utilities and Maintenance

**Branch**: `feature/time-machine-utilities-maintenance` | **Date**: 2026-06-27 | **Spec**: [spec.md](./spec.md)

## Summary
Retroactively specify and verify existing Utilities and Maintenance behavior: clipboard/message retention panels, raw stream debugging, knowledge eraser, Hermes Agent repository maintenance, speech-to-text prompt dictation, reachability indicators, and getting-started documentation.

## Technical Context
**Language/Version**: Swift, SwiftUI, Observation, Foundation, AVFoundation, Speech; project sets `SWIFT_VERSION: 5.0`  
**Primary Dependencies**: Local Hermes runtime paths, dashboard/API endpoints, Keychain API key, Speech framework, Whisper WebSocket endpoint, git runner, filesystem access policy  
**Storage**: AppStorage disclosure/retention flags, local history stores, Keychain API key, temporary audio files, local Hermes knowledge archives  
**Testing**: Xcode build plus local utilities smoke checks  
**Target Platform**: macOS 26+ native app  
**Constraints**: Retention opt-in, destructive erase review, dirty repository update block, STT cleanup, no secret rendering

## Constitution Check
- **Native control surface**: Pass. Utilities are native SwiftUI panels.
- **Integration contracts**: Pass. Uses existing local runtime, Speech, Keychain, dashboard/API, and git helper contracts.
- **Security guardrails**: Pass. Retention/destructive actions are opt-in or reviewed; filesystem and Keychain helpers guard sensitive operations.
- **Verification**: Pass with build plus utility smoke checks; no automated test target exists.
- **Maintainability**: Pass. Adds SDD artifacts only.

## Project Structure
```text
specs/012-utilities-maintenance/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/utilities-maintenance.md
└── tasks.md
```
