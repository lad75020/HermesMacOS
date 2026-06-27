# Research: Utilities and Maintenance

## Decision 1: Keep maintenance utilities explicit and opt-in
**Decision**: Clipboard monitoring, knowledge erasure, repository updates, and STT recording remain user-initiated.  
**Rationale**: These features touch retained data, local knowledge, local repositories, microphone capture, or agent behavior.

## Decision 2: Preserve section-scoped stores and status output
**Decision**: Each utility keeps its own status/error/output state.  
**Rationale**: Utility actions are heterogeneous and should fail independently without obscuring other panels.

## Decision 3: Verify with build plus local smoke checks
**Decision**: Use Xcode build and documented smoke checks rather than synthetic mutations.  
**Rationale**: STT, repository update, knowledge erasure, and endpoint reachability depend on local permissions and service state.
