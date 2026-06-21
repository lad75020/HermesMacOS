# Implementation Plan: App Shell and Settings

**Branch**: `feature/time-machine-app-shell-and-settings` | **Date**: 2026-06-21 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-app-shell-and-settings/spec.md`

## Summary

Validate and preserve the existing native macOS app shell and Settings surface that frame all Hermes workflows: startup/unlock handling, top-level tab navigation, multi-workspace shell state, per-window endpoint settings, saved endpoint pairs, appearance/language preferences, and API/dashboard reachability indicators. The implementation approach is to keep this as a SwiftUI-native control surface with Observable state, UserDefaults/AppStorage preference persistence, shared endpoint/security helpers, and xcodebuild-backed validation.

## Technical Context

**Language/Version**: Swift using the Xcode project setting `SWIFT_VERSION: 5.0`

**Primary Dependencies**: SwiftUI for app shell and Settings UI; Observation for shared state objects; Foundation for persistence and URL handling; LocalAuthentication/Keychain helpers from the shared security layer; XcodeGen project definition in `project.yml`

**Storage**: UserDefaults/AppStorage for shell preferences and endpoint selections; Keychain-backed shared security utilities for sensitive values; no new database storage for this feature

**Testing**: Command-line `xcodebuild -project HermesMacOS.xcodeproj -scheme HermesMacOS -destination 'generic/platform=macOS' build`; focused source validation and manual smoke scenarios because the repository currently has no separate automated test target

**Target Platform**: macOS 26.0 or newer desktop application

**Project Type**: Native macOS desktop app / Hermes Agent control surface

**Performance Goals**: Launch to a usable shell in under 5 seconds on a normally configured Mac; tab switches remain immediate for user-perceived interaction; reachability changes surface within 15 seconds

**Constraints**: Preserve independent per-window endpoint targeting; do not move workflow-specific behavior into this shell feature; avoid exposing partially initialized sensitive state after startup secret unlock failure; maintain keyboard-accessible navigation and readable settings controls

**Scale/Scope**: One macOS application target with 10 top-level shell tabs, settings/preferences state, endpoint-pair management, and two reachability targets (Hermes API and Dashboard)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

The project constitution is still the untouched generated template, so no ratified project-specific governance rules are available. Apply default gates appropriate to this macOS control-surface feature:

- **Platform UX Gate**: PASS — the feature remains native macOS SwiftUI and keeps shell/Settings workflows accessible through visible controls and keyboard-reachable navigation.
- **Secure Local Data Gate**: PASS — sensitive API keys, SSH keys, and trust decisions stay routed through the existing shared security layer; shell preferences only persist non-secret state.
- **Per-Window Isolation Gate**: PASS — endpoint changes are scoped to the selected window connection and must not silently retarget other windows.
- **Build Readiness Gate**: PASS — implementation tasks must end with a successful Xcode build or explicitly reported blocker.
- **Scope Control Gate**: PASS — workflow internals for Ask, Chat, TUI Gateway, History, Approvals, Kanban, Dashboard, Configuration subsections, and Utilities remain outside this feature except for shell composition/routing.

## Project Structure

### Documentation (this feature)

```text
specs/001-app-shell-and-settings/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── app-shell-settings-contract.md
├── checklists/
│   └── requirements.md
└── tasks.md
```

### Source Code (repository root)

```text
project.yml
HermesMacOS/
├── HermesMacOSApp.swift
├── ContentView.swift
├── SettingsView.swift
├── HermesReachabilityMonitor.swift
├── HermesModelsAPI.swift
├── HermesSecurityUtilities.swift
└── HermesMacOS.entitlements
```

**Structure Decision**: Use the existing single-target native macOS application structure. This feature is cross-cutting shell infrastructure, so the relevant source remains in top-level Swift files rather than a new module or directory. No new production source directories are required.

## Phase 0 Research

Research decisions are recorded in [research.md](./research.md).

## Phase 1 Design

Design artifacts are recorded in:

- [data-model.md](./data-model.md)
- [contracts/app-shell-settings-contract.md](./contracts/app-shell-settings-contract.md)
- [quickstart.md](./quickstart.md)

## Complexity Tracking

No constitution or design violations require complexity justification.

## Post-Design Constitution Check

- **Platform UX Gate**: PASS — quickstart and contracts include keyboard/navigation/readability verification.
- **Secure Local Data Gate**: PASS — data model separates non-secret preferences from security-sensitive material managed by shared utilities.
- **Per-Window Isolation Gate**: PASS — Window Connection is a first-class entity and contract expectation.
- **Build Readiness Gate**: PASS — tasks include Xcode build validation.
- **Scope Control Gate**: PASS — artifacts explicitly exclude workflow-specific behavior except shell composition/routing.
