# Why HermesMacOS is structured as a native control surface

HermesMacOS needs to do three jobs at once: talk to Hermes Agent APIs, expose dashboard management features, and manage local runtime files on the user's Mac. A pure web UI would be weaker at local Keychain, filesystem, SSH, pasteboard, speech, and native multi-window workflows. A pure CLI would be weaker for live streaming conversations, dashboards, approvals, and status-heavy operation. The app chooses a native SwiftUI shell around API clients and local helpers.

## The problem
Hermes Agent work spans multiple surfaces:
- Prompting and streaming through `/v1/responses` and `/v1/chat/completions`.
- Dashboard-backed state such as sessions, skills, schedules, plugins, toolsets, MCP servers, and config YAML.
- Local macOS capabilities such as Keychain, LocalAuthentication, pasteboard, AVFoundation, Speech, WebKit, and git/SSH process execution.

If each surface lived in a separate tool, the user would switch between browser, terminal, Settings files, and logs. HermesMacOS centralizes those workflows while still leaving execution to the API gateway, dashboard, and local CLI where appropriate.

## The approach
```text
SwiftUI app shell
  ContentView + side tabs + settings + windows
        |
        +-- Prompt sessions
        |     HermesResponsesSession -> /v1/responses
        |     HermesChatSession      -> /v1/chat/completions
        |
        +-- Dashboard stores
        |     HermesDashboardClient -> dashboard HTML token -> api/* JSON
        |
        +-- Local runtime stores
        |     profile/model/YAML files + Hermes CLI + git/SSH process runner
        |
        +-- Security helpers
              Keychain, encrypted retention, TLS pinning, local approvals
```

The shell owns shared state: selected tab, endpoint settings, dashboard URL, window identity, and per-feature stores. Each feature view receives the pieces it needs instead of reaching into global singletons for everything.

## Why stores and sessions are observable
Prompt clients and dashboard panels produce long-lived status: streaming text, event counts, active request IDs, selected board/task, pending approvals, loading state, and error messages. Observable store/session classes let async work update the UI without manually threading callbacks through every view.

## Why dashboard APIs are accessed through HTML token extraction
The dashboard already owns management data and protected routes. HermesMacOS reuses that session model by extracting the token from the dashboard bootstrap HTML. This avoids duplicating dashboard auth in the app, but it creates coupling to the dashboard's `window.__HERMES_SESSION_TOKEN__` shape.

## Why local runtime mutation remains native
Local profiles, model config, MCP server YAML, SSH keys, clipboard history, and repository updates all touch macOS-specific resources. Implementing them natively gives the app direct access to Keychain, file panels, LocalAuthentication, and controlled process execution.

## Trade-offs
- Benefit: one native app can combine live prompting, configuration, history, approvals, utilities, and repository maintenance.
- Cost: feature files are large because the app has broad surface area and many native integrations.
- Benefit: sensitive values use Keychain and encrypted retention instead of plain settings.
- Cost: disabling sandbox means the app must maintain its own guardrails for filesystem and process safety.
- Benefit: dashboard reuse avoids a second management backend.
- Cost: dashboard token scraping is more fragile than a stable native auth API.

## Alternatives visible from the code
No ADR file documents rejected alternatives. Based on current source, the implemented split is: native SwiftUI for control surface and macOS integration, Hermes API for agent execution, Hermes Dashboard for management state, local file/process helpers for runtime mutation.
