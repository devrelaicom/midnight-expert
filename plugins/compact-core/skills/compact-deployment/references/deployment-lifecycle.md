# Deployment Lifecycle

Reference for the contract deployment and interaction workflow: preparing compiled contracts, deploying them, joining existing deployments, and calling circuits. For provider setup, see `references/network-and-providers.md`. For wallet configuration, see `references/wallet-setup.md`.

## CompiledContract Preparation

Before deploying, wrap the compiler-generated Contract class with its ZK assets using `CompiledContract` from `@midnight-ntwrk/compact-js`:

```typescript
import { CompiledContract } from "@midnight-ntwrk/compact-js";
import { MyContract } from "./managed/mycontract/contract/index.js";
import { witnesses } from "./witnesses.js";

const myCompiledContract = CompiledContract.make("mycontract", MyContract.Contract).pipe(
  CompiledContract.withWitnesses(witnesses),
  CompiledContract.withCompiledFileAssets("src/managed/mycontract"),
);
```

The pipeline:
1. **`CompiledContract.make(name, ContractClass)`** — Creates a compiled contract wrapper
2. **`.withWitnesses(witnesses)`** — Binds witness implementations (or use `.withVacantWitnesses` if the contract has no witnesses)
3. **`.withCompiledFileAssets(path)`** — Points to the `managed/<name>` directory containing `keys/`, `zkir/`, `compiler/`, and `contract/`

### Contracts Without Witnesses

If the contract has no `witness` declarations:

```typescript
const compiled = CompiledContract.make("mycontract", MyContract.Contract).pipe(
  CompiledContract.withVacantWitnesses,
  CompiledContract.withCompiledFileAssets("src/managed/mycontract"),
);
```

## Type Aliases

Define type aliases for type-safe provider and contract references:

```typescript
import type { ImpureCircuitId } from "@midnight-ntwrk/compact-js";
import type { MidnightProviders } from "@midnight-ntwrk/midnight-js-types";
import type { DeployedContract, FoundContract } from "@midnight-ntwrk/midnight-js-contracts";

// Circuit keys union type
type MyCircuits = ImpureCircuitId<MyContract.Contract<MyPrivateState>>;

// Provider type alias
type MyProviders = MidnightProviders<MyCircuits, typeof PrivateStateId, MyPrivateState>;

// Contract type alias (works for both deployed and found)
type DeployedMyContract = DeployedContract<MyContract.Contract<MyPrivateState>>
  | FoundContract<MyContract.Contract<MyPrivateState>>;
```

## deployContract()

Deploys a new contract to the network:

```typescript
import { deployContract } from "@midnight-ntwrk/midnight-js-contracts";

const deployed = await deployContract(providers, {
  compiledContract: myCompiledContract,
  privateStateId: "myContractState",
  initialPrivateState: { secretKey: mySecretKey },
});
```

### Options

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `compiledContract` | `CompiledContract` | Yes | Prepared contract with witnesses and ZK assets |
| `privateStateId` | `string` | Yes | Key for the private state provider store |
| `initialPrivateState` | `PS` | Yes | Initial off-chain state for witnesses |

### Return Value

`deployContract` returns a `DeployedContract<C>` object:

```typescript
// Transaction metadata
deployed.deployTxData.public.contractAddress  // ContractAddress (hex string)
deployed.deployTxData.public.txId             // TransactionId
deployed.deployTxData.public.blockHeight      // bigint
deployed.deployTxData.public.txHash           // string

// Circuit call methods
deployed.callTx.myCircuit(arg1, arg2)         // Promise<FinalizedCallTxData>

// Private deployment data
deployed.deployTxData.private.signingKey       // Signing key for this contract
deployed.deployTxData.private.initialPrivateState  // The initial private state
```

### Error Handling

`deployContract` throws `DeployTxFailedError` if the transaction is submitted but fails on-chain:

```typescript
import { DeployTxFailedError } from "@midnight-ntwrk/midnight-js-contracts";

try {
  const deployed = await deployContract(providers, options);
} catch (error) {
  if (error instanceof DeployTxFailedError) {
    console.error("Deployment failed on-chain:", error.message);
  }
  throw error;
}
```

## findDeployedContract()

Joins an existing contract by its address. This subscribes to the indexer and watches until the contract is found:

```typescript
import { findDeployedContract } from "@midnight-ntwrk/midnight-js-contracts";

const found = await findDeployedContract(providers, {
  contractAddress: "0xabc123...",
  compiledContract: myCompiledContract,
  privateStateId: "myContractState",
  initialPrivateState: { secretKey: mySecretKey },
});
```

### Options

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `contractAddress` | `ContractAddress` | Yes | On-chain hex address of the deployed contract |
| `compiledContract` | `CompiledContract` | Yes | Same compiled contract used for deployment |
| `privateStateId` | `string` | Yes | Key for the private state provider store |
| `initialPrivateState` | `PS` | Yes | Initial off-chain state (each joiner has their own) |

### Return Value

Returns a `FoundContract<C>` with the same `callTx` interface as `DeployedContract`:

```typescript
found.callTx.myCircuit(arg1)  // Same interface as deployed
found.deployTxData.public.contractAddress
```

`findDeployedContract` is used when:
- A second user joins a contract deployed by someone else
- An application reconnects to a previously deployed contract
- Testing multi-party scenarios

## Calling Circuits

After deployment or joining, call exported circuits via the `callTx` object:

```typescript
// No arguments
const txData = await deployed.callTx.increment();

// With arguments
const txData = await deployed.callTx.transfer(recipientKey, 100n);

// Access result metadata
console.log(`Tx: ${txData.public.txId}`);
console.log(`Block: ${txData.public.blockHeight}`);
```

Each `callTx` method:
1. Constructs the circuit call transaction
2. Calls witnesses to provide private inputs
3. Generates a ZK proof via the proof server
4. Balances the transaction (adds fee inputs/outputs)
5. Submits to the node
6. Waits for on-chain confirmation

### Error Handling for Circuit Calls

```typescript
import { CallTxFailedError } from "@midnight-ntwrk/midnight-js-contracts";

try {
  const txData = await deployed.callTx.myCircuit();
} catch (error) {
  if (error instanceof CallTxFailedError) {
    console.error("Circuit call failed:", error.message);
  }
}
```

## Reading Ledger State

Query on-chain contract state through the indexer:

```typescript
import { MyContract } from "./managed/mycontract/contract/index.js";

// One-time query
const contractState = await providers.publicDataProvider.queryContractState(contractAddress);

if (contractState != null) {
  const ledgerState = MyContract.ledger(contractState.data);
  console.log(`Counter: ${ledgerState.counter}`);
  console.log(`Owner: ${Buffer.from(ledgerState.owner).toString("hex")}`);
}
```

### Observable State Changes

Subscribe to state updates in real-time:

```typescript
import { map } from "rxjs";

providers.publicDataProvider
  .contractStateObservable(contractAddress, { type: "latest" })
  .pipe(
    map((contractState) => MyContract.ledger(contractState.data)),
  )
  .subscribe((ledgerState) => {
    console.log(`Updated counter: ${ledgerState.counter}`);
  });
```

Only `export ledger` fields are visible through the `ledger()` function. Non-exported ledger fields are not accessible from TypeScript.

## Constructor Arguments

If a Compact contract has a `constructor`, its arguments are passed at deployment time. Constructors are used to initialize `sealed ledger` fields (immutable after deployment):

```compact
// Compact contract
export sealed ledger admin: Bytes<32>;
export ledger threshold: Uint<64>;

constructor(initial_threshold: Uint<64>) {
  admin = disclose(get_public_key(local_secret_key()));
  threshold = initial_threshold;
}
```

Constructor arguments are passed in the deployment options as additional positional arguments after the standard options:

```typescript
const deployed = await deployContract(providers, {
  compiledContract: myCompiledContract,
  privateStateId: "myContractState",
  initialPrivateState: { secretKey },
  args: [1000n],  // initial_threshold
});
```

## Contract Address Management

The contract address is a hex-encoded string returned after deployment:

```typescript
const address = deployed.deployTxData.public.contractAddress;

// Save for later use
import * as fs from "fs";
fs.writeFileSync("deployment.json", JSON.stringify({
  contractAddress: address,
  deployedAt: new Date().toISOString(),
  network: "preprod",
}, null, 2));

// Load and rejoin
const saved = JSON.parse(fs.readFileSync("deployment.json", "utf-8"));
const found = await findDeployedContract(providers, {
  contractAddress: saved.contractAddress,
  compiledContract: myCompiledContract,
  privateStateId: "myContractState",
  initialPrivateState: { secretKey },
});
```

Contract addresses are deterministic based on the deployment transaction. The same contract deployed twice produces different addresses.
