# ZK SNARK Internals

## PLONK Proving System

Midnight uses the **PLONK** proving system with polynomial commitments.

### Gate-Based Arithmetization

PLONK uses gate-based arithmetization rather than constraint matrices:
- **Gate constraints**: Define arithmetic relationships at each gate (e.g., multiplication, addition)
- **Copy constraints**: Ensure values that should be equal across different gates remain consistent

### 1. Universal Setup

PLONK uses a **universal Structured Reference String (SRS)** — a single trusted setup ceremony that works for ALL circuits up to a maximum size.

```text
UniversalSetup(max_size) → SRS
```

Key properties:
- **Universal**: One SRS supports any circuit up to the maximum gate count
- **No per-circuit ceremony**: Per-circuit proving and verification keys are DERIVED from the universal SRS during compilation

This is a significant improvement over earlier proving systems that required a new trusted ceremony for every circuit.

### 2. Proving

Prover creates proof using:
- Witness (private inputs)
- Public inputs
- Proving key (derived from universal SRS)

```text
Prove(ProvingKey, Witness, PublicInputs) → Proof
```

**Cost**: Proportional to circuit size. Seconds for typical contracts, depending on circuit complexity.

### 3. Verification

Verifier checks proof using:
- Proof
- Public inputs
- Verification key (derived from universal SRS)

```text
Verify(VerificationKey, Proof, PublicInputs) → bool
```

**Cost**: Constant time (milliseconds), regardless of circuit complexity.

## Proof Size

SNARK proofs are succinct:
- Small size (less than a kilobyte)
- Constant verification time
- Efficient on-chain verification

## Security Properties

### Completeness

Valid proof for valid statement always verifies.

### Soundness

Cannot create valid proof for false statement (computationally).

### Zero-Knowledge

Proof reveals nothing beyond statement truth.

## Cryptographic Primitives

Midnight's ZK circuits use specific cryptographic primitives:
- **Hashing** (`persistentHash`): Uses SHA-256 — stable across upgrades, safe for ledger state
- **Coin commitments** (`persistentCommit`): Hash-based commitments binding a value with randomness — used in shielded coin operations via `receiveShielded`/`sendShielded`

The "persistent" prefix indicates these functions use SHA-256, producing stable outputs across compiler versions — safe for storing in ledger state. Their counterparts (`transientHash`, `transientCommit`) use circuit-optimized algorithms that may change between compiler versions. Transient outputs must never be stored on-chain.

## Midnight's SNARK Usage

### Universal SRS

Midnight uses a universal SRS that supports all deployed circuits:
- The SRS is generated once and shared across all contracts
- Per-circuit proving and verification keys are derived from it during compilation

### Per-Circuit Keys

Each Compact circuit has its own keys derived from the universal SRS:
- Proving key (distributed to users)
- Verification key (stored with contract)

### Proof Generation

Users generate proofs locally:
1. Compile Compact to circuit
2. Provide witness (private inputs)
3. Generate proof
4. Submit proof + public transcript

### On-Chain Verification

Nodes verify:
1. Proof is well-formed
2. Proof verifies against public inputs
3. Public inputs match transaction data
