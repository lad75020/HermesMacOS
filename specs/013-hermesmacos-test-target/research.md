# Research: HermesMacOS Test Target

## Decision 1: Use Swift 6 language mode with Xcode 26.6 / Apple Swift 6.3.3

**Decision**: Update project and test-target settings to Swift 6 language mode while relying on the locally installed Xcode 26.6 toolchain, verified by `xcrun swift --version` as Apple Swift 6.3.3. Keep `MACOSX_DEPLOYMENT_TARGET` at 26.0.

**Rationale**: The user explicitly requested the latest Swift version, Xcode 26.6, and macOS 26.0+. Xcode build settings express language mode separately from the compiler patch version, so the plan distinguishes Swift 6 language mode from the Apple Swift 6.3.3 compiler delivered by Xcode 26.6.

**Alternatives considered**:
- Keep `SWIFT_VERSION: 5.0`: rejected because it conflicts with the user's latest-Swift request and leaves the test target on an older language mode.
- Set a patch-level build setting such as `SWIFT_VERSION: 6.3.3`: rejected because Xcode project language mode settings normally use major language modes rather than compiler patch versions.

## Decision 2: Add the test target through XcodeGen and regenerate the checked-in Xcode project

**Decision**: Modify `project.yml` to add a native macOS unit-test target named exactly `HermesMacOSTest`, add a shared runnable test scheme, and regenerate `HermesMacOS.xcodeproj` with XcodeGen.

**Rationale**: The repository constitution and docs identify `project.yml` as the source of truth. Directly editing the generated project would be fragile and would be overwritten by the next generation pass.

**Alternatives considered**:
- Manually edit `project.pbxproj`: rejected because generated project membership must stay reproducible.
- Use a Swift Package test target: rejected because the app is not organized as a Swift package and the user specifically asked for an Xcode target.

## Decision 3: Prefer mock-backed default tests and separate opt-in live smoke checks

**Decision**: Default `HermesMacOSTest` runs against deterministic fixtures, mock URL loading, temporary local runtime directories, and fake credentials. Live Hermes API, Dashboard, TUI Gateway, Whisper, microphone, SSH, and repository smoke checks are documented and opt-in.

**Rationale**: HermesMacOS depends on local services, dashboard tokens, macOS permissions, and mutable user files. Default tests must be safe, repeatable, and runnable on any developer machine without leaking secrets or mutating Laurent's real environment.

**Alternatives considered**:
- Run all tests against Laurent's local Hermes services: rejected due to flakiness, privacy, and environment coupling.
- Skip integration-like coverage entirely: rejected because complete-scope coverage requires request, token, streaming, dashboard, local runtime, and utility behavior to be validated.

## Decision 4: Organize coverage by functional workflows plus technical guardrails

**Decision**: Create two primary suites: `Functional/` for user-facing workflows and `Technical/` for contracts, parsing, storage, security, and async lifecycle behavior. Add `Coverage/HermesMacOSTestCoverageMap.swift` to map every documented app area to tests or opt-in smoke checks.

**Rationale**: HermesMacOS has a broad surface area. A coverage map prevents the new target from becoming a token test bundle and gives maintainers a checklist for future features.

**Alternatives considered**:
- Organize tests by production file only: rejected because it obscures user-facing coverage and makes cross-file workflows harder to audit.
- One large all-scope test file: rejected because it would be brittle and difficult to maintain.

## Decision 5: Use temporary fixtures for local runtime, security, and process behavior

**Decision**: Build support utilities for temporary Hermes home trees, fixture dashboard HTML, fixture SSE/WebSocket streams, fake Keychain/secret identifiers, and bounded fake process runners.

**Rationale**: The app is intentionally unsandboxed and has powerful local capabilities. Tests must demonstrate guardrails while avoiding writes to real profiles, repositories, pins, clipboard history, logs, or Keychain secrets.

**Alternatives considered**:
- Use the real configured Hermes home for local-runtime tests: rejected because it can corrupt user state.
- Mock every local helper without fixture files: rejected because YAML/config mutation and process-safety behavior require realistic on-disk examples.

## Decision 6: Add small testability seams only where needed

**Decision**: Prefer testing existing pure helpers directly. Where behavior is locked inside large UI/session files, add narrowly scoped seams such as injectable URL sessions, parsers, clocks, fixture stores, or extracted pure functions.

**Rationale**: The constitution warns against growing high-churn files. Tests should improve confidence without broad architectural churn.

**Alternatives considered**:
- Large refactor before adding tests: rejected as too risky for an infrastructure feature.
- UI-only tests for everything: rejected because many critical security and request-construction contracts are best validated with focused technical tests.
