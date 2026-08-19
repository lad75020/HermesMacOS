# Feature Specification: App Shell and Settings

**Feature Branch**: `feature/time-machine-app-shell-settings`  
**Created**: 2026-06-27  
**Status**: Refined
**Refined**: 2026-08-20 — Added bottom-sidebar macOS memory and GPU usage gauges backed by the local `GPUUsage` utility.
**Input**: User description: "Feature: App Shell and Settings. Description: Provides the native macOS entry point, main tab shell, endpoint settings, theming, localization, and startup experience users navigate from. Relevant files: project.yml, HermesMacOS/HermesMacOSApp.swift, HermesMacOS/ContentView.swift, HermesMacOS/SettingsView.swift, HermesMacOS/HermesTypography.swift, HermesMacOS/SplashView.swift, HermesMacOS/Localizable.xcstrings, HermesMacOS/HermesMacOS.entitlements. Focus on this feature only; do not modify other features."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Launch into the native control surface (Priority: P1)

A Hermes user launches HermesMacOS and lands in a native, usable shell that exposes the primary app tabs and uses the configured visual language without needing to understand project internals.

**Why this priority**: The app shell is the entry point for every other user-facing feature. If launch, root view selection, and navigation do not work, no downstream Hermes workflow is reachable.

**Independent Test**: Build and launch the app, then verify the splash/unlock flow reaches the main shell and the side tab switcher exposes the expected top-level destinations.

**Acceptance Scenarios**:

1. **Given** HermesMacOS starts normally, **When** the app scene initializes, **Then** the user sees the splash/unlock path followed by the main content shell.
2. **Given** the main content shell is visible, **When** the user selects each side tab, **Then** the selected tab state changes and the matching feature view is composed without crashing.
3. **Given** a tab has background activity attention state, **When** the tab is not selected, **Then** the side tab indicator communicates streaming, completed, or failed state.

---

### User Story 2 - Configure endpoint, appearance, and local app preferences (Priority: P2)

A user opens Settings and configures Hermes API/dashboard endpoints, saved endpoint pairs, credentials, allowed local folders, theme, language, and font preferences used by the app shell and feature views.

**Why this priority**: Endpoint and appearance settings make the app usable across local, Tailscale, and remote Hermes deployments and let each window target the correct services.

**Independent Test**: Open Settings, update non-sensitive preferences, close/reopen Settings, and confirm values persist and are reflected by the app shell.

**Acceptance Scenarios**:

1. **Given** Settings is open, **When** the user edits the API base URL or dashboard URL, **Then** the values are persisted and propagated to windows that use those settings.
2. **Given** the user selects a theme or app language, **When** the main shell redraws, **Then** the selection is applied or queued according to the existing platform behavior.
3. **Given** the user imports or removes an SSH key or API key, **When** the operation completes, **Then** sensitive material is handled through Keychain-backed helpers rather than plaintext app preferences.

---

### User Story 3 - Preserve localization, resources, and app identity (Priority: P3)

A user sees the app with the configured app identity, localized strings, custom typography, splash media, and app entitlement behavior needed for a native macOS developer-tool experience.

**Why this priority**: The app must remain recognizable, localized, and platform-correct, but these refinements depend on the shell and settings paths being stable first.

**Independent Test**: Inspect the built app target and run the app with alternate appearance/language settings to verify resources load and text remains user-facing.

**Acceptance Scenarios**:

1. **Given** the app target is generated from `project.yml`, **When** it builds, **Then** the bundle identifier, display name, app category, permissions text, and entitlements match the HermesMacOS app identity.
2. **Given** bundled fonts and splash resources are available, **When** the app launches, **Then** typography and splash views render without missing-resource failures.
3. **Given** localized strings exist, **When** the app language setting changes, **Then** user-facing shell/settings text uses the selected localization where available.

---

### User Story 4 - Monitor local Mac resource use from navigation (Priority: P4)

A Hermes user can see the Mac's current memory and GPU usage without leaving the navigation shell, so they can recognize local resource pressure while working in any top-level destination.

**Why this priority**: The gauges are supplementary to primary navigation, but they provide useful operational context for local-model and GPU-intensive workflows.

**Independent Test**: Launch HermesMacOS and confirm two compact pie-chart-styled gauges appear at the bottom of the left navigation bar; confirm their labels and percentages update from a valid `GPUUsage` sample and that a failed sample presents a bounded unavailable state.

**Acceptance Scenarios**:

1. **Given** the main shell is visible and `/Volumes/WDBlack4TB/Code/NodeMLX/utils/GPUUsage` returns valid output, **When** the sidebar's resource monitor polls the utility, **Then** it renders separate Memory and GPU gauges at the bottom of the left navigation bar using the reported percentage values.
2. **Given** either value changes, **When** a later successful poll completes, **Then** the matching gauge and its textual percentage update without blocking tab selection or rendering unrelated feature views.
3. **Given** VoiceOver is enabled, **When** focus reaches either gauge, **Then** it exposes a localized label and current percentage value that identifies Memory or GPU usage.
4. **Given** the utility is missing, times out, exits unsuccessfully, or emits unparsable output, **When** the next poll is processed, **Then** the app keeps navigation usable and presents an unavailable/stale gauge state without displaying raw process output or crashing.

---

### Edge Cases

- If LocalAuthentication or startup secret unlock fails, the app must show a bounded failure state instead of exposing protected secrets or crashing.
- If Hermes API or Dashboard endpoints are unreachable, the shell and Settings must remain usable while reachability indicators or feature-specific errors communicate the failure.
- If the user configures remote plaintext HTTP for sensitive traffic, endpoint validation must block secret-bearing requests except for loopback hosts.
- If a saved endpoint pair, theme, language, or font preference is invalid or unavailable, the app must fall back to a safe default and avoid breaking navigation.
- If resources such as bundled fonts or splash media are unavailable, the app must degrade to system fonts or a static shell without blocking core navigation.
- If Settings modifies SSH credentials or API keys, secrets must remain in Keychain-backed storage and temporary key files must be cleaned up.
- If either resource percentage is absent, non-finite, or outside `0...100`, the system must reject that sample and retain a clearly unavailable/stale visual state rather than rendering a misleading gauge.
- If the resource monitor view disappears or the app terminates, its polling task and any running utility process must be cancelled/terminated promptly; it must not leave an uncancellable background loop.
- The monitor must invoke only the fixed local `GPUUsage` executable path, without a shell, user-supplied arguments, or interpolation of untrusted text into a process command.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST initialize a macOS application scene that routes users through the startup unlock/splash path into `ContentView` when permitted.
- **FR-002**: System MUST provide a native side-tab navigation shell for Ask Hermes, Chat with Hermes, History, Sessions, Approvals Inbox, Kanban, Hermes Dashboard, Configuration, and Utilities.
- **FR-003**: System MUST preserve per-window connection state so windows can target different Hermes API and Dashboard hosts.
- **FR-004**: Users MUST be able to configure API base URL, Dashboard URL, optional API key, self-signed certificate behavior, saved endpoint pairs, SSH credentials, allowed folders, theme, language, title font, label font, prompt font size, and chat bubble font size from Settings.
- **FR-005**: System MUST persist non-sensitive shell/settings preferences through app storage or UserDefaults and sensitive values through Keychain-backed helpers.
- **FR-006**: System MUST expose visual attention states for long-running or completed background work in side-tab/workspace controls.
- **FR-007**: System MUST register and use bundled typography/resources when present while preserving safe fallbacks.
- **FR-008**: System MUST keep app identity, permission purpose strings, deployment target, code-signing settings, and entitlements aligned with `project.yml` and localized resources.
- **FR-009**: System MUST display two compact pie-chart-styled gauges, labeled Memory and GPU, anchored below the navigation controls at the bottom of the left navigation bar.
- **FR-010**: System MUST poll the fixed local executable `/Volumes/WDBlack4TB/Code/NodeMLX/utils/GPUUsage` at a bounded cadence (default: every five seconds) and parse both `GPU Usage: <percent>%` and `Memory Usage: <percent>%` values from each successful invocation.
- **FR-011**: System MUST validate parsed resource values as finite percentages in `0...100`, update only values that changed, and make the numeric percentage and gauge meaning accessible in addition to the visual pie chart.
- **FR-012**: System MUST run the blocking utility invocation off the UI actor, enforce a bounded execution time, and cancel polling/process work when the navigation shell is no longer visible or the app exits.
- **FR-013**: System MUST treat resource monitor failures as non-fatal: retain usable navigation, avoid exposing raw utility output, and present an unavailable or stale state until a later valid sample succeeds.
- **FR-SEC**: System MUST preserve HermesMacOS security guardrails for endpoint validation, Keychain/encrypted retention, redaction, TLS pin approval, local filesystem approvals, and bounded process execution where applicable.
- **FR-INT**: System MUST preserve documented Hermes API/Dashboard/TUI Gateway contracts by passing current endpoint settings to composed feature views without changing their headers, tokens, streaming events, cancellation IDs, attachments, retries, or user-visible error states.

### Key Entities *(include if feature involves data)*

- **HermesMacOSTab**: Main navigation destination exposed in the side-tab shell, including its label, icon, selection state, and attention state.
- **HermesAPISettings**: User-configured API base URL, dashboard URL, API key reference, self-signed certificate allowance, and related endpoint options passed to feature views.
- **HermesSavedEndpoint**: Persisted API/dashboard endpoint pair available for quick switching across local, Tailscale, and remote Hermes deployments.
- **HermesAppTheme**: User-selected appearance mode that maps to system, light, or dark color scheme behavior.
- **HermesAppLanguageSelection**: User-selected app language option used by shell/settings localization behavior.
- **HermesSSHHostCredentials**: Keychain-backed host credentials used by local repository maintenance workflows surfaced from Settings.
- **HermesResourceUsageSnapshot**: A validated, timestamped pair of local Memory and GPU percentages with a freshness/availability state used only by the sidebar resource gauges.
- **HermesResourceUsageMonitor**: Main-actor-owned observable monitor that schedules cancellable polling, invokes the fixed utility path off the UI actor, validates output, and publishes only the latest safe snapshot or unavailable state.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A clean `HermesMacOS` scheme build completes successfully using the documented `xcodebuild` command.
- **SC-002**: From a fresh launch, a user can reach the main shell and switch between all top-level tabs without a crash.
- **SC-003**: A user can update and persist API/dashboard endpoint settings and return to the main shell in one Settings session.
- **SC-004**: Sensitive settings remain outside plaintext preference storage according to existing Keychain helper behavior.
- **SC-005**: At least one non-default theme/font/language preference can be selected without breaking the root navigation shell.
- **SC-006**: When `GPUUsage` returns valid percentages, the sidebar shows two correctly labeled gauges whose accessible values match the most recently validated Memory and GPU samples within one polling interval.
- **SC-007**: While the resource utility is unavailable, slow, malformed, or fails, tab selection remains responsive and no crash, raw process output, or unbounded polling/process work is observed.
- **SC-BUILD**: The `HermesMacOS` scheme builds successfully with Xcode or command-line `xcodebuild`.
- **SC-SMOKE**: The primary user journey can be validated independently with documented manual, mock-backed, or live-service smoke checks.

## Assumptions

- Existing app-shell and settings behavior is being specified retroactively from the current implementation rather than redesigned from scratch.
- The feature does not add a new test target; verification relies on build plus manual shell/settings smoke checks documented in this feature.
- Existing flat source-file organization under `HermesMacOS/` remains in place.
- Existing Hermes API, Dashboard, TUI Gateway, security, and local runtime features consume the endpoint/settings state owned by this shell.
- The fixed `GPUUsage` executable is locally installed and currently emits separate `GPU Usage: <percent>%` and `Memory Usage: <percent>%` lines; a direct invocation on 2026-08-20 returned `GPU Usage: 27%` and `Memory Usage: 66.1%`.
- A five-second polling interval is an acceptable default for this non-interactive operational indicator; implementation may make the interval configurable internally without increasing frequency or compromising cancellation behavior.

## Clarifications

### Session 2026-06-27

- No critical product questions were generated for this retroactive feature; current source and docs provide sufficient behavior boundaries for plan/tasks generation.

### Session 2026-08-20

- Add two compact pie-chart-styled resource gauges at the bottom of the existing `HermesSideTabSwitcher` in `ContentView`: one for Memory usage and one for GPU usage.
- Poll `/Volumes/WDBlack4TB/Code/NodeMLX/utils/GPUUsage`, which was verified to be an arm64 Mach-O executable and to return both values in one invocation.
