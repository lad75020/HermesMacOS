# Quickstart: Approvals Inbox

## Build verification

```bash
xcodebuild   -project HermesMacOS.xcodeproj   -scheme HermesMacOS   -destination 'generic/platform=macOS'   -derivedDataPath /tmp/HermesMacOSDerivedData   build
```

## Live/local approval smoke check

1. Configure an API gateway exposing `/v1/approvals` and `/v1/approvals/resolve`.
2. Open Approvals Inbox.
3. Confirm refresh status, pending count, and last-updated time.
4. If no remote approvals exist, create or trigger a local filesystem/TLS approval and verify it appears.
5. Resolve one approval as approve and one as deny when available.
6. Verify each resolve action shows resolving state and refreshes the list afterward.
7. Toggle auto-refresh off, wait more than five seconds, and confirm no automatic refresh starts.
8. Toggle auto-refresh on and verify periodic refresh resumes.
9. Configure unsafe remote plaintext HTTP with an API key and verify sensitive URL validation blocks credentialed approval requests.

## Expected result

- Build succeeds.
- Remote and local approvals display, resolve, refresh, and fail safely with clear status/error messages.
