# Contract: Approvals API

## List approvals

- `GET /v1/approvals`
- Request headers:
  - `Accept: application/json`
  - Optional `Authorization: Bearer <api-key>` only after sensitive URL validation.
- Response:
  - `approvals`: array of approval items
  - `count`: total count
- Response content type must include `application/json`.

## Resolve approval

- `POST /v1/approvals/resolve`
- Request headers:
  - `Accept: application/json`
  - `Content-Type: application/json`
  - Optional `Authorization: Bearer <api-key>` only after sensitive URL validation.
- Body:
  - `choice`: approval decision string such as approve/deny
  - `resolve_all`: false for single-row inbox decisions
  - `session_key`: source session key for the approval

## Local approvals

- Local filesystem/TLS approvals are synthesized into the same row model with ids prefixed by `local-`.
- Local approval resolution calls `HermesLocalApprovalCenter.shared.resolve` and does not call remote APIs.

## Failure behavior

- Remote list failure falls back to local approvals.
- Resolve failure leaves error state visible and does not remove the approval locally.
- Invalid URL, remote plaintext HTTP with API keys, non-JSON list responses, and HTTP failures surface user-visible errors.
