---
name: midnight-verify:verify-ledger
description: >-
  Ledger/protocol claim classification and method routing. Determines what kind
  of ledger claim is being verified and which verification methods apply:
  source investigation (primary), type-checking (pre-flight for TypeScript API),
  compilation/execution (secondary for testable claims), or ledger-v8 execution
  (secondary for API behavioral claims). Handles claims about transaction
  structure, token mechanics (Night/Zswap/Dust), cost model, on-chain VM,
  contract execution, cryptographic primitives, well-formedness rules, and the
  @midnight-ntwrk/ledger-v8 TypeScript API. Loaded by the verifier agent
  alongside the hub skill.
version: 0.1.0
---

# Ledger/Protocol Claim Classification

This skill classifies ledger and protocol claims and determines which verification method to use. The verifier (orchestrator) agent loads this alongside the hub skill (`verify-correctness`).

## Verification Flow

Ledger claims have a richer verification hierarchy than other domains because the ledger crates produce the compiled output that the contract-writer and zkir-checker already work with.

1. **Type-check (pre-flight)** — for TypeScript API claims only. Dispatch type-checker against the existing sdk-workspace (ledger-v8 is already installed). Pre-flight only, never a standalone verdict.
2. **Source investigation (primary)** — always runs for protocol claims. Dispatch source-investigator, which loads `verify-by-ledger-source` for Rust crate-level routing.
3. **Compilation/execution (secondary)** — for claims testable via Compact contracts. Dispatch contract-writer (compile + execute, extract ledger-level evidence) or zkir-checker (inspect compiled circuits).
4. **Ledger-v8 execution (secondary)** — for claims about TypeScript API behavioral output. Write a script that calls ledger-v8 functions and observes output.

## Claim Type → Method Routing

### Claims About Protocol Structure

| Claim Type | Example | Pre-flight | Primary | Secondary |
|---|---|---|---|---|
| Transaction format | "Transactions contain intents, offers, and binding randomness" | — | source-investigator | — |
| Segment ordering | "Segment 0 is guaranteed, executes first" | — | source-investigator | contract-writer (negative test) |
| Causal precedence | "Contract A calling B means A causally precedes B" | — | source-investigator | — |
| Replay protection | "Intent hashes stored in TimeFilterMap" | — | source-investigator | — |
| Well-formedness | "Disjoint check prevents input/output overlap" | — | source-investigator | contract-writer (build invalid tx) |
| Proof staging | "UnprovenTransaction transitions to Proven via prove()" | — | source-investigator | ledger-v8 execution |

### Claims About Token Mechanics

| Claim Type | Example | Pre-flight | Primary | Secondary |
|---|---|---|---|---|
| Night UTXO | "UTXO uniqueness from (intent_hash, output_no)" | — | source-investigator | — |
| Zswap commitments | "CoinCommitment = Hash<(CoinInfo, CoinPublicKey)>" | — | source-investigator | ledger-v8 execution (call coinCommitment) |
| Zswap nullifiers | "CoinNullifier = Hash<(CoinInfo, CoinSecretKey)>" | — | source-investigator | ledger-v8 execution (call coinNullifier) |
| Zswap transients | "Transients use ephemeral single-leaf Merkle tree" | — | source-investigator | — |
| Dust generation | "Dust generates proportional to backing Night value" | — | source-investigator | — |
| Dust spending | "Dust spend requires ZK proof of generation chain" | — | source-investigator | — |
| Token types | "NIGHT is TokenType::Unshielded with raw [0u8; 32]" | — | source-investigator | ledger-v8 execution (call nativeToken) |

### Claims About Cost Model

| Claim Type | Example | Pre-flight | Primary | Secondary |
|---|---|---|---|---|
| Cost dimensions | "SyntheticCost has 5 dimensions: read, compute, block, write, churn" | — | source-investigator | — |
| Fee formula | "Fee = max(read, compute, block) + write + churn" | — | source-investigator | contract-writer (compile, measure cost) |
| Block limits | "Block usage limit is 200,000 bytes" | — | source-investigator | — |
| Price adjustment | "Per-dimension price targets 50% block fullness" | — | source-investigator | — |
| Guaranteed limits | "Guaranteed section has separate cost bounds" | — | source-investigator | — |

### Claims About On-Chain VM

| Claim Type | Example | Pre-flight | Primary | Secondary |
|---|---|---|---|---|
| Opcode semantics | "idx loads from Map by key" | — | source-investigator | zkir-checker (inspect compiled) |
| StateValue types | "5 types: Null, Cell, Map, Array, BoundedMerkleTree" | — | source-investigator | — |
| Stack machine | "VM is a stack machine, always exactly 1 item initially" | — | source-investigator | — |
| Cached reads | "idxc requires value to be cached in memory" | — | source-investigator | — |

### Claims About Contract Execution

| Claim Type | Example | Pre-flight | Primary | Secondary |
|---|---|---|---|---|
| Contract address | "ContractAddress = Hash<ContractDeploy>" | — | source-investigator | — |
| Effects system | "Effects declare claimed nullifiers, commitments, calls" | — | source-investigator | contract-writer (compile + execute) |
| Caller determination | "Caller is calling contract, then single UTXO owner, then None" | — | source-investigator | — |
| Transcripts | "Guaranteed transcript executes before fees are taken" | — | source-investigator | — |

### Claims About Cryptographic Primitives

| Claim Type | Example | Pre-flight | Primary | Secondary |
|---|---|---|---|---|
| Pedersen commitments | "Value commitment = g*r + h*v where h = hash(type, segment)" | — | source-investigator | — |
| Fiat-Shamir binding | "Binding uses challenge c = hash(ErasedIntent, g*r, g*s)" | — | source-investigator | — |
| Signatures | "Schnorr over Secp256k1 per BIP 340" | — | source-investigator | — |
| Hashing | "field::hash uses Poseidon" | — | source-investigator | — |
| Merkle trees | "Commitment tree uses persistent Merkle tree" | — | source-investigator | — |

### Claims About Ledger TypeScript API

| Claim Type | Example | Pre-flight | Primary | Secondary |
|---|---|---|---|---|
| Type/export existence | "ledger-v8 exports Transaction class" | type-checker | source-investigator | — |
| Function signature | "coinCommitment takes (coin, coinPublicKey)" | type-checker | source-investigator | — |
| Function behavior | "nativeToken() returns the NIGHT raw token type" | type-checker | source-investigator | ledger-v8 execution |
| Class API | "ZswapLocalState has spend() method" | type-checker | source-investigator | — |
| CostModel API | "CostModel.initialCostModel() returns default fee config" | type-checker | source-investigator | ledger-v8 execution |

### Claims About Formal Properties

| Claim Type | Example | Pre-flight | Primary | Secondary |
|---|---|---|---|---|
| Balance preservation | "Total funds preserved except mints, dust, and treasury" | — | source-investigator | — |
| Transaction binding | "Assembled transaction cannot be disassembled" | — | source-investigator | — |
| Infragility | "Defensively-created tx survives malicious merge" | — | source-investigator | — |
| Causality | "Contract call A → B implies A success ⟹ B success" | — | source-investigator | — |
| Self-determination | "User cannot spend another user's funds" | — | source-investigator | — |

### Routing Rules

**When in doubt:**
- Protocol structure, token mechanics, crypto primitives → source-investigator (Rust source is authoritative)
- TypeScript API surface → type-checker pre-flight + source-investigator (trace WASM binding to Rust)
- Testable behavior (cost, well-formedness, token operations) → source-investigator + contract-writer or ledger-v8 execution as secondary
- Formal properties → source-investigator only (these are about the proof structure in code)

**Source investigation is always primary.** Secondary methods (compilation, execution) provide corroborating evidence but are not required for a verdict.

## Hints from Existing Skills

The verifier or sub-agents may consult these skills for context. They are **hints only** — never cite them as evidence.

- `compact-core:compact-standard-library` — stdlib functions that map to ledger primitives
- `compact-core:compact-compilation` — how Compact compiles to ZKIR (relevant for VM claims)
- `midnight-tooling:compact-cli` — compiler behavior and flags
