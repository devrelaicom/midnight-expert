# ZKIR and Keys

Deep-dive reference covering ZKIR format, prover/verifier keys, circuit metrics, and the `--skip-zk` development workflow. These are the cryptographic artifacts produced during Compact compilation that enable zero-knowledge proof generation and on-chain verification.

## ZKIR Overview

ZKIR (Zero-Knowledge Intermediate Representation) is a circuit description format produced by the Compact compiler. It encodes the constraint system for each exported impure circuit, telling the proof server how to generate ZK proofs at runtime.

Each exported impure circuit produces its own ZKIR file. Pure circuits and non-exported circuits do not generate ZKIR because they do not require independent ZK proofs.

## ZKIR Formats

The compiler produces two serialization formats for each circuit's ZKIR:

| Format | Extension | Description |
|--------|-----------|-------------|
| JSON | `.zkir` | Human-readable JSON containing the versioned circuit description |
| Binary | `.bzkir` | Binary encoding for more efficient processing |

Both files represent the same circuit -- they are different serializations of the same data. The JSON format is useful for inspection and debugging. The binary format is used by the proof infrastructure for faster loading.

After compilation, you will find these files in the `zkir/` output directory:

```
build/
  zkir/
    increment.zkir      # JSON format
    increment.bzkir     # Binary format
    reset.zkir
    reset.bzkir
```

## ZKIR Versioning

ZKIR files carry a version field in their JSON payload. Both v2 and v3 currently exist. The version determines which processing library is used.

Version detection reads the `version` field from the parsed JSON:

```typescript
type ZkirVersion = { major: number; minor: number };

const detectZkirVersion = (json: string): ZkirVersion => {
  const v = JSON.parse(json).version;
  if (!v) {
    throw new Error(`Unable to detect ZKIR version in JSON: ${json}`);
  }
  return v;
};
```

Different packages handle each version:

| Version | Package | Conversion Function |
|---------|---------|---------------------|
| v2 | `@midnight-ntwrk/zkir-v2` | `jsonIrToBinaryV2(json)` |
| v3 | `@midnight-ntwrk/zkir-v3` | `jsonIrToBinaryV3(json)` |

When loading ZKIR at runtime, the version is detected first and the appropriate converter is selected:

```typescript
import { jsonIrToBinary as jsonIrToBinaryV2 } from '@midnight-ntwrk/zkir-v2';
import { jsonIrToBinary as jsonIrToBinaryV3 } from '@midnight-ntwrk/zkir-v3';

const readIrFile = async (contractDir: string, circuitId: string): Promise<Uint8Array> => {
  const json = await fs.readFile(
    path.join(contractDir, 'zkir', circuitId + '.zkir'), 'utf-8'
  );
  const version = detectZkirVersion(json);
  return version.major === 3 ? jsonIrToBinaryV3(json) : jsonIrToBinaryV2(json);
};
```

### Zkir Class API

Both `@midnight-ntwrk/zkir-v2` and `@midnight-ntwrk/zkir-v3` export a `Zkir` class for working with circuit representations programmatically:

```typescript
class Zkir {
  static fromJson(json: string): Zkir;       // Parse from JSON string
  static deserialize(bytes: Uint8Array): Zkir; // Parse from binary
  getK(): number;                             // Get the evaluation domain parameter
  serialize(): Uint8Array;                    // Serialize to binary
}
```

## Prover Keys

One prover key is generated per exported impure circuit. Prover keys are stored in the `keys/` output directory with the `.prover` extension:

```
build/
  keys/
    increment.prover
    increment.verifier
    reset.prover
    reset.verifier
```

The prover key is part of `ProvingKeyMaterial`, the full bundle needed to generate a ZK proof for a circuit:

```typescript
type ProvingKeyMaterial = {
  proverKey: Uint8Array;   // The proving key bytes
  verifierKey: Uint8Array; // The corresponding verifier key bytes
  ir: Uint8Array;          // The ZKIR binary (circuit description)
};
```

Prover keys are used client-side (or by the proof server) to generate ZK proofs when a user submits a transaction that calls a circuit. The `KeyMaterialProvider` interface abstracts access to these keys:

```typescript
type KeyMaterialProvider = {
  lookupKey(keyLocation: string): Promise<ProvingKeyMaterial | undefined>;
  getParams(k: number): Promise<Uint8Array>;
};
```

The `getParams(k)` method fetches the structured reference string (SRS) parameters for a given domain size `k`. These parameters are shared across all circuits with the same `k` value and are typically downloaded once and cached.

## Verifier Keys

One verifier key is generated per exported impure circuit. Verifier keys are stored in the `keys/` output directory with the `.verifier` extension.

In the TypeScript SDK, verifier keys are typed as a branded `Uint8Array`:

```typescript
type VerifierKey = Uint8Array & Brand.Brand<'VerifierKey'>;
```

### Role in Contract Deployment

Verifier keys are submitted on-chain during contract deployment. They are embedded in the contract's on-chain state, allowing network validators to verify ZK proofs submitted with transactions -- without knowing the private witness values.

Each circuit's verifier key is loaded via the `ZKConfiguration` interface:

```typescript
interface ZKConfiguration.Reader<C> {
  getVerifierKey(
    provableCircuitId: ProvableCircuitId<C>
  ): Effect.Effect<
    Option.Option<VerifierKey>,
    ZKConfigurationReadError
  >;

  getVerifierKeys(
    provableCircuitIds: ProvableCircuitId<C>[]
  ): Effect.Effect<
    readonly [ProvableCircuitId<C>, Option.Option<VerifierKey>][],
    ZKConfigurationReadError
  >;
}
```

The file-system implementation (`ZKFileConfiguration`) reads verifier keys from the `keys/` directory:

```typescript
const KEYS_FOLDER = 'keys';
const VERIFIER_EXT = '.verifier';
```

### Verifier Key Management

After deployment, verifier keys can be updated on-chain using the Contract Maintenance Authority (CMA). This enables circuit upgrades without redeploying the entire contract:

- `insertVerifierKey(vk)` -- Add or replace a circuit's verifier key
- `removeVerifierKey()` -- Remove a circuit's verifier key

These operations require authorization from the contract's signing key.

## Circuit Metrics

The compiler outputs metrics for each circuit during compilation:

```
Compiling 2 circuits:
  circuit "increment" (k=13, rows=4569)
  circuit "reset" (k=13, rows=4580)
```

### Understanding k and rows

| Metric | Meaning | Impact |
|--------|---------|--------|
| `k` | Evaluation domain size is 2^k | Larger k = larger circuit = more computation for proving |
| `rows` | Actual number of constraint rows used | Must be <= 2^k |

The `k` parameter determines the size of the polynomial evaluation domain used in the proof system. A circuit with `k=13` operates in a domain of 2^13 = 8,192 rows. The actual constraint count (`rows`) must fit within this domain.

### What Metrics Tell You

- **Proving time scales with k**: Each increment of k roughly doubles the proving time and memory usage. A circuit with k=13 proves significantly faster than one with k=17.
- **Rows show actual complexity**: The gap between `rows` and 2^k shows how much unused capacity remains in the domain. A circuit with `rows=4569` and `k=13` (8,192 capacity) is using about 56% of its domain.
- **Identical k values share parameters**: Circuits with the same `k` can share SRS parameters, reducing download and storage overhead.

### Typical k Values

| k Range | Circuit Complexity | Example |
|---------|-------------------|---------|
| 10-13 | Simple circuits | Counters, basic state updates |
| 14-16 | Medium circuits | Token transfers, access control |
| 17-20 | Complex circuits | Merkle tree operations, complex business logic |

## Key Generation Bottleneck

Key generation is the slowest phase of compilation. The compiler shows a progress bar during this step because it can take significant time, especially for contracts with many circuits or circuits with large k values.

The time is dominated by:
- Computing the proving key from the circuit description and SRS parameters
- Deriving the verifier key from the proving key

For complex contracts with many exported impure circuits, full compilation can take several minutes. This is the primary motivation for the `--skip-zk` flag during development.

## The --skip-zk Flag

The `--skip-zk` flag skips key generation entirely, producing all compilation outputs **except** the `keys/` directory:

```bash
compactc --skip-zk contract.compact build/
```

### What --skip-zk Produces

| Output | With --skip-zk | Without --skip-zk |
|--------|---------------|-------------------|
| TypeScript bindings | Yes | Yes |
| `contract-info.json` | Yes | Yes |
| `zkir/*.zkir` files | Yes | Yes |
| `zkir/*.bzkir` files | Yes | Yes |
| `keys/*.prover` files | **No** | Yes |
| `keys/*.verifier` files | **No** | Yes |
| Circuit metrics in stderr | **No** | Yes |

The ZKIR directory is still generated because ZKIR production is fast -- it is only the key derivation step that is slow and gets skipped.

### Development Workflow

Use `--skip-zk` during active development for fast iteration:

```bash
# Fast compile for development (seconds)
compactc --skip-zk contract.compact build/

# Full compile before deployment (may take minutes)
compactc contract.compact build/
```

This workflow lets you quickly verify that your contract compiles, inspect the generated TypeScript bindings, and run unit tests that do not require proof generation -- all without waiting for key generation.

## When You Need Full Compilation

You must run compilation without `--skip-zk` in these situations:

| Scenario | Why |
|----------|-----|
| Before deploying to the network | Deployment requires verifier keys to be submitted on-chain |
| Before integration testing with the proof server | The proof server needs prover keys and ZKIR to generate proofs |
| Before submitting to CI/CD for release | Release artifacts must include complete key material |
| After changing any circuit logic | Keys are derived from the circuit description; changed circuits need new keys |

If you attempt to deploy a contract compiled with `--skip-zk`, the deployment will fail because the verifier keys are missing from the `keys/` directory.

## Proof Server Relationship

The proof server is a separate Docker container that generates ZK proofs for transactions at runtime. It reads ZKIR files and uses prover keys to produce proofs when a DApp submits a transaction.

```bash
docker run -p 6300:6300 midnightntwrk/proof-server -- midnight-proof-server --network testnet
```

The DApp communicates with the proof server via `httpClientProofProvider`, sending circuit inputs and receiving the generated proof. The proof is then included in the transaction submitted to the network, where validators verify it against the on-chain verifier keys.

The proof server is not involved during compilation -- it only consumes the compilation outputs at runtime. See the proof server documentation for configuration and operational details.

## Quick Reference

### Compilation Output Structure

```
build/
  contract/
    index.d.ts                # TypeScript type definitions
    index.js                  # JavaScript implementation
    index.js.map              # Source map
  zkir/
    <circuit>.zkir            # JSON circuit description
    <circuit>.bzkir           # Binary circuit description
  keys/                       # (absent with --skip-zk)
    <circuit>.prover          # Prover key material
    <circuit>.verifier        # Verifier key bytes
  compiler/
    contract-info.json        # Circuit manifest
```

### Key Types Summary

| Type | Package | Description |
|------|---------|-------------|
| `ProvingKeyMaterial` | `@midnight-ntwrk/zkir-v2`, `@midnight-ntwrk/zkir-v3` | Bundle of prover key + verifier key + IR bytes |
| `KeyMaterialProvider` | `@midnight-ntwrk/zkir-v2`, `@midnight-ntwrk/zkir-v3` | Interface to look up keys and SRS parameters |
| `VerifierKey` | `@midnight-ntwrk/compact-js` | Branded `Uint8Array` for on-chain verifier keys |
| `ZKIR` | `@midnight-ntwrk/compact-js` | Branded `Uint8Array` for ZKIR binary data |
| `ProvableCircuitId` | `@midnight-ntwrk/compact-js` | Branded identifier for circuits that require proofs |
