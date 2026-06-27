# Implementation Plan: Dashboard Web Embedding

**Branch**: `feature/time-machine-dashboard-web-embedding` | **Date**: 2026-06-27 | **Spec**: [spec.md](./spec.md)

## Summary
Retroactively specify and verify the existing dashboard WebKit embed: safe URL normalization, page path selection, app-color-scheme theme query, document-start theme override script, reload token behavior, native empty state, and persistent `WKWebView` store.

## Technical Context
**Language/Version**: Swift, SwiftUI, WebKit; project sets `SWIFT_VERSION: 5.0`  
**Primary Dependencies**: Hermes Dashboard HTTP/HTTPS pages; `WKWebView`; endpoint security helpers  
**Storage**: WebKit internal state via one store-owned web view; dashboard localStorage theme override  
**Testing**: Xcode build plus dashboard UI smoke checks  
**Target Platform**: macOS 26+ native app  
**Constraints**: Reject remote plaintext HTTP, preserve connected-host label, avoid duplicate loads for same URL/reload token

## Constitution Check
- **Native control surface**: Pass. Uses SwiftUI shell around a WebKit dashboard surface.
- **Integration contracts**: Pass. Loads dashboard pages via configured Dashboard URL/page path.
- **Security guardrails**: Pass. Rejects remote plaintext dashboard URLs.
- **Verification**: Pass with build plus dashboard smoke checks. No automated test target exists for this WebKit behavior.
- **Maintainability**: Pass. Adds SDD artifacts only.

## Project Structure
```text
specs/008-dashboard-web-embedding/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/dashboard-web-embedding.md
└── tasks.md
```

```text
HermesMacOS/HermesDashboardWebView.swift
docs/reference-app-surface.md
```
