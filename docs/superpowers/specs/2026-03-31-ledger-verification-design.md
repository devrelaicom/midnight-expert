# Ledger Protocol Verification and Testing — Design Spec

**Date:** 2026-03-31
**Status:** Approved
**Scope:** Add ledger/protocol verification domain to midnight-verify plugin; add ledger-testing skill to midnight-cq plugin

## Overview

The Midnight ledger (`midnightntwrk/midnight-ledger`) is a Rust workspace producing WASM bindings that ship as npm packages (`@midnight-ntwrk/ledger-v8`, `@midnight-ntwrk/zkir-v2`, `@midnight-ntwrk/onchain-runtime`). It defines the protocol layer: transaction structure, three token systems (Night/Zswap/Dust), cost model, on-chain VM, contract execution, and cryptographic primitives. Claims about the ledger are foundational — errors here cascade into bad Compact code and bad DApp architecture.

## Design Decisions

- **Separate domain**: verify-ledger is a parallel domain skill (like verify-compact, verify-wallet-sdk). It owns all claims about the ledger — both protocol-level (Rust implementation) and TypeScript API (`ledger-v8`). There is minor overlap with verify-sdk for ledger-v8 type claims, but that's acceptable: verify-sdk covers ledger-v8 when it's part of a broader SDK usage check, verify-ledger covers it when the claim is specifically about the ledger.
- **Reuse agents**: No new agents. The existing source-investigator, type-checker, contract-writer, and zkir-checker agents are dispatched with ledger-specific context.
- **Source-first with rich secondary paths**: Source investigation against the Rust codebase is the primary method for all protocol claims. Unlike the wallet SDK (source-only for most claims), ledger claims have rich secondary verification via compilation and execution — because the ledger crates produce the compiled output that contract-writer and zkir-checker already work with.
- **New method skill for source investigation**: `verify-by-ledger-source` contains the 24-crate routing table and Rust-specific search guidance. Loaded by the source-investigator for ledger claims.
- **Execution guidance in existing skills**: Rather than new method skills, ledger-specific execution guidance is added to `verify-by-execution` (Ledger Execution Mode) and `verify-by-type-check` (Ledger API Execution Mode). These tell existing agents how to extract ledger-level evidence from their normal workflows.
- **midnight-cq ledger-testing skill**: Guides developers writing tests for code that uses `ledger-v8` and `onchain-runtime` directly.

## Part 1: midnight-verify — verify-ledger

### 1.1 Domain Skill: verify-ledger

**Purpose:** Classify ledger/protocol claims and route them to the correct verification methods.

**Domain indicators** (how the verifier orchestrator recognizes ledger claims):

- Transaction structure (intents, segments, offers, binding randomness, TTL)
- Token mechanics (Night UTXO, Zswap commitment/nullifier, Dust generation/spending/registration)
- Cost model (SyntheticCost dimensions, fee pricing, block limits, normalization, guaranteed segment limits)
- On-chain VM (opcodes, StateValue types, stack machine, cached/uncached reads, tainted values)
- Contract execution (ContractState, deployment, calls, transcripts, effects, caller determination)
- Cryptographic primitives (Pedersen commitments, Fiat-Shamir binding, coin commitments, nullifiers, Merkle trees, Poseidon hash)
- `@midnight-ntwrk/ledger-v8` API surface (Transaction class, ZswapLocalState, DustLocalState, LedgerState, CostModel, Intent)
- `@midnight-ntwrk/onchain-runtime` API surface (ContractState, StateValue, VM operations)
- Well-formedness rules (disjoint check, sequencing/causal precedence, effects check, balancing check, Pedersen check, TTL check)
- Field-aligned binary encoding (FAB format)
- Formal security properties (balance preservation, transaction binding, infragility, causality, self-determination)
- Replay protection (TimeFilterMap, intent hash history)
- Proof staging (UnprovenTransaction → proved → proof-erased → signature-erased)

**Verification flow:**

| Claim Category | Pre-flight | Primary | Secondary |
|---|---|---|---|
| Protocol structure (tx format, segments, offers) | — | source-investigator | contract-writer (build tx, check well-formedness) |
| Token mechanics (Night UTXO, Zswap, Dust) | — | source-investigator | contract-writer (test token operations) |
| Cost model (dimensions, formulas, limits) | — | source-investigator | contract-writer (compile, measure cost) |
| On-chain VM (opcodes, state types) | — | source-investigator | zkir-checker (inspect compiled ZKIR) |
| Contract execution (effects, caller, transcripts) | — | source-investigator | contract-writer (compile + execute) |
| Crypto primitives (commitments, nullifiers, hashes) | — | source-investigator | ledger-v8 execution (call functions, observe output) |
| Ledger TypeScript API (types, signatures, exports) | type-checker | source-investigator | ledger-v8 execution |
| Well-formedness rules | — | source-investigator | contract-writer (build invalid tx, confirm rejection) |
| FAB encoding | — | source-investigator | — |
| Security properties (theorems) | — | source-investigator | — |

**Verdict qualifiers:**

- `Confirmed (source-verified)` — Rust source confirms the claim
- `Confirmed (source-verified + tested)` — source confirmed, compilation/execution also confirms
- `Confirmed (tested)` — compilation/execution directly confirms (e.g., cost model output matches claim)
- `Refuted (source-verified)` — Rust source contradicts the claim
- `Refuted (tested)` — compilation/execution contradicts the claim
- `Inconclusive` — source investigation insufficient, no execution path available

### 1.2 Method Skill: verify-by-ledger-source

**Purpose:** Rust crate-level source investigation guidance for the source-investigator agent when handling ledger claims.

**Repository routing table:**

| Claim About | Crate | Key Paths |
|---|---|---|
| Coin types, commitments, nullifiers, token types | `coin-structure` | `src/coin.rs`, `src/contract.rs`, `src/transfer.rs` |
| NIGHT constant, ShieldedTokenType, UnshieldedTokenType | `coin-structure` | `src/coin.rs` |
| Hashing (persistent, transient, Poseidon) | `base-crypto` | `src/hash.rs` |
| Signatures (Schnorr/Secp256k1, BIP340) | `base-crypto` | `src/signatures.rs` |
| FAB encoding (field-aligned binary) | `base-crypto` | `src/fab/` |
| Pedersen commitments, value commitments | `transient-crypto` | `src/commitment.rs` |
| Encryption (Poseidon CTR, ECDH) | `transient-crypto` | `src/encryption.rs` |
| Merkle trees | `transient-crypto` | `src/merkle_tree.rs` |
| Curve operations (Fr, embedded curve) | `transient-crypto` | `src/curve.rs` |
| ZK proof structures, prover traits | `transient-crypto` | `src/proofs.rs` |
| VM opcodes, instruction execution | `onchain-vm` | `src/ops.rs`, `src/vm.rs` |
| VM cost model (per-instruction costs) | `onchain-vm` | `src/cost_model.rs` |
| StateValue types (Null, Cell, Map, Array, BoundedMerkleTree) | `onchain-state` | `src/` |
| Contract state, runtime context, transcripts | `onchain-runtime` | `src/context.rs`, `src/transcript.rs` |
| Communication commitment | `onchain-runtime` | `src/` (re-exported) |
| Transaction structure, assembly, well-formedness | `ledger` | `src/structure.rs`, `src/construct.rs`, `src/semantics.rs` |
| Transaction proving and verification | `ledger` | `src/prove.rs`, `src/verify.rs` |
| Dust operations (spend, registration, generation) | `ledger` | `src/dust.rs` |
| Intent structure, replay protection | `ledger` | `src/structure.rs` |
| Zswap offers, inputs, outputs, transients | `zswap` | `src/` |
| Zswap local state, chain state | `zswap` | `src/` |
| Fee token, cost model at ledger level | `ledger` | `src/structure.rs` (FEE_TOKEN) |
| Serialization format | `serialize` | `src/` |
| Storage (MPT, delta tracking) | `storage`, `storage-core` | `src/` |
| WASM bindings (ledger-v8 JS API) | `ledger-wasm` | `src/lib.rs`, `src/crypto.rs`, `src/tx.rs`, `src/zswap_wasm.rs`, `src/dust.rs` |
| WASM bindings (onchain-runtime JS API) | `onchain-runtime-wasm` | `src/` |
| ZKIR v2 checker/prover | `zkir` | `src/ir.rs`, `src/ir_vm.rs` |
| Precompiled circuits | `zkir-precompiles` | `dust/`, `zswap/`, `token-vault/`, etc. |
| Proof server HTTP API | `proof-server` | `src/main.rs` |

**Crate dependency graph context:**

```
base-crypto → transient-crypto → coin-structure → onchain-state → onchain-vm → onchain-runtime
                                                                                      ↓
                                                              zswap ← ledger ← ledger-wasm (WASM)
```

Supporting: `serialize`, `storage-core`, `storage`. Proofs: `zkir`, `zkir-v3`.

**Search strategy:**

1. Start with octocode-mcp `githubSearchCode` against `midnightntwrk/midnight-ledger`
2. For crypto primitive claims — start in `base-crypto` or `transient-crypto`
3. For transaction/protocol claims — start in `ledger/src/` then trace to `zswap/`, `coin-structure/`
4. For VM/runtime claims — start in `onchain-vm/src/` then `onchain-runtime/`
5. For TypeScript API claims — start in `ledger-wasm/src/` to find the WASM binding, then trace to the underlying Rust implementation
6. Clone locally (to /tmp, SSH, `--depth 1`) for cross-crate dependency tracing
7. Clean up cloned repos after investigation

**Evidence rules:**

Source code is evidence. Everything else is a hint.

| Source | Role | Rule |
|---|---|---|
| Rust source code (function definitions, type definitions, implementations) | Primary evidence | Always the target. Verdicts must cite Rust source. |
| Test files in the repo | Navigation aid | Follow test imports to find the right source code. Can be run as a last resort (clone to /tmp, `cargo test`), but realistically never needed. |
| `spec/` documents (13 specification files) | Hints only | Useful for orienting where to look. Never evidence on their own. Any claim derived from specs must be corroborated by Rust source inspection. |
| `docs/api/` generated TypeScript docs | Navigation aid | Useful for finding what's exported via WASM, then trace back to Rust source. |

### 1.3 Changes to Existing midnight-verify Components

**verifier agent (`agents/verifier.md`):**
- Add ledger/protocol to domain list in description
- Add `midnight-verify:verify-ledger` to skills list
- Add ledger dispatch rules: source-investigator (primary), type-checker (pre-flight for TS API claims), contract-writer (secondary for testable claims), zkir-checker (secondary for VM/circuit claims)
- Add ledger examples to description

**verify-correctness hub skill (`skills/verify-correctness/SKILL.md`):**
- Add "Ledger/Protocol" row to domain classification table with indicators
- Add ledger dispatch rules to section 3
- Add ledger-specific verdict qualifiers to section 4
- Note: ledger claims can dispatch contract-writer and zkir-checker as secondary verification

**source-investigator agent (`agents/source-investigator.md`):**
- Add ledger example to description
- Add `midnight-verify:verify-by-ledger-source` to skills list
- Add routing: when claim domain is ledger → load `verify-by-ledger-source`

**verify-by-type-check skill (`skills/verify-by-type-check/SKILL.md`):**
- Add "Ledger API Execution Mode" section
- When domain is `ledger` and claim is about behavioral output of a ledger-v8 function: write a `.mjs` script that imports from `@midnight-ntwrk/ledger-v8`, calls the function, and outputs the result as JSON
- Uses the existing `sdk-workspace` (ledger-v8 is already installed there)
- This extends beyond type-checking — it calls functions and observes output

**verify-by-execution skill (`skills/verify-by-execution/SKILL.md`):**
- Add "Ledger Execution Mode" section
- When dispatched for a ledger claim: compile a Compact contract as usual, but after execution, extract ledger-level evidence
- Guidance on what evidence to extract:
  - Cost claims → inspect SyntheticCost via `CostModel`
  - Structure claims → inspect Transaction properties, well-formedness via `wellFormed()`
  - Balance claims → check per-segment per-token-type balance
  - VM claims → inspect compiled ZKIR instructions

## Part 2: midnight-cq — ledger-testing

### 2.1 Skill: ledger-testing

**Purpose:** Guide developers writing tests for code that uses `@midnight-ntwrk/ledger-v8` and `@midnight-ntwrk/onchain-runtime` directly.

**Target audience:** Developers working with transaction construction, proof staging, ZswapLocalState management, cost calculations, and cryptographic operations.

**Scope — what users are doing:**
- Constructing transactions (building Intents, adding contract calls, signing, proving, binding)
- Managing proof staging (UnprovenTransaction → proved → proof-erased)
- Working with ZswapLocalState (spend, apply, revert, replayEvents, watchFor)
- Working with DustLocalState (time-dependent balances, replayEvents, processTtls)
- Using CostModel for fee estimation
- Calling cryptographic functions (coinCommitment, coinNullifier, persistentHash, etc.)
- Serializing/deserializing ledger types for persistence
- Building well-formed transactions (balancing, Pedersen checks, TTL)

**What this skill does NOT cover:**
- Testing Compact contract logic (use `compact-testing`)
- Testing DApp UI flows (use `dapp-testing`)
- Testing wallet SDK implementations (use `wallet-testing`)
- Testing DApp Connector API integration (use `dapp-connector-testing`)

**Core testing challenges:**

1. **Proof staging type parameters** — Transaction<S,P,B> has three type parameters controlling state. Tests need to construct transactions at the right stage and transition them correctly through the pipeline.
2. **Hex string types** — Many types (CoinPublicKey, ContractAddress, TokenType, Nullifier, etc.) are hex-encoded strings. Tests need valid hex fixtures, not arbitrary strings. The `sample*` functions (sampleCoinPublicKey, sampleContractAddress, etc.) generate valid test data.
3. **State immutability** — ZswapLocalState and DustLocalState return new instances on mutation. Tests must assert on the returned state, not the original.
4. **Time-dependent Dust** — DustLocalState.walletBalance() takes a Date parameter. Tests need to control time for deterministic results.
5. **Cost model assertions** — SyntheticCost has 5 dimensions. Tests should assert on specific dimensions, not just "cost > 0".

**Anti-patterns:**
- Using arbitrary strings where hex-encoded types are expected (use sample* functions)
- Asserting on original state after mutation instead of returned state
- Not controlling time in Dust balance assertions
- Asserting only that cost is non-zero instead of checking specific dimensions
- Skipping proof staging transitions (going directly from Unproven to erased)
- Not testing well-formedness rejection for invalid transactions

### 2.2 Reference: transaction-construction-patterns.md

- Proof staging lifecycle: UnprovenTransaction → prove() → Transaction<S,Proof,B> → bind() → eraseProofs()
- Building Intents with addCall(), addDeploy()
- Signing Intents (signatureData(), signature verification)
- Transaction merging
- Testing well-formedness: wellFormed() with WellFormedStrictness
- Testing that invalid transactions are rejected (negative testing)

### 2.3 Reference: ledger-state-patterns.md

- ZswapLocalState: spend(), apply(), applyFailed(), revertTransaction(), replayEvents(), watchFor(), clearPending()
- DustLocalState: spend(), replayEvents(), processTtls(), walletBalance(time), generationInfo()
- Time control for Dust assertions
- Serialization round-trip testing (serialize → deserialize → assert equality)
- LedgerState.apply() for on-chain state testing
- Testing coin lifecycle (pending → confirmed → spent via nullifier)

### 2.4 Reference: crypto-fixture-patterns.md

- Using sample functions: sampleCoinPublicKey(), sampleContractAddress(), sampleRawTokenType(), sampleSigningKey(), sampleEncryptionPublicKey(), sampleIntentHash(), sampleUserAddress(), sampleDustSecretKey()
- Testing coinCommitment() and coinNullifier() with known inputs
- Testing nativeToken(), feeToken(), shieldedToken(), unshieldedToken()
- Verifying encode/decode round-trips (encodeCoinPublicKey ↔ decodeCoinPublicKey, etc.)
- Testing signData() and verifySignature()

### 2.5 Changes to midnight-cq

**`.claude-plugin/plugin.json`:**
- Add keywords: `"ledger"`, `"ledger-v8"`, `"transaction"`, `"zswap"`, `"onchain-runtime"`, `"proof-staging"`, `"cost-model"`

**`README.md`:**
- Add ledger-testing skill documentation

**`agents/cq-runner.md`:**
- Detect `@midnight-ntwrk/ledger-v8` or `@midnight-ntwrk/onchain-runtime` in package.json dependencies

**`agents/cq-reviewer.md`:**
- Load `midnight-cq:ledger-testing` skill
- Add ledger test quality checks:
  - sample* functions used for fixture generation (not arbitrary strings)
  - Proof staging transitions tested in order
  - State immutability respected (assert on returned state)
  - Time controlled in Dust balance tests
  - Cost model assertions check specific dimensions
  - Well-formedness rejection tested (negative cases)

## File Inventory

### New files — midnight-verify (2)

| File | Purpose |
|---|---|
| `skills/verify-ledger/SKILL.md` | Domain skill — routing table |
| `skills/verify-by-ledger-source/SKILL.md` | Method skill — Rust crate-level source investigation |

### Modified files — midnight-verify (5)

| File | Change |
|---|---|
| `agents/verifier.md` | Add ledger domain, dispatch rules, examples |
| `skills/verify-correctness/SKILL.md` | Add Ledger/Protocol to domain classification, verdict qualifiers |
| `agents/source-investigator.md` | Add ledger example, verify-by-ledger-source skill reference |
| `skills/verify-by-type-check/SKILL.md` | Add Ledger API Execution Mode section |
| `skills/verify-by-execution/SKILL.md` | Add Ledger Execution Mode section |

### New files — midnight-cq (4)

| File | Purpose |
|---|---|
| `skills/ledger-testing/SKILL.md` | Testing code that uses ledger-v8 and onchain-runtime |
| `skills/ledger-testing/references/transaction-construction-patterns.md` | Proof staging, Intent construction, well-formedness |
| `skills/ledger-testing/references/ledger-state-patterns.md` | ZswapLocalState, DustLocalState, serialization |
| `skills/ledger-testing/references/crypto-fixture-patterns.md` | Hex fixture generation, crypto function testing |

### Modified files — midnight-cq (4)

| File | Change |
|---|---|
| `.claude-plugin/plugin.json` | Add ledger keywords |
| `README.md` | Document ledger-testing skill |
| `agents/cq-runner.md` | Detect ledger-v8 in dependencies |
| `agents/cq-reviewer.md` | Audit ledger test quality patterns |

### Total: 6 new files, 9 modified files. No new agents.
