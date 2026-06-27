# Research: Dashboard Web Embedding

## Decision 1: Keep dashboard inside WebKit
**Decision**: Embed dashboard pages with `WKWebView` instead of rebuilding every dashboard page natively.  
**Rationale**: The Dashboard already provides rich management pages; native app can integrate them safely while other tabs provide deeper native workflows.

## Decision 2: Theme through query plus script override
**Decision**: Append a theme query and inject a small document-start script.  
**Rationale**: This synchronizes first load and dashboard theme API reads without requiring dashboard code changes.

## Decision 3: Reject remote plaintext HTTP
**Decision**: Allow localhost HTTP and HTTPS, reject remote HTTP.  
**Rationale**: Dashboard is a control surface and should not expose sensitive session state over remote plaintext transport.
