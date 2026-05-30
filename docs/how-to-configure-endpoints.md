# How to configure endpoints and saved windows

This guide configures HermesMacOS to talk to a Hermes API gateway and Hermes Dashboard, then saves endpoint pairs for reuse across windows.

## Prerequisites
- HermesMacOS is built and running.
- You know the Hermes API base URL. It normally includes `/v1`.
- You know the Hermes Dashboard URL.

## Steps

1. Open Settings.

2. Set the Hermes API Base URL.

   Use a value like:

   ```text
   http://localhost:8642/v1
   ```

   `HermesAPISettings` normalizes endpoint suffixes from this base URL for `/responses`, `/chat/completions`, `/profiles`, approvals, and cancellation.

3. Set the Dashboard URL.

   Use a value like:

   ```text
   http://localhost:9119
   ```

   Dashboard-backed features use this URL to fetch the dashboard HTML, extract the session token, and call dashboard API routes.

4. Enter an API key if your gateway requires one.

   HermesMacOS stores the key in Keychain. It does not encode the key back into the persisted `HermesAPISettings` JSON.

5. Decide whether to allow self-signed certificates.

   For local or Tailscale deployments with private TLS, enable the self-signed option. The first untrusted certificate is not silently accepted. HermesMacOS queues an approval and pins the leaf SHA-256 fingerprint only after approval.

6. Save the current API/dashboard pair.

   Use the saved endpoints controls in Settings. The saved endpoint stores the API URL, dashboard URL, save time, and optional SSH display metadata.

7. Apply saved endpoints to windows.

   Each window has a `HermesWindowConnection` record. Applying a saved endpoint updates the selected window's API settings and dashboard URL without forcing all windows to target the same host.

8. Add SSH credentials when the host is remote.

   For repository maintenance over SSH, set a username and import a private key. The key is stored in Keychain and only written to a private temporary file during SSH command execution.

## Verification
- The side rail API LED should turn reachable when the API gateway responds on one of the probe URLs.
- The dashboard LED should turn reachable when the dashboard responds.
- The profile selector should populate from `/v1/profiles`.
- Dashboard-backed tabs should load after token extraction succeeds.

## Troubleshooting
- If a dashboard route returns unauthorized, refresh the dashboard panel so `HermesDashboardClient` can refetch the session token.
- If remote HTTP is rejected, switch the URL to HTTPS. Sensitive remote plaintext HTTP is intentionally blocked.
- If a self-signed certificate changed, reset the current host pin in Settings so you can approve the new fingerprint.
- If SSH update reports missing settings, make sure the saved endpoint host has both username and private key configured.
