# How to manage Hermes runtime from the app

This guide uses HermesMacOS as a desktop control surface for local Hermes Agent runtime configuration and dashboard-backed management.

## Prerequisites
- Hermes Dashboard URL is configured and reachable.
- Hermes Dashboard page exposes `window.__HERMES_SESSION_TOKEN__`.
- Local Hermes paths are accessible to the app for profile/model/MCP changes.
- For repository updates, the target Hermes Agent repository path and optional SSH credentials are configured.

## Manage profiles
1. Open Configuration.
2. Expand Profiles.
3. Review local profile names, paths, provider/model values, config/env/soul status, skill count, and gateway running state.
4. Create, edit, use, or delete profiles from the profile controls.

Profile operations read and write profile files such as `config.yaml`, `.env`, `SOUL.md`, and the root `active_profile` marker.

## Manage runtime models
1. Open Configuration.
2. Expand Runtime Models.
3. Update the main model provider/model or auxiliary model slots.
4. Save changes.

The store reads and writes YAML values in the Hermes home `config.yaml`.

## Manage skills
1. Open Configuration.
2. Expand Skills.
3. Refresh the dashboard skill list.
4. Toggle skills from the dashboard list.
5. Install a skill from an HTTP/HTTPS URL or a picked local file when needed.

Dashboard listing uses `api/skills`; toggles use `api/skills/toggle`. Local installation uses Hermes CLI helpers.

## Manage MCP servers
1. Open Configuration.
2. Expand MCP Servers.
3. Add a command-based or URL-based MCP server.
4. Test one server or all servers.
5. Enable/disable servers or per-tool rules.
6. Inspect recent MCP-related logs when probes fail.

The app updates local YAML and can run a Python MCP probe through the local Hermes environment.

## Manage schedules
1. Open Configuration.
2. Expand Schedules.
3. Create a schedule manually or use an automation template.
4. Pause, resume, trigger, or inspect latest output.

The app uses dashboard cron job endpoints under `api/cron/jobs`.

## Manage plugins and toolsets
- Plugins load from `api/dashboard/plugins/hub` and can be toggled when supported.
- Toolsets load from `api/tools/toolsets`; the app also contains YAML merge helpers for CLI toolset configuration.

## Use Approvals Inbox
Open Approvals Inbox to approve or deny queued local or certificate trust decisions. The store auto-refreshes and shows pending count through tab attention.

## Update Hermes Agent repository
1. Open Utilities.
2. Expand Installation.
3. Refresh repository status.
4. Preview merge/update from upstream.
5. Run update only after reviewing dirty files, branch lag, and conflicts.

For remote hosts, the app wraps git commands through SSH using saved credentials.

## Verification
- Configuration refresh should show profiles, model config path, dashboard skills, schedules, plugins, and toolsets without errors.
- Saving a model or profile change should be visible after refresh.
- MCP probe output should return structured probe results or a readable error.
- Repository update should show command output and final status.

## Troubleshooting
- Dashboard token missing: verify the dashboard HTML contains `window.__HERMES_SESSION_TOKEN__`.
- Local file denied: approve the queued local approval or add the expected folder to allowed folders in Settings.
- MCP probe cannot find command: check PATH normalization and the Hermes home `node/bin`, Homebrew, local bin, and fallback system paths.
- Repository update blocked by dirty state: review status first. Do not update over uncommitted local changes you want to keep.
