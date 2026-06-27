# Feature Specification: Local Runtime and Profile Management

**Feature Branch**: `feature/time-machine-local-runtime-profile-management`  
**Created**: 2026-06-27  
**Status**: Draft  
**Input**: User description: "Feature: Local Runtime and Profile Management. Description: Lets users read and mutate local Hermes profiles, provider/model slots, raw configuration, and MCP server YAML through guarded local runtime operations. Relevant files: HermesMacOS/HermesLocalProfiles.swift, HermesMacOS/HermesLocalRuntimeModels.swift, HermesMacOS/HermesLocalConfigurationRuntime.swift, HermesMacOS/HermesMCPServersYAML.swift, docs/how-to-configure-endpoints.md, docs/how-to-manage-hermes-runtime.md. Focus on this feature only; do not modify other features."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Inspect and manage local profiles (Priority: P1)
A user reviews local Hermes profiles, creates or edits a named profile, switches the active profile, and deletes non-default profiles with safeguards.

**Acceptance Scenarios**:
1. **Given** Hermes home is accessible, **When** profiles refresh, **Then** default and named profiles show provider, model, base URL, config/env/soul, skills, and gateway state.
2. **Given** a new profile draft is valid, **When** created, **Then** config/env/soul files are seeded and optional skills are cloned.
3. **Given** a default profile delete/rename is attempted, **When** validation runs, **Then** the operation is rejected.

---

### User Story 2 - Manage runtime model/configuration files (Priority: P2)
A user views and edits local provider/model slots and raw runtime config with filesystem approval safeguards.

**Acceptance Scenarios**:
1. **Given** local config exists, **When** runtime models refresh, **Then** current provider/model slots display.
2. **Given** a model change is saved, **When** the file write completes, **Then** refresh shows the updated YAML values.
3. **Given** local filesystem access is denied, **When** mutation starts, **Then** the operation stops with a visible error.

---

### User Story 3 - Operate local Hermes CLI and MCP YAML helpers (Priority: P3)
A user runs guarded local Hermes commands and edits MCP server YAML through native forms.

**Acceptance Scenarios**:
1. **Given** local or SSH runtime credentials are available, **When** a command is run, **Then** output appears with command label and timeout-safe result.
2. **Given** MCP server form values are valid, **When** saved, **Then** local YAML is updated and refresh reflects changes.
3. **Given** malformed MCP env/header data is entered, **When** validation runs, **Then** the app shows validation messages and avoids writing malformed YAML.

### Edge Cases
- Missing Hermes home should surface a clear path error.
- Switching away from an active profile that is deleted should restore default active profile.
- Remote runtime commands require SSH username and temporary private key material.
- Temporary SSH identity files must be removed after command execution.
- Local writes must require filesystem approval for the Hermes home path.

## Requirements *(mandatory)*
- **FR-001**: System MUST list default and named Hermes profiles from Hermes home/profile directories.
- **FR-002**: System MUST create, edit, activate, and delete allowed local profiles with validation and filesystem approval.
- **FR-003**: System MUST read/write provider, model, base URL, env, SOUL, skill clone, active profile, and profile metadata where implemented.
- **FR-004**: System MUST read and update local runtime model/provider slots in Hermes config YAML.
- **FR-005**: System MUST run guarded local/remote Hermes CLI commands with timeout and captured output.
- **FR-006**: System MUST support local MCP server YAML add/edit/remove/probe helpers where implemented.
- **FR-SEC**: System MUST require local filesystem access policy for Hermes home mutations and remove temporary SSH identity files.
- **FR-INT**: System MUST preserve local Hermes directory/config/YAML conventions.

### Key Entities
- **HermesLocalProfilesStore**: Profile discovery, create/edit/use/delete, active profile marker, file seeding, validation, and filesystem approval.
- **HermesLocalRuntimeModelsStore**: Local provider/model slot read/write behavior.
- **HermesLocalConfigurationRuntime**: Guarded Hermes CLI execution and SSH wrapping.
- **HermesMCPServersYAML**: YAML helpers for MCP server configuration.
- **HermesLocalProfileDraft / HermesLocalProfileInfo**: Profile form and row data.

## Success Criteria *(mandatory)*
- **SC-001**: Profiles refresh and display current default/named profile metadata.
- **SC-002**: Valid profile create/edit/use/delete flows update disk state and refresh UI.
- **SC-003**: Runtime model save changes persist to config YAML.
- **SC-004**: MCP YAML helpers validate input and avoid malformed writes.
- **SC-005**: Local/remote CLI command output is visible and cleans temporary SSH identity files.
- **SC-BUILD**: The `HermesMacOS` scheme builds successfully.
- **SC-SMOKE**: Primary local runtime/profile flows can be validated independently with documented smoke checks.

## Assumptions
- This pass documents the existing local runtime/profile implementation and does not change Hermes config formats.
- Live verification requires local Hermes home access and, for remote commands, SSH credentials.
- No automated test target exists yet.
