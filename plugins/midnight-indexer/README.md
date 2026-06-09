# midnight-indexer

<p align="center">
  <img src="assets/mascot.png" alt="midnight-indexer mascot" width="200" />
</p>

Technical reference for the Midnight indexer -- architecture, GraphQL API, data model, and operational guidance for querying on-chain state.

## Skills

### midnight-indexer:indexer-architecture

Covers the indexer's Rust-based component architecture (chain-indexer, wallet-indexer, indexer-api, spo-indexer), standalone vs cloud deployment modes, database options (PostgreSQL vs SQLite), node connection via WebSocket, and configuration.

#### References

| Name | Description | When it is used |
|------|-------------|-----------------|
| [deployment-and-crates.md](skills/indexer-architecture/references/deployment-and-crates.md) | The seven workspace crates, each binary's role, the `cloud`/`standalone` feature gates, standalone vs cloud topology, and the main-DB / ledger-DB split | When choosing a deployment mode or learning which component does what |
| [nats-messaging.md](skills/indexer-architecture/references/nats-messaging.md) | NATS pub-sub deep-dive: the trait abstraction, both implementations, payload fields, the self-healing subscriber loop, and per-component wiring | When debugging inter-component messaging or implementing against the pub-sub layer |
| [configuration-reference.md](skills/indexer-architecture/references/configuration-reference.md) | The complete `APP__*` env/config catalog from the serde structs and `config.yaml` files, with defaults and standalone-vs-cloud differences | When configuring any indexer component or looking up a key's default |

### midnight-indexer:indexer-data-model

Covers what the indexer indexes across nine data categories (blocks, transactions, contract actions, contract balances, unshielded UTXOs, ledger events, DUST generation, system parameters, and SPO data), the database schema, and entity relationships.

#### References

| Name | Description | When it is used |
|------|-------------|-----------------|
| [database-schema.md](skills/indexer-data-model/references/database-schema.md) | Complete table catalog from the migrations — every column, PK, index, the foreign-key map, and Postgres-vs-SQLite differences | When writing queries against the schema or reasoning about entity relationships |
| [dust-and-spo-data.md](skills/indexer-data-model/references/dust-and-spo-data.md) | DUST-generation and SPO subsystem deep-dive: cNIGHT registrations, QDO/`dtime` model, generation-tree indexes, and the SPO identity/committee/epoch/stake flow | When working with DUST generation data or SPO/stake indexing |

### midnight-indexer:indexer-graphql-api

Covers the GraphQL API for querying on-chain state, managing wallet sessions, and subscribing to real-time events. Includes HTTP and WebSocket endpoints on port 8088, query limits (complexity 200, depth 15), and the v3/v4 API paths.

#### References

| Name | Description | When it is used |
|------|-------------|-----------------|
| [schema-reference.md](skills/indexer-graphql-api/references/schema-reference.md) | Complete schema reference transcribed from `schema-v4.graphql`: all queries, mutations, subscriptions, object types, interfaces, unions, scalars, the enum, and directives | When you need the exact shape, arguments, or nullability of any type or field |
| [graphql-types.md](skills/indexer-graphql-api/references/graphql-types.md) | Key types returned by the indexer GraphQL API (Block, Transaction, etc.) | When constructing queries or understanding the shape of API responses |
| [pagination-and-offsets.md](skills/indexer-graphql-api/references/pagination-and-offsets.md) | Offset-based addressing for queries and subscriptions using BlockOffset and other offset types | When paginating results or specifying starting points for subscriptions |
| [dust-beta-api.md](skills/indexer-graphql-api/references/dust-beta-api.md) | The in-flight `@beta` DUST API surface: `dustGenerations`, the commitment/generation Merkle-tree updates, and the index model | When working with the preview DUST-generation API |
| [error-handling.md](skills/indexer-graphql-api/references/error-handling.md) | Common error responses from the GraphQL API and how to resolve them | When troubleshooting complexity limit, depth limit, or request size errors |

#### Examples

| Name | Description | When it is used |
|------|-------------|-----------------|
| [http-requests.md](skills/indexer-graphql-api/examples/http-requests.md) | Complete curl examples for the indexer GraphQL HTTP endpoint | When making HTTP POST queries against the indexer |
| [websocket-subscriptions.md](skills/indexer-graphql-api/examples/websocket-subscriptions.md) | TypeScript examples using graphql-ws for real-time subscriptions | When setting up WebSocket subscriptions to indexer events |
| [subscription-examples.md](skills/indexer-graphql-api/examples/subscription-examples.md) | Executed `blocks` / `zswapLedgerEvents` / `dustLedgerEvents` walkthroughs with real captured output over `graphql-transport-ws` | When verifying subscription behaviour or debugging the WebSocket protocol |

### midnight-indexer:indexer-operations

Covers running, monitoring, and troubleshooting the indexer — the `/live` and `/ready` health probes, Prometheus metrics and OpenTelemetry tracing, caught-up status, node reconnection and recovery, the wallet-session lifecycle, NATS failure handling, and common failure modes.

#### References

| Name | Description | When it is used |
|------|-------------|-----------------|
| [monitoring-and-troubleshooting.md](skills/indexer-operations/references/monitoring-and-troubleshooting.md) | The observability surface (logs, OTLP tracing, the named Prometheus metrics on port 9000), node reconnect/recovery internals, health checks, log signals, and a common-failure table | When setting up production monitoring or investigating an operational issue |

#### Examples

| Name | Description | When it is used |
|------|-------------|-----------------|
| [running-standalone.md](skills/indexer-operations/examples/running-standalone.md) | Executed walkthrough of inspecting the standalone indexer on the devnet: container status, `/ready` and `/live` probes, a basic query, metrics, and error/transport behaviour | When operating or sanity-checking a standalone indexer |
