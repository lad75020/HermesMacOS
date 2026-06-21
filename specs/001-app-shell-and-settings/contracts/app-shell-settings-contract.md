# Contract: App Shell and Settings

This contract describes externally observable behavior for the native shell and Settings surface. It is a UI/state contract rather than a network API contract.

## Shell Navigation Contract

### Initial launch

**Given** no saved shell state exists
**When** HermesMacOS launches successfully
**Then** the app presents the main shell with a valid default tab selected and at least one usable workspace for workflows that require a workspace.

**Given** saved shell state exists
**When** HermesMacOS launches successfully
**Then** the app restores the last valid top-level tab and valid workspace selections.

**Given** saved shell state references a removed or invalid tab/workspace
**When** HermesMacOS launches
**Then** the app falls back to a valid default and does not crash or block navigation.

### Tab switching

**Given** a user has state in a workflow tab
**When** the user selects another tab and returns
**Then** the workflow state remains available unless the user explicitly reset or deleted it.

**Given** a background workflow emits an attention-worthy status
**When** another tab is selected
**Then** the navigation surface indicates attention without changing the selected tab.

## Settings Contract

### Endpoint editing

**Given** a user changes API or dashboard endpoint values for the selected window
**When** the user applies the change
**Then** the selected window uses the new values and other windows retain their own endpoint settings.

### Saved endpoint pairs

**Given** a user saves a complete API/dashboard endpoint pair
**When** the user selects that pair later
**Then** Settings restores both endpoints together for the selected window.

**Given** an endpoint pair is malformed or incomplete
**When** the user attempts to apply it
**Then** Settings prevents unsafe application or shows a recoverable error.

### Display preferences

**Given** a user changes theme, language, or font preferences
**When** the user returns to the shell
**Then** visible shell labels and controls reflect the selected preference while remaining readable and reachable.

## Reachability Contract

**Given** the current API endpoint is reachable
**When** reachability checks run
**Then** the shell shows the API as reachable.

**Given** the current dashboard endpoint is unreachable
**When** reachability checks run
**Then** the shell shows the dashboard as unreachable while navigation remains usable.

**Given** endpoints are changed in Settings
**When** reachability checks run again
**Then** the checks use the updated selected-window endpoints.

## Startup Secret Contract

**Given** required startup secrets cannot be unlocked
**When** the app starts
**Then** the normal shell is not shown and the user sees a clear failure state.

**Given** startup secrets unlock successfully
**When** the app starts
**Then** the user proceeds to the normal shell without unnecessary secret exposure.
