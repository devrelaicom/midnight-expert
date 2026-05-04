# DApp Connector API Errors

> **Last verified:** 2026-05-04 against `midnightntwrk/midnight-dapp-connector-api@v4.0.1` (anchor: `src/errors.ts`, modified 2025-11-18; spec: `SPECIFICATION.md`, modified 2026-02-17).

Errors from the Midnight DApp Connector — the browser-based API that connects DApps to the Midnight Lace wallet extension.

## Source

These errors are returned by the DApp Connector API when a DApp interacts with the wallet. They surface as `APIError` objects with a `type` field (not as `instanceof` checks — always use `error.type === 'DAppConnectorAPIError'`).

## Error Codes (v4.0.x — current)

| Code | Description | Semantic | Fixes |
|------|-------------|----------|-------|
| `Disconnected` | Connection to the wallet was lost mid-session | Session-level — the WebSocket or communication channel dropped | Re-establish connection by calling `connect(networkId)` (use `getConnectionStatus()` to observe state). The legacy v3 `enable()` method was removed in v4.0.0. |
| `InternalError` | Connector could not process the request internally | Internal wallet/connector failure | Retry the operation; check Lace wallet logs; update wallet extension |
| `InvalidRequest` | Malformed transaction or invalid request parameters | Client error — the DApp sent bad data | Verify transaction structure; check parameter types and formats |
| `PermissionRejected` | Session-level denial — user's general preference to deny this DApp | Persistent — user has blocked this DApp | Inform the user; they must unblock the DApp in wallet settings |
| `Rejected` | One-time user rejection — user saw the request and declined | Per-request — user declined this specific transaction | Inform the user the action was cancelled; do not auto-retry |

### Key Distinction: `Rejected` vs. `PermissionRejected`

- **`Rejected`**: The user saw the specific transaction/request and said "no" this time. The DApp can try again with a different request.
- **`PermissionRejected`**: The user has set a session-level preference to deny this DApp entirely. Retrying will produce the same result until the user changes their wallet settings.

### Detecting APIError

```typescript
// CORRECT — check the type field
if (error.type === 'DAppConnectorAPIError') {
  switch (error.code) {
    case 'Rejected': // user declined
    case 'PermissionRejected': // user blocked DApp
    case 'InvalidRequest': // bad request
    case 'InternalError': // internal failure
    case 'Disconnected': // connection lost
  }
}

// WRONG — do NOT use instanceof
// if (error instanceof APIError) { ... }
```

### APIError Structure

```typescript
type APIError = Error & {
  type: 'DAppConnectorAPIError';
  code: ErrorCode;  // one of the 5 codes above
  reason: string;   // human-readable explanation
}
```

## Legacy Error Codes (v3.0.0)

The v3.0.0 DApp Connector API had only 3 error codes:

| Code | Description |
|------|-------------|
| `InternalError` | Same as v4.0.x |
| `InvalidRequest` | Same as v4.0.x |
| `Rejected` | Same as v4.0.x |

`PermissionRejected` and `Disconnected` were added in v4.0.0.

## Transaction Status Types

The DApp Connector also reports transaction status through these values:

| Status | Description |
|--------|-------------|
| `finalized` | Transaction has been finalized by consensus |
| `confirmed` | Transaction included in a block but not yet finalized |
| `pending` | Transaction submitted, awaiting block inclusion |
| `discarded` | Transaction was discarded (not included) |
