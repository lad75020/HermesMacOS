# Contract: App Shell and Settings

This feature is an in-process UI/state contract rather than a network API contract.

## App Launch Contract

- `HermesMacOSApp` creates the macOS app scene and Settings scene.
- Startup secret unlock is attempted before exposing protected app state.
- On successful unlock, `ContentView` is rendered as the root control surface.
- On unlock failure, the user sees a bounded failure path without secret exposure.

## Navigation Contract

- `ContentView` owns selected top-level tab state.
- `HermesMacOSTab` exposes Ask Hermes, Chat with Hermes, History, Sessions, Approvals Inbox, Kanban, Hermes Dashboard, Configuration, and Utilities.
- The side-tab switcher must preserve accessibility labels and selected-state feedback.
- Feature views receive current endpoint and window context from the shell.

## Settings Contract

- Settings must expose API base URL, Dashboard URL, API key, self-signed certificate controls, saved endpoint pairs, SSH credentials, allowed folders, theme, language, and font sizing controls.
- Non-sensitive settings persist through app storage/UserDefaults.
- Sensitive settings persist through Keychain-backed helpers.
- Endpoint updates must be usable by existing feature views without changing downstream API/Dashboard/TUI Gateway contracts.

## Resource Contract

- `project.yml` defines bundle identity, deployment target, signing, Info.plist purpose strings, and entitlements.
- `HermesTypography` registers bundled fonts when present and preserves usable fallback behavior.
- `SplashView` uses bundled splash resources without blocking eventual access to the shell.
- `Localizable.xcstrings` and localized InfoPlist strings provide user-facing localizations where available.
