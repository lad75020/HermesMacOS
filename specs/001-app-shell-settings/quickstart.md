# Quickstart: App Shell and Settings

## Build verification

```bash
xcodebuild   -project HermesMacOS.xcodeproj   -scheme HermesMacOS   -destination 'generic/platform=macOS'   -derivedDataPath /tmp/HermesMacOSDerivedData   build
```

## Manual smoke check

1. Launch HermesMacOS from Xcode or Finder.
2. Confirm startup unlock/splash resolves to the main native shell.
3. Select every side-tab item: Ask Hermes, Chat with Hermes, History, Sessions, Approvals Inbox, Kanban, Hermes Dashboard, Configuration, and Utilities.
4. Open Settings.
5. Change a non-sensitive preference such as theme, title font, label font, prompt font size, or chat bubble font size.
6. Change API/Dashboard endpoint text to a safe local test value, then restore the desired endpoint.
7. Close and reopen Settings; confirm non-sensitive settings persisted.
8. If testing credentials, import/remove a test SSH key or API key and confirm no plaintext key material is committed or displayed outside intended secure UI.
9. Relaunch the app and confirm the shell still opens with the saved preferences.

## Expected result

- The app builds successfully.
- The shell remains responsive while switching tabs.
- Settings changes persist and do not expose secrets in plaintext source, logs, or committed files.
