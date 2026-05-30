# Build HermesMacOS and send your first Ask Hermes prompt

This tutorial takes you from a clean checkout to a running HermesMacOS window connected to local Hermes services. By the end, you can open Ask Hermes, choose a profile, and send a prompt through `/v1/responses`.

## What you need
- macOS 26.0 or newer.
- Xcode with SwiftUI, AppKit, WebKit, AVFoundation, and Speech support.
- XcodeGen if you need to regenerate `HermesMacOS.xcodeproj` from `project.yml`.
- A Hermes API gateway reachable at an API base URL such as `http://localhost:8642/v1`.
- A Hermes Dashboard reachable at a dashboard URL such as `http://localhost:9119`.

## Step 1: Generate and open the project
From the repository root:

```bash
xcodegen generate
open HermesMacOS.xcodeproj
```

You should now see the `HermesMacOS` scheme in Xcode.

## Step 2: Build and run the app
In Xcode, select the `HermesMacOS` scheme and run it.

For command-line verification, run:

```bash
xcodebuild   -project HermesMacOS.xcodeproj   -scheme HermesMacOS   -destination 'generic/platform=macOS'   build
```

If another Xcode build has DerivedData locked, use an isolated path:

```bash
xcodebuild   -project HermesMacOS.xcodeproj   -scheme HermesMacOS   -destination 'generic/platform=macOS'   -derivedDataPath /tmp/HermesMacOSDerivedData   build
```

## Step 3: Configure the local endpoints
Open Settings in HermesMacOS.

Set:
- Hermes API Base URL: `http://localhost:8642/v1`, or your reachable API gateway including `/v1`.
- Dashboard URL: `http://localhost:9119`, or your reachable Hermes Dashboard.
- Hermes API key: optional. If you set one, HermesMacOS stores it in Keychain and sends it as a bearer token.

The side rail contains reachability LEDs for API and dashboard status. They probe common local API and dashboard endpoints.

## Step 4: Send the first Ask Hermes request
Open the Ask Hermes tab.

1. Pick a profile if profiles load from `/v1/profiles`.
2. Type a prompt.
3. Leave streaming enabled for a live response, or switch to non-streaming if you need one final JSON response.
4. Press Send.

The app sends a `POST /v1/responses` request. It includes `X-Hermes-Profile`, a request ID for cancellation, and the API key authorization header if configured.

## Step 5: Verify continuation and cancellation
After a response completes:
- Send a follow-up prompt in the same workspace to continue the stored response session.
- Press Cancel while a response streams to call the request cancellation endpoint.
- Add another Ask workspace if you want a separate draft/session side by side.

## What you built
You now have a running HermesMacOS app connected to Hermes Agent and Dashboard. You can send prompts through the Responses API, inspect streaming status, switch profiles, and continue or cancel active work.

## Troubleshooting
- Profiles do not load: check that the API base URL includes `/v1` and that `/v1/profiles` is reachable.
- Dashboard panels fail: check that the Dashboard URL serves HTML containing `window.__HERMES_SESSION_TOKEN__`.
- Remote HTTP is blocked: use HTTPS for non-loopback hosts when sending sensitive traffic.
- Self-signed HTTPS fails: enable self-signed certificate support in Settings and approve the fingerprint in Approvals Inbox.
- Secrets cannot unlock: LocalAuthentication must be available because the app uses it to unlock Keychain-backed secrets for the login session.
