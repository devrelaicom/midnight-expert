# Fees and Gas

How transaction fees work on Midnight -- from DUST generation through the gas model and dynamic pricing to practical cost optimization for Compact developers.

## DUST Overview

DUST is a shielded, non-transferable network resource used exclusively for paying transaction fees. It is not a token and cannot be sent to another user. DUST is generated from NIGHT holdings and operates on its own commitment/nullifier paradigm, separate from the Zswap protocol.

### Key Properties

| Property | Detail |
|----------|--------|
| Non-transferable | Can only be spent on fees, never transferred between users |
| Generated from NIGHT | Value grows linearly over time based on backing NIGHT UTXO |
| Capped per NIGHT | Maximum ~5 DUST per 1 NIGHT (initial parameters: `night_dust_ratio = 5_000_000_000`) |
| Decays after NIGHT spent | Once backing NIGHT UTXO is consumed, DUST value decays toward zero |
| Shielded | DUST spends use ZK proofs; individual fee amounts are not publicly visible |
| Non-persistent | Protocol reserves the right to modify DUST allocation rules or reset DUST on hardforks |

### Generation and Decay

Holding NIGHT UTXOs produces DUST over time. The rate depends on the amount of NIGHT held, the DUST-to-NIGHT ratio (rho), and the configured "time to cap" (delta). With initial parameters, it takes approximately one week to reach maximum DUST from a freshly registered NIGHT UTXO.

Once the backing NIGHT UTXO is spent, the associated DUST UTXO stops generating and begins decaying toward zero. The DUST can still be spent during decay, but its effective value shrinks. If only a portion of NIGHT is spent, the change UTXO backs a new DUST UTXO that begins generating while the old one decays.

The atomic unit of DUST is the **Speck** (1 DUST = 10^15 Specks), allowing fine-grained fee payments.

### Testnet

On testnet, request tNIGHT from the faucet, then delegate via your wallet to generate tDUST. Wait for tDUST to accrue (typically 1-2 minutes) before deploying or interacting with contracts.

## Fee Collection Mechanics

### Fee Timing

Fees for all phases of execution -- both guaranteed and fallible -- are collected during the guaranteed phase. If the fallible phase fails, fees are still consumed with no refund. This ensures validators are always compensated for processing work, even when the fallible portion does not execute.

### DUST Spends

Fee payment uses DUST spends -- 1-to-1 "transfers" with one input nullifier, one output commitment, and a public fee declaration. Ownership cannot change; the same public key must control both input and output.

Each DUST spend includes a zero-knowledge proof verifying:

1. The input is valid and included in the DUST commitment Merkle tree at a recent point in time
2. The output value equals the updated input value minus the declared fee, and is non-negative
3. The output uses the same public key as the input

The spend references a timestamp (within the `dust_grace_period`, initially 3 hours) rather than a Merkle tree root directly. The network uses this timestamp to look up the appropriate tree state.

### Night Registration and Fee Bootstrapping

New NIGHT UTXOs can pay for their own registration fees through a bootstrapping mechanism. For a registration to pay fees, the relevant Night address must have Night inputs present in the transaction, and at least one of those inputs must not already be generating DUST. When this condition is met, the DUST that those inputs *would have generated* is used to cover transaction fees up to the declared limit. Any remaining amount is distributed across the new DUST outputs.

If other parts of the transaction already sufficiently cover the fees, DUST is not subtracted from the new registration. Registrations are processed sequentially in order of segment IDs, and fee payments from registrations occur during the guaranteed segment only.

## Gas Model

Every contract call on Midnight declares a gas bound in its execution transcript. This gas bound drives the fee calculation.

### Execution Transcripts and Gas

Execution transcripts consist of:

- A declared **gas bound**, used to derive the fees for the call
- A declared **effects object**, binding the contract's semantics to other transaction components
- The **program** to execute

Program execution has an attached cost bounded by the gas limit. If execution exceeds the budget, it aborts, invalidating that part of the transaction.

### SyntheticCost

Rather than a single gas number, Midnight tracks five independent resource dimensions via `SyntheticCost`:

| Dimension | What It Measures | Unit |
|-----------|-----------------|------|
| `read_time` | Time spent reading from disk | Picoseconds |
| `compute_time` | Single-threaded compute time | Picoseconds |
| `block_usage` | Block space consumed | Bytes |
| `bytes_written` | Net new state bytes written (writes minus deletes) | Bytes |
| `bytes_churned` | State bytes written temporarily or overwritten | Bytes |

The distinction between `bytes_written` and `bytes_churned` matters: permanent writes cost more than temporary state changes because they consume long-term storage.

Initial block limits for these dimensions:

```
block_limits = {
    read_time:     1 second,
    compute_time:  1 second,
    block_usage:   200,000 bytes,
    bytes_written: 50,000 bytes,  // Note: the spec document says 20,000 but the implementation uses 50,000
    bytes_churned: 1,000,000 bytes,
}
```

### From SyntheticCost to Fee

The fee computation takes the maximum of the three "denial-of-service" dimensions (read time, compute time, block usage), then adds write and churn costs independently:

```
fee = (max(read_cost, compute_cost, block_cost) + write_cost + churn_cost)
      * overall_price
      * SPECKS_PER_DUST
```

This design benefits balanced transactions while remaining neutral to denial-of-service transactions that specialize in one dimension.

## Dynamic Pricing

Midnight adjusts fees dynamically to target 50% block fullness across all resource dimensions.

### Per-Dimension Price Factors

Each primary dimension has its own price factor that adjusts independently:

- Blocks more than 50% full in a dimension cause that dimension's price to increase
- Blocks less than 50% full cause the price to decrease
- Dimension price factors are normalized so their average equals 1
- A minimum ratio prevents any dimension from becoming effectively free (initially `min_ratio = 0.25`)

### Overall Price

On top of per-dimension factors, a global `overall_price` scalar adjusts based on aggregate block fullness -- rising when blocks are generally full and falling when they are empty.

### Mental Model

Think of the fee adjustment as tuning an n-dimensional pricing vector in polar coordinates: a scalar magnitude (the overall price) multiplied by a direction vector on the unit sphere (the normalized dimension factors). The magnitude responds to total demand; the direction responds to which resources are scarce.

Fees are market-responsive -- rising under congestion, falling when underutilized -- but predictable because adjustments happen incrementally, block by block. Initial parameters set all dimension factors to 1, `overall_price` to 10, and `min_ratio` to 0.25.

## Practical Guidance for Developers

The core principle: more ledger operations means higher gas means higher fees.

### Relative Gas Cost by Operation

| Operation | Gas Impact | Notes |
|-----------|-----------|-------|
| `pure` circuit call | Lowest | No state operations, pure computation |
| `ledger field = value` | Low | Single cell write |
| `Counter.increment(n)` | Low | Small state mutation |
| `Map.insert(k, v)` | Medium | Key-value write |
| `Set.insert(v)` | Medium | Similar to Map insert |
| `MerkleTree.insert(v)` | Higher | Tree rebalancing, more bytes written |
| `witness` call | None (on-chain) | Executes locally off-chain, no gas cost |

### Optimization Strategies

**Minimize state reads and writes in circuits.** Every ledger read contributes to `read_time` and every write contributes to `bytes_written` or `bytes_churned`. Fewer ledger operations directly reduce gas.

**Use `pure` circuits for computation that does not touch the ledger.** Pure circuits have the lowest gas cost because they perform no state operations. Use them for validation, hash computation, or any work that does not need contract state.

**Push complexity into witnesses.** Witnesses execute off-chain on the user's machine and cost no gas. Perform expensive computation and complex validation in witnesses, then pass only minimal results into circuits for on-chain verification.

**Keep export circuits lean.** Limit export circuits to operations that truly must happen on-chain: state reads, state writes, and ZK-verified assertions.

**Prefer `Counter` over `Map` for simple numeric state.** A `Counter.increment(n)` is a smaller state mutation than inserting into or updating a `Map`.

**Batch operations when possible.** A single circuit with multiple related writes is more gas-efficient than separate transactions, because fixed costs (proof verification, block usage) are amortized.

### Example: Gas-Aware Contract Design

```compact
export ledger totalVotes: Counter;
export ledger hasVoted: Set<Bytes<32>>;

// Witness runs off-chain -- no on-chain gas cost
witness computeVoterHash(secret: Bytes<32>): Bytes<32>;

export circuit castVote(voterSecret: Bytes<32>): [] {
  // Hash computation happens in the witness (off-chain, zero gas)
  const voterHash = computeVoterHash(voterSecret);
  // On-chain: only a Set membership check, a Set insert, and a Counter increment
  assert(!disclose(hasVoted.member(disclose(voterHash))), "Already voted");
  hasVoted.insert(disclose(voterHash));
  totalVotes.increment(1);
}
```

In this example, the witness handles the hash computation off-chain. The export circuit only performs the minimum on-chain operations: one `Set` membership check, one `Set` insert, and one `Counter` increment. This keeps `bytes_written` and `compute_time` low.
