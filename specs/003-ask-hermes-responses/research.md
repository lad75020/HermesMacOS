# Research: Ask Hermes Responses

## Decision 1: Keep Ask on `/v1/responses`

**Decision**: Preserve the dedicated Responses API client instead of routing Ask through Chat or TUI Gateway.

**Rationale**: Ask supports stored response continuation, reasoning controls, SSE Responses events, and workspace behavior that differ from `/v1/chat/completions` and TUI WebSocket sessions.

**Alternatives considered**:
- Use Chat Completions for Ask: rejected because it would lose Responses-specific continuation and event handling.
- Use TUI Gateway for Ask: rejected because TUI Gateway is a separate live JSON-RPC protocol.

## Decision 2: Keep tool/event stream output separate from assistant text

**Decision**: Render optional stream-output bubbles separately from assistant response bubbles.

**Rationale**: Users need concise tool/event status without polluting answer text or making debug logs look like assistant content.

**Alternatives considered**:
- Append all event text to assistant messages: rejected because it violates transcript clarity and the desired concise status behavior.

## Decision 3: Preserve workspace isolation in the shell

**Decision**: Each Ask workspace owns independent draft/session/attachment/attention state.

**Rationale**: Long-running or parallel prompts need independent lifecycle and completion/failure indicators.

**Alternatives considered**:
- Single global Ask session: rejected because it prevents parallel workstreams.

## Decision 4: Verify with build plus live-service smoke checks

**Decision**: Use Xcode build and documented manual/live Hermes gateway checks.

**Rationale**: No test target exists, and full behavior depends on a live or mock Hermes API gateway.
