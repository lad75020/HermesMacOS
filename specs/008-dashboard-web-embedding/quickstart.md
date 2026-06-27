# Quickstart: Dashboard Web Embedding

## Build verification
```bash
xcodebuild -project HermesMacOS.xcodeproj -scheme HermesMacOS -destination 'generic/platform=macOS' -derivedDataPath /tmp/HermesMacOSDerivedData build
```

## UI smoke check
1. Configure Dashboard URL as `http://localhost:9119` or HTTPS dashboard host.
2. Open Hermes Dashboard or any dashboard-backed embedded tab.
3. Verify the page loads and the connected-host label remains visible.
4. Press Reload and verify the page reloads.
5. Switch light/dark mode and verify the dashboard URL/theme updates.
6. Configure a remote plaintext `http://example.com` dashboard URL and verify the empty state appears.

## Expected result
- Build succeeds.
- Safe dashboard URLs load; unsafe/invalid URLs do not.
