# Data Model: App Shell and Settings

## App Shell State

Represents what the user sees and how the main control surface preserves context.

**Fields / attributes**:

- Selected top-level tab: one of Ask, Chat, TUI Gateway, History, Sessions, Approvals, Kanban, Dashboard, Configuration, Utilities
- Startup values: last valid tab and any shell preferences safe to restore on launch
- Workspace selections: current workspace per multi-workspace workflow
- Attention states: visual status for background workflows such as streaming, completed, failed, or needs-attention
- Unlock state: whether startup secrets are available or the failure view must be shown

**Validation rules**:

- Selected tab must always resolve to a known top-level tab.
- A deleted or missing workspace selection must fall back to a valid remaining workspace.
- Attention states must not force tab selection changes.
- Unlock failure must prevent the normal shell from exposing sensitive partial state.

## Window Connection

Represents the endpoints and connection settings active for one app window.

**Fields / attributes**:

- Window identifier
- Hermes API base endpoint
- Hermes dashboard endpoint
- Self-signed certificate allowance state
- Optional API-key availability indicator, without exposing the raw secret
- Optional SSH credential availability indicator, without exposing the raw secret

**Validation rules**:

- Endpoint edits apply to the selected window context only.
- API and dashboard endpoints may be changed independently while saved endpoint pairs restore both together.
- Sensitive secret values are stored and read through the shared security layer, not through plain shell preference storage.

## Saved Endpoint Pair

Represents a reusable target deployment that users can apply to a window.

**Fields / attributes**:

- Display name or host label
- Hermes API base endpoint
- Hermes dashboard endpoint
- Created/updated ordering for presentation when available

**Validation rules**:

- A pair must include both API and dashboard endpoints.
- Malformed or incomplete pairs must not be silently applied.
- Removing a pair must not erase the active window's current endpoints unless the user explicitly applies a different pair.

## User Preferences

Represents non-secret user choices that affect the shell and Settings experience.

**Fields / attributes**:

- Theme selection
- App language selection
- Title, label, and prompt font preferences
- Allowed folder selections or references, where applicable
- Last selected Settings/window target context

**Validation rules**:

- Missing or invalid preference values fall back to safe defaults.
- Display preferences must keep labels readable and controls accessible.
- Folder access choices must stay consistent with the shared filesystem access policy.

## Reachability Status

Represents observed availability for configured Hermes services.

**Fields / attributes**:

- API target status: unknown/loading, reachable, or unreachable
- Dashboard target status: unknown/loading, reachable, or unreachable
- Last check timing
- Endpoint used for the check

**Validation rules**:

- Reachability checks must use the current window's endpoints.
- Unreachable status must not clear drafts, workspaces, or settings.
- Unknown/loading status is valid during startup and endpoint transitions.
