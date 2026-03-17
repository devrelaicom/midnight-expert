# Transaction Construction Guide

## Overview

Building a Midnight transaction involves assembling Zswap offers and optionally contract calls, then generating the required proofs.

## Simple Transfer Transaction

### Goal
Send 50 NIGHT from your wallet to a recipient.

### Step 1: Identify Spendable Coin

From your local wallet:
```text
MyCoin {
  coin_info: {
    value: 100,
    type: NIGHT,
    nonce: 0x789...
  },
  public_key: CoinPublicKey(0xpub123...),
  secret_key: CoinSecretKey(0xsec456...),
  merkle_index: 42
}
```

### Step 2: Generate Merkle Path

Query the current commitment tree:
```text
merkle_path = getMerklePath(index: 42)
merkle_root = getCurrentRoot()
```

### Step 3: Compute Nullifier

```text
nullifier = Hash<(CoinInfo, CoinSecretKey)>
         = Hash<(coin_info, 0xsec456...)>
         = 0xnull...
```

### Step 4: Create Recipient Output

```text
recipient_coin_info = CoinInfo {
  value: 50,
  type: NIGHT,
  nonce: fresh_random()
}

recipient_commitment = Hash<(recipient_coin_info, recipient_public_key)>
```

### Step 5: Create Change Output

```text
// Note: Fees are omitted for simplicity. In practice, excess value
// after balancing becomes the transaction fee.
change_coin_info = CoinInfo {
  value: 50,    // 100 - 50 = 50 change
  type: NIGHT,
  nonce: fresh_random()
}

change_commitment = Hash<(change_coin_info, my_public_key)>
```

### Step 6: Build Zswap Offer

```text
Offer {
  inputs: [{
    nullifier: 0xnull...,
    contractAddress: contract_addr,
    proof: generateInputProof(...)
  }],
  outputs: [
    {
      commitment: recipient_commitment,
      contractAddress: contract_addr,
      proof: generateOutputProof(...)
    },
    {
      commitment: change_commitment,
      contractAddress: contract_addr,
      proof: generateOutputProof(...)
    }
  ],
  transient: [],
  deltas: { NIGHT: 0 }  // 100 in, 100 out
}
```

### Step 7: Assemble Transaction

```text
Transaction {
  guaranteed_zswap_offer: Offer,
  fallible_zswap_offer: None,
  contract_calls: None,
  binding_randomness: generateBindingRandomness(...)
}
```

### Step 8: Submit

Broadcast transaction to network.

## Contract Interaction Transaction

### Goal
Call a contract function while also transferring tokens.

### Step 1: Prepare Contract Call

Each ContractCall contains both guaranteed and fallible transcripts:

```text
ContractCall {
  contract_address: ContractAddress(0xcontract...),
  entry_point: "deposit",
  guaranteed_transcript: {
    effects: {
      received_commitments: [{ value: 10, type: NIGHT }]
    },
    program: <impact_program>
  },
  fallible_transcript: { ... },
  communication_commitment: None,
  zk_proof: generateContractProof(witness_data)
}
```

### Step 2: Prepare Zswap for Contract

Create output targeted to contract:
```text
contract_coin_info = CoinInfo {
  value: 10,
  type: NIGHT,
  nonce: fresh_random()
}

contract_coin = Output {
  commitment: Hash<(contract_coin_info, contract_public_key)>,
  type_value_commit: <multi-base Pedersen value commitment>,
  contract_address: Some(ContractAddress(0xcontract...)),
  zk_proof: ...
}
```

### Step 3: Build Combined Transaction

```text
Transaction {
  guaranteed_zswap_offer: {
    inputs: [my_input],
    outputs: [contract_coin, my_change],
    transient: [],
    deltas: { NIGHT: 0 }
  },
  contract_calls: [ContractCall],
  binding_randomness: generateBindingRandomness(...)
}
```

### Step 4: Binding Randomness

Binding randomness opens the homomorphic Pedersen commitment:
```text
binding_randomness = generateBindingRandomness(contract_calls, binding_data)
```

## Atomic Swap Transaction

### Goal
Exchange tokens atomically with another party.

### My Offer (Partial)

```text
MyOffer {
  inputs: [my_token_a_input],  // Spending 100 TOKEN_A
  outputs: [],
  transient: [],
  deltas: {
    TOKEN_A: +100,  // Giving away
    TOKEN_B: -50    // Want to receive
  }
}
```

> **Note:** Partial offers with negative deltas are not independently valid.
> They become valid only when merged, at which point the combined deltas
> must be non-negative per token type.

### Counterparty Offer (Partial)

```text
TheirOffer {
  inputs: [their_token_b_input],  // Spending 50 TOKEN_B
  outputs: [
    my_token_b_output,   // 50 TOKEN_B to me
    their_token_a_output // 100 TOKEN_A to them
  ],
  transient: [],
  deltas: {
    TOKEN_A: -100,  // Receiving
    TOKEN_B: +50    // Giving away
  }
}
```

### Merged Transaction

```text
MergedOffer {
  inputs: [my_token_a_input, their_token_b_input],
  outputs: [my_token_b_output, their_token_a_output],
  deltas: {
    TOKEN_A: +100 - 100 = 0,
    TOKEN_B: -50 + 50 = 0
  }
}

Transaction {
  guaranteed_zswap_offer: MergedOffer,
  binding_randomness: ...
}
```

## Common Patterns

### Pattern: Fee Payment

Always include slightly more input than output:
```text
Input: 100 NIGHT
Outputs: 50 (recipient) + 49.9 (change)
Fee: 0.1 NIGHT (implicit, non-negative delta)
```

### Pattern: Multiple Inputs

Combine multiple small coins:
```text
inputs: [coin1, coin2, coin3]  // Total 30 + 50 + 20 = 100
outputs: [recipient_90, change_10]
```

### Pattern: Multiple Recipients

Single transaction, multiple outputs:
```text
outputs: [
  recipient1_output,
  recipient2_output,
  recipient3_output,
  change_output
]
```
