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

## Native translation smoke check (macOS 26)
1. Open a completed Chat with Hermes bubble containing non-English text. Do not use a bubble that is still streaming.
2. Select a non-empty phrase within that one bubble, right-click the selection, and choose **Translate to English**.
3. Confirm the selected phrase is replaced in the same bubble, while text before and after it, bubble order, and the message identity remain unchanged.
4. Repeat with an empty selection, a selection attempted across bubbles, and a still-streaming response; the translation action must not alter message text.
5. With a language pair unavailable or a deliberately unidentifiable selection, confirm a recoverable translation error appears and the original bubble text is preserved.
6. Confirm the Hermes gateway receives no additional Chat Completions request while translating.

## Expected result
- Build succeeds.
- Chat can send, stream, cancel, attach files, and resume against a reachable Hermes gateway.
- Translation uses the local macOS Translation framework and never sends selected bubble text through the Hermes API.
