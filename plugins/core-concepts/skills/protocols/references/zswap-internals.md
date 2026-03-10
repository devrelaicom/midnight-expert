# Zswap Internals

## Foundation

Zswap extends Zerocash with:
- Multi-asset support
- Atomic swap capability
- Contract integration

Based on Zerocash (the academic protocol), with Midnight-specific extensions for smart contract integration and multi-asset support.

## Cryptographic Primitives

### Coin Commitments (Hash-Based)

Coin commitments use a hash function, not Pedersen commitments:

```
CoinCommitment = Hash(CoinInfo, ZswapCoinPublicKey)
```

Where CoinInfo = {value, type_, nonce}.

**Properties**:
- Binding: Cannot open to different coin info
- Hiding: Cannot determine committed values without the key
- Deterministic given the same inputs

These are stored in the commitment Merkle tree as leaves.

### Value Commitments (Pedersen Multi-Base)

Separate from coin commitments, Pedersen commitments are used for the `type_value_commit` field on inputs and outputs. These exist solely for **balance verification**:

```
type_value_commit = type·G_t + value·G_v + randomness·G_r
```

**Properties**:
- Perfectly hiding: Cannot determine committed values
- Computationally binding: Cannot open to different values
- Homomorphic: Commit(a) + Commit(b) = Commit(a+b)

The homomorphic property allows verifiers to check that inputs and outputs balance without learning individual values.

**Important**: Do not confuse these with coin commitments. Coin commitments are hash-based and identify coins in the Merkle tree. Value commitments are Pedersen-based and exist only for balance proofs.

### Nullifiers

```
CoinNullifier = Hash(CoinInfo, ZswapCoinSecretKey)
```

Where CoinInfo = {value, type_, nonce}. The coin commitment is NOT an input to nullifier computation.

**Properties**:
- Deterministic: Same inputs produce the same nullifier
- Unlinkable: Cannot derive the commitment from the nullifier
- Collision-resistant: Different inputs produce different nullifiers

## Offer Structure Details

### Complete Offer

```
Offer {
  inputs: [Input, ...],
  outputs: [Output, ...],
  transient: [TransientCoin, ...],
  deltas: Map<RawTokenType, i128>,
  proofs: [ZKProof, ...]
}
```

### Input Structure

```
Input {
  nullifier: Bytes<32>,
  type_value_commit: PedersenCommit,
  contract_address: Option<ContractAddress>,
  merkle_root: Bytes<32>,
  merkle_proof: MerklePath,
  zk_proof: Proof
}
```

**Proof demonstrates**:
- Knowledge of CoinInfo and ZswapCoinSecretKey that produce the nullifier
- Knowledge of CoinInfo and ZswapCoinPublicKey whose hash exists in the Merkle tree
- Nullifier correctly computed from CoinInfo and secret key
- Owner authorized the spend

### Output Structure

```
Output {
  commitment: Bytes<32>,
  type_value_commit: PedersenCommit,
  contract_address: Option<ContractAddress>,
  ciphertext: Option<EncryptedNote>,
  zk_proof: Proof
}
```

**Proof demonstrates**:
- Commitment correctly formed as Hash(CoinInfo, ZswapCoinPublicKey)
- Type/value commitment matches the coin's type and value
- Valid encryption (if present)

### Transient Coins

Coins created and spent in same transaction:
- Never actually exist on-chain
- Enable complex swap patterns
- Balance internally

## Balance Verification

### Per-Token Accounting

For each token type:
```
sum(input_values) = sum(output_values) + fees
```

### Homomorphic Verification

Using the homomorphic property of the **Pedersen value commitments** (type_value_commit fields):
```
sum(input_type_value_commits) - sum(output_type_value_commits) = Commit(delta)
```

This applies to Pedersen value commitments only, not to coin commitments. Verifiable without knowing actual values.

The contract section's zero-value contribution is proven via a Schnorr proof (one per transaction).

### Multi-Asset Balancing

Each offer specifies a delta vector:
```
deltas: {
  NIGHT: -100,    // Spending 100 NIGHT
  TOKEN_A: +50,   // Receiving 50 TOKEN_A
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

```
Offer1 + Offer2 = MergedOffer {
  inputs: Offer1.inputs + Offer2.inputs,
  outputs: Offer1.outputs + Offer2.outputs,
  transient: Offer1.transient + Offer2.transient,
  deltas: Offer1.deltas + Offer2.deltas,
  proofs: Offer1.proofs + Offer2.proofs
}
```

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
```
TokenType = Hash(contract_address, domain_separator)
```

Tokens are issued through Zswap mint operations in Compact contracts.

### Coin Operations in Contracts

Token operations are stdlib circuit calls, imported via `import CompactStandardLibrary;`:

```compact
// Receive a shielded coin targeted to this contract
receive(coinInfo: CoinInfo): []

// Send value to a recipient (public key or contract address)
send(input: QualifiedCoinInfo, recipient: Either<ZswapCoinPublicKey, ContractAddress>, value: Uint<128>): SendResult

// Mint an unshielded token
mintUnshieldedToken(domainSep: Bytes<32>, value: Uint<64>, recipient: Either<ContractAddress, UserAddress>): Bytes<32>
```

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

Midnight uses PLONK with KZG10 polynomial commitments. Proof sizes are compact (typically under a kilobyte per proof) and constant for a given circuit.

### Verification Time

- Per-proof: milliseconds
- Parallelizable across inputs/outputs
- Constant regardless of value/complexity

## Current Status

**Note**: Zswap implementation is still being refined:
- Performance optimizations ongoing
- Some details may change
- Native currency implementation evolving
