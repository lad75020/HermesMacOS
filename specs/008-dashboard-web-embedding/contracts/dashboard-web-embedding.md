# Contract: Dashboard Web Embedding

## URL normalization
- Empty strings return no URL.
- Full `http`/`https` URLs with hosts are accepted only when safe.
- Host-only values are interpreted as HTTPS hosts.
- Remote plaintext HTTP is rejected; localhost HTTP is allowed.
- Optional `pagePath` replaces the URL path.
- Existing `theme` query items are removed and replaced with one active theme.

## Theme mapping
- Dark color scheme maps to `mono`.
- Light color scheme maps to `solarized-light`.
- A document-start script stores the desired theme in dashboard localStorage and patches theme API responses when possible.

## Load/reload behavior
- New URL triggers `webView.load(URLRequest(url:))`.
- Same URL plus new reload token triggers `webView.reload()`.
- Same URL and token performs no duplicate load.
