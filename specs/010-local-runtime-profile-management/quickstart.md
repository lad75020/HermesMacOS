# Quickstart: Local Runtime and Profile Management

## Build verification
```bash
xcodebuild -project HermesMacOS.xcodeproj -scheme HermesMacOS -destination 'generic/platform=macOS' -derivedDataPath /tmp/HermesMacOSDerivedData build
```

## Local smoke check
1. Open Configuration > Profiles and refresh.
2. Create a disposable profile, verify it appears, set it active, then restore default and delete it.
3. Open Runtime Models, inspect current provider/model slots, and save a harmless value only if intentional.
4. Open MCP Servers and validate add/edit form errors for malformed input.
5. Run a safe local Hermes command from a configuration section and verify output appears.

## Expected result
- Build succeeds.
- Local profile/runtime operations are guarded, visible, and reversible.
