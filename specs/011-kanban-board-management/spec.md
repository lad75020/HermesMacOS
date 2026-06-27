# Feature Specification: Kanban Board Management

**Feature Branch**: `feature/time-machine-kanban-board-management`  
**Created**: 2026-06-27  
**Status**: Draft  
**Input**: User description: "Feature: Kanban Board Management. Description: Lets users manage Hermes Kanban boards, columns, tasks, comments, task actions, dispatch runs, profiles, and live updates. Relevant files: HermesMacOS/HermesKanbanView.swift, docs/reference-app-surface.md. Focus on this feature only; do not modify other features."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - View boards, columns, and tasks (Priority: P1)
A user opens Kanban and sees boards, visible workflow columns, tasks, metadata, profiles, and live status.

**Acceptance Scenarios**:
1. **Given** dashboard Kanban APIs are reachable, **When** the view refreshes, **Then** boards, columns, and tasks decode into native models.
2. **Given** tasks have metadata, **When** rendered, **Then** priority, assignee, status, timestamps, latest summary, failures, skills, and current run data are shown where available.
3. **Given** no data or an API error, **When** loading completes, **Then** the UI shows empty/error states without crashing.

---

### User Story 2 - Manage tasks, comments, and actions (Priority: P2)
A user creates or updates tasks, moves statuses, reviews comments/logs, and invokes task actions.

**Acceptance Scenarios**:
1. **Given** task fields are valid, **When** the user creates or edits a task, **Then** the request is sent and board data refreshes.
2. **Given** a movable task, **When** status changes, **Then** the task appears in the target column.
3. **Given** comments/logs/actions are available, **When** the user opens task details, **Then** the task detail panel exposes them with clear feedback.

---

### User Story 3 - Dispatch work with profiles and live updates (Priority: P3)
A user dispatches tasks using available profiles and monitors running/review/blocked/done transitions.

**Acceptance Scenarios**:
1. **Given** profiles are loaded, **When** dispatch controls render, **Then** profile choices display default/model/provider metadata.
2. **Given** dispatch starts, **When** runs update, **Then** live status and current run metadata refresh.
3. **Given** a task fails, **When** consecutive failure/error fields update, **Then** the task shows blocked/review status and failure context.

### Edge Cases
- Unknown task statuses should fall back to Todo while preserving raw status data.
- Running tasks should not be manually moved if only movable statuses are allowed.
- Missing board/task fields should fall back to IDs or safe defaults.
- Live update failure should not lose existing board state.

## Requirements *(mandatory)*
- **FR-001**: System MUST provide native Kanban board, column, and task models backed by dashboard Kanban APIs.
- **FR-002**: System MUST support visible workflow columns triage, todo, scheduled, ready, running, blocked, review, and done.
- **FR-003**: System MUST display task metadata including assignee, priority, workspace, tenant, summaries, comments, run IDs, failures, timestamps, and skills where present.
- **FR-004**: System MUST support board/task refresh and management actions exposed by the existing Kanban store/view.
- **FR-005**: System MUST support task comments, logs, actions, dispatch, and profile selection where implemented.
- **FR-006**: System MUST handle unknown/missing API fields with safe defaults.
- **FR-INT**: System MUST preserve dashboard Kanban API contracts and live update behavior.

### Key Entities
- **HermesKanbanColumnStatus**: Workflow status enum, titles, icons, tints, visible/movable status sets.
- **HermesKanbanTask**: Task row model with metadata, status, preview, and timestamps.
- **HermesKanbanColumn / HermesKanbanBoardInfo / HermesKanbanProfile**: Board structure and dispatch profile metadata.
- **HermesKanbanView**: Native board/task/comment/action/dispatch UI.

## Success Criteria *(mandatory)*
- **SC-001**: Board refresh loads visible columns and tasks.
- **SC-002**: Task create/edit/move/comment/action operations report clear status and refresh data.
- **SC-003**: Dispatch/profile controls show current run state and failure metadata.
- **SC-BUILD**: The `HermesMacOS` scheme builds successfully.
- **SC-SMOKE**: Primary Kanban flows can be validated independently with dashboard smoke checks.

## Assumptions
- This pass documents the existing Kanban implementation and does not add new dashboard APIs.
- Live verification requires a dashboard with Kanban endpoints and task data.
- No automated test target exists yet.
