# Data Model: Dashboard Web Embedding

## HermesDashboardView
- **Attributes**: dashboardURL, pagePath, title, systemImage, colorScheme, reloadToken.
- **Relationships**: owns SwiftUI chrome and delegates web content to `HermesDashboardWebView`.
- **Validation**: invalid normalized URL renders an empty state.

## HermesConfigurationWebURL
- **Attributes**: raw URL string, optional page path, color scheme.
- **Relationships**: builds loadable URL for dashboard pages.
- **Validation**: supports http/https only, rejects remote plaintext HTTP, replaces existing theme query.

## HermesDashboardWebViewStore
- **Attributes**: WKWebView, lastLoadedURL, lastReloadToken.
- **Relationships**: reused by SwiftUI wrappers to preserve WebKit navigation/session state.
- **Validation**: loads only when URL changes; reloads only when reload token changes.

## HermesDashboardWebView
- **Attributes**: store, URL, reloadToken.
- **Relationships**: `NSViewRepresentable` bridge for `WKWebView`.
