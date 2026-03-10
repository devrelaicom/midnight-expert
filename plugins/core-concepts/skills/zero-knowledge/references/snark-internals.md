# ZK SNARK Internals

## Mathematical Foundation

### Elliptic Curves

ZK SNARKs use elliptic curve cryptography for:
- Efficient group operations
- Bilinear pairings
- Compact representations

### Bilinear Pairings

A pairing is a function:
```
e: G1 × G2 → GT
```

Properties:
- Bilinearity: e(aP, bQ) = e(P, Q)^(ab)
- Non-degeneracy: e(P, Q) ≠ 1 for generators
- Computability: Efficiently computable

Pairings enable verification without revealing values.

## PLONK Proving System

Midnight uses the **PLONK** (Permutations over Lagrange-bases for Oecumenical Non-interactive Arguments of Knowledge) proving system with **KZG10** polynomial commitments.

### Gate-Based Arithmetization

PLONK uses gate-based arithmetization rather than constraint matrices:
- **Gate constraints**: Define arithmetic relationships at each gate (e.g., multiplication, addition)
- **Copy constraints**: Ensure wires carrying the same value are consistent across gates
- **Permutation argument**: Enforces copy constraints efficiently via a grand product check

### 1. Universal Setup

PLONK uses a **universal Structured Reference String (SRS)** — a single trusted setup ceremony that works for ALL circuits up to a maximum size.

```
UniversalSetup(max_size) → SRS
```

Key properties:
- **Universal**: One SRS supports any circuit up to the maximum gate count
- **Updatable**: Additional participants can strengthen the SRS security over time
- **No per-circuit ceremony**: Per-circuit proving and verification keys are DERIVED from the universal SRS during compilation

This is a significant improvement over earlier proving systems that required a new trusted ceremony for every circuit.

### 2. Proving

Prover creates proof using:
- Witness (private inputs)
- Public inputs
- Proving key (derived from universal SRS)

```
Prove(ProvingKey, Witness, PublicInputs) → Proof
```

**Cost**: Proportional to circuit size. Seconds for typical contracts, depending on circuit complexity.

### 3. Verification

Verifier checks proof using:
- Proof
- Public inputs
- Verification key (derived from universal SRS)

```
Verify(VerificationKey, Proof, PublicInputs) → bool
```

Verification involves checking polynomial commitment (KZG10) evaluations via pairing checks.

**Cost**: Constant time (milliseconds), regardless of circuit complexity.

## Proof Size

SNARK proofs are succinct:
- Constant size (less than a kilobyte), independent of circuit complexity
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
- **Hashing** (`persistentHash`): Uses Poseidon hash — efficient in ZK circuits due to low gate count
- **Commitments** (`persistentCommit`): Hash-based commitments for hiding values with randomness
- **Balance proofs**: Use Pedersen commitments (multi-base, homomorphic) — a separate mechanism from coin commitments

## Midnight's SNARK Usage

### Universal SRS

Midnight uses a universal SRS that supports all deployed circuits:
- The SRS is generated once and shared across all contracts
- Per-circuit proving and verification keys are derived from it during compilation
- The SRS is updatable, allowing ongoing security improvements

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
