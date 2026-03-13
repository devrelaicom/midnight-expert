# Basic Shielded Transfer

## Overview

A simple private token transfer from Alice to Bob using Zswap.

## Steps

### 1. Alice's Preparation

Alice has a coin (UTXO) she wants to send:

```
Alice's Coin:
  commitment: Hash(CoinInfo, Alice's ZswapCoinPublicKey) = 0xabc...
  CoinInfo: { value: 100, type: NIGHT, nonce: 0x456... }
  secret_key: 0x123... (only Alice knows)
```

### 2. Construct Zswap Input

Alice creates an input to spend her coin:

```
Input {
  nullifier: Hash(CoinInfo, ZswapCoinSecretKey),  // Unlinkable to commitment
  type_value_commit: Pedersen(NIGHT, 100),          // For balance verification
  merkle_proof: [path to commitment in tree],
  zk_proof: "I know CoinInfo and keys that produce this nullifier and a valid commitment in the tree"
}
```

The nullifier is computed from CoinInfo and Alice's secret key -- the commitment itself is NOT an input.

### 3. Construct Zswap Output

Alice creates an output for Bob:

```
Output {
  commitment: Hash(CoinInfo_new, Bob's ZswapCoinPublicKey),  // Hash-based, NOT Pedersen
  type_value_commit: Pedersen(NIGHT, 100),                    // Pedersen, for balance verification
  ciphertext: Encrypt(CoinInfo_new, to: Bob's_public_key),
  zk_proof: "This commitment is well-formed"
}
```

Where CoinInfo_new = {value: 100, type: NIGHT, nonce: fresh_nonce}.

### 4. Build Offer

```
Offer {
  inputs: [Alice's input],
  outputs: [Bob's output],
  deltas: {},  // Balanced (ignoring fees)
}
```

### 5. Submit Transaction

```
Transaction {
  guaranteedCoins: Offer,
  // No contract calls needed
}
```

### 6. On-Chain Processing

1. Verify nullifier not in nullifier set
2. Verify Merkle proof against valid root
3. Verify all ZK proofs
4. Add nullifier to nullifier set
5. Add new commitment to Merkle tree

### 7. Bob Receives

Bob scans blockchain for outputs encrypted to his key:

```
1. Decrypt ciphertext with Bob's private key
2. Learn: CoinInfo (value = 100 NIGHT, type, nonce)
3. Compute commitment = Hash(CoinInfo, Bob's ZswapCoinPublicKey) and verify it matches
4. Store locally: CoinInfo, commitment
5. Bob can now spend this coin (using his ZswapCoinSecretKey to compute a nullifier)
```

## Privacy Analysis

| Participant | What They See |
|-------------|---------------|
| Alice | Everything about her coin |
| Bob | Only his received coin |
| Observers | A transaction occurred (nullifier, new commitment) |
| Observers | NOT: sender, receiver, amount, or which coin spent |

## Code Representation

In Compact, token operations are stdlib circuit calls imported via `import CompactStandardLibrary;`:

```compact
// sendShielded(input, recipient, value) is a stdlib call, not special syntax
sendShielded(qualifiedCoinInfo, recipientKey, 100 as Uint<128>)
```

The Zswap machinery (commitments, nullifiers, proofs) happens automatically.
