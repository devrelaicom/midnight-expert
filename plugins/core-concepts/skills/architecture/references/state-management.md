# State Management

## Global State Structure

```
GlobalState {
  zswap: ZswapState,
  contracts: Map<ContractAddress, ContractState>
}
```

## Zswap State

### Components

```
ZswapState {
  // Merkle tree of all coin commitments
  commitment_tree: MerkleTree,

  // Next available slot in tree
  commitment_tree_first_free: u32,

  // All coin commitments ever created (prevents duplicates)
  commitment_set: Set<CoinCommitment>,

  // All spent coin nullifiers
  nullifiers: Set<CoinNullifier>,

  // Recent valid Merkle roots (expires over time)
  commitment_tree_history: TimeFilterMap<MerkleTreeRoot>
}
```

### Commitment Tree Operations

**Insert (new coin created)**:
```
1. Compute commitment = Hash<(CoinInfo, ZswapCoinPublicKey)>
2. Check commitment NOT in commitment_set (prevents duplicates)
3. Add commitment to commitment_set
4. Insert at position commitment_tree_first_free
5. Increment commitment_tree_first_free
6. Recompute Merkle root
7. Add new root to commitment_tree_history
```

**Verify (coin exists)**:
```
1. Receive: commitment, Merkle path, claimed root
2. Verify claimed root in commitment_tree_history
3. Verify path leads from commitment to root
```

### Nullifier Set Operations

**Check (not spent)**:
```
1. Compute nullifier = Hash<(CoinInfo, ZswapCoinSecretKey)>
2. Check: nullifier NOT in nullifiers
```

**Insert (mark spent)**:
```
1. Add nullifier to nullifiers
2. Nullifier can never be added again
```

### Commitment Tree History

Maintains recent Merkle roots for:
- Users with slightly stale Merkle paths
- Concurrent transaction handling
- Practical usability

Window typically covers several blocks. Old roots expire over time via `TimeFilterMap`.

## Contract State

### Structure

Contract state consists of an Impact state value plus a map of entry point names to operations (SNARK verifier keys):

```
ContractState {
  state: ImpactValue,                            // Impact state value
  operations: Map<String, SNARKVerifierKey>       // Entry point → verifier key
}
```

Contract Merkle trees are `MerkleTree(d)` Impact values with compile-time-fixed depth, stored as part of the Impact state. They are not separate top-level structures.

### Contract Address

```
ContractAddress = Hash(contract_state, nonce)    // Bytes<32>
```

### Field Types

| Compact Type | State Representation |
|--------------|---------------------|
| `Field` | Single field element |
| `Boolean` | Field (0 or 1) |
| `Bytes<N>` | N bytes |
| `ContractAddress` | Bytes<32> |
| `Map<K,V>` | Key-value mapping |

## State Transitions

### Atomic Updates

All state changes in a transaction are atomic:

```
Before: State_n
Transaction: Tx
After: State_n+1

Either ALL changes apply, or NONE do.
```

### Contract State Update Flow

```
1. Load current state: S_current
2. Execute Impact program with transaction inputs
3. Compute resulting effects: E_result
4. Verify E_result == E_declared (from proof)
5. Apply E_declared to S_current → S_new
6. Store S_new
```

### Zswap State Update Flow

```
For each output:
  assert !commitment_set.contains(output.commitment)
  commitment_set.insert(output.commitment)
  commitment_tree.insert(output.commitment)

For each input:
  assert !nullifiers.contains(input.nullifier)
  nullifiers.insert(input.nullifier)
```

## State Consistency

### Cross-Component Consistency

Zswap and contract states must be consistent:
- Coins received by contracts match Zswap outputs
- Coins sent by contracts match Zswap inputs
- Values balance across both

### Proof Binding

ZK proofs bind:
- Private inputs to public effects
- Zswap operations to contract operations
- All components to transaction binding

## State Pruning

### What Can Be Pruned

| Component | Prunable? | Notes |
|-----------|-----------|-------|
| `commitment_tree_history` | Yes | Old roots expire via TimeFilterMap |
| Contract state | Current only | Historical states not needed |

### What Cannot Be Pruned

- `commitment_set` — Must persist forever to prevent duplicate commitments
- `nullifiers` — Must persist forever to prevent double-spend
- Current contract states
- The commitment tree itself

## State Queries

### User Perspective

Users need to:
1. Track their own coins (commitments they own)
2. Generate Merkle paths for spending
3. Monitor for incoming coins (encrypted outputs)

### Node Perspective

Nodes maintain:
1. Full current state (all components)
2. Ability to verify any transaction
3. State proofs for light clients
