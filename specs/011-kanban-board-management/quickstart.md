# Quickstart: Kanban Board Management

## Build verification
```bash
xcodebuild -project HermesMacOS.xcodeproj -scheme HermesMacOS -destination 'generic/platform=macOS' -derivedDataPath /tmp/HermesMacOSDerivedData build
```

## Dashboard Kanban smoke check
1. Configure a dashboard with Kanban enabled.
2. Open Kanban and refresh boards.
3. Verify columns and task cards render with metadata.
4. Create or edit a disposable task if safe.
5. Move the task between movable statuses.
6. Add a comment or inspect logs/actions if available.
7. Dispatch a safe task/profile only if intentionally testing execution.

## Expected result
- Build succeeds.
- Board refresh and safe task operations report clear status and preserve board state.
