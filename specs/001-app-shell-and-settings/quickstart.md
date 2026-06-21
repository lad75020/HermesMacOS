# Quickstart: App Shell and Settings

## Prerequisites

- macOS 26.0 or newer.
- Xcode installed with macOS SwiftUI support.
- The `HermesMacOS.xcodeproj` project present in the repository root.
- Optional: local Hermes API and Dashboard services for live reachability checks.

## Build validation

From the repository root:

```bash
xcodebuild \
  -project HermesMacOS.xcodeproj \
  -scheme HermesMacOS \
  -destination 'generic/platform=macOS' \
  build
```

If DerivedData is locked by another build, use an isolated DerivedData path:

```bash
xcodebuild \
  -project HermesMacOS.xcodeproj \
  -scheme HermesMacOS \
  -destination 'generic/platform=macOS' \
  -derivedDataPath /tmp/HermesMacOSDerivedData \
  build
```

## Manual smoke scenarios

### 1. Launch and restore shell state

1. Launch HermesMacOS.
2. Verify the main shell appears with a valid selected tab.
3. Select a different top-level tab and close/reopen the app.
4. Verify the last valid selected tab is restored or safely defaulted.

Expected result: The app reaches a usable shell in under 5 seconds and never opens to a missing tab or workspace.

### 2. Switch tabs without losing context

1. Create or edit draft state in a shell workflow that supports user input.
2. Switch to at least three other top-level tabs.
3. Return to the original tab.

Expected result: The original workflow state is still available unless explicitly reset by the user.

### 3. Verify multi-workspace shell behavior

1. In a multi-workspace workflow, create a new workspace.
2. Select between workspaces.
3. Delete a non-selected workspace and then the selected workspace if the UI permits it.

Expected result: The shell always leaves a valid selected workspace or creates/falls back to a usable default.

### 4. Apply Settings endpoint changes

1. Open Settings.
2. Change the Hermes API and dashboard endpoints for the selected window.
3. Apply the settings and return to the shell.
4. If using multiple windows, verify only the selected window changed target.

Expected result: The shell and reachability checks use the selected window's endpoints without silently retargeting other windows.

### 5. Save and restore endpoint pairs

1. Save a complete API/dashboard endpoint pair.
2. Change endpoints to different values.
3. Re-select the saved endpoint pair.

Expected result: Both API and dashboard endpoint values are restored together.

### 6. Reachability indicators

1. Configure reachable local Hermes API and dashboard endpoints.
2. Verify both indicators become reachable.
3. Change one endpoint to a deliberately unreachable host or stop the related service.
4. Wait up to 15 seconds.

Expected result: The relevant indicator changes to unavailable while tab navigation remains usable.

### 7. Appearance and accessibility basics

1. Change theme, language, and font settings.
2. Navigate through the shell using pointer and keyboard focus movement.
3. Inspect labels in the main navigation and Settings.

Expected result: Controls remain readable, reachable, and understandable across supported preferences.
