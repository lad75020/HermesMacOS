# Research: App Shell and Settings

## Decision 1: Treat this as a retroactive specification of existing behavior

**Decision**: Do not redesign shell/settings source code unless verification finds a defect. Capture current behavior and trace it to build/smoke checks.

**Rationale**: The queue was generated from existing source, and README/docs already describe the app as a native SwiftUI control surface. The first Time Machine feature is foundational and should stabilize traceability before downstream feature specs.

**Alternatives considered**:
- Refactor `ContentView` immediately: rejected because it would expand scope and risk unrelated feature behavior.
- Add a test target immediately: rejected for this feature because repository docs state no current test target; this belongs in a separate testing feature.

## Decision 2: Keep settings persistence split by sensitivity

**Decision**: Continue using AppStorage/UserDefaults for non-sensitive preferences and Keychain-backed helpers for API keys, SSH keys, certificate pins, and unlock/retention secrets.

**Rationale**: This matches documented HermesMacOS security conventions and avoids plaintext secret storage.

**Alternatives considered**:
- Move all settings into Keychain: rejected because non-sensitive appearance/navigation preferences do not require secret storage and would complicate synchronization.
- Store secrets in UserDefaults with redaction: rejected because redaction is not a storage protection mechanism.

## Decision 3: Preserve per-window endpoint context

**Decision**: Keep per-window connection state in the shell and pass current API/dashboard settings into composed feature views.

**Rationale**: README highlights multiple windows targeting different Hermes API/dashboard hosts. Centralizing endpoint context in the shell avoids duplicated settings logic in each feature tab.

**Alternatives considered**:
- Make each feature tab own endpoint settings: rejected because it increases coupling and inconsistent endpoint behavior.
- Force a single global endpoint for all windows: rejected because it removes a documented workflow.

## Decision 4: Verification relies on build plus manual shell/settings smoke checks

**Decision**: Use documented `xcodebuild` scheme build and manual app-shell/settings smoke checks.

**Rationale**: `docs/codebase/TESTING.md` states there is no dedicated test target. A build is the canonical automated check currently available.

**Alternatives considered**:
- Claim suite-green: rejected because no suite exists.
- Add UI tests in this feature: rejected as out of scope for retroactive shell specification.
