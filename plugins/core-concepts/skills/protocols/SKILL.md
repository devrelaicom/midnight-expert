---
name: core-concepts:protocols
description: This skill should be used when the user asks about Kachina smart contract protocol, Zswap token transfers, atomic swaps, shielded transfers, offers, coins, nullifiers, commitments, confidential smart contracts, the two-state model (public/private state), token minting, how ZK proofs enable privacy in Midnight protocol transactions, or private transaction mechanisms.
version: 0.1.0
---

# Midnight Protocols

Midnight uses two foundational protocols: **Kachina** for data-protecting smart contracts and **Zswap** for shielded token transfers.

## Protocol Selection

| Need | Protocol |
|------|----------|
| Smart contract logic | Kachina |
| Token transfers | Zswap |
| Atomic multi-party swaps | Zswap |
| Private computation | Kachina |
| Shielded coins | Zswap |

## Kachina Protocol

Kachina enables confidential, general-purpose smart contracts while maintaining decentralization.

### Core Architecture

```text
┌─────────────────────────────────────────┐
│           On-Chain (Public)             │
│  - Contract code                        │
│  - Public state                         │
│  - Merkle roots                         │
└─────────────────────────────────────────┘
              ^ ZK Proofs ^
┌─────────────────────────────────────────┐
│           Off-Chain (Private)           │
│  - User's private inputs                │
│  - Local state                          │
│  - Witness data                         │
└─────────────────────────────────────────┘
```

### Two-State Model

| State Type | Location | Visibility |
|------------|----------|------------|
| Public state | Blockchain | Everyone |
| Private state | User's machine | Owner only |

ZK proofs bridge these states: prove something about private state without revealing it.

### How Kachina Works

1. User submits command to contract
2. User maintains transcript of interactions (queries + expected responses)
3. ZK proof validates transcript correctness
4. Public effects applied to blockchain

### Key Properties

| Property | Benefit |
|----------|---------|
| Concurrency | Multiple users act simultaneously without blocking |
| Privacy | Private state never leaves user's machine |
| Composability | Contracts interact via public state (cross-contract calls still under development) |
| Reordering | Conflicting transactions optimally reordered |

### Use Cases

- DeFi protocols with confidential balances and private trade execution
- Supply chain verification with confidential commercial data
- Healthcare systems with patient privacy via selective disclosure
- Any computation mixing public coordination with private user data

## Zswap Protocol

Zswap is a shielded token mechanism for confidential atomic swaps, based on Zerocash.

### Core Concept

```text
Zswap Offer = Inputs + Outputs + Transient + Deltas
```

- **Inputs**: Coins being spent (nullifiers)
- **Outputs**: New coins being created (commitments)
- **Transient**: Coins created and spent in same transaction
- **Deltas**: Net value change per token type (signed)

### Transaction Privacy

| Hidden | Visible |
|--------|---------|
| Sender | Transaction occurred |
| Receiver | Proof validity |
| Amount | Fee payment |
| Token type (can be) | Nullifiers (unlinkable) |

### Offer Structure

```text
Offer {
  inputs: [
    { nullifier, type_value_commit, merkle_proof, zk_proof }
  ],
  outputs: [
    { commitment, type_value_commit, optional_contract, optional_ciphertext, zk_proof }
  ],
  transient: [...],
  deltas: Map<string, bigint>
}
```

### Atomic Swaps

Zswap enables multi-party atomic exchanges:

```text
Party A: Offers 10 TokenX
Party B: Offers 5 TokenY
            |
    Merged off-chain
            |
   Single atomic transaction
   (Either both happen or neither)
```

### Merging Rules

Two transactions can merge if at least one has an empty contract call section. Coin sets must be disjoint. Merged transaction combines:
- All inputs (coins spent)
- All outputs (coins created)
- Balanced delta vectors

### Integration with Contracts

Contracts issue custom tokens via Zswap:

```text
Token type = Hash(domain_separator, contract_address)
Contract can mint/burn tokens through Zswap stdlib operations
```

### Zswap Outputs

New coins are created as hash-based commitments (`Hash(CoinInfo, ZswapCoinPublicKey)`), paired with a separate Pedersen value commitment for balance verification. See `references/zswap-internals.md` for the complete output structure.

> **Important**: The coin commitment is hash-based, not a Pedersen commitment. The `type_value_commit` field is a separate Pedersen commitment used only for balance verification.

### Zswap Inputs

Coins are spent by publishing a nullifier (`Hash(CoinInfo, ZswapCoinSecretKey)`) with a Merkle proof of commitment existence and a ZK validity proof. The commitment itself is NOT an input to nullifier computation, making nullifiers unlinkable to the original commitment. See `references/zswap-internals.md` for the complete input structure.

> **Critical**: The nullifier is computed from CoinInfo and the secret key -- the commitment itself is NOT an input to nullifier computation. This makes nullifiers unlinkable to the original commitment without knowledge of the secret key.

## Protocol Interaction

```text
┌──────────────────────────────────────────┐
│              Transaction                  │
├──────────────────────────────────────────┤
│  Zswap Section        |  Contract Section │
│  - Guaranteed offer   |  - Contract calls │
│  - Fallible offer     |  - ZK proofs      │
│  (Token transfers)    |  (State changes)  │
└──────────────────────────────────────────┘
```

Transactions combine Zswap (value movement) with Kachina (computation).

- **Guaranteed offer**: Token operations that must succeed for the transaction to be valid. Fees are collected here. Effects always persist.
- **Fallible offer**: Optional token operations that may fail without affecting the guaranteed section. Used for operations that depend on external state (swaps, conditional transfers).

See `core-concepts:architecture` for the full three-phase execution model.

## Practical Application

### Simple Transfer

```text
1. Create Zswap offer with:
   - Input: Your coin (nullifier + proof)
   - Output: Recipient's new coin (commitment)
   - Deltas: Must net to non-negative (excess becomes fees)
2. Submit transaction
```

### Atomic Swap

```text
1. Party A creates partial offer: NIGHT: +10, TokenX: -10
   // Positive delta = inputs exceed outputs = giving that token type
2. Party B creates partial offer: TokenX: +10, NIGHT: -10
   // Bob gives TokenX, wants NIGHT
3. Merge offers (deltas sum to zero — balanced)
4. Submit single transaction
5. Both transfers atomic
```

### Contract + Transfer

```text
1. Zswap offer moves tokens
2. Contract call updates state
3. Both bound cryptographically
4. Atomic execution
```

## References

For detailed technical information:
- **`references/kachina-deep-dive.md`** - UC security model, transcript validation
- **`references/zswap-internals.md`** - Coin commitments, value commitments, offer construction

## Examples

Working patterns:
- **`examples/basic-transfer.md`** - Simple shielded transfer
- **`examples/atomic-swap.md`** - Multi-party atomic exchange
