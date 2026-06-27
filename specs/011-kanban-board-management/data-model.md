# Data Model: Kanban Board Management

## HermesKanbanColumnStatus
- **Attributes**: raw status, title, icon, tint, visible order, movable status set.

## HermesKanbanTask
- **Attributes**: id, title, body, assignee, status, priority, timestamps, workspace, tenant, result, latest summary, comments, current run, failures, skills.
- **Validation**: missing/unknown status falls back to todo; display labels use safe defaults.

## HermesKanbanColumn
- **Attributes**: name, tasks.
- **Relationships**: groups tasks by workflow status.

## HermesKanbanBoardInfo
- **Attributes**: slug, name, description, icon, current flag, total.

## HermesKanbanProfile
- **Attributes**: name, default flag, model, provider, description, skill count.

## HermesKanbanView
- **Relationships**: orchestrates board refresh, task operations, comments/logs/actions, dispatch, and profile selection.
