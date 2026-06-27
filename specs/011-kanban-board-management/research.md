# Research: Kanban Board Management

## Decision 1: Preserve native board models around dashboard APIs
**Decision**: Keep decoded task/column/profile structs and native SwiftUI board UI.  
**Rationale**: Native interactions provide fast board management while the dashboard remains the source of truth.

## Decision 2: Use safe defaults for partial API rows
**Decision**: Unknown statuses map to Todo and missing fields use IDs or placeholder labels.  
**Rationale**: Kanban data evolves and the app should remain resilient.

## Decision 3: Verify with build plus dashboard smoke checks
**Decision**: Use Xcode build and live board/task checks.  
**Rationale**: Behavior depends on dashboard Kanban state and no test target exists.
