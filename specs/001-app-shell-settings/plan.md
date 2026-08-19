# Implementation Plan: App Shell and Settings

**Branch**: `feature/time-machine-app-shell-settings` | **Date**: 2026-06-27 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-app-shell-settings/spec.md`
**Propagated**: 2026-08-20 — Added the local memory/GPU resource-gauge implementation and verification work from the refined specification.

## Summary

Retroactively specify and verify the existing HermesMacOS app shell and Settings feature, then add a focused local resource monitor. The existing shell remains in `HermesMacOSApp.swift`, `ContentView.swift`, and Settings/resources files; the new work adds cancellable polling of the fixed `GPUUsage` executable and two bottom-sidebar pie-chart-style gauges without changing tab/navigation contracts.

## Technical Context

**Language/Version**: Swift 6.0, SwiftUI, project currently sets `SWIFT_VERSION: 6.0` in `project.yml`
**Primary Dependencies**: SwiftUI, Foundation `Process`/`Pipe`, Observation, structured concurrency, AppKit where used by composed views, LocalAuthentication through the startup unlock gate, Keychain helpers, UserDefaults/AppStorage, bundled fonts/resources
**Storage**: UserDefaults/AppStorage for non-sensitive shell/settings preferences; Keychain for API keys, SSH keys, certificate pins, and startup/local-retention secrets  
**Testing**: The `HermesMacOSTest` XCTest target plus `xcodebuild` build/test verification and manual shell/resource-gauge smoke checks
**Target Platform**: macOS 26+ native app  
**Project Type**: Desktop app / native Hermes Agent control surface  
**Performance Goals**: Keep tab switching responsive; poll no more frequently than every five seconds; run blocking utility work off the UI actor; avoid uncancellable background loops
**Constraints**: Unsandboxed app with app-level guardrails; invoke only `/Volumes/WDBlack4TB/Code/NodeMLX/utils/GPUUsage` without a shell or user arguments; enforce a utility timeout; block remote plaintext secret traffic; preserve Keychain/encrypted retention and approvals model
**Scale/Scope**: Single Xcode app target and XCTest target with flat source layouts; this change is limited to the navigation-shell resource indicator

## Constitution Check

- **Native control surface**: Pass. The feature is the native SwiftUI app scene, `ContentView` shell, side-tab navigation, Settings scene, splash, typography, and localized app resources.
- **Integration contracts**: Pass. Endpoint settings are passed to Hermes API, Dashboard, TUI Gateway, local runtime, Git/SSH, speech, and utility feature views; this feature does not change downstream request headers, tokens, streaming, cancellation, retries, attachments, or error semantics.
- **Security guardrails**: Pass. API keys, SSH keys, certificate pins, and unlock/retention secrets remain handled by `HermesSecurityUtilities.swift` and Keychain helpers. Remote plaintext sensitive URLs remain governed by endpoint validation.
- **Verification**: Pass with XCTest coverage for parsing/error handling and the resource gauge's UI contract, plus a clean `HermesMacOSTest` scheme run and manual shell smoke checks.
- **Maintainability**: Pass. Keep subprocess parsing/polling in a focused monitor and gauge rendering in a focused view, instead of expanding the already large `ContentView.swift`.

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
├── HermesResourceUsageMonitor.swift
├── HermesResourceUsageGauge.swift
├── SettingsView.swift
├── HermesTypography.swift
├── SplashView.swift
├── Localizable.xcstrings
└── HermesMacOS.entitlements
HermesMacOSTest/
├── Technical/HermesResourceUsageMonitorTests.swift
└── Functional/LocalizationAndAccessibilityTests.swift
```

**Structure Decision**: Keep the existing flat `HermesMacOS/` source layout. Add a monitor/model file for polling and validation, a small gauge view for rendering/accessibility, and focused XCTest coverage. The source directories are already globbed by `project.yml`, so no explicit Xcode project-file entry is required.

## Complexity Tracking

The resource monitor introduces bounded subprocess lifecycle management and main-actor UI publication. This is necessary to satisfy FR-009 through FR-013; contain it behind an injectable execution seam so parsing, timeout, and error states are testable without invoking the host utility from tests.

**Refinement traceability**:
- **FR-009**: `HermesResourceUsageGauge` renders the two bottom-sidebar Memory/GPU pie-chart-style gauges.
- **FR-010**: `HermesResourceUsageMonitor` invokes the fixed `GPUUsage` path on a five-second bounded poll loop and parses both fields.
- **FR-011**: The monitor validates finite `0...100` values and the gauge provides visible and accessible percentage semantics.
- **FR-012**: The execution seam keeps blocking process work off the UI actor, applies a timeout, and participates in view-task cancellation.
- **FR-013**: The monitor publishes safe unavailable/stale state so the sidebar remains responsive after a utility failure.

## Phase 0: Research

See [research.md](./research.md).

## Phase 1: Design

See [data-model.md](./data-model.md), [contracts/app-shell-settings.md](./contracts/app-shell-settings.md), and [quickstart.md](./quickstart.md).

## Phase 2: Tasks

See [tasks.md](./tasks.md).
