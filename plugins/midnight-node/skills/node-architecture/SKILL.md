---
name: midnight-node:node-architecture
description: Midnight node architecture, Substrate runtime, Polkadot SDK, pallets, consensus, AURA, GRANDPA, BEEFY, MMR, ledger storage, ParityDB, transaction lifecycle, ZK proof verification, Cardano integration, partner chains, cNIGHT bridging, transaction filtering, throttle pallet, source layout, epoch, block production, finality, light client, how does the Midnight node produce blocks, what pallets does Midnight use, how do transactions flow through the node, how does Midnight connect to Cardano.
version: 0.1.0
---

# Node Architecture

The Midnight node is a Substrate-based blockchain client built on Polkadot SDK (polkadot-stable2509) and the Cardano Partner Chain framework (v1.8.1). It produces blocks, finalizes them, verifies ZK proofs, manages ledger state, and bridges to the Cardano mainchain.

**Current version:** node-0.22.0 — These version identifiers track upstream releases and may change with new Midnight releases.

## Source Layout

```text
midnight-node/
├── node/           # Client binary — networking, RPC server, service wiring
├── runtime/        # WASM runtime — pallet composition, runtime API, genesis
├── pallets/        # Custom pallets — Midnight-specific on-chain logic
├── primitives/     # Shared types — block, transaction, address, crypto
├── ledger/         # Custom ledger storage — ParityDB-backed, ZK state
├── res/            # Static resources — chain specs, genesis configs
│   └── cfg/        # Network-specific TOML configuration presets
└── ...
```

## Runtime Pallets (approximately 28)

The runtime composes approximately 28 pallets organized by function. The exact count depends on how umbrella entries (such as partner chain bridge pallets) are counted individually.

### Standard Substrate

| Pallet | Purpose |
|--------|---------|
| `frame_system` | Core runtime framework — accounts, events, block context |
| `pallet_timestamp` | On-chain time via inherent extrinsics |
| `pallet_preimage` | Store and manage preimages for hashed proposals |
| `pallet_balances` | Account balance management |
| `pallet_transaction_payment` | Fee calculation and payment |
| `pallet_sudo` | Superuser dispatch for development/testing |
| `pallet_utility` | Batch calls and proxy dispatch |
| `pallet_scheduler` | Scheduled dispatch of calls at future blocks |

### Consensus

| Pallet | Purpose |
|--------|---------|
| `pallet_aura` | AURA block production — round-robin slot assignment |
| `pallet_grandpa` | GRANDPA deterministic finality gadget |
| `pallet_beefy` | BEEFY bridge protocol for light client proofs |
| `pallet_mmr` | Merkle Mountain Range for light client state proofs |

### Partner Chains (Cardano Integration)

| Pallet | Purpose |
|--------|---------|
| `pallet_sidechain` | Sidechain registration and cross-chain message handling |
| `pallet_session_validator_management` | Validator set rotation synced from Cardano mainchain |
| `sp_session_validator_management_query` | Query interface for session/validator data |
| Partner chain bridge pallets | cNIGHT bridging and cross-chain token transfers |

### Midnight-Specific

| Pallet | Purpose |
|--------|---------|
| `pallet_midnight` | Core Midnight logic — transaction processing, ZK proof verification, ledger API |
| `pallet_midnight_system` | System-level Midnight operations — epoch transitions, parameter management |
| `pallet_node_version` | On-chain node version tracking and compatibility checks |
| `pallet_cnight_observation` | cNIGHT cross-chain observation and validation |
| `pallet_system_parameters` | On-chain governance parameters — D-parameter, Terms & Conditions |
| `pallet_throttle` | Transaction rate limiting — max bytes over a sliding window |

### Governance

| Pallet | Purpose |
|--------|---------|
| `pallet_collective` (Council) | Council governance body — motions and voting |
| `pallet_collective` (TechnicalCommittee) | Technical committee governance body |
| `pallet_federated_authority` | Two-body federated governance — requires both Council and TechnicalCommittee approval |

## Consensus Mechanism

The Midnight node uses a layered consensus architecture.

```text
┌──────────────────────────────────────────────────────┐
│                   Light Clients                       │
│          BEEFY (ECDSA) + MMR state proofs            │
├──────────────────────────────────────────────────────┤
│                     Finality                          │
│           GRANDPA (Ed25519 signatures)                │
│       Justification period: 512 blocks               │
├──────────────────────────────────────────────────────┤
│                  Block Production                     │
│         AURA (Sr25519, round-robin slots)             │
│    Block time: 6 seconds, 300 slots/epoch            │
└──────────────────────────────────────────────────────┘
```

### AURA (Block Production)

- **Algorithm:** Round-robin slot assignment among registered authorities
- **Key type:** Sr25519
- **Block time:** 6 seconds per slot
- **Epoch length:** 300 slots (30 minutes)

### GRANDPA (Finality)

- **Algorithm:** Deterministic finality via Byzantine agreement
- **Key type:** Ed25519
- **Justification period:** Every 512 blocks, GRANDPA produces a finality proof
- **Behavior:** Finalizes chains of blocks, not individual blocks

### BEEFY (Bridge Protocol)

- **Algorithm:** Best effort to extend finality for bridge proofs
- **Key type:** ECDSA (secp256k1)
- **Purpose:** Produces compact finality proofs for light clients and cross-chain bridges

### MMR (Merkle Mountain Range)

- **Purpose:** Append-only authenticated data structure for light client state proofs
- **Usage:** Light clients verify on-chain state without downloading the full chain

## Ledger Storage

The Midnight node maintains a custom ledger separate from the standard Substrate state trie. This ledger stores ZK-specific state including commitment trees, nullifier sets, and contract states.

- **Storage engine:** Custom ParityDB-based implementation
- **Separation:** Ledger state is distinct from Substrate's key-value state storage
- **Versions:** Supports v7 and v8 ledger formats
- **Contents:** Zswap state roots, contract states, commitment trees, nullifier sets

## Transaction Lifecycle

```text
Client                    Node                        Runtime
  │                        │                            │
  │  send_mn_transaction   │                            │
  │───────────────────────→│                            │
  │                        │  LedgerApi::apply_transaction()
  │                        │───────────────────────────→│
  │                        │                            │  ZK proof verification
  │                        │                            │  Nullifier check
  │                        │                            │  Contract state update
  │                        │                            │  Commitment tree update
  │                        │←───────────────────────────│
  │                        │  Events emitted            │
  │                        │  (contract actions,        │
  │                        │   ledger events)           │
  │←───────────────────────│                            │
  │  Transaction hash      │                            │
```

1. **Submission:** Client sends a transaction via `send_mn_transaction` RPC
2. **Pool filtering:** `FilteringTransactionPool` validates the transaction against `CheckCallFilter` rules
3. **Application:** `LedgerApi::apply_transaction()` processes the transaction in the runtime
4. **ZK verification:** Zero-knowledge proof is verified against the circuit's verification key
5. **State update:** Nullifiers are consumed, commitments are added, contract state is updated
6. **Events:** Runtime events are emitted for contract actions and ledger state changes

## Transaction Filtering

The node implements multi-layer transaction filtering to protect against spam and resource exhaustion.

| Layer | Mechanism | Purpose |
|-------|-----------|---------|
| `FilteringTransactionPool` | Custom transaction pool implementation | Rejects transactions before they enter the pool |
| `CheckCallFilter` | Signed extension | Validates transaction calls against allow/deny rules |
| `pallet_throttle` | Runtime pallet | Rate-limits transaction throughput by total bytes over a sliding window |

The Throttle pallet enforces a configurable maximum number of transaction bytes within a rolling window, preventing any single block or burst from overwhelming the network.

## Cardano Integration

The Midnight node connects to the Cardano mainchain through a PostgreSQL database backed by `db-sync`.

```text
Cardano Node ──→ db-sync ──→ PostgreSQL ←── Midnight Node
                                              (main chain follower)
```

### Key Integration Points

| Feature | Details |
|---------|---------|
| **Connection** | PostgreSQL connection to Cardano db-sync instance |
| **cNIGHT bridging** | Observes Cardano UTXOs for cNIGHT lock transactions |
| **Transfer limits** | Maximum 256 cNIGHT transfers per Midnight block |
| **Governance sync** | Council and TechnicalCommittee membership read from Cardano mainchain UTXOs |
| **Validator management** | Validator set rotation driven by Cardano epoch transitions |
| **Mock mode** | `use_main_chain_follower_mock=true` for development without Cardano |

## Cross-References

- `midnight-tooling:devnet` — Manages the node as part of the local development stack
- `compact-core:compact-transaction-model` — Transaction structure and execution model from the Compact language perspective
- `core-concepts:architecture` — High-level Midnight network architecture and component relationships
