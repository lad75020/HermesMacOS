# Quickstart: Dashboard Configuration Management

## Build verification
```bash
xcodebuild -project HermesMacOS.xcodeproj -scheme HermesMacOS -destination 'generic/platform=macOS' -derivedDataPath /tmp/HermesMacOSDerivedData build
```

## Dashboard/local smoke check
1. Configure Dashboard URL and local Hermes runtime.
2. Open Configuration and verify all expandable sections render.
3. Press Refresh and confirm Skills, Plugins, Toolsets, MCP Servers, Schedules, Profiles, Runtime Models, and local runtime status update or show scoped errors.
4. Use filters in skills/plugins/toolsets/MCP/schedules.
5. Trigger a safe schedule or toggle a harmless skill/toolset if available.
6. Validate profile delete shows confirmation before destructive action.

## Expected result
- Build succeeds.
- Configuration sections refresh independently and supported actions report clear status/errors.
