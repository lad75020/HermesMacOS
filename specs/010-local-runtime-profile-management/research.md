# Research: Local Runtime and Profile Management

## Decision 1: Use direct filesystem stores for profile/config files
**Decision**: Preserve direct local read/write helpers rather than routing every operation through dashboard APIs.  
**Rationale**: Profile and runtime YAML files are local Hermes runtime artifacts and need offline/local control.

## Decision 2: Require filesystem approval for Hermes home mutations
**Decision**: Gate mutating local profile/runtime operations through `HermesFilesystemAccessPolicy`.  
**Rationale**: These writes can change agent behavior and should remain explicit.

## Decision 3: Verify with build plus local smoke checks
**Decision**: Use Xcode build and documented local profile/model/MCP checks.  
**Rationale**: Disk state varies per installation and no automated test target exists.
