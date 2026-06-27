# Quickstart: Utilities and Maintenance

## Build verification
```bash
xcodebuild -project HermesMacOS.xcodeproj -scheme HermesMacOS -destination 'generic/platform=macOS' -derivedDataPath /tmp/HermesMacOSDerivedData build
```

## Utilities smoke check
1. Open Utilities.
2. Expand Clipboard History and verify monitoring is off by default; use Refresh only if intentionally checking the pasteboard.
3. Expand Messages History and confirm prompt/response tabs render retained entries or an empty state.
4. Expand Debugging and verify raw Responses/Chat stream controls render.
5. Expand Knowledge Eraser, enter a harmless topic, scan, and review candidates without erasing unless intentional.
6. Expand Hermes Installation, refresh repository status, and verify branch/lag/dirty output is visible.
7. Toggle dictation with a selected STT engine only if microphone permission/network behavior is safe to test.
8. Confirm API/dashboard reachability LEDs reflect the configured local endpoints.

## Expected result
- Build succeeds.
- Utility actions remain explicit, scoped status/errors are visible, and destructive/retentive actions require user intent.
