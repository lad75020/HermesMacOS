# Data Model: Dashboard Configuration Management

## HermesConfigurationView
- **Attributes**: AppStorage expansion flags, dashboard stores, local stores, search/draft fields, API settings, dashboard URL.
- **Relationships**: owns all configuration sections and refresh orchestration.
- **Validation**: destructive profile delete uses confirmation dialog.

## Dashboard resource stores
- **Entities**: Skills, Plugins, Toolsets, MCP Servers, Schedules.
- **Attributes**: resource arrays, loading/status/error state, query/filter or mutation state where implemented.
- **Relationships**: used by corresponding `HermesConfiguration*Section` views.

## Local runtime stores
- **Entities**: Local profiles, runtime models, raw/local runtime status.
- **Attributes**: local Hermes home/runtime paths, profile/model records, command output/status.
- **Relationships**: used by profile/runtime model/local system sections.

## Section view models
- **Attributes**: search text, create/edit drafts, validation messages, disclosure state.
- **Relationships**: bind top-level view state into focused section components.
