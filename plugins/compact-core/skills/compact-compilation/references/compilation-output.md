# Compilation Output

The Compact compiler transforms a `.compact` source file into a target directory containing four categories of artifacts: TypeScript/JavaScript bindings, ZK Intermediate Representation files, cryptographic keys, and compiler metadata. Together, these artifacts form everything a DApp needs to deploy and interact with a Midnight smart contract.

## Full Directory Tree

```
<target-dir>/
├── contract/
│   ├── index.d.ts          # TypeScript type definitions
│   ├── index.js            # JavaScript implementation (or index.cjs)
│   └── index.js.map        # Source map back to .compact source
├── zkir/
│   ├── <circuit>.zkir      # JSON ZK Intermediate Representation
│   └── <circuit>.bzkir     # Binary ZKIR (compiled from JSON)
├── keys/
│   ├── <circuit>.prover    # Prover key (ProvingKeyMaterial)
│   └── <circuit>.verifier  # Verifier key (Uint8Array)
└── compiler/
    └── contract-info.json  # Circuit manifest and metadata
```

## File Count Formula

For a contract with **N exported impure circuits**, the compiler produces:

| Category | Files | Count |
|----------|-------|-------|
| contract/ | `index.d.ts`, `index.js`, `index.js.map` | 3 |
| zkir/ | One `.zkir` + one `.bzkir` per exported impure circuit | 2N |
| keys/ | One `.prover` + one `.verifier` per exported impure circuit | 2N |
| compiler/ | `contract-info.json` | 1 |
| **Total** | | **4N + 4** |

Pure circuits and non-exported (internal) circuits do not add any files to `zkir/` or `keys/`.

## The Core Relationship

Each **exported impure circuit** produces exactly four ZK artifacts:

```
1 exported impure circuit = 1 .zkir + 1 .bzkir + 1 .prover + 1 .verifier
```

The rules are:

| Circuit type | contract/ | zkir/ | keys/ | compiler/ |
|---|---|---|---|---|
| Exported impure | Yes | Yes | Yes | Yes |
| Exported pure | Yes (in `pureCircuits`) | No | No | Yes |
| Internal (non-exported) | No | No | No | No |

**Why the distinction matters**: Impure circuits modify ledger state and therefore require ZK proofs to verify state transitions on-chain. Pure circuits perform stateless computations that need no proof. Internal circuits are inlined into their callers at compile time and produce no standalone artifacts.

## contract/ Directory

The `contract/` directory contains TypeScript and JavaScript bindings that your DApp imports to interact with the compiled contract. It includes types for **all** exported circuits, both pure and impure.

The three generated files are:

- **`index.d.ts`** -- TypeScript type definitions including the `Contract` class, `Witnesses` interface, `Ledger` type, `PureCircuits`, and `ImpureCircuits` type aliases. This is what provides type safety in your DApp code.
- **`index.js`** (or `index.cjs`) -- JavaScript implementation of the contract runtime. Instantiate the `Contract` class with your witness implementations to get a runnable contract.
- **`index.js.map`** -- Source map linking the generated JavaScript back to the original `.compact` source. This enables debugger step-through from TypeScript into Compact source.

The generated `Contract` class exposes:

```typescript
class Contract<PS, W extends Witnesses<PS>> {
  witnesses: W;
  circuits: Circuits<PS>;          // All exported circuits (pure + impure)
  impureCircuits: ImpureCircuits<PS>;  // Only impure circuits
  initialState(context: ConstructorContext<PS>, ...args): ConstructorResult<PS>;
}
```

Pure circuits are available as a separate export:

```typescript
const pureCircuits: PureCircuits;
```

For a deep dive into the generated TypeScript types, see `typescript-bindings.md`.

## zkir/ Directory

The `zkir/` directory contains one pair of files per **exported impure circuit**:

- **`<circuit>.zkir`** -- JSON-formatted ZK Intermediate Representation. This is a human-readable description of the circuit's constraint system, including version information, gates, and wiring.
- **`<circuit>.bzkir`** -- Binary ZKIR compiled from the JSON format. This is what the proof server actually consumes when generating proofs.

The JSON ZKIR includes a `version` field (e.g., `{ "major": 3, "minor": 0 }`) that determines which ZKIR runtime is used. The binary format is derived from the JSON by calling `jsonIrToBinary()`.

Pure circuits produce no ZKIR files because they require no ZK proofs.

For a deep dive into ZKIR structure and how it relates to keys, see `zkir-and-keys.md`.

## keys/ Directory

The `keys/` directory contains one prover/verifier key pair per **exported impure circuit**:

- **`<circuit>.prover`** -- The prover key (`ProvingKeyMaterial`). Used by the proof server to generate ZK proofs for transactions that call this circuit.
- **`<circuit>.verifier`** -- The verifier key (`Uint8Array`). Used by the network validators to verify that submitted proofs are valid.

Key generation is typically the **slowest part of compilation**. The compiler displays a progress meter during this phase:

```
Compiling 2 circuits:
  circuit "post" (k=13, rows=4569)
  circuit "takeDown" (k=13, rows=4580)
Overall progress [====================] 2/2
```

To skip key generation during development, use `--skip-zk`:

```bash
compact compile src/myContract.compact ./output --skip-zk
```

This produces the same output except without the `keys/` directory, which is useful for faster iteration when you only need the TypeScript bindings.

For a deep dive into key structure and the proving workflow, see `zkir-and-keys.md`.

## compiler/contract-info.json

The `contract-info.json` file is a circuit manifest containing metadata about every exported circuit in the contract. It has three top-level fields:

```json
{
  "circuits": [
    {
      "name": "increment",
      "pure": false,
      "arguments": [
        { "name": "amount", "type": { "type-name": "Uint<16>" } }
      ],
      "result-type": { "type-name": "[]" }
    },
    {
      "name": "add",
      "pure": true,
      "arguments": [
        { "name": "a", "type": { "type-name": "Uint<64>" } },
        { "name": "b", "type": { "type-name": "Uint<64>" } }
      ],
      "result-type": { "type-name": "Uint<64>" }
    }
  ],
  "witnesses": [...],
  "contracts": [...]
}
```

Each circuit entry includes:

| Field | Description |
|-------|-------------|
| `name` | Circuit name as declared in Compact |
| `pure` | `true` for pure circuits, `false` for impure |
| `arguments` | Array of parameter names and types |
| `result-type` | Return type of the circuit |

**Composable contracts**: The `contracts` array lists dependency contracts. When compiling a contract that references another deployed contract, the compiler reads the dependency's `contract-info.json` to validate the interface. If the file is missing or malformed, compilation fails with:

```
Exception: malformed contract-info file <path> for <Contract>:
  missing association for "circuits"; try recompiling <Contract>
```

**SDK consumption**: The `NodeZkConfigProvider` and `FetchZkConfigProvider` read this file at runtime to look up circuit metadata. When your DApp requests a verifier key for a circuit, the SDK first checks `contract-info.json` to confirm the circuit exists and whether it requires a proof:

```typescript
const zkConfigProvider = new NodeZkConfigProvider<CircuitKeys>(zkConfigPath);
```

## Stale File Cleanup

When a circuit is removed from the source code, the compiler automatically removes orphaned ZKIR files from the `zkir/` directory to prevent unnecessary key generation.

For example, if a contract originally exported circuits `foo` and `bar`, the `zkir/` directory would contain `foo.zkir`, `foo.bzkir`, `bar.zkir`, and `bar.bzkir`. If `bar` is later removed from the source, the compiler deletes the `bar` ZKIR files on the next compilation. Without this cleanup, the compiler would continue to generate prover and verifier keys for the removed circuit, wasting time and potentially causing failures if the proof system changed between compiler versions.

This cleanup applies only to `zkir/` files. The `keys/` directory is regenerated from the current ZKIR files, so stale keys are never produced as long as stale ZKIR files are removed.

## Annotated Example: PureImpureDemo

Using the `PureImpureDemo.compact` example (see `examples/PureImpureDemo.compact` in this skill), consider a contract with:

- 2 exported impure circuits: `increment` and `reset`
- 1 exported pure circuit: `add`
- 1 internal helper circuit: `double` (not exported)

```compact
export ledger count: Counter;

export circuit increment(amount: Uint<16>): [] {
  const doubled = double(amount);
  count.increment(disclose(doubled));
}

export circuit reset(): [] {
  count.resetToDefault();
}

export pure circuit add(a: Uint<64>, b: Uint<64>): Uint<64> {
  return a + b as Uint<64>;
}

circuit double(x: Uint<16>): Uint<16> {
  return (x + x) as Uint<16>;
}
```

### Compiler Output

```
Compiling 2 circuits:
  circuit "increment" (k=10, rows=...)
  circuit "reset" (k=10, rows=...)
Overall progress [====================] 2/2
```

Only 2 circuits are compiled (the exported impure ones). The pure circuit `add` and the internal helper `double` produce no ZK artifacts.

### Exact Files Produced

```
output/
├── contract/
│   ├── index.d.ts              # Types for increment, reset, AND add
│   ├── index.js                # Runtime for all exported circuits
│   └── index.js.map            # Source map to PureImpureDemo.compact
├── zkir/
│   ├── increment.zkir          # JSON ZKIR for increment
│   ├── increment.bzkir         # Binary ZKIR for increment
│   ├── reset.zkir              # JSON ZKIR for reset
│   └── reset.bzkir             # Binary ZKIR for reset
├── keys/
│   ├── increment.prover        # Proving key for increment
│   ├── increment.verifier      # Verification key for increment
│   ├── reset.prover            # Proving key for reset
│   └── reset.verifier          # Verification key for reset
└── compiler/
    └── contract-info.json      # Manifest for all 3 exported circuits
```

### What Each Circuit Type Produces

| Circuit | Type | contract/ | zkir/ | keys/ | compiler/ |
|---------|------|-----------|-------|-------|-----------|
| `increment` | Exported impure | `ImpureCircuits`, `Circuits` | `increment.zkir`, `increment.bzkir` | `increment.prover`, `increment.verifier` | Listed with `pure: false` |
| `reset` | Exported impure | `ImpureCircuits`, `Circuits` | `reset.zkir`, `reset.bzkir` | `reset.prover`, `reset.verifier` | Listed with `pure: false` |
| `add` | Exported pure | `PureCircuits`, `Circuits` | (none) | (none) | Listed with `pure: true` |
| `double` | Internal | (none) | (none) | (none) | (none) |

File count: N=2 exported impure circuits, so **4(2) + 4 = 12 files total**.

### How the DApp Consumes These Files

In a Node.js DApp, point the ZK config provider at the output directory:

```typescript
import { NodeZkConfigProvider } from '@midnight-ntwrk/midnight-js-node-zk-config-provider';

type CircuitKeys = 'increment' | 'reset';
const zkConfigProvider = new NodeZkConfigProvider<CircuitKeys>(
  path.resolve(__dirname, '..', 'output')
);
```

In a browser DApp, use the fetch-based provider instead:

```typescript
import { FetchZkConfigProvider } from '@midnight-ntwrk/midnight-js-fetch-zk-config-provider';

type CircuitKeys = 'increment' | 'reset';
const zkConfigProvider = new FetchZkConfigProvider<CircuitKeys>(
  window.location.origin,
  fetch.bind(window)
);
```

Note that the `CircuitKeys` type union includes only the **impure** circuit names. Pure circuits do not need ZK configuration because they produce no proofs.
