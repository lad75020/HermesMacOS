# Research: Memory Tab and Tab Settings

**Feature**: `014-memory-tab-settings`  
**Date**: 2026-06-28  
**Inputs considered**: user request for latest Swift and macOS 26+, existing HermesMacOS docs/codebase maps, current `project.yml`, local toolchain output (`Apple Swift 6.3.3`, Xcode 26.6, macOS 26.5.1), existing Hindsight Knowledge Eraser helper.

## Decision 1: Swift and platform baseline

**Decision**: Plan the feature against Apple Swift 6.3.3 as observed in the workspace toolchain, keep `project.yml` on Swift 6 language mode, and preserve `MACOSX_DEPLOYMENT_TARGET: 26.0` / macOS 26+.

**Rationale**: The repository already sets `SWIFT_VERSION: 6.0` and macOS deployment target 26.0. The active toolchain reports `Apple Swift version 6.3.3` and Xcode 26.6, matching the user's request for the latest Swift version and macOS 26 and above without requiring project-wide migration churn.

**Alternatives considered**:
- Raise `SWIFT_VERSION` to a literal `6.3`: Xcode project settings use language-mode identifiers rather than exact compiler patch versions; this would be unnecessary and risky.
- Lower the deployment target for broader compatibility: rejected because the user explicitly requested macOS 26 and above.

## Decision 2: Tab visibility preferences

**Decision**: Store Ask Hermes and Chat with Hermes visibility as non-sensitive app preferences, default both to enabled, and filter the side-tab list at render/selection time while preserving each tab's workspace/session objects in memory.

**Rationale**: Visibility is not sensitive and belongs with Settings/app-shell preferences. Filtering the navigation list avoids deleting workspaces, drafts, attachments, and session state when a tab is temporarily hidden. If the selected tab becomes hidden, selection can move to the first enabled non-hidden tab.

**Alternatives considered**:
- Remove tab state when hidden: rejected because it would violate the spec's preservation requirement.
- Move toggles to Configuration instead of Settings: rejected because the user explicitly asked for Settings and this is an app-shell preference, not a Hermes runtime setting.

## Decision 3: Memory tab provider boundary

**Decision**: Implement a native Memory tab with a dedicated `@Observable` store and a small Hindsight provider client/helper that reuses the existing local Python/provider boundary pattern from `HermesKnowledgeEraserUtility.swift` rather than directly manipulating Hindsight storage from Swift.

**Rationale**: Existing Knowledge Eraser code already initializes `plugins.memory.hindsight.HindsightMemoryProvider` through the Hermes Agent Python runtime and uses provider-level Hindsight operations. Reusing this boundary keeps HermesMacOS out of provider storage internals, allows provider errors to stay user-facing and bounded, and matches the app's unsandboxed local-runtime guardrails.

**Alternatives considered**:
- Query Hindsight database/files directly from Swift: rejected because provider internals can change and direct storage access bypasses provider policy.
- Embed the Hermes Dashboard route in WebKit: rejected because the requested Memory tab needs native pagination/filter/delete behavior and no existing route was identified for this exact surface.

## Decision 4: Pagination and filtering behavior

**Decision**: Keep Memory tab paging state in the store with a default small page size, apply filter text to provider search/list requests where supported, and clamp page index after refresh/delete. Rows should show content preview plus available metadata and use bounded expanded text.

**Rationale**: The spec requires pagination and filtering. Store-owned page/filter state allows deterministic tests for page clamping, empty states, delete refresh, and stale request handling. Bounded previews protect UI responsiveness when memories are long.

**Alternatives considered**:
- Load all memories and filter only in Swift: acceptable only for mock/small lists but risky for large memory banks; provider-backed filtering/listing should be preferred.
- Infinite scrolling: rejected because the spec asks for explicit paginated list controls and success criteria reference paging.

## Decision 5: Delete semantics

**Decision**: Delete one memory at a time after explicit confirmation. For Hindsight, use provider-supported invalidation/deletion behavior and refresh the current filtered page after success. On failure, keep the row visible and show a concise error without raw stack traces or secrets.

**Rationale**: Existing Knowledge Eraser Hindsight deletion marks memories invalidated through the provider/API path. Individual confirmed deletion minimizes accidental loss and meets the spec without bulk destructive workflows.

**Alternatives considered**:
- Bulk delete selected rows: rejected as out of scope for v1.
- Delete without confirmation: rejected because memory content can be sensitive and deletion is destructive.

## Decision 6: Verification strategy

**Decision**: Add deterministic `HermesMacOSTest` coverage for tab visibility filtering/defaults, Memory store pagination/filter/delete state transitions, redaction/error sanitization, and provider-helper JSON decoding. Keep live Hindsight checks opt-in and documented in quickstart.

**Rationale**: The repo now has a native test target and policy that default tests must not require live services. The implementation can validate state and contracts with fixtures, then reserve live provider checks for explicit smoke runs.

**Alternatives considered**:
- Rely only on manual UI smoke: rejected because the test target exists and this feature has pure state logic suitable for fixture tests.
- Require live Hindsight for default tests: rejected by the repository testing policy.
