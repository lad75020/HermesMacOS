# Contract: Local Runtime Files and Commands

## Profile directories
- Default profile lives at Hermes home root.
- Named profiles live under `profiles/<name>`.
- Profile files may include `config.yaml`, `.env`, `SOUL.md`, and `skills/`.
- Active profile marker is written to Hermes home `active_profile`.

## Runtime config
- Provider/model slots and MCP server config are read/written from local YAML files using existing helpers.
- Writes require filesystem access approval for Hermes home.

## CLI execution
- Local commands run Hermes executable with `HERMES_HOME` and TERM environment.
- Remote commands wrap Hermes command through SSH with saved username and temporary private key file.
- Temporary identity files are removed in defer cleanup.
- Command output captures exit status, stdout/stderr, and timeout information.
