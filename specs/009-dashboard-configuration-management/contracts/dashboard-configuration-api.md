# Contract: Dashboard Configuration API

## Resource categories
- Skills: list/toggle/install/manage through `HermesDashboardSkillsStore`.
- Plugins: hub/status/actions through `HermesDashboardPluginsStore`.
- Toolsets: list/toggle/configure through `HermesDashboardToolsetsStore`.
- MCP Servers: list/create/update/delete/test through `HermesDashboardMCPServersStore` where implemented.
- Schedules: list/create/trigger/update/delete through `HermesDashboardSchedulesStore`.
- Profiles/runtime models: dashboard raw config and local runtime stores as implemented.

## Shared behavior
- Stores resolve dashboard base URL and session/auth context through shared helpers.
- Each store owns section-specific status and errors.
- Mutation actions refresh or update local store state after success.
- Invalid drafts must produce validation messages before network mutation.

## Security
- Secret-bearing dashboard/local config operations use existing endpoint/session/keychain/local runtime guardrails.
