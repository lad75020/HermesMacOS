# Quickstart: Security and Endpoint Guardrails

## Build verification

```bash
xcodebuild   -project HermesMacOS.xcodeproj   -scheme HermesMacOS   -destination 'generic/platform=macOS'   -derivedDataPath /tmp/HermesMacOSDerivedData   build
```

## Manual/security smoke checks

1. Configure a remote non-loopback `http://` API or dashboard URL with an API key and confirm a sensitive operation is blocked before the key is sent.
2. Configure `http://localhost:8642/v1` and confirm loopback development traffic remains allowed.
3. Save an API key in Settings, close/reopen the app, and confirm the key is usable after unlock without being serialized into project files or plaintext preferences.
4. Enable local retention with test text containing a fake bearer token, fake private key block, and fake data URL; confirm retained output is redacted and encrypted.
5. Connect to a self-signed test host with self-signed support enabled; confirm a certificate approval is queued, approve it, then confirm the pin is reused.
6. Reset the host pin and confirm the approval path is presented again on next connection.
7. Attempt a guarded local filesystem operation outside allowed folders; deny the approval and confirm the operation fails without mutation.
8. For SSH-backed repository updates, use a test key and confirm temporary identity files are removed after the command finishes.

## Expected result

- The app builds successfully.
- Unsafe remote plaintext sensitive traffic is blocked.
- Secrets are stored through Keychain/encrypted retention paths.
- TLS and filesystem exceptions require explicit approval.
