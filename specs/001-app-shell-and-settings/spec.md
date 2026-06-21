# Feature Specification: App Shell and Settings

**Feature Branch**: `feature/time-machine-app-shell-and-settings`

**Created**: 2026-06-21

**Status**: Draft

**Input**: User description: "Feature: App Shell and Settings. Description: Provides the native macOS app entry point, tab navigation, reachability indicators, saved endpoints, and user preferences that frame every Hermes workflow. Relevant files: project.yml, HermesMacOS/HermesMacOSApp.swift, HermesMacOS/ContentView.swift, HermesMacOS/SettingsView.swift, HermesMacOS/HermesReachabilityMonitor.swift, HermesMacOS/HermesMacOS.entitlements. Focus on this feature only; do not modify other features."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Launch into the Hermes control surface (Priority: P1)

A HermesMacOS user opens the app and lands in a stable native control surface that preserves the last meaningful startup state, shows the expected Hermes tabs, and makes the selected workspace ready for use.

**Why this priority**: Every other workflow depends on a predictable app shell, correct tab composition, and startup state restoration.

**Independent Test**: Can be tested by launching the app with no prior preferences and with saved preferences, then verifying the visible tab shell, default selection, restored selection, and usable workspace controls.

**Acceptance Scenarios**:

1. **Given** the app has no saved startup selection, **When** the user launches HermesMacOS, **Then** the app shows the main shell with a usable default Hermes workflow selected.
2. **Given** the user previously selected a different top-level Hermes tab, **When** the user relaunches HermesMacOS, **Then** the app restores the last valid tab without blocking access to the rest of the shell.
3. **Given** startup secrets cannot be unlocked, **When** the app starts, **Then** the user sees a clear failure state instead of an incomplete or unsafe main shell.

---

### User Story 2 - Navigate between Hermes workflows (Priority: P2)

A user switches between Ask, Chat, TUI Gateway, History, Sessions, Approvals, Kanban, Dashboard, Configuration, and Utilities while preserving each workflow's local state and attention indicators.

**Why this priority**: The shell exists to coordinate multiple Hermes workflows; users must navigate without losing context or missing attention-worthy updates.

**Independent Test**: Can be tested by creating or changing state in multiple tabs, switching away and back, and verifying state, selected workspace, and attention indicators remain consistent.

**Acceptance Scenarios**:

1. **Given** the user has active state in one workflow, **When** the user switches to another workflow and back, **Then** the original workflow state remains available.
2. **Given** a background workflow changes status while another tab is selected, **When** the shell displays navigation, **Then** the relevant tab communicates attention without hijacking the current workflow.
3. **Given** the user creates, selects, or deletes a workspace in a multi-workspace workflow, **When** navigation updates, **Then** the shell keeps a valid selected workspace and never leaves the user stranded on a missing workspace.

---

### User Story 3 - Configure endpoint and preference defaults (Priority: P3)

A user opens Settings to manage Hermes API and dashboard endpoints, saved endpoint pairs, security-related connection options, SSH credentials, allowed folders, theme, language, and font preferences.

**Why this priority**: The app must adapt to local, remote, and multi-window Hermes environments while keeping settings understandable and recoverable.

**Independent Test**: Can be tested by changing settings, saving or removing endpoint pairs, reopening Settings, and confirming the selected window uses the intended connection and preferences.

**Acceptance Scenarios**:

1. **Given** the user edits the API and dashboard endpoints, **When** the user applies the settings, **Then** the active window uses the new endpoints and the shell reflects the connection target.
2. **Given** the user saves an endpoint pair, **When** the user selects it later, **Then** both API and dashboard endpoints are restored together.
3. **Given** the user changes display preferences, **When** the user returns to the main shell, **Then** the app applies the chosen appearance and typography preferences without requiring unrelated configuration changes.

---

### User Story 4 - Understand service reachability (Priority: P4)

A user sees lightweight reachability signals for the Hermes API and dashboard so they can distinguish app navigation problems from unavailable backend services.

**Why this priority**: Reachability feedback reduces confusion and helps users troubleshoot local or remote Hermes deployments before invoking workflow-specific actions.

**Independent Test**: Can be tested by pointing endpoints at reachable and unreachable services and verifying that the shell updates the visible reachability state within a short, predictable interval.

**Acceptance Scenarios**:

1. **Given** the configured API endpoint is reachable, **When** the reachability monitor runs, **Then** the shell indicates the API is available.
2. **Given** the configured dashboard endpoint is unavailable, **When** the reachability monitor runs, **Then** the shell indicates the dashboard is unavailable without blocking unrelated local navigation.
3. **Given** endpoints change in Settings, **When** the app returns to the shell, **Then** reachability checks use the updated endpoints.

### Edge Cases

- If a saved tab or workspace identifier no longer exists, the shell falls back to a valid default and preserves the rest of the saved preferences.
- If all user-created workspaces for a workflow are deleted, the shell leaves at least one usable workspace or returns to a valid default state.
- If a saved endpoint pair is malformed or incomplete, Settings prevents unsafe application or displays a clear recoverable error.
- If the Hermes API or dashboard is temporarily offline, reachability indicators update without freezing navigation or clearing user drafts.
- If multiple windows target different endpoints, changing one window's settings does not silently retarget another window.
- If the app language or typography preference changes, visible shell labels remain readable and controls remain accessible.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The app MUST present a native main shell with a stable set of Hermes workflow tabs: Ask, Chat, TUI Gateway, History, Sessions, Approvals, Kanban, Dashboard, Configuration, and Utilities.
- **FR-002**: The app MUST restore the last valid selected top-level tab and startup preference state when available, and MUST fall back to a safe default when saved values are missing or invalid.
- **FR-003**: The shell MUST preserve independent state for active workflows when users navigate between tabs.
- **FR-004**: Multi-workspace workflows MUST allow users to create, select, and delete workspaces while maintaining a valid current workspace at all times.
- **FR-005**: Navigation MUST communicate background attention states such as streaming, completed, failed, or status-worthy activity without automatically changing the user's selected tab.
- **FR-006**: Settings MUST allow users to view and update the Hermes API endpoint, Hermes dashboard endpoint, optional API key state, self-signed certificate allowance, saved endpoint pairs, SSH credential controls, allowed folders, theme, language, and font preferences.
- **FR-007**: Saved endpoint pairs MUST restore API and dashboard endpoints together for the selected window context.
- **FR-008**: Endpoint changes MUST be applied to the selected window context without silently overwriting other windows that target different Hermes hosts.
- **FR-009**: The shell MUST display reachability status for the configured Hermes API and dashboard targets.
- **FR-010**: Reachability checks MUST distinguish reachable, unreachable, and unknown/loading states without blocking user navigation.
- **FR-011**: The startup flow MUST show a clear failure view when required secrets cannot be unlocked, rather than exposing partially initialized sensitive state.
- **FR-012**: App-level configuration MUST remain consistent with the declared macOS application identity, permissions, localizations, and entitlement expectations for the control surface.

### Key Entities *(include if feature involves data)*

- **App Shell State**: The selected top-level tab, active workspace selections, attention states, and startup values that determine what the user sees when the app is opened or navigated.
- **Window Connection**: A per-window pairing of Hermes API endpoint, dashboard endpoint, and related connection settings used by workflow tabs in that window.
- **Saved Endpoint Pair**: A named reusable pairing of API and dashboard endpoints that users can apply to a window.
- **User Preferences**: Display, language, typography, allowed-folder, and security-related choices persisted for future app sessions.
- **Reachability Status**: The current availability state for API and dashboard services as shown by the shell.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A returning user can launch the app and reach the previously selected valid shell tab in under 5 seconds on a normally configured Mac.
- **SC-002**: A user can switch among any two main tabs 20 consecutive times without losing the selected workspace or draft state for either tab.
- **SC-003**: A user can save, select, and remove an endpoint pair in Settings with the active window reflecting the intended pair on the next return to the shell.
- **SC-004**: Reachability indicators reflect a deliberate endpoint availability change within 15 seconds without blocking tab navigation.
- **SC-005**: Invalid persisted tab, workspace, or endpoint preference data is recovered to a safe default in 100% of tested malformed-state scenarios.
- **SC-006**: All visible shell and Settings controls remain reachable by keyboard navigation and readable under each supported app theme and localization.

## Assumptions

- The feature is limited to the app shell, Settings surface, startup state, tab/workspace navigation, endpoint selection, reachability indicators, and related app identity configuration.
- Workflow-specific behavior inside Ask, Chat, TUI Gateway, History, Approvals, Kanban, Dashboard, Configuration subsections, and Utilities is covered by separate Time Machine features except where the shell must compose or route to those views.
- Users may run multiple app windows with different Hermes API and dashboard targets.
- Local loopback Hermes API and dashboard services are common defaults, but users can configure remote HTTPS or trusted local/Tailscale endpoints.
- Sensitive secrets and trust decisions are handled through the shared security layer; this feature only requires the shell and Settings to surface and route those controls correctly.
