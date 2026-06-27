# Feature Specification: Dashboard Configuration Management

**Feature Branch**: `feature/time-machine-dashboard-configuration-management`  
**Created**: 2026-06-27  
**Status**: Draft  
**Input**: User description: "Feature: Dashboard Configuration Management. Description: Lets users inspect and manage dashboard-backed profiles, models, MCP servers, skills, schedules, plugins, and toolsets from native SwiftUI panels. Relevant files: HermesMacOS/HermesConfigurationView.swift, HermesMacOS/HermesConfigurationRuntimeModelsSection.swift, HermesMacOS/HermesConfigurationRuntimeModelSlotEditorCard.swift, HermesMacOS/HermesConfigurationSchedulesSection.swift, HermesMacOS/HermesConfigurationMCPServersSection.swift, HermesMacOS/HermesConfigurationToolsetsSection.swift, HermesMacOS/HermesConfigurationProfilesSection.swift, HermesMacOS/HermesConfigurationPluginsSection.swift, HermesMacOS/HermesConfigurationSkillsSection.swift, HermesMacOS/HermesDashboardSkills.swift, HermesMacOS/HermesDashboardToolsets.swift, HermesMacOS/HermesDashboardSchedules.swift, HermesMacOS/HermesDashboardMCPServers.swift, HermesMacOS/HermesDashboardPluginsStore.swift. Focus on this feature only; do not modify other features."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Refresh and inspect configuration sections (Priority: P1)
A user opens Configuration and sees dashboard-backed Skills, Plugins, Toolsets, MCP Servers, Schedules, Profiles, Runtime Models, and local runtime status refreshed into native panels.

**Independent Test**: Open Configuration with a reachable dashboard and verify each section refreshes or shows a scoped error.

**Acceptance Scenarios**:
1. **Given** dashboard and local runtime are reachable, **When** Configuration appears, **Then** all configured dashboard stores and local stores refresh.
2. **Given** a section fails, **When** other sections succeed, **Then** errors remain scoped to the failing section.
3. **Given** the user presses Refresh, **When** the action runs, **Then** dashboard and local runtime stores refresh again.

---

### User Story 2 - Manage dashboard resources (Priority: P2)
A user filters, inspects, toggles, creates, edits, or triggers supported dashboard-backed resources through native controls.

**Independent Test**: Filter skills/toolsets/MCP/schedules/plugins, toggle a skill/toolset where supported, trigger a schedule, and verify API status updates.

**Acceptance Scenarios**:
1. **Given** skills are loaded, **When** the user filters or toggles a skill, **Then** the UI updates via the skills store and dashboard API.
2. **Given** schedules are loaded, **When** a job is triggered, **Then** the schedules store posts the trigger and refreshes status.
3. **Given** MCP server draft inputs are invalid, **When** submitted, **Then** validation messages prevent malformed configuration calls.
4. **Given** plugins/toolsets/profiles/model slots load, **When** inspected, **Then** their status and metadata render in native cards.

---

### User Story 3 - Preserve safety and usability (Priority: P3)
A user can work with configuration without leaking secrets or losing local/dash state; destructive operations require explicit UI flows.

**Independent Test**: Test section disclosure persistence, profile delete confirmation, and secret-bearing dashboard calls over safe endpoints.

**Acceptance Scenarios**:
1. **Given** section disclosure states change, **When** the view reloads, **Then** expansion preferences persist in AppStorage.
2. **Given** a profile delete is requested, **When** confirmation appears, **Then** deletion only occurs after explicit destructive confirmation.
3. **Given** dashboard configuration APIs require auth, **When** calls are made, **Then** dashboard session/token handling and endpoint validation remain centralized in stores/helpers.

### Edge Cases
- Dashboard unavailable should not block local runtime/profile refresh.
- Empty search filters should show full resource lists.
- Invalid URLs, malformed schedule expressions, or malformed MCP env/header JSON should show validation messages.
- Config changes may be rejected by dashboard; stores must keep error/status feedback visible.

## Requirements *(mandatory)*
- **FR-001**: System MUST provide a native Configuration surface composed of expandable sections for skills, plugins, profiles, toolsets, MCP servers, schedules, runtime models, and local runtime status.
- **FR-002**: System MUST refresh dashboard-backed stores and local runtime/profile stores from a single top-level refresh action.
- **FR-003**: System MUST support query/filter state for skills, plugins, toolsets, MCP servers, and schedules.
- **FR-004**: System MUST support dashboard-backed management actions exposed by the existing stores, including skill/toolset operations, schedules operations, MCP/profile/plugin/model inspection or edits where implemented.
- **FR-005**: System MUST preserve expansion preferences using AppStorage keys under `hermes.macOS.configuration.*`.
- **FR-006**: System MUST show connected host/window context and section-scoped status/errors.
- **FR-SEC**: System MUST avoid storing secrets in plaintext UI state beyond existing guarded local/runtime stores and must rely on existing endpoint/session validation helpers.
- **FR-INT**: System MUST preserve dashboard API contracts for skills, plugins, toolsets, MCP servers, schedules, profiles, and runtime model configuration.

### Key Entities
- **HermesConfigurationView**: Top-level native configuration surface and refresh orchestrator.
- **HermesDashboardSkillsStore / Toolsets / Schedules / MCPServers / PluginsStore**: Dashboard-backed resource stores.
- **HermesLocalProfilesStore / HermesLocalRuntimeModelsStore / HermesLocalConfigurationRuntime**: Local runtime/profile/model sources.
- **HermesConfiguration*Section**: Native section cards for each resource type.

## Success Criteria *(mandatory)*
- **SC-001**: Opening Configuration refreshes all dashboard and local sections without blocking independent sections.
- **SC-002**: Users can filter and inspect each dashboard-backed resource type.
- **SC-003**: Supported mutate/trigger/toggle operations update status and refresh relevant data.
- **SC-004**: Expansion preferences and destructive confirmations behave predictably.
- **SC-BUILD**: The `HermesMacOS` scheme builds successfully.
- **SC-SMOKE**: The primary configuration management flow can be validated independently with documented dashboard smoke checks.

## Assumptions
- This pass documents the existing Configuration implementation and does not add new dashboard APIs.
- Live verification requires a reachable Hermes Dashboard and local Hermes runtime.
- No automated test target exists yet.
