---
name: proof-server:proof-server-integration
description: This skill covers how the Midnight proof server is invoked in practice — who calls it, the client-server contract, self-hosted vs wallet-delegated proving, network proof-server endpoints, production deployment behind a reverse proxy, and CORS. Use it for "who calls the proof server", "ProofProvider", "wallet-delegated proving", "proof server endpoint", "production proof server", "proof server behind a proxy", or wiring a DApp/SDK to a proof server.
version: 0.1.0
---

# Proof Server Integration

How the Midnight proof server is invoked in practice — who calls it, the protocol it exposes, deployment modes, and where to find deeper detail.

For Docker setup and version-tag selection, see `midnight-tooling:proof-server`. For DApp-side provider assembly (React, Vite), see `midnight-dapp-dev:core`. For the full HTTP API reference, see `proof-server:proof-server-api`.

---

## Who Calls the Proof Server

The proof server is not called directly by application code. The call is made by the `midnight-js` SDK via the `ProofProvider` abstraction:

```text
DApp / CLI script
  └─ midnight-js SDK (callTx / submitCallTx)
       └─ ProofProvider.proveTx()
            └─ POST /prove  →  proof server (port 6300)
```

The `ProofProvider` instance is created by the factory function:

```
httpClientProofProvider(proofServerUri, zkConfigProvider)
```

from `@midnight-ntwrk/midnight-js-http-client-proof-provider`. The DApp supplies the URI; the SDK handles binary serialization of the request body and response parsing.

Do not build the `/prove` request body yourself — the binary format is complex. Cross-reference `proof-server:proof-server-api` for the serialization spec if you need low-level detail.

For provider assembly (where `httpClientProofProvider` fits into the full `MidnightProviders` object), see `midnight-dapp-dev:core` and `midnight-dapp-dev:midnight-sdk`.

---

## Invocation Modes

| Mode | Description | When to use |
|---|---|---|
| **Self-hosted local** | Proof server at `localhost:6300`; DApp or test suite constructs `httpClientProofProvider("http://localhost:6300", zkConfigProvider)` | Local development; devnet; CI pipelines |
| **Wallet-delegated** | The wallet extension (e.g. Lace) supplies proving on the user's behalf via `dappConnectorProofProvider`; DApp does not connect to a proof server directly | Browser DApps where users have a Midnight wallet; see `midnight-wallet:wallet-sdk` |
| **CI / headless** | Self-hosted with `--no-fetch-params` and reduced `--num-workers` to cap resource use | Automated test runs; pre-cached params scenarios |
| **Remote / production** | Proof server behind a reverse proxy; URI passed as a runtime configuration value | Staging/production DApps; multi-user environments |

> Detailed deployment and hardening notes are in `references/network-and-deployment.md` and `proof-server:proof-server-operations`.

---

## Client-Server Contract

### Request and Response

`ProofProvider.proveTx()` POSTs a binary-encoded proof request to `/prove` and receives a binary-encoded proof response. The encoding is handled entirely by the SDK — application code only sees typed TypeScript values.

For the binary serialization format and endpoint details, see `proof-server:proof-server-api`.

### CORS

The proof server uses **`Cors::permissive()`**: all origins are accepted, no credential restrictions. This is appropriate for local/internal use. For public or multi-tenant deployments, place the server behind a reverse proxy that enforces allowed origins.

### Backpressure

| HTTP status | Meaning | What to do |
|---|---|---|
| `503 Service Unavailable` | Worker pool saturated; server is too busy | Back off and retry; check `/ready` for utilisation |
| `429 Too Many Requests` | Rate-limited (if proxy layer enforces limits) | Respect `Retry-After` header |

For status-code details, see `proof-server:proof-server-api` (status-codes reference) and `midnight-status-codes:status-codes`.

### Version Compatibility

The SDK, proof server, and Compact compiler must be kept in sync. Version mismatches are a common source of proof generation failures.

```text
Compact compiler version
  → determines proof version string (GET /proof-versions)
  → must match proof server's supported proof versions
  → must match SDK's expected proof format
```

Check `/proof-versions` on the running server to confirm compatibility. See `proof-server:proof-server-operations` for diagnosing version mismatch errors.

---

## Deployment

For production hardening (reverse proxy, TLS, CORS restrictions, load-balancer health probes), see:

- `references/network-and-deployment.md` — deployment modes and production checklist
- `proof-server:proof-server-operations` — monitoring, scaling, and troubleshooting

For Docker images and configuration flags (`--port`, `--num-workers`, `--no-fetch-params`), see `midnight-tooling:proof-server` and `proof-server:proof-server-configuration`.

---

## References

| Name | Description | When used |
|---|---|---|
| `references/network-and-deployment.md` | Deployment modes, production hardening, reverse proxy, CORS context | Choosing a deployment mode; production checklist |

---

## Cross-references

| Skill | What it covers |
|---|---|
| `midnight-dapp-dev:core` | Full DApp provider assembly including where `httpClientProofProvider` fits |
| `midnight-dapp-dev:midnight-sdk` | `ProofProvider` type, `httpClientProofProvider`, `dappConnectorProofProvider`, SDK packages |
| `midnight-wallet:wallet-sdk` | Wallet-delegated proving via `dappConnectorProofProvider` |
| `midnight-tooling:proof-server` | Docker setup, version-tag selection, running the server |
| `proof-server:proof-server-api` | Full HTTP API: endpoints, binary serialization, status codes, CORS policy |
| `proof-server:proof-server-operations` | Monitoring, health checks, troubleshooting, scaling, version compatibility |
