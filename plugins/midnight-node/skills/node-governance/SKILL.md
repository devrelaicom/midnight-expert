---
name: node-governance
description: Midnight governance, federated authority, Council, TechnicalCommittee, Technical Committee, Substrate, pallet, governance motions, voting, proposals, two-body governance, runtime upgrades, D-parameter, systemParameters_getDParameter, pallet_system_parameters, validator selection balance, membership, Cardano mainchain governance sync, motion lifecycle, approval threshold, 5-day voting window, governance root operations, how does voting work on Midnight, how are governance members selected.
version: 0.1.0
---

# Node Governance

The Midnight network uses a federated authority governance model implemented on-chain through Substrate pallets. Governance controls critical operations such as runtime upgrades, system parameter changes, and validator set management.

## Federated Authority Model

Governance uses a two-body system where both bodies must independently approve an action for it to take effect.

```text
┌─────────────────────┐     ┌──────────────────────────┐
│       Council       │     │  Technical Committee     │
│                     │     │                          │
│  General governance │     │  Technical assessment    │
│  oversight          │     │  and validation          │
│                     │     │                          │
│  2/3 majority       │     │  2/3 majority            │
│  required           │     │  required                │
└────────┬────────────┘     └─────────┬────────────────┘
         │                            │
         │      Both must approve     │
         └──────────┬─────────────────┘
                    │
                    ▼
         ┌──────────────────┐
         │  Root Operation  │
         │  Executed        │
         └──────────────────┘
```

### Council

- **Role:** General governance oversight and policy decisions
- **Composition:** Members synced from Cardano mainchain UTXOs
- **Voting threshold:** 2/3 majority of council members

### Technical Committee

- **Role:** Technical assessment and validation of proposed changes
- **Composition:** Members synced from Cardano mainchain UTXOs
- **Voting threshold:** 2/3 majority of committee members

## Motion Lifecycle

Every governance action follows a defined lifecycle from proposal to execution.

```text
Propose ──→ Vote ──→ Approve ──→ Close
   │          │         │          │
   │          │         │          │
   ▼          ▼         ▼          ▼
Motion     Members   2/3 super-  Execute if
created    cast      majority    both bodies
on-chain   votes     reached     approved
                                 (5-day window)
```

### Stages

| Stage | Description |
|-------|-------------|
| **Propose** | A member of either body submits a motion (a callable dispatch) |
| **Vote** | Members of the originating body cast Aye or Nay votes |
| **Approve** | The motion passes if it reaches a 2/3 supermajority |
| **Close** | After both bodies approve, the motion is executed within a 5-day voting window |

### Voting Rules

| Rule | Value |
|------|-------|
| Approval threshold | 2/3 majority in each body |
| Voting window | 5 days from proposal |
| Both bodies required | Yes — a motion approved by only one body does not execute |
| Execution | Automatic upon close if both bodies have approved |

### Motion Failure Paths

| Scenario | Outcome |
|----------|---------|
| Motion does not reach 2/3 threshold within the voting window | Motion expires without effect; no on-chain state changes occur |
| One body approves but the other rejects or fails to reach threshold | Proposal fails; the approval from the first body is not carried forward. A fresh motion must be submitted to retry |

## Governance Membership

Governance body membership is not managed on the Midnight chain directly. Instead, membership is synchronized from the Cardano mainchain.

```text
Cardano Mainchain
    │
    │  UTXOs designating governance members
    │
    ▼
Midnight Node (main chain follower)
    │
    │  Reads and validates membership UTXOs
    │
    ▼
On-chain Governance Pallets
    │
    ├── Council membership updated
    └── TechnicalCommittee membership updated
```

This design anchors governance authority in the Cardano mainchain, ensuring that governance membership changes follow Cardano's own security and finality guarantees.

## Governed Operations

The federated authority model governs the following critical operations:

| Operation | Description |
|-----------|-------------|
| **Runtime upgrades** | Deploy new WASM runtime to upgrade on-chain logic |
| **System parameter changes** | Modify D-parameter, Terms & Conditions, and other chain parameters |
| **Critical system operations** | Emergency actions requiring root-level dispatch |

### Runtime Upgrades

Runtime upgrades replace the on-chain WASM runtime without requiring a hard fork. Both governance bodies must approve the upgrade motion containing the new runtime blob.

```text
New Runtime WASM
    │
    ▼
Council Motion (propose + 2/3 approve)
    │
    ▼
TechnicalCommittee Motion (propose + 2/3 approve)
    │
    ▼
Runtime Upgrade Executed
(new WASM runtime active at next block)
```

## D-Parameter

The D-parameter controls the balance between permissioned (federated) validators and permissionless (staked) validators in block production.

| D Value | Effect |
|---------|--------|
| `1.0` | Fully federated — only permissioned validators produce blocks |
| `0.0` | Fully permissionless — only staked validators produce blocks |
| Between | Mixed — proportional blend of permissioned and permissionless validators |

The D-parameter is stored on-chain via `pallet_system_parameters` and can be queried via the `systemParameters_getDParameter` RPC method. Changes to the D-parameter require governance approval through the federated authority process.

## Cross-References

- `core-concepts:architecture` — High-level network architecture and the role of governance in the Midnight ecosystem
- `midnight-indexer:indexer-data-model` — Indexed governance data including D-parameter history and Terms & Conditions
- `midnight-node:node-architecture` — Governance pallets and their role in the runtime
- `midnight-node:node-rpc-api` — RPC methods for querying governance parameters
