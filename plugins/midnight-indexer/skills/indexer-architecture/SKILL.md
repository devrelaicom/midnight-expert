---
name: indexer-architecture
description: This skill covers indexer architecture, components, chain-indexer, wallet-indexer, indexer-api, spo-indexer, standalone mode, cloud mode, configuration, deployment, storage, PostgreSQL vs SQLite, NATS, telemetry, or node connection. Covers "how does the indexer connect to a node", "what database does the indexer use", "how to run the indexer locally", "choosing between standalone and cloud deployment", and "indexer data flow".
version: 0.1.0
---

# Indexer Architecture

The Midnight indexer is a Rust application (edition 2024) built with async-graphql, axum, and subxt. It connects to a Midnight node via WebSocket, indexes on-chain data into a database, and exposes it through a GraphQL API.

**Current version:** 4.0.0 (released 2026-03-17)

## Component Overview

```text
┌──────────────────────────────────────────────────────────────────┐
│                      Midnight Indexer                            │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌────────────────┐   ┌────────────────┐   ┌────────────────┐   │
│  │ chain-indexer  │──→│       DB       │←──│  indexer-api   │   │
│  │ (node via WS)  │   │ (Postgres/     │   │  (GraphQL      │   │
│  │                │   │  SQLite)       │   │   :8088)       │   │
│  └────────────────┘   └────────────────┘   └────────────────┘   │
│                                                                  │
│  ┌────────────────┐   ┌────────────────┐   ┌────────────────┐   │
│  │ wallet-indexer │   │  spo-indexer   │   │ indexer-common │   │
│  │ (wallet        │   │ (stake pool    │   │ (shared types/ │   │
│  │  correlation)  │   │  via Blockfrost│   │  migrations)   │   │
│  └────────────────┘   └────────────────┘   └────────────────┘   │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ indexer-standalone (all-in-one with SQLite)              │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

## Components

| Component | Purpose |
|-----------|---------|
| `chain-indexer` | Connects to node via WebSocket, subscribes to new blocks, writes indexed data to DB |
| `wallet-indexer` | Manages wallet sessions using encrypted viewing keys (`APP__INFRA__SECRET`), scans blocks for relevant shielded transactions |
| `indexer-api` | Serves the GraphQL API on port 8088 |
| `spo-indexer` | Indexes stake pool operator data via Blockfrost |
| `indexer-standalone` | All-in-one binary bundling all components with SQLite storage |
| `indexer-common` | Shared types, database migrations, and utilities |

## Data Flow

```text
Midnight Node (ws://localhost:9944)
        │
        ▼
  Chain Indexer ──→ Database (PostgreSQL or SQLite)
                         │
                         ▼
                    Indexer API (GraphQL :8088)
                         │
                         ▼
                    DApp / Wallet
```

## Deployment Modes

### Cloud Mode

- **Storage:** PostgreSQL 17
- **Messaging:** NATS for inter-component pub-sub (see [NATS Messaging](#nats-messaging-cloud-mode) below)
- **Components:** Run chain-indexer, wallet-indexer, indexer-api, and spo-indexer as separate services
- **Use case:** Production deployments, high availability

### Standalone Mode

- **Storage:** SQLite (single file)
- **Components:** Single `indexer-standalone` binary bundles everything
- **Use case:** Local development, devnet, testing

### Deployment Mode Comparison

| Aspect | Standalone | Cloud |
|--------|-----------|-------|
| Storage | SQLite (single file) | PostgreSQL 17 |
| Messaging | In-process (Tokio broadcast) | NATS |
| Scaling | Single process | Horizontal (separate services) |
| Use case | Local dev, devnet, testing | Production, high availability |

## NATS Messaging (Cloud Mode)

In cloud mode, the indexer components run as separate processes and use [NATS](https://nats.io/) (v2.12.x) as a lightweight pub-sub bus for inter-component event notification. In standalone mode, the same pub-sub interface is implemented with in-process Tokio broadcast channels — NATS is not used.

### Message Types

| Message | Published by | Subscribed by | Purpose |
|---------|-------------|---------------|---------|
| `BlockIndexed` | `chain-indexer` | `wallet-indexer`, `indexer-api` | Signals a block has been indexed; carries `height`, optional `max_transaction_id`, `caught_up` flag |
| `WalletIndexed` | `wallet-indexer` | `indexer-api` | Signals new relevant transactions for a wallet session; carries `wallet_id` |
| `UnshieldedUtxoIndexed` | `chain-indexer` | `indexer-api` | Signals unshielded UTXOs indexed for a specific address; carries `address` |

The `spo-indexer` does not use NATS.

NATS subjects follow the pattern `pub-sub.<MessageType>` (e.g., `pub-sub.BlockIndexed`). Messages are JSON-serialized.

### Configuration

| Environment Variable | Purpose | Default |
|---------------------|---------|---------|
| `APP__INFRA__PUB_SUB__URL` | NATS server address | `localhost:4222` |
| `APP__INFRA__PUB_SUB__USERNAME` | Authentication username | `indexer` |
| `APP__INFRA__PUB_SUB__PASSWORD` | Authentication password | *(required, no default)* |
| `APP__INFRA__PUB_SUB__MAX_RECONNECTS` | Reconnection attempts after disconnect | `4` |

In Docker deployments, the NATS server runs with `--user indexer --pass <password> -js`. Connections are plaintext (no TLS).

### Failure Modes

| Scenario | Behavior |
|----------|----------|
| NATS unavailable at startup | Process exits with connection error — no retry loop on initial connect |
| NATS disconnects after startup | `async-nats` attempts up to `max_reconnects` (default 4) reconnections automatically |
| Subscriber stream completes | Self-healing outer stream resubscribes every 100ms until NATS is available |
| Publisher fails to publish | Error propagates up; chain-indexer stops block indexing, wallet-indexer stops wallet task |
| Subscriber is down when message published | Message is lost (core NATS, not JetStream); component catches up by polling the database on reconnect |
| Slow consumer | Logged as warning; NATS may drop messages for the slow subscriber |

### NATS Events Logged

| Event | Log Level |
|-------|-----------|
| `Connected` | DEBUG |
| `Disconnected` | WARN |
| `LameDuckMode` | WARN |
| `Draining` | WARN |
| `Closed` | WARN |
| `SlowConsumer` | WARN |
| `ServerError` | WARN |
| `ClientError` | WARN |

## Configuration

All configuration uses environment variables with the `APP__` prefix and double-underscore nesting.

### Core Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `APP__APPLICATION__NETWORK_ID` | `undeployed` | Network identifier |
| `APP__INFRA__STORAGE__CNN_URL` | `/data/indexer.sqlite` | SQLite path (standalone) or PostgreSQL connection URL (cloud) |
| `APP__INFRA__NODE__URL` | `ws://localhost:9944` | Node WebSocket endpoint |
| `APP__INFRA__API__PORT` | `8088` | GraphQL API port |
| `APP__INFRA__SECRET` | (required) | 32-byte hex encryption secret for wallet viewing keys |

Generate a secret: `openssl rand -hex 32`

### Operational Parameters

| Parameter | Value | Description |
|-----------|-------|-------------|
| `blocks_buffer` | 10 | Number of blocks to buffer during indexing |
| `caught_up_max_distance` | 10 | Max blocks behind tip to consider "caught up" |
| `active_wallets_ttl` | 30 minutes | Time-to-live for inactive wallet sessions |
| `transaction_batch_size` | 50 | Transactions processed per batch |
| Node reconnection | Exponential backoff, max 30 attempts | Automatic reconnection on WebSocket disconnect |
| Subscription recovery timeout | 30 seconds | Timeout for recovering dropped subscriptions |

## Node Connection

The indexer connects to a Midnight node via WebSocket on port 9944 using the `subxt` Rust library. It subscribes to new finalized blocks and processes them sequentially, extracting transactions, contract actions, and ledger events.

## Telemetry

Both telemetry systems are disabled by default.

| System | Protocol | Default Port | Purpose |
|--------|----------|-------------|---------|
| OpenTelemetry | OTLP | — | Distributed tracing |
| Prometheus | HTTP scrape | 9000 | Metrics collection |

## Cross-References

- `midnight-tooling:devnet` — Manages the indexer as part of the local development stack
- `dapp-development:midnight-sdk` — Uses the indexer as a provider for contract state queries
