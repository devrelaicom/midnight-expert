---
name: midnight-indexer:indexer-data-model
description: This skill should be used when the user asks about the indexer data model, what the indexer indexes, indexer schema, contract actions, unshielded UTXOs, ledger events, DUST generation, Decentralized Unshielded Staking Token, SPO data, blocks table, transactions table, zswap events, indexer database, or the contract action lifecycle. Covers "what tables does the indexer have", "indexer entity relationships", and "what data does the indexer store".
version: 0.1.0
---

# Indexer Data Model

The Midnight indexer extracts and stores on-chain data into a relational database, making it queryable through the GraphQL API. This skill covers what gets indexed, the database schema, and the relationships between entities.

## What Gets Indexed

The indexer processes every finalized block and extracts nine categories of data:

1. **Blocks** — Hash, height, timestamp, author, parent hash, protocol version
2. **Transactions** — Regular and System variants with hashes, identifiers, raw content, and Merkle tree roots
3. **Contract actions** — Deploy, Call, and Update events with contract address, state, zswap state, and entry point
4. **Contract balances** — Unshielded token balances per contract action
5. **Unshielded UTXOs** — Creation and spending tracking, owner addresses, token types, DUST registration status
6. **Ledger events** — Zswap events (inputs/outputs) and DUST events (initial UTXOs, dtime updates, spend processing, parameter changes)
7. **DUST generation** — cNIGHT registrations from Cardano, generation rate and capacity tracking
8. **System parameters** — D-parameter and Terms & Conditions history (both stored in the `system_parameters_d` table)
9. **SPO data** — Identities, committee membership, epoch performance, stake distribution, pool metadata

## Database Schema

### Core Tables

| Table | Purpose |
|-------|---------|
| `blocks` | Block metadata — hash, height, timestamp, block author |
| `transactions` | Transaction records — variant (Regular/System), hash, raw bytes |
| `regular_transactions` | Extended data for regular transactions — result, Merkle root, fees |

### Contract Tables

| Table | Purpose |
|-------|---------|
| `contract_actions` | Deploy, Call, and Update events — contract address, state snapshot |
| `contract_balances` | Token balances associated with each contract action |

### Token and UTXO Tables

| Table | Purpose |
|-------|---------|
| `unshielded_utxos` | UTXO lifecycle tracking — creation, spending, owner address, token type |
| `ledger_events` | Zswap events (inputs/outputs) and DUST events |
| `dust_generation_info` | NIGHT UTXO tracking for DUST generation |
| `cnight_registrations` | Cardano stake key to Midnight address mappings |

### Wallet Tables

| Table | Purpose |
|-------|---------|
| `wallets` | Wallet sessions with encrypted viewing keys |
| `relevant_transactions` | Wallet-to-transaction association for shielded scanning |

When a wallet connects via the `connect` mutation, its viewing key is encrypted using `APP__INFRA__SECRET` and stored in the `wallets` table. The wallet-indexer then scans each new block, attempting to decrypt transaction outputs with the viewing key. Transactions that decrypt successfully are "relevant" to that wallet and inserted into `relevant_transactions`, a many-to-many join table linking `wallets` to `transactions`. This join table enables the `shieldedTransactions` subscription to stream only the transactions a specific wallet can view.

### Governance and SPO Tables

| Table | Purpose |
|-------|---------|
| `system_parameters_d` | D-parameter history (governance) |
| `epochs` | Epoch boundary records |
| `spo_identity` | Stake pool operator identity records |
| `committee_membership` | SPO committee membership tracking |

## Entity Relationships

```text
blocks
  └── transactions (1:N)
        ├── regular_transactions (1:1, for Regular variant)
        │     └── contract_actions (1:N)
        │           ├── contract_balances (1:N)
        │           └── unshielded_utxos (1:N)
        └── ledger_events (1:N)
              ├── zswap events (inputs/outputs)
              └── dust events

wallets
  └── relevant_transactions (N:M with transactions)
```

## Contract Action Lifecycle

Contract actions follow a defined lifecycle tracked by the indexer:

```text
Deploy ──→ Call ──→ Call ──→ ... ──→ Update
  │          │        │                 │
  │          │        │                 │
  ▼          ▼        ▼                 ▼
Initial    Entry    Entry           New verifier
state      point    point           keys / state
           exec     exec
```

| Action | Description |
|--------|-------------|
| **Deploy** | Contract is deployed to the network with initial state and verifier keys |
| **Call** | Contract entry point is invoked, state is updated |
| **Update** | Contract verifier keys or operations are updated |

Each action records:
- The contract address
- The resulting contract state
- The resulting zswap state
- The parent transaction
- Any unshielded token balances

## Transaction Variants

| Variant | Description |
|---------|-------------|
| **Regular** | User-submitted transactions with ZK proofs, contract calls, and token operations |
| **System** | Protocol-generated transactions (epoch boundaries, parameter updates) |

Regular transactions include additional fields:
- `result` — SUCCESS, PARTIAL_SUCCESS, or FAILURE
- `merkle_root` — Commitment tree root at time of transaction
- `fees` — Paid and estimated fees

## Unshielded UTXO Tracking

The indexer tracks the full lifecycle of unshielded UTXOs:

```text
Created (in contract action)
  │
  ├── Owner address recorded
  ├── Token type recorded
  ├── DUST registration status tracked
  │
  ▼
Spent (in later transaction)
  │
  └── Spending transaction recorded
```

## DUST Generation Data

The indexer tracks DUST (Decentralized Unshielded Staking Token) generation:
- **cNIGHT registrations** — Cardano stake keys mapped to Midnight addresses
- **Generation rate** — How quickly DUST accrues
- **Capacity** — Maximum DUST that can be generated
- **Initial UTXOs, dtime updates, spend processing, parameter changes** — All tracked as DUST ledger events

## Cross-References

- `compact-core:compact-tokens` — Token types and shielded/unshielded semantics
- `compact-core:compact-transaction-model` — Transaction structure and execution phases
- `core-concepts:data-models` — UTXO model fundamentals and ledger structure
- `midnight-indexer:indexer-graphql-api` — Querying indexed data via GraphQL
