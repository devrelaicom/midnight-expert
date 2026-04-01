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
  @midnight-ntwrk/ledger-v8 TypeScript API. Loaded by the /verify command
  alongside the hub skill.
version: 0.1.0
---

# Ledger/Protocol Claim Classification

This skill classifies ledger and protocol claims and determines which verification method to use. The /verify command loads this alongside the `midnight-verify:verify-correctness` hub skill.

## Verification Flow

Ledger claims have a richer verification hierarchy than other domains because the ledger crates produce the compiled output that the contract-writer and zkir-checker already work with.

1. **Type-check (pre-flight)** — for TypeScript API claims only. Dispatch @"midnight-verify:type-checker (agent)" against the existing sdk-workspace (ledger-v8 is already installed). Pre-flight only, never a standalone verdict.
2. **Source investigation (primary)** — always runs for protocol claims. Dispatch @"midnight-verify:source-investigator (agent)", which loads `verify-by-ledger-source` for Rust crate-level routing.
3. **Compilation/execution (secondary)** — for claims testable via Compact contracts. Dispatch @"midnight-verify:contract-writer (agent)" (compile + execute, extract ledger-level evidence) or @"midnight-verify:zkir-checker (agent)" (inspect compiled circuits).
4. **Ledger-v8 execution (secondary)** — for claims about TypeScript API behavioral output. Write a script that calls ledger-v8 functions and observes output.

## Claim Type → Method Routing

### Claims About Protocol Structure

| Claim Type | Example | Pre-flight | Primary | Secondary |
|---|---|---|---|---|
| Transaction format | "Transactions contain intents, offers, and binding randomness" | — | @"midnight-verify:source-investigator (agent)" | — |
| Segment ordering | "Segment 0 is guaranteed, executes first" | — | @"midnight-verify:source-investigator (agent)" | @"midnight-verify:contract-writer (agent)" (negative test) |
| Causal precedence | "Contract A calling B means A causally precedes B" | — | @"midnight-verify:source-investigator (agent)" | — |
| Replay protection | "Intent hashes stored in TimeFilterMap" | — | @"midnight-verify:source-investigator (agent)" | — |
| Well-formedness | "Disjoint check prevents input/output overlap" | — | @"midnight-verify:source-investigator (agent)" | @"midnight-verify:contract-writer (agent)" (build invalid tx) |
| Proof staging | "UnprovenTransaction transitions to Proven via prove()" | — | @"midnight-verify:source-investigator (agent)" | ledger-v8 execution |

### Claims About Token Mechanics

| Claim Type | Example | Pre-flight | Primary | Secondary |
|---|---|---|---|---|
| Night UTXO | "UTXO uniqueness from (intent_hash, output_no)" | — | @"midnight-verify:source-investigator (agent)" | — |
| Zswap commitments | "CoinCommitment = Hash<(CoinInfo, CoinPublicKey)>" | — | @"midnight-verify:source-investigator (agent)" | ledger-v8 execution (call coinCommitment) |
| Zswap nullifiers | "CoinNullifier = Hash<(CoinInfo, CoinSecretKey)>" | — | @"midnight-verify:source-investigator (agent)" | ledger-v8 execution (call coinNullifier) |
| Zswap transients | "Transients use ephemeral single-leaf Merkle tree" | — | @"midnight-verify:source-investigator (agent)" | — |
| Dust generation | "Dust generates proportional to backing Night value" | — | @"midnight-verify:source-investigator (agent)" | — |
| Dust spending | "Dust spend requires ZK proof of generation chain" | — | @"midnight-verify:source-investigator (agent)" | — |
| Token types | "NIGHT is TokenType::Unshielded with raw [0u8; 32]" | — | @"midnight-verify:source-investigator (agent)" | ledger-v8 execution (call nativeToken) |

### Claims About Cost Model

| Claim Type | Example | Pre-flight | Primary | Secondary |
|---|---|---|---|---|
| Cost dimensions | "SyntheticCost has 5 dimensions: read, compute, block, write, churn" | — | @"midnight-verify:source-investigator (agent)" | — |
| Fee formula | "Fee = max(read, compute, block) + write + churn" | — | @"midnight-verify:source-investigator (agent)" | @"midnight-verify:contract-writer (agent)" (compile, measure cost) |
| Block limits | "Block usage limit is 200,000 bytes" | — | @"midnight-verify:source-investigator (agent)" | — |
| Price adjustment | "Per-dimension price targets 50% block fullness" | — | @"midnight-verify:source-investigator (agent)" | — |
| Guaranteed limits | "Guaranteed section has separate cost bounds" | — | @"midnight-verify:source-investigator (agent)" | — |

### Claims About On-Chain VM

| Claim Type | Example | Pre-flight | Primary | Secondary |
|---|---|---|---|---|
| Opcode semantics | "idx loads from Map by key" | — | @"midnight-verify:source-investigator (agent)" | @"midnight-verify:zkir-checker (agent)" (inspect compiled) |
| StateValue types | "5 types: Null, Cell, Map, Array, BoundedMerkleTree" | — | @"midnight-verify:source-investigator (agent)" | — |
| Stack machine | "VM is a stack machine, always exactly 1 item initially" | — | @"midnight-verify:source-investigator (agent)" | — |
| Cached reads | "idxc requires value to be cached in memory" | — | @"midnight-verify:source-investigator (agent)" | — |

### Claims About Contract Execution

| Claim Type | Example | Pre-flight | Primary | Secondary |
|---|---|---|---|---|
| Contract address | "ContractAddress = Hash<ContractDeploy>" | — | @"midnight-verify:source-investigator (agent)" | — |
| Effects system | "Effects declare claimed nullifiers, commitments, calls" | — | @"midnight-verify:source-investigator (agent)" | @"midnight-verify:contract-writer (agent)" (compile + execute) |
| Caller determination | "Caller is calling contract, then single UTXO owner, then None" | — | @"midnight-verify:source-investigator (agent)" | — |
| Transcripts | "Guaranteed transcript executes before fees are taken" | — | @"midnight-verify:source-investigator (agent)" | — |

### Claims About Cryptographic Primitives

| Claim Type | Example | Pre-flight | Primary | Secondary |
|---|---|---|---|---|
| Pedersen commitments | "Value commitment = g*r + h*v where h = hash(type, segment)" | — | @"midnight-verify:source-investigator (agent)" | — |
| Fiat-Shamir binding | "Binding uses challenge c = hash(ErasedIntent, g*r, g*s)" | — | @"midnight-verify:source-investigator (agent)" | — |
| Signatures | "Schnorr over Secp256k1 per BIP 340" | — | @"midnight-verify:source-investigator (agent)" | — |
| Hashing | "field::hash uses Poseidon" | — | @"midnight-verify:source-investigator (agent)" | — |
| Merkle trees | "Commitment tree uses persistent Merkle tree" | — | @"midnight-verify:source-investigator (agent)" | — |

### Claims About Ledger TypeScript API

| Claim Type | Example | Pre-flight | Primary | Secondary |
|---|---|---|---|---|
| Type/export existence | "ledger-v8 exports Transaction class" | @"midnight-verify:type-checker (agent)" | @"midnight-verify:source-investigator (agent)" | — |
| Function signature | "coinCommitment takes (coin, coinPublicKey)" | @"midnight-verify:type-checker (agent)" | @"midnight-verify:source-investigator (agent)" | — |
| Function behavior | "nativeToken() returns the NIGHT raw token type" | @"midnight-verify:type-checker (agent)" | @"midnight-verify:source-investigator (agent)" | ledger-v8 execution |
| Class API | "ZswapLocalState has spend() method" | @"midnight-verify:type-checker (agent)" | @"midnight-verify:source-investigator (agent)" | — |
| CostModel API | "CostModel.initialCostModel() returns default fee config" | @"midnight-verify:type-checker (agent)" | @"midnight-verify:source-investigator (agent)" | ledger-v8 execution |

### Claims About Formal Properties

| Claim Type | Example | Pre-flight | Primary | Secondary |
|---|---|---|---|---|
| Balance preservation | "Total funds preserved except mints, dust, and treasury" | — | @"midnight-verify:source-investigator (agent)" | — |
| Transaction binding | "Assembled transaction cannot be disassembled" | — | @"midnight-verify:source-investigator (agent)" | — |
| Infragility | "Defensively-created tx survives malicious merge" | — | @"midnight-verify:source-investigator (agent)" | — |
| Causality | "Contract call A → B implies A success ⟹ B success" | — | @"midnight-verify:source-investigator (agent)" | — |
| Self-determination | "User cannot spend another user's funds" | — | @"midnight-verify:source-investigator (agent)" | — |

### Routing Rules

**When in doubt:**
- Protocol structure, token mechanics, crypto primitives → @"midnight-verify:source-investigator (agent)" (Rust source is authoritative)
- TypeScript API surface → @"midnight-verify:type-checker (agent)" pre-flight + @"midnight-verify:source-investigator (agent)" (trace WASM binding to Rust)
- Testable behavior (cost, well-formedness, token operations) → @"midnight-verify:source-investigator (agent)" + @"midnight-verify:contract-writer (agent)" or ledger-v8 execution as secondary
- Formal properties → @"midnight-verify:source-investigator (agent)" only (these are about the proof structure in code)

**Source investigation is always primary.** Secondary methods (compilation, execution) provide corroborating evidence but are not required for a verdict.

## Hints from Existing Skills

Sub-agents may load these skills for context. They are **hints only** — never cite skill content as evidence.

- `compact-core:compact-standard-library` skill — stdlib functions that map to ledger primitives
- `midnight-tooling:compact-cli` skill — how Compact compiles to ZKIR (relevant for VM claims)
- `midnight-tooling:compact-cli` skill — compiler behavior and flags
