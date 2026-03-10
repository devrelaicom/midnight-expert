---
name: core-concepts:data-models
description: Use when asking about UTXO vs account models, ledger tokens, shielded/unshielded tokens, nullifiers, coins, balances, or choosing between token paradigms in Midnight.
---

# Midnight Data Models

Midnight supports two distinct token paradigms: **UTXO-based ledger tokens** and **account-based contract tokens**. Choose based on privacy requirements and use case complexity.

## Quick Decision Guide

| Requirement | Use UTXO (Ledger Tokens) | Use Account (Contract Tokens) |
|-------------|--------------------------|-------------------------------|
| Privacy critical | Yes - independent, shieldable | Less native privacy than UTXO; shielded contract tokens in development |
| Parallel processing | Yes - no ordering deps | No - sequential nonce |
| Simple transfers | Yes | Overkill |
| Complex DeFi logic | Limited | Yes |
| Gaming state machines | No | Yes |
| Governance/delegation | No | Yes |

## UTXO Model (Ledger Tokens)

UTXO = Unspent Transaction Output. Each token is a discrete digital coin that must be spent entirely.

### Core Mechanics

```
Creation -> Existence -> Consumption -> Prevention of Reuse
```

1. **Creation**: UTXO born with value, type, and cryptographic commitment: `CoinCommitment = Hash<(CoinInfo, ZswapCoinPublicKey)>`
2. **Existence**: Queryable in the commitment tree
3. **Consumption**: Entire UTXO spent in transaction (change returned as new UTXO)
4. **Prevention**: Nullifier added to global set, prevents double-spend

### Nullifier Innovation

Unlike Bitcoin, which references prior outputs directly by txid+index (revealing which coin was spent), Midnight uses nullifiers:

```
CoinNullifier = Hash<(CoinInfo, ZswapCoinSecretKey)>
```

Where `CoinInfo = { value, type_, nonce }`.

**Privacy benefit**: The nullifier is computed from the raw coin data and the spending key, not from the commitment. This means the nullifier reveals nothing about which coin commitment was spent.

### Shielded vs Unshielded

Each UTXO independently chooses privacy level:
- **Shielded**: Commitment hidden, value/owner private
- **Unshielded**: Value visible for regulatory compliance

```compact
// Receiving a shielded coin (CoinInfo provided by witness)
receive(coin);

// Sending tokens — returns SendResult with change info
send(input, recipient, value);
```

## Account Model (Contract Tokens)

Maintain address-to-balance mappings within Compact contracts, following OpenZeppelin-style standards adapted for Compact.

### When to Use

- Complex DeFi state machines requiring intricate interactions
- Gaming systems with stateful game logic
- Governance tokens with delegation mechanics
- Social tokens tracking relationships

### Trade-offs

| Aspect | Account Model Limitation |
|--------|-------------------------|
| Privacy | Less native privacy than UTXO; shielded contract tokens in development |
| Ordering | Nonce creates sequential dependency |
| MEV | Mempool visibility enables front-running |
| Scalability | Redundant computation on every node |

## Ledger Structure

Midnight's ledger has two components:

### 1. Zswap State
- Commitment tree: `MerkleTree<CoinCommitment>`
- First free index: `u32`
- Commitment set: `Set<CoinCommitment>` (prevents duplicate commitments)
- Nullifier set: `Set<CoinNullifier>`
- Historic roots: `TimeFilterMap<MerkleTreeRoot>` (time-based expiry)

### 2. Contract Map
- Associates contract addresses with states
- Each contract state holds an Impact state value plus entry point operations (SNARK verifier keys)

## Token Types

Token types are 256-bit collision-resistant hashes:
- **Native token**: The type identifier is the 256-bit zero value (retrieved via `nativeToken(): Bytes<32>`)
- **Custom tokens**: `Hash(contract_address, domain_separator)`

```compact
// Get the native token type identifier (256-bit zero)
const native = nativeToken();

// Custom token type = Hash(contractAddress, domainSeparator)
const color = tokenType(domainSep, contractAddr);
```

## Practical Application

### Choose UTXO When:
1. Users need transaction privacy
2. High throughput required (parallel processing)
3. Simple value transfers dominate
4. Regulatory compliance via selective disclosure (viewing keys)

### Choose Account When:
1. Complex state logic required
2. Tokens interact with sophisticated contract logic
3. Privacy is secondary to functionality
4. Integration with existing DeFi patterns

## References

For detailed technical information:
- **`references/utxo-mechanics.md`** - Complete UTXO lifecycle, nullifier computation
- **`references/ledger-structure.md`** - Zswap state internals, Merkle tree details

## Examples

Working Compact patterns:
- **`examples/token-handling.compact`** - Receiving, sending, and minting tokens
