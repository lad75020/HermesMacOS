# Implementation Plan: Memory Tab and Tab Settings

**Branch**: `main` | **Date**: 2026-06-28 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/014-memory-tab-settings/spec.md`

## Summary

Add Settings controls that independently hide/show the Ask Hermes and Chat with Hermes side tabs while preserving their in-memory workspace/session state, and add a native Memory tab for browsing, filtering, paging, and deleting readable Hindsight memory entries. Implementation should use Apple Swift 6 language mode with the latest installed Apple Swift 6.3.3 toolchain, keep macOS 26.0+ as the deployment floor, isolate Hindsight access behind provider-level local runtime helpers, and add deterministic `HermesMacOSTest` coverage for tab visibility and Memory list/delete state.

## Technical Context

**Language/Version**: Apple Swift language mode 6 (`SWIFT_VERSION: 6.0`) using the latest installed workspace toolchain observed during planning: Apple Swift 6.3.3, Xcode 26.6. Keep SwiftUI/Observation code compatible with Swift 6 strict concurrency expectations.

**Primary Dependencies**: SwiftUI, Observation, Foundation, AppKit, existing HermesMacOS security/process helpers, existing Hermes Agent local Python runtime for Hindsight provider access. No new third-party Swift package is planned.

**Storage**: `@AppStorage`/UserDefaults for non-sensitive tab visibility preferences only. Hindsight memory content remains provider-owned; the Memory tab displays provider results and sends provider-level delete/invalidate requests. Do not persist raw memory lists, provider debug output, tokens, or stack traces.

**Testing**: `xcodegen generate` when project membership changes; `xcodebuild` app build; deterministic `HermesMacOSTest` tests for tab visibility defaults/toggles, selection fallback, Memory store pagination/filter/delete behavior, JSON decoding, and sanitized provider errors. Live Hindsight smoke is opt-in only.

**Target Platform**: Native macOS 26.0+ desktop app.

**Project Type**: Desktop app / native Hermes Agent control surface.

**Performance Goals**: Memory tab first page should render within 3 seconds for reachable provider data; list operations are cancellable/stale-response guarded; row content previews are bounded; no unbounded background polling for Memory tab v1.

**Constraints**: App is intentionally unsandboxed; preserve app-level guardrails. Hindsight operations may touch local runtime/provider services and must use bounded process/helper execution, sanitized errors, and provider APIs instead of direct storage mutation. Existing Ask Hermes, Chat with Hermes, Dashboard, and TUI Gateway contracts must not change.

**Scale/Scope**: Single macOS app target plus existing unit-test target. Feature touches app shell, Settings, a new Memory tab surface, and test coverage. Bulk memory deletion, support for non-Hindsight providers, and provider configuration UI are out of scope.

## Constitution Check

*GATE: Passed before Phase 0 research. Re-check after Phase 1 design also passed.*

- **Native control surface**: Pass. The feature is a native SwiftUI app-shell/Settings enhancement plus a native Memory tab. It preserves HermesMacOS as a desktop control surface and does not replace requested UI with a web wrapper.
- **Integration contracts**: Pass. Ask Hermes and Chat with Hermes API behavior remains unchanged; only their side-tab visibility is filtered. Hindsight memory access is isolated behind a provider-level helper boundary using the active Hermes home/profile context. Dashboard/TUI Gateway contracts are not modified.
- **Security guardrails**: Pass. Tab preferences are non-sensitive. Memory content is sensitive, so the plan avoids persistent raw list storage, requires delete confirmation, sanitizes errors, uses bounded local helper execution, and avoids direct provider storage mutation from Swift.
- **Verification**: Pass. Plan includes `xcodegen generate` when needed, app build, deterministic `HermesMacOSTest` coverage, manual Settings/Memory smoke, and opt-in live Hindsight smoke with disposable data.
- **Maintainability**: Pass. Large/high-churn files are extended surgically for enum/navigation wiring only; Memory list/provider state goes into focused new files; tests and coverage map updates keep behavior discoverable.

## Project Structure

### Documentation (this feature)

```text
specs/014-memory-tab-settings/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── memory-tab-ui-contract.md
├── checklists/
│   └── requirements.md
└── tasks.md             # Phase 2 output from /speckit-tasks, not created here
```

### Source Code (repository root)

```text
HermesMacOS/
├── ContentView.swift                       # HermesMacOSTab adds Memory; visible-tab filtering and selection fallback
├── SettingsView.swift                      # Ask/Chat tab visibility toggles
├── HermesMemoryView.swift                  # New native Memory tab UI
├── HermesMemoryStore.swift                 # @Observable page/filter/delete state and provider orchestration
├── HermesHindsightMemoryClient.swift       # Provider-boundary Hindsight list/delete helper and DTO decoding
├── HermesSecurityUtilities.swift           # Reuse existing HermesProcessRunner/HermesRuntimePaths only if needed
└── Localizable.xcstrings                   # User-facing Settings/Memory strings when localized

HermesMacOSTest/
├── Functional/
│   ├── AppShellAndSettingsTests.swift      # Tab defaults, toggles, fallback, coverage updates
│   └── MemoryTabWorkflowTests.swift        # Memory tab paging/filter/delete fixture workflows
├── Technical/
│   └── HindsightMemoryClientTests.swift    # DTO decoding, error sanitization, helper contract tests
└── Coverage/
    └── HermesMacOSTestCoverageMap.swift    # Add Memory tab and tab visibility coverage entries

docs/
├── reference-app-surface.md                # Document Memory tab and Settings toggles if docs are updated in implementation
└── how-to-use-ask-and-chat.md              # Note optional tab visibility if docs are updated in implementation
```

**Structure Decision**: Use focused new Memory files for UI/store/provider boundary and keep `ContentView.swift`/`SettingsView.swift` changes narrow. Use existing `HermesMacOSTest` structure for deterministic tests; update `project.yml` and regenerate Xcode project only if new Swift source/test files are not covered by current source globs or if project membership needs explicit adjustment.

## Phase 0: Research Summary

Research completed in [research.md](research.md).

Key decisions:
- Use Apple Swift 6 language mode with observed Apple Swift 6.3.3 / Xcode 26.6, preserving macOS 26.0+.
- Store Ask/Chat visibility as non-sensitive app preferences defaulting to visible.
- Hide tabs by filtering navigation, not by deleting workspace/session state.
- Use a provider-level Hindsight helper/client for Memory tab list/filter/delete.
- Add deterministic tests and keep live Hindsight smoke opt-in.

## Phase 1: Design Summary

Design artifacts generated:
- [data-model.md](data-model.md): Tab visibility, Memory tab state, Memory entry, filter, and delete request models.
- [contracts/memory-tab-ui-contract.md](contracts/memory-tab-ui-contract.md): Settings visibility, Memory list, filter, pagination, delete, Hindsight provider boundary, and test contracts.
- [quickstart.md](quickstart.md): Build/test/manual smoke commands and optional live Hindsight smoke.

Post-design constitution re-check: passed. No violations require complexity tracking.

## Complexity Tracking

No constitution violations identified.
