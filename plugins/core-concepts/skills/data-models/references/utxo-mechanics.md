# UTXO Mechanics Deep Dive

## UTXO Lifecycle

### 1. Creation

A UTXO is created when:
- A transaction output specifies a new coin
- The coin has: value, type, owner public key, nonce

```text
CoinCommitment = Hash<(CoinInfo, ZswapCoinPublicKey)>
```

Where `CoinInfo = { value, type, nonce }`.

The commitment is added to the global Merkle tree of coin commitments.

### 2. Existence

While unspent, a UTXO:
- Has a position in the Merkle tree
- Can be proven to exist via Merkle path
- Remains spendable by the owner

### 3. Consumption

To spend a UTXO:
1. Prove knowledge of the commitment preimage (CoinInfo + ZswapCoinPublicKey)
2. Prove the commitment exists in the Merkle tree
3. Generate a nullifier
4. Include nullifier in transaction

The entire UTXO is consumed -- partial spends are impossible. Change is returned as a new UTXO.

### 4. Prevention of Reuse

The nullifier prevents double-spending:

```text
CoinNullifier = Hash<(CoinInfo, ZswapCoinSecretKey)>
```

Properties:
- Deterministic: Same inputs always produce same nullifier
- Unlinkable: Nullifier reveals nothing about which UTXO was spent
- One-way: Cannot derive coin info or secret key from nullifier

## Nullifier Computation

### Formula

```text
CoinNullifier = Hash<(CoinInfo, ZswapCoinSecretKey)>
```

Where `CoinInfo = { value, type, nonce }`. The nullifier is computed from the raw coin data and the spending key, NOT from the commitment. Using the commitment would create a linkable relationship between nullifiers and commitments, defeating privacy.

### Privacy Properties

| Observer sees | Observer learns |
|--------------|-----------------|
| Nullifier | A coin was spent |
| Nullifier | Cannot link to commitment |
| Multiple nullifiers | Cannot determine if same owner |

### Why Not Reference Spent Outputs Directly?

Bitcoin references prior outputs directly by txid+index, revealing which coin was spent. Midnight uses nullifiers because:
- Direct references reveal which UTXO is being consumed
- Nullifiers hide the connection between the spent coin and the nullifier
- Enables private transactions without revealing transaction graph

## Merkle Tree Structure

### Commitment Tree

```text
        Root
       /    \
     H01    H23
    /  \   /   \
  C0   C1 C2   C3  <- CoinCommitments
```

Each leaf is a coin commitment: `Hash<(CoinInfo, ZswapCoinPublicKey)>`. The root is published on-chain. Note: Pedersen commitments are used separately for balance proofs, not for Merkle tree leaves.

### Proving Membership

To prove a coin exists:
1. Provide the commitment
2. Provide sibling hashes (Merkle path)
3. Verifier recomputes root
4. Root must match known valid root

### Historic Roots

Midnight maintains a `TimeFilterMap<MerkleTreeRoot>` of valid past roots with time-based expiry because:
- Tree changes with each transaction
- Users may have paths computed against old roots
- Accepting historic roots improves UX
- Expired roots are pruned based on time window

## Shielded vs Unshielded

### Shielded UTXOs

- Commitment hides all details
- Value, type, owner all private
- Default for privacy

### Unshielded UTXOs

- Value may be visible
- Useful for regulatory compliance
- Selective disclosure via viewing keys

### Choosing Privacy Level

Shielded and unshielded operations use distinct Compact stdlib functions: `receiveShielded()`/`sendShielded()` (using `ShieldedCoinInfo`) for shielded coins, and `receiveUnshielded()`/`sendUnshielded()` (using `color: Bytes<32>` and `amount: Uint<128>`) for unshielded coins. These have fundamentally different signatures. For selective disclosure, viewing keys are shared at the wallet level.

## Parallel Processing

UTXOs enable natural parallelism:

```text
UTXO A -> Tx1
UTXO B -> Tx2  <- Can process simultaneously
UTXO C -> Tx3
```

No ordering dependency unless:
- Same UTXO spent (impossible -- would need same nullifier)
- Contract state conflicts (handled separately)

## Comparison with Bitcoin UTXOs

| Aspect | Bitcoin | Midnight |
|--------|---------|----------|
| Spending mechanism | References output by txid+index | Nullifier (unlinkable to commitment) |
| Privacy | Pseudonymous (transaction graph visible) | Private (nullifiers hide which coin was spent) |
| Merkle tree | Transactions | Coin commitments |
| Pruning | Can prune spent outputs | Keeps nullifier set (append-only) |
