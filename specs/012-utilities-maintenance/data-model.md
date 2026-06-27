# Data Model: Utilities and Maintenance

## HermesUtilitiesView
- **Attributes**: disclosure flags, retention flags, selected history mode, status messages, connected host/window, injected stores.
- **Relationships**: hosts clipboard, message history, debugging, knowledge eraser, and installation sections.

## HermesInstallationStatus
- **Attributes**: repository path/root, branch, revision, remote URL, ahead/behind counts, dirty state, dirty summary, conflict files, merge preview, operation output.
- **Validation**: update allowed only when not busy and working tree is clean.

## HermesKnowledgeEraserItem / ScanResult / EraseResult
- **Attributes**: candidate kind/title/path/location/preview/content/confidence, selected IDs, archive path, skipped IDs.
- **Validation**: non-empty topic and selected candidates required before erase; filesystem access required.

## HermesSpeechToTextSession
- **Attributes**: selected engine, recording/processing state, status/error messages, audio engine/tasks, transcript buffers, request ID, temporary recording URL.
- **Validation**: microphone permission, locale/audio format availability, WebSocket/network success, cleanup on stop/cancel/error.

## HermesReachabilityMonitor
- **Attributes**: API/dashboard reachable booleans and endpoint URL sets.
- **Validation**: HTTP 2xx-4xx counts as reachable; probes timeout quickly and use secure API key retrieval.
