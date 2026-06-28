# Quickstart: Memory Tab and Tab Settings

## Prerequisites

- macOS 26.0 or newer.
- Xcode 26.6 or compatible Xcode 26 toolchain.
- Apple Swift 6 language mode; local toolchain observed during planning: Apple Swift 6.3.3.
- HermesMacOS repository at `/Volumes/WDBlack4TB/Code/HermesMacOS`.
- Optional live-smoke Hindsight provider configured in a disposable Hermes profile.

## One-line command equivalents

```bash
cd /Volumes/WDBlack4TB/Code/HermesMacOS && xcodegen generate
cd /Volumes/WDBlack4TB/Code/HermesMacOS && xcodebuild -project HermesMacOS.xcodeproj -scheme HermesMacOS -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/HermesMacOSBuildDerivedData build
cd /Volumes/WDBlack4TB/Code/HermesMacOS && xcodebuild -project HermesMacOS.xcodeproj -scheme HermesMacOSTest -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/HermesMacOSTestDerivedData test
```

## Default verification flow

1. Regenerate the project if `project.yml` or new Swift source membership changes:

   ```bash
   xcodegen generate
   ```

2. Build the app:

   ```bash
   xcodebuild \
     -project HermesMacOS.xcodeproj \
     -scheme HermesMacOS \
     -destination 'platform=macOS,arch=arm64' \
     -derivedDataPath /tmp/HermesMacOSBuildDerivedData \
     build
   ```

3. Run deterministic tests:

   ```bash
   xcodebuild \
     -project HermesMacOS.xcodeproj \
     -scheme HermesMacOSTest \
     -destination 'platform=macOS,arch=arm64' \
     -derivedDataPath /tmp/HermesMacOSTestDerivedData \
     test
   ```

4. Confirm the new tests cover:
   - Ask Hermes and Chat with Hermes visibility defaults.
   - Hiding/restoring each prompt tab from Settings.
   - Selection fallback when a selected prompt tab is hidden.
   - Memory list pagination and filtering.
   - Memory delete success and failure fixture paths.
   - Sanitized provider errors.

## Manual app smoke

1. Launch HermesMacOS.
2. Open Settings.
3. Disable `Ask Hermes tab`; verify the Ask Hermes side-tab entry disappears and the app remains on an enabled tab.
4. Re-enable `Ask Hermes tab`; verify it returns without restart.
5. Repeat for `Chat with Hermes tab`.
6. Disable both prompt tabs; verify non-prompt tabs remain reachable and Settings can restore both.
7. Open the Memory tab.
8. Verify Refresh, Previous, Next, range text, filter text field, and empty/error states render clearly.
9. With fixture or live Hindsight data available, apply a filter and page through results.
10. Delete one memory after confirmation; verify only that row is removed after refresh.

## Optional live Hindsight smoke

Run only with explicit disposable provider data. Do not use real secrets, real sensitive memories, or production banks.

1. Configure Hermes Agent with a disposable Hindsight memory provider and test bank.
2. Seed at least two non-sensitive test memories.
3. Launch HermesMacOS with the matching Hermes home/profile.
4. Open Memory and verify a page of memories appears within 3 seconds.
5. Filter by a known test word and confirm only matching memories remain visible.
6. Delete one disposable memory and confirm it no longer appears after refresh.
7. Verify no raw provider stack traces, tokens, or credentials appear in the UI.

## Implementation evidence (2026-06-28)

- `xcodegen generate` completed successfully and regenerated `HermesMacOS.xcodeproj`.
- `xcodebuild -project HermesMacOS.xcodeproj -scheme HermesMacOS -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/HermesMacOSBuildDerivedData build` completed with `** BUILD SUCCEEDED **`. Xcode emitted pre-existing Swift concurrency warnings in `HermesSpeechToText.swift`; no new Memory-tab errors were reported.
- `xcodebuild -project HermesMacOS.xcodeproj -scheme HermesMacOSTest -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/HermesMacOSTestDerivedData test` completed with `** TEST SUCCEEDED **`: 88 tests, 0 failures.
- Non-destructive manual smoke was performed against `/tmp/HermesMacOSBuildDerivedData/Build/Products/Debug/HermesMacOS.app`: the Memory tab appeared in the side rail, opened successfully, exposed filter/refresh/previous/next/range controls, reached the empty-memory state without leaking raw provider output, and Settings showed the Ask Hermes tab / Chat with Hermes tab visibility toggles. No live disposable Hindsight row was available, so live deletion was covered by deterministic fixture tests only.

## Rollback checks

- Re-enable both prompt tabs from Settings if navigation becomes too sparse.
- If Memory provider access fails, verify the app still loads non-memory tabs and existing Ask/Chat behavior remains unchanged.
- If project generation changes, inspect `project.pbxproj` for intended source/test membership only.
