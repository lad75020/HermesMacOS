# Contract: Utilities and Maintenance

## Utility panels
- Clipboard monitoring is disabled by default and can be refreshed or cleared only by user action.
- Messages history displays retained prompts/responses when persistence is enabled.
- Debugging panel exposes raw Responses/Chat stream inspection through existing UI.

## Knowledge eraser
- Scan requires a non-empty topic and filesystem access to Hermes workspace.
- Erase requires selected candidates and archives erased items before removal.
- Remaining/skipped items are reported after erase.

## Speech-to-text
- Apple local engine uses microphone permission, supported locale, SpeechTranscriber, and SpeechAnalyzer.
- Whisper engine records local audio and sends it to the configured WebSocket only after stop with transcription enabled.
- Stop/cancel/error paths release audio taps, cancel tasks, and update status/error text.

## Reachability and maintenance
- API probe URLs include localhost/127.0.0.1 gateway and `/v1/models`/`/v1/profiles` variants.
- Dashboard probe URLs include localhost and 127.0.0.1 dashboard roots.
- Probes attach bearer authorization only from Keychain and never render token values.
- Installation update flow refreshes git status, previews merge/update, blocks dirty updates, and produces a review prompt.
