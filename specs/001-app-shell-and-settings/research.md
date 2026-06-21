# Research: App Shell and Settings

## Decision: Keep app shell state in native SwiftUI/Observable objects

**Rationale**: The existing app shell composes native SwiftUI tabs, workspace switchers, reachability LEDs, and Settings state. Keeping shell orchestration in SwiftUI preserves platform behavior, allows immediate redraws from observable state, and avoids adding a second navigation/state framework.

**Alternatives considered**:

- Move shell state behind a dashboard API: rejected because tab/workspace selection and per-window endpoint targeting are local UI concerns.
- Introduce a separate navigation framework: rejected because the current SwiftUI composition already expresses the required shell states and would add migration risk.

## Decision: Persist non-secret shell preferences separately from sensitive secrets

**Rationale**: Selected tabs, appearance choices, endpoint labels, font settings, and language choices are safe to persist as user preferences. API keys, SSH keys, certificate pins, and trust decisions remain in the shared security layer so Settings can route to them without duplicating secret handling.

**Alternatives considered**:

- Store all settings together in a single preferences blob: rejected because it risks mixing secret and non-secret state and makes recovery from malformed preferences harder.
- Require users to re-enter endpoints on every launch: rejected because it weakens the returning-user launch outcome.

## Decision: Scope endpoint changes to a window connection

**Rationale**: HermesMacOS supports multiple windows that may target different Hermes API/dashboard hosts. Treating endpoint settings as a selected-window operation prevents one window from silently disrupting another active workflow.

**Alternatives considered**:

- Global endpoint changes for every window: rejected because it violates multi-window independence.
- Separate API-only and dashboard-only saved presets: rejected because users commonly need matching pairs for one Hermes deployment.

## Decision: Represent reachability as lightweight shell feedback, not blocking workflow state

**Rationale**: Users need to know whether the Hermes API or dashboard appears reachable, but navigation should remain usable while services start, restart, or fail. Non-blocking reachability indicators help troubleshoot without deleting drafts or forcing tab changes.

**Alternatives considered**:

- Block navigation when a service is unreachable: rejected because local Settings, Utilities, and troubleshooting remain useful while services are offline.
- Hide reachability until a workflow fails: rejected because it delays important diagnostics.

## Decision: Validate through build plus focused smoke scenarios

**Rationale**: The repository currently declares no dedicated test target, so reliable validation for this feature is an Xcode build plus targeted smoke scenarios for launch, tab state, Settings persistence, per-window targeting, and reachability changes.

**Alternatives considered**:

- Add a new full UI test target as part of this feature: deferred because it would expand project structure beyond the shell feature and should be planned separately.
- Rely only on source inspection: rejected because the delivered app must still compile.
