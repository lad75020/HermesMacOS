# Research: TUI Gateway Workspaces

## Decision 1: Use Dashboard WebSocket JSON-RPC
**Decision**: Preserve `api/ws` JSON-RPC rather than HTTP Responses/Chat APIs.  
**Rationale**: TUI Gateway mirrors the terminal TUI live protocol, including request bubbles and session lifecycle methods.

## Decision 2: Prefer one-time tickets over session-token fallback
**Decision**: Request `api/auth/ws-ticket` when possible and fall back to dashboard token query auth.  
**Rationale**: Tickets reduce exposure of longer-lived dashboard session tokens while preserving compatibility.

## Decision 3: Keep workspace state isolated
**Decision**: Each workspace owns one store and UI composer/request state.  
**Rationale**: Long-running live sessions need independent WebSockets, transcripts, attachments, and attention states.

## Decision 4: Verify with build plus live dashboard smoke checks
**Decision**: Use Xcode build and documented manual checks.  
**Rationale**: Behavior depends on a reachable dashboard WebSocket and no test target exists.
