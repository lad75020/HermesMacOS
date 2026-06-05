# HermesMacOS documentation

HermesMacOS is a native SwiftUI macOS control surface for Hermes Agent. It combines prompt clients, dashboard-backed management panels, local runtime configuration, utilities, and repository maintenance workflows in one desktop app.

## Start here
- [Getting started tutorial](tutorial-getting-started.md): build the app, connect it to local Hermes services, and send the first Ask Hermes prompt.
- [How to configure endpoints and saved windows](how-to-configure-endpoints.md): set API/dashboard hosts, API keys, self-signed certificate handling, saved endpoint pairs, and SSH credentials.
- [How to use Ask Hermes and Chat with Hermes](how-to-use-ask-and-chat.md): profiles, reasoning, attachments, streaming, cancellation, and session resume.
- [How to use the TUI Gateway tab](how-to-use-tui-gateway.md): connect the native TUI WebSocket, use multiple TUI workspaces, send attachments, answer requests, and resume sessions.
- [How to manage Hermes runtime from the app](how-to-manage-hermes-runtime.md): profiles, models, skills, MCP servers, schedules, plugins, toolsets, approvals, and repository updates.

## Reference
- [Application surface reference](reference-app-surface.md): tabs, settings, utilities, and user-facing features.
- [API and storage reference](reference-api-and-storage.md): Hermes API routes, dashboard routes, headers, local storage, Keychain, and files touched.
- [TUI Gateway WebSocket reference](reference-tui-gateway-websocket.md): JSON-RPC setup, methods, event envelopes, stream grouping, workspace state, and attachment flow.

## Explanation
- [Architecture explanation](explanation-architecture.md): how the SwiftUI shell, sessions, stores, dashboard client, and local runtime helpers fit together.
- [Security model explanation](explanation-security-model.md): why the app is unsandboxed and how it uses Keychain, encrypted retention, approvals, TLS pinning, and LocalAuthentication.

## Codebase maps
The codebase map documents the source structure and maintenance model:
- [Stack](codebase/STACK.md)
- [Structure](codebase/STRUCTURE.md)
- [Architecture](codebase/ARCHITECTURE.md)
- [Conventions](codebase/CONVENTIONS.md)
- [Integrations](codebase/INTEGRATIONS.md)
- [Testing](codebase/TESTING.md)
- [Concerns](codebase/CONCERNS.md)
