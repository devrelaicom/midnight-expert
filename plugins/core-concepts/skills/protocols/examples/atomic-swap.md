# Atomic Swap Example

## Scenario

Alice wants to exchange 100 NIGHT for 50 TOKEN_A from Bob.
Neither trusts the other. They need atomic exchange.

## Traditional Problem

Without atomicity:
1. Alice sends 100 NIGHT to Bob
2. Bob receives NIGHT, disappears
3. Alice loses funds

## Zswap Solution

### Step 1: Alice Creates Partial Offer

Alice offers her NIGHT, wants TOKEN_A:

```text
Alice's Offer {
  inputs: [
    { nullifier: 0xaaa..., value: 100 NIGHT, proof: ... }
  ],
  outputs: [],  // Alice wants TOKEN_A, not creating NIGHT outputs
  deltas: {
    NIGHT: +100,    // Alice giving 100 NIGHT (inputs exceed outputs)
    TOKEN_A: -50    // Alice wants 50 TOKEN_A (outputs exceed inputs)
  }
}
```

This offer is **incomplete**: deltas don't balance.

### Step 2: Bob Creates Complementary Offer

Bob offers TOKEN_A, wants NIGHT. Bob also constructs an output for Alice (he knows her public key from the order book).

> **Note:** Bob needs Alice's `ZswapCoinPublicKey` (not just an address) to construct the output commitment for her. This key must be available via the order book or a separate communication channel.

```text
Bob's Offer {
  inputs: [
    { nullifier: 0xbbb..., value: 50 TOKEN_A, proof: ... }
  ],
  outputs: [
    { commitment: 0xccc..., value: 100 NIGHT, to: Bob },
    { commitment: 0xddd..., value: 50 TOKEN_A, to: Alice }
  ],
  deltas: {
    NIGHT: -100,    // Bob wants 100 NIGHT (outputs exceed inputs)
    TOKEN_A: +50    // Bob giving 50 TOKEN_A (inputs exceed outputs)
  }
}
```

Also incomplete alone (deltas don't balance without Alice's input).

### Step 3: Merge Offers

Anyone (Alice, Bob, or a relay) can merge:

```text
Merged Offer {
  inputs: [
    Alice's NIGHT input,
    Bob's TOKEN_A input
  ],
  outputs: [
    Bob's NIGHT output,
    Alice's TOKEN_A output  // Constructed by Bob in Step 2
  ],
  deltas: {}  // All token types net to zero — balanced swap
}
```

Now balanced.

### Step 4: Complete Transaction

```text
Transaction {
  guaranteedCoins: Merged Offer
}
```

### Step 5: Atomic Execution

Either:
- **Both transfers happen**: Alice gets TOKEN_A, Bob gets NIGHT
- **Neither happens**: Both keep original coins

No partial execution possible.

## Key Properties

### Non-Interactive

Alice and Bob don't need to communicate directly:
1. Alice publishes her offer (e.g., to order book)
2. Bob finds matching offer
3. Bob creates complementary offer
4. Merge and submit

### Privacy Preserved

Observers see:
- Two nullifiers (unlinkable to identities)
- Two new commitments
- A valid transaction

Observers don't see:
- Who is Alice, who is Bob
- Exact amounts (hidden in commitments)
- Which specific coins were swapped

### Trustless

- No escrow needed
- No trusted third party
- Cryptographic guarantees only

## Order Book Pattern

For exchanges:

```text
1. Makers post partial offers (incomplete deltas)
2. Takers find matching offers
3. Taker creates complementary offer
4. Merge creates complete transaction
5. Submit to blockchain
6. Atomic settlement
```

## Multi-Party Swaps

Zswap supports N-party atomic swaps:

```text
Alice: -100 NIGHT, +50 TOKEN_A
Bob: -50 TOKEN_A, +30 TOKEN_B
Carol: -30 TOKEN_B, +100 NIGHT

Merged: All deltas sum to zero
Result: Atomic 3-way exchange
```

## Failure Modes

| Scenario | Result |
|----------|--------|
| Proofs invalid | Transaction rejected, nothing happens |
| Nullifier already spent | Transaction rejected, nothing happens |
| Deltas don't balance | Cannot merge, incomplete offers remain |
| Network partition | Transaction either confirms or doesn't |

All failures are safe: no partial execution.
