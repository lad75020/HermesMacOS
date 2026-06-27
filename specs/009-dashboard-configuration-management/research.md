# Research: Dashboard Configuration Management

## Decision 1: Keep configuration split into stores and section views
**Decision**: Preserve one top-level orchestration view with focused stores/sections per resource type.  
**Rationale**: This keeps failures and state scoped and avoids coupling unrelated dashboard APIs.

## Decision 2: Refresh local and dashboard sources together
**Decision**: The top-level refresh action updates dashboard resources, local runtime models, local profiles, and runtime status.  
**Rationale**: Configuration is a single operational view even though data comes from several backends.

## Decision 3: Verify with build plus live smoke checks
**Decision**: Use Xcode build and dashboard/local-runtime UI checks.  
**Rationale**: Behavior depends on live dashboard data and no automated test target exists.
