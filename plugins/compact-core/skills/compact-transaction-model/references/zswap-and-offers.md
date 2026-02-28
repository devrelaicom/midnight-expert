# Zswap and Offers

How Midnight's Zswap protocol structures value transfer -- from individual offers with inputs, outputs, and transient coins through complete transactions with contract calls to merged atomic swaps, all secured by Pedersen commitment-based integrity.

## Zswap Overview

Zswap is Midnight's shielded token mechanism, based on Zerocash and extended with two capabilities that Zerocash lacks: native multi-asset token support and atomic swaps. The protocol powers all shielded value transfer on the Midnight ledger.

The fundamental unit of Zswap is the **offer**, which conceptually is a set of inputs and outputs. This matches the UTXO (Unspent Transaction Output) model, but with a critical privacy property inherited from Zerocash: the set of unspent transactions is not computable. An observer cannot link an input (spend) to the output it consumes, because inputs reference their original commitments through unlinkable nullifiers rather than direct pointers.

Midnight uses a slight variation of the original Zswap protocol that permits contracts to hold funds. This extension is essential for Compact smart contracts that manage shielded tokens on behalf of users -- receiving coins into contract-owned addresses and releasing them under programmatic control.

## Zswap Offers

A Zswap offer consists of four components:

| Component | Description |
|-----------|-------------|
| Inputs (spends) | A set of coin inputs that consume existing coins by producing nullifiers |
| Outputs | A set of coin outputs that create new coins by placing commitments in the global Merkle tree |
| Transient coins | Coins that are both created and spent within the same transaction |
| Balance vector | A vector tracking the net value of the offer across all token types |

### Transient Coins

Transient coins are outputs immediately followed by inputs within a single offer. They enable contracts to receive and re-spend coins atomically, without waiting for block confirmation. This is essential for contract-managed token operations where a coin must be created for a contract and then immediately consumed by that same contract in one transaction.

The key distinction from regular inputs is that a transient input spends from a **locally created** coin commitment set rather than the global one. This prevents index collisions: if the transient coin were placed in the global Merkle tree and then spent from it, the index assigned to it might collide with other concurrent transactions that are also inserting commitments. By using a local commitment set, the transient coin's lifecycle is entirely self-contained within the offer.

### Balance Vector

The balance vector has one dimension for every possible token type. Each dimension carries a value computed from the offer's inputs and outputs:

- An **input** of a given token type counts **positively** toward that dimension (value flowing in).
- An **output** of a given token type counts **negatively** toward that dimension (value flowing out).

An offer's balance vector is considered **balanced** if every dimension is non-negative. Before this check is applied, the vector is typically **adjusted** to account for:

- Token mints (new tokens entering circulation, increasing a dimension)
- Fee deductions (DUST consumed for transaction fees, decreasing a dimension)

## Inputs (Spends)

A Zswap input spends an existing coin by referencing its original commitment in the global Merkle tree without revealing which commitment it corresponds to. An input consists of:

| Component | Purpose |
|-----------|---------|
| Nullifier | An unlinkable reference to the original commitment; prevents double-spending without revealing which coin is spent |
| Pedersen commitment | A multi-base Pedersen commitment to the type/value vector of the coin being spent |
| Contract address (optional) | Present if and only if the coin is targeted at a contract; identifies the owning contract |
| Merkle root | A root of a Merkle tree that contains the commitment corresponding to this nullifier |
| ZK proof | A zero-knowledge proof that all of the above are correct with respect to each other |

### Input Validity

An input is valid if and only if both conditions hold:

1. The zero-knowledge proof verifies -- attesting that the nullifier, Pedersen commitment, contract address, and Merkle root are all internally consistent and correctly derived.
2. The Merkle root is in the **set of valid past roots**. The ledger maintains a history of recent Merkle tree roots (bounded by a time-to-live window). This allows inputs to reference slightly older tree states, accommodating the delay between transaction construction and inclusion in a block.

## Outputs

A Zswap output creates a new coin and places a corresponding commitment in the global Merkle tree. An output consists of:

| Component | Purpose |
|-----------|---------|
| Coin commitment | A hash-based commitment placed in the global Merkle tree; proves the coin exists without revealing its contents |
| Pedersen commitment | A multi-base Pedersen commitment to the type/value vector of the newly created coin |
| Contract address (optional) | Present if and only if the output is targeted at a contract |
| Ciphertext (optional) | Encrypted coin information for the recipient, present when the output is directed toward a user who must be able to discover and spend it |
| ZK proof | A zero-knowledge proof that all of the above are correct with respect to each other |

### Output Validity

An output is valid if its zero-knowledge proof verifies. Unlike inputs, outputs do not require a Merkle root check because they create new commitments rather than referencing existing ones. The commitment is added to the global Merkle tree upon transaction inclusion.

## Token Types

Every coin in Zswap carries a **token type** (also called a color) -- a 256-bit value that identifies what kind of asset the coin represents. The token type is embedded in each coin's commitment and Pedersen commitment, so it is part of the value that is hidden from observers but verified by zero-knowledge proofs.

| Token Type | Derivation | Description |
|------------|------------|-------------|
| Native (NIGHT) | Pre-defined zero value | The native Midnight token; not derived from any contract |
| Contract-issued | `tokenType(domainSep, contractAddress)` | A collision-resistant hash of the contract's address and a developer-chosen domain separator |

### Native Token

The native token (NIGHT) uses the pre-defined **zero value** (`0x0000...0000`) as its token type. It is not derived from any contract address and is the only token type that exists without a corresponding contract deployment.

### Contract-Issued Tokens

Contract-issued token types are derived deterministically from two inputs:

| Input | Description |
|-------|-------------|
| Domain separator | A 32-byte value (`Bytes<32>`) chosen by the contract developer to distinguish different token types |
| Contract address | The deploying contract's unique on-chain address, obtained via `kernel.self()` |

Because the contract address is unique per deployment and the hash function is collision-resistant, no two contracts can produce the same token type. A single contract can issue multiple distinct token types by varying the domain separator.

In Compact, the `tokenType` standard library function computes this derivation:

```compact
const color = tokenType(pad(32, "mytoken:"), kernel.self());
```

For full details on token issuance, minting, and burning from Compact contracts, see the `compact-tokens` skill.

## Transaction Structure

A complete Midnight transaction wraps Zswap offers together with optional contract interactions. The structure has three top-level components:

| Component | Required | Description |
|-----------|----------|-------------|
| Guaranteed Zswap offer | Yes | An offer whose effects are always applied if the transaction is included; never rolled back |
| Fallible Zswap offer | No | An offer whose effects are applied only if the fallible execution phase succeeds; rolled back on failure |
| Contract calls segment | No | A sequence of contract calls or deployments, plus binding cryptography |

The guaranteed/fallible distinction is fundamental to Midnight's execution model. The guaranteed offer's effects are always committed if the transaction is included in a block, even if the fallible phase fails. This allows critical operations (fee payment, authorization) to persist regardless of whether the contract logic succeeds. See the `execution-phases` reference for the full execution pipeline.

### Contract Call Contents

When a transaction includes contract calls, the contract calls segment contains:

| Element | Purpose |
|---------|---------|
| Sequence of contract calls/deploys | The ordered list of operations to execute against on-chain contracts |
| Binding commitment | A Pedersen commitment that cryptographically ties this section to the rest of the transaction |
| Binding randomness | The randomness used in the binding commitment, enabling integrity verification |

Each individual contract call within the sequence contains:

| Element | Purpose |
|---------|---------|
| Guaranteed transcript | The declared visible effects that execute in the guaranteed phase |
| Fallible transcript | The declared visible effects that execute in the fallible phase |
| Communication commitment | A commitment for cross-contract interaction (currently under development) |
| ZK proof | A zero-knowledge proof that the transcripts are valid for this contract and bound to other transaction elements |

## Transaction Merging

Zswap enables **atomic swaps** by allowing two independent transactions to be merged into a single composite transaction. This is the mechanism by which two parties who do not trust each other can exchange assets atomically -- either both sides of the swap execute, or neither does.

### Merging Constraints

Transaction merging has one key constraint: at least one of the two transactions must have an **empty contract calls section**. This restriction exists because contract call sections carry binding commitments that are specific to their enclosing transaction. Merging two transactions that both contain contract calls would require reconciling two independent binding commitments, which is not currently supported.

### Merging Outcome

The output of merging is a new composite transaction that combines the effects of both input transactions. The guaranteed offers are combined, the fallible offers are combined, and the non-empty contract calls section (if any) is preserved.

### How Integrity Survives Merging

The ability to merge transactions without compromising integrity relies on the homomorphic properties of Pedersen commitments:

1. Each input and output in both transactions carries its own Pedersen commitment to its type/value vector.
2. These commitments are **homomorphically summed** across the merged transaction. The sum of commitments equals the commitment to the sum of values, without revealing individual values.
3. Only the parties who created the individual components know the **opening randomnesses** that decompose the composite commitment back into its parts.
4. This ensures that funds are spent as each party originally intended. Neither party can alter the other's contribution to the merged transaction without invalidating the composite commitment.

## Transaction Integrity

Midnight inherits its transaction integrity mechanism from Zswap's Pedersen commitment scheme. This mechanism ensures that a transaction, once assembled, cannot be tampered with -- its parts cannot be meaningfully separated or recombined without the knowledge of the original creators.

### Pedersen Commitment Flow

The integrity mechanism works through a chain of commitments:

1. **Per-I/O commitments.** Every input and output in a Zswap offer carries a multi-base Pedersen commitment to its type/value vector. These commitments hide the actual values while enabling homomorphic aggregation.

2. **Homomorphic summation.** The individual Pedersen commitments are summed across the entire transaction. Because Pedersen commitments are additively homomorphic, the sum of commitments equals a commitment to the sum of values.

3. **Composite opening.** The composite commitment is opened (verified) to check whole-transaction integrity. This confirms that the total value flowing in matches the total value flowing out, adjusted for fees and mints, without revealing any individual values.

### Contract Call Binding

The contract call section of a transaction also contributes to the overall Pedersen commitment. However, this contribution is special: it is **restricted to carry no value vector**. A contract call section must not introduce hidden value that could unbalance the transaction.

This restriction is enforced via a **Fiat-Shamir transformed Schnorr proof** -- a proof of knowledge of an exponent of the Pedersen generator. The proof demonstrates that the contract call section's commitment is purely a randomness commitment (of the form `g * r`) and carries no value component. This prevents an attacker from embedding hidden value in the contract call section to siphon funds from the Zswap offers.

### Binding Guarantee

The combination of Pedersen commitments, homomorphic summation, and Schnorr proof binding produces a strong guarantee: a transaction, once assembled, can only be disassembled by the party that originally assembled it. No component of the transaction can be meaningfully extracted and used in a different transaction without including all other components. This property holds even after merging, because the opening randomnesses remain private to their respective creators.
