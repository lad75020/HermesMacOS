# Data Model: App Shell and Settings

## HermesMacOSTab

Represents a top-level destination in the side-tab shell.

- **Attributes**: stable identifier, localized title, icon/system image, selection state, optional attention state.
- **Relationships**: selects one composed feature view inside `ContentView`; receives attention from Ask/Chat/TUI or background feature state.
- **Validation**: tab identifiers must remain stable enough for persisted UI state and history resume targets.

## HermesAPISettings

Represents API and dashboard endpoint configuration passed from shell/settings into feature views.

- **Attributes**: API base URL, dashboard URL, optional API key reference/value path, self-signed certificate allowance, saved endpoint metadata.
- **Relationships**: used by Ask, Chat, TUI Gateway, Dashboard-backed stores, History/Sessions, Approvals, Configuration, and Utilities.
- **Validation**: sensitive requests must pass endpoint security validation; remote plaintext HTTP is blocked except loopback.

## HermesSavedEndpoint

Represents a reusable API/dashboard endpoint pair.

- **Attributes**: display name or host identity, API URL, dashboard URL, creation/update metadata where available.
- **Relationships**: selected from Settings and applied to per-window endpoint state.
- **Validation**: URLs should normalize to supported schemes and avoid unsafe remote plaintext sensitive use.

## HermesAppTheme

Represents user appearance preference.

- **Attributes**: system, light, or dark.
- **Relationships**: maps to the app/window SwiftUI color scheme.
- **Validation**: unknown stored values fall back to system behavior.

## HermesAppLanguageSelection

Represents user language preference.

- **Attributes**: system/default plus supported localizations.
- **Relationships**: affects user-facing shell/settings strings through localization resources.
- **Validation**: unsupported stored values fall back to system/default language.

## HermesSSHHostCredentials

Represents sensitive SSH credentials for repository maintenance workflows surfaced from Settings.

- **Attributes**: host, username, Keychain-backed private key reference.
- **Relationships**: consumed by `HermesInstallationSession` and process helpers when running SSH-backed git operations.
- **Validation**: private keys must be stored in Keychain and materialized only as temporary `0600` files that are cleaned up.
