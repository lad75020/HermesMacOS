# Research: Chat Completions Console

## Decision 1: Keep Chat on `/v1/chat/completions`
**Decision**: Preserve a dedicated chat client rather than reusing the Responses or TUI Gateway path.  
**Rationale**: Chat has system prompt, chat message history, and content payload encoding semantics distinct from Responses and WebSocket TUI.

## Decision 2: Preserve encrypted draft/session retention
**Decision**: Keep chat drafts and session metadata in redacted/encrypted storage.  
**Rationale**: Prompts may contain secrets and should not remain in plaintext UserDefaults.

## Decision 3: Verify with build plus live-service smoke checks
**Decision**: Use Xcode build and documented manual checks.  
**Rationale**: No automated test target exists and backend behavior depends on a reachable Hermes gateway.
