# Zswap Internals

## Foundation

Zswap extends Zerocash with:
- Native token support (multi-asset)
- Atomic swaps

Midnight adds its own variation on top of Zswap for smart contract integration via the Kachina protocol.

## Cryptographic Primitives

### Coin Commitments (Hash-Based)

Coin commitments use a hash function, not Pedersen commitments:

```text
CoinCommitment = Hash(CoinInfo, ZswapCoinPublicKey)
```

Where CoinInfo = {value, type, nonce}.

**Properties**:
- Binding: Cannot open to different coin info
- Hiding: Cannot determine committed values without the key
- Deterministic given the same inputs

These are stored in the commitment Merkle tree as leaves.

### Value Commitments (Pedersen)

Separate from coin commitments, each input and output carries a Pedersen value commitment used solely for **balance verification**.

**Properties**:
- Perfectly hiding: Cannot determine committed values
- Computationally binding: Cannot open to different values
- Homomorphic: These are homomorphic -- the network can check that inputs and outputs balance without learning individual values

**Important**: Do not confuse these with coin commitments. Coin commitments are hash-based and identify coins in the Merkle tree. Value commitments are Pedersen-based and exist only for balance proofs.

### Nullifiers

```text
CoinNullifier = Hash(CoinInfo, ZswapCoinSecretKey)
```

Where CoinInfo = {value, type, nonce}. The coin commitment is NOT an input to nullifier computation.

**Properties**:
- Deterministic: Same inputs produce the same nullifier
- Unlinkable: Cannot derive the commitment from the nullifier
- Collision-resistant: Different inputs produce different nullifiers

## Offer Structure

An offer comprises inputs (coins being spent), outputs (new coins being created), transient coins (created and destroyed within the same transaction), and a delta vector describing the net value change per token type.

### Inputs

An input provides a nullifier, evidence of coin existence (a Merkle proof against a recent root), and a Pedersen value commitment for balance verification. An accompanying ZK proof demonstrates knowledge of the coin information and secret key that produce the nullifier, that the corresponding coin commitment exists in the Merkle tree, and that the owner authorized the spend.

### Outputs

An output carries a coin commitment, a Pedersen value commitment for balance verification, and optional encrypted data for the recipient. An accompanying ZK proof demonstrates that the commitment is correctly formed, that the value commitment matches the coin's type and value, and that the encryption (if present) is valid.

### Transient Coins

Coins created and spent in the same transaction:
- Never actually exist on-chain
- Enable complex swap patterns
- Balance internally

## Balance Verification

### Per-Token Accounting

For each token type:
```text
sum(input_values) = sum(output_values) + fees
```

### Homomorphic Verification

Using the homomorphic property of the Pedersen value commitments, the network verifies that the sum of input commitments minus the sum of output commitments equals a commitment to the declared delta. This applies to Pedersen value commitments only, not to coin commitments, and is verifiable without knowing actual values.

The contract section's zero-value contribution is proven via a Schnorr proof (one per transaction).

### Multi-Asset Balancing

Each offer specifies a delta vector:
```text
deltas: {
  NIGHT: +100,    // Spending 100 NIGHT (inputs exceed outputs)
  TOKEN_A: -50,   // Receiving 50 TOKEN_A (outputs exceed inputs)
}
```

Merged offers must balance (non-negative per token type after adjustments for fees and mints).

## Merging Protocol

### Merge Requirements

Two offers can merge if:
1. At least one has empty contract call section
2. Combined deltas balance (non-negative per token type after adjustments)
3. No nullifier conflicts (coin sets must be disjoint)

### Merge Process

Merging concatenates all inputs, outputs, and transient coins from both offers, and sums the delta vectors element-wise. The result is a single combined offer that executes atomically.

### Non-Interactive Merging

Key innovation: Offers merge without parties communicating:
- Party A publishes partial offer
- Party B publishes complementary offer
- Anyone can merge them
- Atomic execution guaranteed

## Contract Integration

### Targeted Coins

Coins can specify contract address:
- Only that contract can spend them
- Enables contract-controlled value

### Token Issuance

Contracts create tokens via:
```text
TokenType = Hash(domain_separator, contract_address)
```

Tokens are issued through Zswap mint operations in Compact contracts.

### Coin Operations in Contracts

Compact contracts interact with Zswap through standard library functions for receiving, sending, and minting tokens. These are stdlib circuit calls imported via `import CompactStandardLibrary;`. See `compact-core:compact-standard-library` for function signatures and usage details.

## Security Properties

### Unlinkability

- Inputs unlinkable to outputs (nullifier cannot be linked to original coin commitment)
- Transaction graph hidden
- Only balancing verified

### Non-Malleability

- Offers bound by proofs
- Cannot modify without invalidating proofs
- Safe for multi-party composition

## Performance

### Proof Characteristics

Midnight uses ZK Snarks. Proof sizes are sublinear with respect to circuit size.

### Verification Time

- Per-proof: milliseconds
- Parallelizable across inputs/outputs
- Constant regardless of value/complexity

## Current Status

**Note**: Zswap implementation is still being refined:
- Performance optimizations ongoing
- Some details may change
- Native currency implementation evolving
