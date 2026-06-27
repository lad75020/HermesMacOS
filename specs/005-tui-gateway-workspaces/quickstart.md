# Quickstart: TUI Gateway Workspaces

## Build verification
```bash
xcodebuild -project HermesMacOS.xcodeproj -scheme HermesMacOS -destination 'generic/platform=macOS' -derivedDataPath /tmp/HermesMacOSDerivedData build
```

## Live dashboard smoke check
1. Configure a Dashboard URL exposing `api/ws` and session token HTML.
2. Open TUI Gateway and press Connect.
3. Confirm status reaches `Session ready` and events increment.
4. Send a prompt and verify message start/delta/complete bubbles.
5. Attach an image and confirm an `input.attachment` bubble plus successful prompt submit.
6. Create a second workspace, switch back, and verify each workspace kept its transcript/draft.
7. Trigger an approval or clarify request and respond from the transcript bubble.
8. Resume a stored History/Sessions row into TUI Gateway.

## Expected result
- Build succeeds.
- TUI Gateway connects, streams, handles attachments/requests, and isolates workspaces against a reachable dashboard.
