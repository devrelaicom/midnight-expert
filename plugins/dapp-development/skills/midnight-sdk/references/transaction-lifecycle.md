# Transaction Lifecycle

Complete reference for the Midnight transaction lifecycle: from circuit call construction through ZK proving, balancing, submission, and on-chain finalization. For package-level API details, see `references/package-reference.md`. For the high-level deployment workflow, see `compact-core:compact-deployment`.

## Pipeline Overview

Every contract interaction follows a five-stage pipeline:

```
1. Build         2. Prove          3. Balance        4. Submit         5. Finalize
   |                |                 |                 |                 |
   v                v                 v                 v                 v
   createUnproven   proofProvider     walletProvider    midnightProvider  publicDataProvider
   CallTx()         .prove()          .balanceTx()      .submitTx()       (indexer confirms)
   |                |                 |                 |                 |
   v                v                 v                 v                 v
   UnprovenTx  ->  ProvenTx     ->  BalancedTx   ->  TransactionId ->  FinalizedTxData
```

### Stage 1: Build (Create Unproven Transaction)

Constructs the transaction by executing the circuit logic and witness functions locally:

```typescript
import { createUnprovenCallTx } from "@midnight-ntwrk/midnight-js-contracts";

const unproven = await createUnprovenCallTx(
  deployed,       // DeployedContract or FoundContract
  providers,      // MidnightProviders bundle
  "myCircuit",    // Circuit name (must match Compact export)
  [arg1, arg2],   // Circuit arguments
);
```

During this stage:
- The circuit's Compact code is evaluated locally
- Witness functions are called to supply private inputs
- The private state is read and potentially updated
- An unproven transaction is constructed with all inputs and outputs

The unproven transaction contains the full transaction structure but no ZK proof yet.

### Stage 2: Prove (Generate ZK Proof)

The proof server generates a zero-knowledge proof that the circuit was executed correctly:

```typescript
// Happens automatically in callTx, or manually:
const proof = await providers.proofProvider.prove(circuitId, proveInputs);
```

During this stage:
- The unproven transaction and its witness data are sent to the proof server
- The proof server loads the circuit's ZKIR and proving keys
- A ZK-SNARK proof is generated
- The proof is attached to the transaction

This is the most computationally expensive stage. Proof generation time depends on circuit complexity and can range from seconds to minutes.

### Stage 3: Balance (Add Fee Inputs/Outputs)

The wallet adds fee inputs and change outputs to make the transaction valid:

```typescript
// Happens automatically in callTx, or manually:
const balanced = await providers.walletProvider.balanceTx(
  unprovenTx,
  newCoins,  // Optional: newly created shielded coins
  ttl,       // Optional: transaction time-to-live
);
```

During this stage:
- The wallet selects UTXOs to cover transaction fees
- Fee inputs are added to the transaction
- Change outputs are created for excess value
- The transaction is signed with the wallet's keys

### Stage 4: Submit (Send to Network)

The finalized transaction is submitted to the Midnight node:

```typescript
// Happens automatically in callTx, or manually:
const txId = await providers.midnightProvider.submitTx(finalizedTx);
```

The node validates the transaction and broadcasts it to the network. The `submitTx` call returns the transaction ID immediately; it does not wait for block inclusion.

### Stage 5: Finalize (Confirm On-Chain)

The SDK watches the indexer for transaction confirmation:

```typescript
// Happens automatically in callTx (blocks until confirmed)
// Or watch manually via observable:
providers.publicDataProvider
  .contractStateObservable(contractAddress, { type: "latest" })
  .subscribe((state) => {
    // State updated after transaction finalized
  });
```

The indexer monitors the blockchain and emits events when the transaction is included in a block. The `callTx` high-level API blocks until this confirmation arrives.

## High-Level vs Low-Level API Comparison

### High-Level (callTx)

```typescript
// All 5 stages in one call
const txData = await deployed.callTx.myCircuit(arg1, arg2);
// Returns: FinalizedCallTxData with txId, txHash, blockHeight
```

Advantages:
- Simplest API surface
- Automatic error handling across all stages
- Blocks until on-chain confirmation

Limitations:
- No control over individual stages
- Cannot inspect intermediate state
- Blocks the calling thread until finalization

### Low-Level (Manual Pipeline)

```typescript
import {
  createUnprovenCallTx,
  submitCallTx,
  submitCallTxAsync,
} from "@midnight-ntwrk/midnight-js-contracts";

// Stage 1: Build
const unproven = await createUnprovenCallTx(deployed, providers, "myCircuit", [arg1, arg2]);

// Inspect unproven transaction here if needed
console.log("Unproven tx created, circuit:", unproven.circuitId);

// Stages 2-5: Prove + Balance + Submit + Finalize
const txData = await submitCallTx(providers, unproven);

// OR Stages 2-4 only: Prove + Balance + Submit (no finalization wait)
const txId = await submitCallTxAsync(providers, unproven);
```

Advantages:
- Inspect or modify the transaction between stages
- Choose whether to wait for finalization
- Batch multiple unproven transactions before submission
- Custom error handling per stage

## Deployment Transaction Lifecycle

Contract deployment follows a similar pipeline with a dedicated function:

```typescript
import { deployContract } from "@midnight-ntwrk/midnight-js-contracts";

// Performs all 5 stages for the deployment transaction
const deployed = await deployContract(providers, {
  compiledContract,
  privateStateId: "myState",
  initialPrivateState: { secretKey },
  args: [constructorArg1],  // Optional constructor arguments
});

// deployed.deployTxData contains:
deployed.deployTxData.public.contractAddress;  // The new contract's address
deployed.deployTxData.public.txId;
deployed.deployTxData.public.blockHeight;
```

The deployment transaction:
1. Includes the contract bytecode and initial state
2. Is proven (ZK proof that the constructor executed correctly)
3. Is balanced (fees added)
4. Is submitted and confirmed
5. The contract address is deterministically derived from the transaction

## Error Handling by Stage

| Stage | Error Type | Common Causes |
|-------|-----------|---------------|
| Build | Witness execution error | Private state missing, witness logic error, type mismatch |
| Prove | Proof generation failure | Proof server not running, circuit too complex, timeout |
| Balance | Balancing failure | Insufficient funds, no available UTXOs, wallet disconnected |
| Submit | Submission rejection | Invalid transaction, node unreachable, nonce conflict |
| Finalize | Finalization timeout | Network congestion, transaction dropped, indexer lag |

```typescript
try {
  const txData = await deployed.callTx.myCircuit(arg);
} catch (error) {
  if (error instanceof CallTxFailedError) {
    // Transaction was submitted but failed on-chain
    console.error("On-chain failure:", error.message);
  } else if (error.message?.includes("proof")) {
    // Proof generation failed
    console.error("Proving error:", error.message);
  } else if (error.message?.includes("balance")) {
    // Balancing failed (likely insufficient funds)
    console.error("Balance error:", error.message);
  } else {
    // Other errors (witness execution, network, etc.)
    console.error("Transaction error:", error);
  }
}
```

## Transaction Timing

Typical durations for each stage on a healthy network:

| Stage | Local (Undeployed) | Preview/Preprod |
|-------|-------------------|-----------------|
| Build | < 100ms | < 100ms |
| Prove | 2-30s (depends on circuit) | 2-30s |
| Balance | < 500ms | < 1s |
| Submit | < 500ms | < 2s |
| Finalize | ~6s (one block) | ~20s (block time varies) |

Proof generation is the bottleneck. Complex circuits with many constraints take longer to prove. The proof server caches some intermediate computations, so repeated proofs for the same circuit are faster.

## Concurrent Transactions

Multiple transactions can be in-flight simultaneously using async variants:

```typescript
// Submit multiple transactions without waiting for each to finalize
const txIds = await Promise.all([
  submitCallTxAsync(providers, unproven1),
  submitCallTxAsync(providers, unproven2),
  submitCallTxAsync(providers, unproven3),
]);

// Watch for all finalizations via observable
let finalized = 0;
providers.publicDataProvider
  .contractStateObservable(contractAddress, { type: "latest" })
  .subscribe((state) => {
    finalized++;
    if (finalized === txIds.length) {
      console.log("All transactions finalized");
    }
  });
```

Note: concurrent transactions from the same wallet must not conflict on UTXOs. The wallet provider handles UTXO selection, but rapid concurrent submissions can cause balancing failures if available UTXOs are exhausted.
