# Contract: Kanban API

## Board data
- Dashboard returns boards, columns, tasks, profiles, comments, logs, actions, and run metadata consumed by `HermesKanbanView`.
- Tasks decode with optional fields and safe defaults.

## Workflow statuses
- Visible order: triage, todo, scheduled, ready, running, blocked, review, done.
- Movable statuses exclude running.

## Mutations and actions
- Task create/update/move/comment/action/dispatch operations use existing store/view helpers and refresh affected board state after success.
- Errors remain visible and should not discard previous board state.
