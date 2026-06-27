# Feature Specification: Dashboard Web Embedding

**Feature Branch**: `feature/time-machine-dashboard-web-embedding`  
**Created**: 2026-06-27  
**Status**: Draft  
**Input**: User description: "Feature: Dashboard Web Embedding. Description: Embeds Hermes Dashboard pages in a native WebKit surface while preserving endpoint configuration and native app navigation. Relevant files: HermesMacOS/HermesDashboardWebView.swift, docs/reference-app-surface.md. Focus on this feature only; do not modify other features."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Load a dashboard page in native WebKit (Priority: P1)
A user opens a Dashboard-backed tab and sees the configured Hermes Dashboard page inside a rounded native container.

**Why this priority**: Native dashboard embedding is the feature's core behavior.

**Independent Test**: Configure dashboard URL, open Hermes Dashboard tab, and verify the WebKit view loads the normalized page URL.

**Acceptance Scenarios**:
1. **Given** a valid dashboard URL, **When** the view appears, **Then** `WKWebView` loads that URL once.
2. **Given** a `pagePath` is supplied, **When** the URL is normalized, **Then** the embedded page uses that path.
3. **Given** no valid dashboard URL exists, **When** the tab renders, **Then** a Dashboard URL required empty state is shown.

---

### User Story 2 - Apply native theme and reload behavior (Priority: P2)
A user sees the embedded dashboard use a light/dark dashboard theme matching the app color scheme and can reload the page.

**Why this priority**: Embedded web pages need to feel coherent in the native shell and recover from stale content.

**Independent Test**: Toggle app light/dark mode, inspect the loaded URL/theme, press reload, and verify the page reloads without rebuilding the store.

**Acceptance Scenarios**:
1. **Given** dark mode, **When** the URL is built, **Then** the query contains `theme=mono`.
2. **Given** light mode, **When** the URL is built, **Then** the query contains `theme=solarized-light`.
3. **Given** the user presses Reload, **When** reload token changes, **Then** the existing web view reloads.

---

### User Story 3 - Keep embedded navigation secure and reusable (Priority: P3)
The dashboard embed rejects unsafe remote plaintext URLs, allows back/forward gestures, and reuses one `WKWebView` per store.

**Why this priority**: Embedded dashboard pages are sensitive control surfaces and should not duplicate web state unnecessarily.

**Independent Test**: Try remote plaintext HTTP, local HTTP, and HTTPS dashboard URLs; verify only safe/allowed URLs load and the same store persists navigation state.

**Acceptance Scenarios**:
1. **Given** a remote plaintext HTTP dashboard URL, **When** normalized, **Then** the URL is rejected.
2. **Given** localhost HTTP or HTTPS, **When** normalized, **Then** the URL is allowed.
3. **Given** an existing store, **When** the view updates with the same URL and reload token, **Then** it does not issue a duplicate load.

### Edge Cases
- Host-only dashboard strings should default to HTTPS.
- Existing dashboard theme query parameters should be replaced, not duplicated.
- Unsupported URL schemes should be rejected.
- JavaScript theme override should not break page load if dashboard theme API requests fail.

## Requirements *(mandatory)*

### Functional Requirements
- **FR-001**: System MUST provide a reusable SwiftUI `HermesDashboardView` that embeds a dashboard page through WebKit.
- **FR-002**: System MUST normalize configured dashboard URL strings and optional page paths.
- **FR-003**: System MUST reject unsupported schemes and remote plaintext HTTP URLs.
- **FR-004**: System MUST append exactly one dashboard `theme` query item matching the current color scheme.
- **FR-005**: System MUST show a native empty state when no safe dashboard URL can be built.
- **FR-006**: System MUST expose a reload action that reloads the existing web view.
- **FR-007**: System MUST allow back/forward navigation gestures in the embedded web view.
- **FR-008**: System MUST inject a theme override script at document start to keep dashboard theme API state aligned.
- **FR-SEC**: System MUST use endpoint security checks to avoid embedding remote plaintext control surfaces.
- **FR-INT**: System MUST preserve dashboard page navigation and native app connected-host labeling.

### Key Entities *(include if feature involves data)*
- **HermesDashboardView**: Native SwiftUI wrapper with header, reload button, connected host label, and WebKit content/empty state.
- **HermesConfigurationWebURL**: URL normalization, page path, scheme/security, and theme query helper.
- **HermesDashboardWebViewStore**: Long-lived `WKWebView` owner, theme script injector, and load/reload tracking.
- **HermesDashboardWebView**: `NSViewRepresentable` bridge that mounts and updates the stored web view.

## Success Criteria *(mandatory)*
- **SC-001**: A valid local/HTTPS dashboard URL loads in WebKit.
- **SC-002**: Invalid/unsafe dashboard URLs show the empty state and do not load.
- **SC-003**: Color scheme changes produce the expected dashboard theme query.
- **SC-004**: Reload refreshes the current page without replacing the store.
- **SC-BUILD**: The `HermesMacOS` scheme builds successfully with Xcode or command-line `xcodebuild`.
- **SC-SMOKE**: The primary dashboard embed flow can be validated independently with documented UI smoke checks.

## Assumptions
- This pass documents the existing Dashboard WebKit implementation and does not add new dashboard routes.
- Live verification requires a reachable Hermes Dashboard.
- No automated test target exists yet.

## Clarifications
### Session 2026-06-27
- No critical product questions were generated; existing source defines the dashboard embedding behavior boundaries.
