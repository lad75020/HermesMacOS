# Quickstart: Security and Local Access

Use these checks to validate the Security and Local Access feature after implementation. The feature is security-focused, so most checks are scenario or source-validation checks plus an Xcode build.

## Prerequisites

- Work from repository root: `/Volumes/WDBlack4TB/Code/HermesMacOS`
- Use branch: `feature/time-machine-security-and-local-access`
- Keep the app connected to a loopback Hermes API by default, for example `http://localhost:8642/v1`.
- Use a remote HTTP URL only for negative validation; do not send real credentials to a remote plaintext service.

## 1. Protected secret storage

1. Open Settings and enter a test API key.
2. Save or trigger the settings persistence path.
3. Verify encoded `HermesAPISettings` does not contain the raw key.
4. Verify `HermesAPIKeychain.loadAPIKey()` can load the key after the app-session unlock gate.
5. Clear the key and verify future loads return an empty value.
6. For a remote host, import a small test SSH private key and verify saved endpoint metadata contains only display information.
7. Call the SSH temporary identity-file path during an SSH workflow and verify the file is created with user-only permissions and later cleaned where practical.

## 2. Sensitive endpoint validation

1. Configure `http://localhost:8642/v1` with an API key and verify credentialed requests are allowed.
2. Configure a non-loopback `http://example.invalid:8642/v1` with an API key and verify request preparation fails closed before attaching `Authorization`.
3. Verify reachability probes do not attach API keys to remote plaintext requests.
4. Configure a normal HTTPS endpoint and verify requests use platform trust.

## 3. TLS trust approvals

1. Connect to an HTTPS endpoint with an untrusted/self-signed leaf certificate while self-signed support is enabled.
2. Verify the current connection attempt is rejected and a local TLS approval appears in Approvals Inbox.
3. Approve the fingerprint and verify a host-scoped Keychain pin is written.
4. Reset the pin from Settings and verify a later untrusted certificate requires a fresh approval.
5. Change the certificate fingerprint and verify the previous pin is not silently reused.

## 4. Retained local data

1. Save prompt, response, draft, title, and clipboard entries that include strings such as `Authorization: Bearer secret-token`, `sk-...`, a JWT-like value, and a private-key block.
2. Verify retained plaintext in memory/display is redacted for common secret patterns before persistence.
3. Verify persistent values are written through `HermesEncryptedRetentionStore` under encrypted keys rather than legacy plaintext preference keys.
4. Seed a supported legacy plaintext value, load it once, and verify it migrates to encrypted storage and removes the legacy key.
5. Clear/delete retained entries and verify both encrypted and legacy preference keys are removed.

## 5. Filesystem access and local approvals

1. Verify the default allowlist includes the selected Hermes home, Hermes agent root, and the user's home folder.
2. Add and remove a user-selected allowed folder from Settings.
3. Attempt a supported local operation inside an allowed folder and verify it proceeds without an extra prompt.
4. Attempt a supported local operation outside the allowlist and verify a local filesystem approval appears in Approvals Inbox.
5. Deny the approval and verify the original operation fails with a clear local-access error.
6. Approve the approval and verify the waiting operation continues exactly once.

## 6. Bounded process execution

1. Route local process work through `HermesProcessRunner.run(...)` where this feature's files manage process or SSH execution.
2. Run a short command and verify stdout/stderr capture and exit code reporting.
3. Run a command that exceeds a small timeout and verify timeout state is reported and the child process is terminated.
4. Verify user-facing debug output is bounded and redacted before display/copy/export.

## 7. Build validation

Run the macOS app build:

```sh
xcodebuild -project HermesMacOS.xcodeproj -scheme HermesMacOS -configuration Debug -derivedDataPath /tmp/HermesMacOSDerived build
```

Expected result:

```text
** BUILD SUCCEEDED **
```

Xcode may print unrelated connected-device or passcode warnings; treat the final build result and error lines as the validation signal.
