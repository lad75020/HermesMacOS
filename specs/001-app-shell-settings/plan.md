# Implementation Plan: App Shell and Settings

**Branch**: `feature/time-machine-app-shell-settings` | **Date**: 2026-06-27 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-app-shell-settings/spec.md`

## Summary

Retroactively specify and verify the existing HermesMacOS app shell and Settings feature. The implementation already lives in `HermesMacOSApp.swift`, `ContentView.swift`, `SettingsView.swift`, typography/splash/localization resources, `project.yml`, and app entitlements. This plan keeps the scope to documentation, traceability, and build/smoke verification; no source redesign is required unless verification finds a defect.

## Technical Context

**Language/Version**: Swift, SwiftUI, project currently sets `SWIFT_VERSION: 5.0` in `project.yml`  
**Primary Dependencies**: SwiftUI, AppKit where used by composed views, LocalAuthentication through the startup unlock gate, Keychain helpers, UserDefaults/AppStorage, bundled fonts/resources  
**Storage**: UserDefaults/AppStorage for non-sensitive shell/settings preferences; Keychain for API keys, SSH keys, certificate pins, and startup/local-retention secrets  
**Testing**: `xcodebuild` build verification plus manual shell/settings smoke checks; no automated test target currently exists  
**Target Platform**: macOS 26+ native app  
**Project Type**: Desktop app / native Hermes Agent control surface  
**Performance Goals**: Keep tab switching responsive; avoid uncancellable background loops; keep splash/resources and typography registration bounded  
**Constraints**: Unsandboxed app with app-level guardrails; block remote plaintext secret traffic; preserve Keychain/encrypted retention and approvals model  
**Scale/Scope**: Single Xcode target with a flat `HermesMacOS/` source layout; app shell composes all feature areas but this work only covers shell/settings concerns

## Constitution Check

- **Native control surface**: Pass. The feature is the native SwiftUI app scene, `ContentView` shell, side-tab navigation, Settings scene, splash, typography, and localized app resources.
- **Integration contracts**: Pass. Endpoint settings are passed to Hermes API, Dashboard, TUI Gateway, local runtime, Git/SSH, speech, and utility feature views; this feature does not change downstream request headers, tokens, streaming, cancellation, retries, attachments, or error semantics.
- **Security guardrails**: Pass. API keys, SSH keys, certificate pins, and unlock/retention secrets remain handled by `HermesSecurityUtilities.swift` and Keychain helpers. Remote plaintext sensitive URLs remain governed by endpoint validation.
- **Verification**: Pass with build and manual smoke plan. Repository has no test target, so verification is `xcodebuild -project HermesMacOS.xcodeproj -scheme HermesMacOS -destination 'generic/platform=macOS' build` plus shell/settings smoke checks.
- **Maintainability**: Pass. No new source files are required; artifacts document existing files and avoid further growth in large SwiftUI files.

## Project Structure

### Documentation (this feature)

```text
specs/001-app-shell-settings/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── app-shell-settings.md
└── tasks.md
```

### Source Code (repository root)

```text
project.yml
HermesMacOS/
├── HermesMacOSApp.swift
├── ContentView.swift
├── SettingsView.swift
├── HermesTypography.swift
├── SplashView.swift
├── Localizable.xcstrings
└── HermesMacOS.entitlements
```

**Structure Decision**: Keep the existing flat `HermesMacOS/` source layout and add only Spec Kit artifacts under `specs/001-app-shell-settings/`.

## Complexity Tracking

No constitution violations or additional complexity are introduced.

## Phase 0: Research

See [research.md](./research.md).

## Phase 1: Design

See [data-model.md](./data-model.md), [contracts/app-shell-settings.md](./contracts/app-shell-settings.md), and [quickstart.md](./quickstart.md).

## Phase 2: Tasks

See [tasks.md](./tasks.md).
