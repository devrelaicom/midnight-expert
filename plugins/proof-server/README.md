# proof-server

Deep technical reference for the Midnight proof server -- internal architecture, complete API reference, configuration tuning, and operational monitoring.

## Skills

### proof-server:proof-server-api

Covers the proof server REST API on port 6300 including the /prove, /check, /k, /fetch-params, /health, /ready, and /proof-versions endpoints, request/response formats, binary serialization, status codes, and CORS policy.

### proof-server:proof-server-architecture

Covers the proof server's Rust/actix-web internals including the worker pool, job queue, job lifecycle, proving pipeline, ZKIR versioning (V2/V3), key material management, concurrency control, and the component layout of the midnight-proof-server binary.

### proof-server:proof-server-configuration

Covers all CLI flags and environment variables for the proof server: num-workers, job-capacity, job-timeout, no-fetch-params, port, verbose mode, Docker configuration, memory requirements, and production tuning guidance.

### proof-server:proof-server-operations

Covers monitoring via the /ready endpoint, health check patterns for Docker and Kubernetes, troubleshooting 503/429/400 errors, timeout and memory issues, capacity planning, horizontal scaling, and version compatibility diagnostics.
