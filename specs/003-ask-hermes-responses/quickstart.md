# Quickstart: Ask Hermes Responses

## Build verification

```bash
xcodebuild   -project HermesMacOS.xcodeproj   -scheme HermesMacOS   -destination 'generic/platform=macOS'   -derivedDataPath /tmp/HermesMacOSDerivedData   build
```

## Live-service smoke check

1. Configure API base URL to a reachable Hermes gateway exposing `/v1/responses` and `/v1/profiles`.
2. Open Ask Hermes.
3. Confirm profiles load or the default profile remains usable with an error message.
4. Send a streaming prompt and verify assistant text, event count, elapsed time, and final status update.
5. Send a non-streaming prompt and verify a final assistant message is appended.
6. Start a long prompt, press Cancel, and verify the UI exits streaming state and a cancel request is attempted.
7. Send a follow-up prompt and verify continuation remains in the same workspace.
8. Attach a small image and a UTF-8 text file in separate prompts and verify request preparation succeeds.
9. Create a second Ask workspace, send a different prompt, switch back, and verify each workspace retained its own draft/output.

## Expected result

- The app builds successfully.
- Ask Hermes can send, stream, cancel, continue, and isolate workspace sessions against a reachable Hermes API gateway.
- Attachments and security failures produce clear errors without corrupting the transcript.
