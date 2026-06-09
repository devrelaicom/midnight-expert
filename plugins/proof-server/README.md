# proof-server

<p align="center">
  <img src="assets/mascot.png" alt="proof-server mascot" width="200" />
</p>

Deep technical reference for the Midnight proof server -- internal architecture, complete API reference, configuration tuning, and operational monitoring.

## Skills

### proof-server:proof-server-api

Covers the proof server REST API on port 6300 including the /prove, /check, /k, /fetch-params, /health, /ready, and /proof-versions endpoints, request/response formats, binary serialization, status codes, and CORS policy.

#### References

| Name | Description | When it is used |
|------|-------------|-----------------|
| [binary-serialization.md](skills/proof-server-api/references/binary-serialization.md) | The custom tagged binary encoding used by proving endpoints, including the wire format and framing spec | When implementing low-level client code or debugging malformed request/response bodies |
| [status-codes.md](skills/proof-server-api/references/status-codes.md) | HTTP status codes returned by each endpoint and the plain-text or JSON error bodies they carry | When interpreting error responses from /prove, /check, /k, /health, or /ready |

#### Examples

| Name | Description | When it is used |
|------|-------------|-----------------|
| [metadata-endpoints.md](skills/proof-server-api/examples/metadata-endpoints.md) | Runnable curl examples for every metadata and health endpoint with exact captured output | When testing endpoint availability or inspecting version and health responses |
| [constructing-a-prove-request.md](skills/proof-server-api/examples/constructing-a-prove-request.md) | How the SDK assembles and serializes a raw /prove request body, using the integration test pipeline as evidence | When understanding the binary request structure or debugging proof submission failures |

### proof-server:proof-server-architecture

Covers the proof server's Rust/actix-web internals including the worker pool, job queue, job lifecycle, proving pipeline, ZKIR IR-format dispatch (`zkir_v2` / `zkir_v3`), key material management, concurrency control, and the component layout of the midnight-proof-server binary.

#### References

| Name | Description | When it is used |
|------|-------------|-----------------|
| [proving-pipeline.md](skills/proof-server-architecture/references/proving-pipeline.md) | The end-to-end proving pipeline from versioned proof preimage through optional pre-proving check to PLONK proof generation | When tracing how a /prove or /check request is processed internally |
| [key-material.md](skills/proof-server-architecture/references/key-material.md) | How cryptographic public parameters and proving keys are fetched at startup and resolved at runtime | When diagnosing startup latency, missing-params errors, or understanding --no-fetch-params behaviour |

### proof-server:proof-server-configuration

Covers all CLI flags and environment variables for the proof server: num-workers, job-capacity, job-timeout, no-fetch-params, port, verbose mode, Docker configuration, memory requirements, and production tuning guidance.

### proof-server:proof-server-operations

Covers monitoring via the /ready endpoint, health check patterns for Docker and Kubernetes, troubleshooting 503/429/400 errors, timeout and memory issues, capacity planning, horizontal scaling, and version compatibility diagnostics.

#### References

| Name | Description | When it is used |
|------|-------------|-----------------|
| [logging-and-monitoring.md](skills/proof-server-operations/references/logging-and-monitoring.md) | Structured log output, actix access logs, and /ready-based monitoring patterns (no Prometheus endpoint) | When setting up log aggregation, interpreting tracing output, or configuring health probes |

### proof-server:proof-server-integration

Covers how the Midnight proof server is invoked in practice -- who calls it (the `midnight-js` SDK via `ProofProvider`), the client-server contract, self-hosted vs wallet-delegated proving, network proof-server endpoints, production deployment behind a reverse proxy, and CORS. Use for questions about wiring a DApp or SDK to a proof server, `httpClientProofProvider`, `dappConnectorProofProvider`, or choosing a deployment mode.

#### References

| Name | Description | When it is used |
|------|-------------|-----------------|
| [network-and-deployment.md](skills/proof-server-integration/references/network-and-deployment.md) | Deployment modes, production hardening, reverse proxy configuration, CORS context, and image registries | When choosing a deployment mode, hardening a production proof server, or working through a production deployment checklist |
