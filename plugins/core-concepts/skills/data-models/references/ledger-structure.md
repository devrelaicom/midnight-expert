# Ledger Structure

## Overview

Midnight's ledger has two main components:
1. **Zswap State** - Token/coin management
2. **Contract Map** - Smart contract states

## Zswap State

```
ZswapState {
  commitment_tree: MerkleTree<CoinCommitment>,
  commitment_tree_first_free: u32,
  commitment_set: Set<CoinCommitment>,
  nullifiers: Set<CoinNullifier>,
  commitment_tree_history: TimeFilterMap<MerkleTreeRoot>
}
```

### Commitment Tree

- Merkle tree of all coin commitments
- Depth determines maximum coins
- Leaves are coin commitments: `CoinCommitment = Hash<(CoinInfo, ZswapCoinPublicKey)>`
- Note: Pedersen commitments are used separately for balance proofs, not as Merkle tree leaves

### Commitment Tree First Free

- Points to next available tree position (`u32`)
- Increments with each new coin
- Never decreases (append-only)

### Commitment Set

- `Set<CoinCommitment>` that prevents duplicate commitments
- Checked before inserting a new commitment into the tree
- Ensures each coin commitment is unique

### Nullifiers

- `Set<CoinNullifier>` containing all spent coin nullifiers
- Checked before accepting new spends
- Prevents double-spending

### Commitment Tree History

- `TimeFilterMap<MerkleTreeRoot>` of accepted historic Merkle roots
- Allows proofs against recent tree states
- Entries expire based on time window (not kept indefinitely)

## Contract Map

```
ContractMap = Map<ContractAddress, ContractState>
```

A contract state consists of an Impact state value plus a map of entry point names to operations (SNARK verifier keys). The verifier keys allow the network to verify ZK proofs for each circuit entry point.

### Contract Address

Derived from deployment:
```
address = Hash(contract_state, nonce)
```

The address is computed from the initial contract state and a nonce, not from the full deployment transaction data.

### State Types

| Type | Storage | Visibility |
|------|---------|------------|
| Field | Direct value | Public |
| MerkleTree | Root only on-chain | Contents private |
| Set | Membership structure | Contents private |

## State Transitions

### Adding a Coin

```
1. Compute commitment = Hash<(CoinInfo, ZswapCoinPublicKey)>
2. Check commitment not already in commitment_set
3. Insert commitment at commitment_tree_first_free
4. Add commitment to commitment_set
5. Increment commitment_tree_first_free
6. Update Merkle root
7. Add new root to commitment_tree_history
```

### Spending a Coin

```
1. Verify nullifier not in nullifiers set
2. Verify Merkle proof against valid root in commitment_tree_history
3. Verify ZK proof of ownership
4. Add nullifier to nullifiers set
```

### Updating Contract State

```
1. Lookup contract by address
2. Verify ZK proof matches circuit (using stored verifier keys)
3. Execute Impact program
4. Verify resulting effects match declared
5. Store new state
```

## Token Types

### Native Token

```
type = 0x0000...0000  (256-bit zero)
```

The native token TYPE IDENTIFIER is the 256-bit zero value. This identifies the token type, not the token's value or balance. Retrieved in Compact via `nativeToken(): Bytes<32>`.

### Custom Tokens

```
type = Hash(contract_address, domain_separator)
```

The domain separator allows one contract to issue multiple token types.

## Value Accounting

### Zswap Balance Equation

Per token type:
```
sum(input_values) - sum(output_values) + mints >= 0
```

Fees are accounted for in the native token dimension.

Enforced via:
- Multi-base Pedersen commitment homomorphism (for balance proofs)
- Balance proofs per token type
- Fee verification on the native token dimension

### Multi-Asset Support

Each token type has independent balance accounting. The native token dimension also covers transaction fees.
