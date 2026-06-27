# Quickstart: Chat Completions Console

## Build verification
```bash
xcodebuild -project HermesMacOS.xcodeproj -scheme HermesMacOS -destination 'generic/platform=macOS' -derivedDataPath /tmp/HermesMacOSDerivedData build
```

## Live-service smoke check
1. Configure a reachable Hermes API gateway.
2. Open Chat with Hermes and confirm profiles load or default remains usable.
3. Enter an optional system prompt and send a streaming message.
4. Send a non-streaming message and verify final assistant output and token usage when available.
5. Start a long response, press Cancel, and verify streaming stops.
6. Attach a small image and a UTF-8 text file in separate prompts.
7. Resume a compatible session from History when available.

## Expected result
- Build succeeds.
- Chat can send, stream, cancel, attach files, and resume against a reachable Hermes gateway.
