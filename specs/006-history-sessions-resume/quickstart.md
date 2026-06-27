# Quickstart: History and Session Resume

## Build verification

```bash
xcodebuild   -project HermesMacOS.xcodeproj   -scheme HermesMacOS   -destination 'generic/platform=macOS'   -derivedDataPath /tmp/HermesMacOSDerivedData   build
```

## Live dashboard smoke check

1. Configure a Dashboard URL with existing session history.
2. Open History.
3. Enter a query and run Search.
4. Confirm status changes through token fetch/search and ends with result counts or a clear no-results message.
5. Change the profile filter and confirm visible results narrow to that profile.
6. Expand a result and confirm readable initial/final messages are shown.
7. Resume the result into Ask Hermes, Chat with Hermes, and TUI Gateway when each target is idle.
8. Open Sessions.
9. Page through non-cron sessions and switch chronological/reverse chronological display order.
10. Expand or load a session’s details and confirm messages appear.
11. Resume a stored session to Ask Hermes or TUI Gateway.
12. Start a search/load and press Cancel; verify loading flags clear and status is Cancelled.

## Expected result

- The app builds successfully.
- History search, profile filtering, result inspection, Sessions pagination/details, cancellation, and resume actions work against a reachable dashboard with history data.
