# Feature Specification: App Shell and Settings

**Feature Branch**: `feature/time-machine-app-shell-settings`  
**Created**: 2026-06-27  
**Status**: Draft  
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

### Edge Cases

- If LocalAuthentication or startup secret unlock fails, the app must show a bounded failure state instead of exposing protected secrets or crashing.
- If Hermes API or Dashboard endpoints are unreachable, the shell and Settings must remain usable while reachability indicators or feature-specific errors communicate the failure.
- If the user configures remote plaintext HTTP for sensitive traffic, endpoint validation must block secret-bearing requests except for loopback hosts.
- If a saved endpoint pair, theme, language, or font preference is invalid or unavailable, the app must fall back to a safe default and avoid breaking navigation.
- If resources such as bundled fonts or splash media are unavailable, the app must degrade to system fonts or a static shell without blocking core navigation.
- If Settings modifies SSH credentials or API keys, secrets must remain in Keychain-backed storage and temporary key files must be cleaned up.

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
- **FR-SEC**: System MUST preserve HermesMacOS security guardrails for endpoint validation, Keychain/encrypted retention, redaction, TLS pin approval, local filesystem approvals, and bounded process execution where applicable.
- **FR-INT**: System MUST preserve documented Hermes API/Dashboard/TUI Gateway contracts by passing current endpoint settings to composed feature views without changing their headers, tokens, streaming events, cancellation IDs, attachments, retries, or user-visible error states.

### Key Entities *(include if feature involves data)*

- **HermesMacOSTab**: Main navigation destination exposed in the side-tab shell, including its label, icon, selection state, and attention state.
- **HermesAPISettings**: User-configured API base URL, dashboard URL, API key reference, self-signed certificate allowance, and related endpoint options passed to feature views.
- **HermesSavedEndpoint**: Persisted API/dashboard endpoint pair available for quick switching across local, Tailscale, and remote Hermes deployments.
- **HermesAppTheme**: User-selected appearance mode that maps to system, light, or dark color scheme behavior.
- **HermesAppLanguageSelection**: User-selected app language option used by shell/settings localization behavior.
- **HermesSSHHostCredentials**: Keychain-backed host credentials used by local repository maintenance workflows surfaced from Settings.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A clean `HermesMacOS` scheme build completes successfully using the documented `xcodebuild` command.
- **SC-002**: From a fresh launch, a user can reach the main shell and switch between all top-level tabs without a crash.
- **SC-003**: A user can update and persist API/dashboard endpoint settings and return to the main shell in one Settings session.
- **SC-004**: Sensitive settings remain outside plaintext preference storage according to existing Keychain helper behavior.
- **SC-005**: At least one non-default theme/font/language preference can be selected without breaking the root navigation shell.
- **SC-BUILD**: The `HermesMacOS` scheme builds successfully with Xcode or command-line `xcodebuild`.
- **SC-SMOKE**: The primary user journey can be validated independently with documented manual, mock-backed, or live-service smoke checks.

## Assumptions

- Existing app-shell and settings behavior is being specified retroactively from the current implementation rather than redesigned from scratch.
- The feature does not add a new test target; verification relies on build plus manual shell/settings smoke checks documented in this feature.
- Existing flat source-file organization under `HermesMacOS/` remains in place.
- Existing Hermes API, Dashboard, TUI Gateway, security, and local runtime features consume the endpoint/settings state owned by this shell.

## Clarifications

### Session 2026-06-27

- No critical product questions were generated for this retroactive feature; current source and docs provide sufficient behavior boundaries for plan/tasks generation.
