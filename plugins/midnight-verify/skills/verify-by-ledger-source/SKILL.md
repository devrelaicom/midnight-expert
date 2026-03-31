---
name: midnight-verify:verify-by-ledger-source
description: >-
  Verification by source code inspection of the Midnight ledger Rust codebase.
  Searches and reads the actual Rust implementation to verify claims about
  transaction structure, token mechanics, cost model, on-chain VM, contract
  execution, and cryptographic primitives. Routes claims to specific crates
  within the 24-crate workspace. Uses octocode-mcp for quick lookups, falls
  back to local cloning for deep investigation. Loaded by the source-investigator
  agent when the claim domain is ledger/protocol.
version: 0.1.0
---

# Verify by Ledger Source Code Inspection

You are verifying a claim about the Midnight ledger protocol by reading the actual Rust source code. Follow these steps in order.

## Critical Rule

**Source code is evidence. Everything else is a hint.**

| Source | Role | Rule |
|---|---|---|
| Rust source code (function definitions, type definitions, implementations) | Primary evidence | Always the target. Verdicts must cite Rust source. |
| Test files in the repo | Navigation aid | Follow test imports to find the right source code. Can be run as a last resort (clone to /tmp, `cargo test`), but realistically never needed. |
| `spec/` documents (13 specification files) | Hints only | Useful for orienting where to look. Never evidence on their own. Any claim derived from specs must be corroborated by Rust source inspection. |
| `docs/api/` generated TypeScript docs | Navigation aid | Useful for finding what's exported via WASM, then trace back to Rust source. |

## Step 1: Determine Where to Look

**Crate routing — match the claim to the right crate and path:**

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

**Crate dependency graph:**

```
base-crypto → transient-crypto → coin-structure → onchain-state → onchain-vm → onchain-runtime
                                                                                      ↓
                                                              zswap ← ledger ← ledger-wasm (WASM)
```

Supporting: `serialize`, `storage-core`, `storage`. Proofs: `zkir`, `zkir-v3`.

## Step 2: Search with octocode-mcp

Start with targeted lookups using the `octocode-mcp` tools:

1. **`githubSearchCode`** — search for specific function names, type names, implementations in `midnightntwrk/midnight-ledger`
2. **`githubGetFileContent`** — read a specific file once you know the path
3. **`githubViewRepoStructure`** — understand crate layout if unsure

**Search strategy:**

- For crypto primitive claims: start in `base-crypto/src/` or `transient-crypto/src/`
- For transaction/protocol claims: start in `ledger/src/` then trace to `zswap/`, `coin-structure/`
- For VM/runtime claims: start in `onchain-vm/src/` then `onchain-runtime/`
- For TypeScript API claims: start in `ledger-wasm/src/` to find the WASM binding, then trace to the underlying Rust implementation
- Start narrow (exact function/type name), broaden if no results
- Verify you're on the default branch

## Step 3: Clone Locally if Needed

If octocode-mcp results are insufficient — tracing cross-crate dependencies, following trait implementations across crates, or understanding the full call chain:

```bash
CLONE_DIR=$(mktemp -d)
git clone --depth 1 git@github.com:midnightntwrk/midnight-ledger.git "$CLONE_DIR/midnight-ledger"
```

Always use SSH protocol (`git@github.com:`), not HTTPS.

After investigation, clean up:

```bash
rm -rf "$CLONE_DIR"
```

## Step 4: Read and Interpret Source

**What counts as evidence (ordered by strength):**

1. **Rust function/type/trait definitions** — strong evidence. If the source defines a struct with field X, that's definitive.
2. **Rust test files** — navigation aid. Follow test imports to pinpoint source. Not evidence themselves.
3. **`spec/` documents** — hints for where to look. The 13 spec files (preliminaries, intents-transactions, zswap, dust, night, contracts, cost-model, field-aligned-binary, onchain-runtime, properties, storage-io-cost-modeling, cardano-system-transactions) describe intended behavior but must be corroborated by Rust source.
4. **`docs/api/` TypeScript docs** — navigation aid. Generated from WASM bindings. Trace back to Rust.

**Watch for:**

- The workspace has 24 crates. A type defined in `coin-structure` may be re-exported through `ledger` and appear via WASM in `ledger-wasm`. Trace to the original definition.
- `#[wasm_bindgen]` functions in `*-wasm` crates are thin wrappers. The real implementation is in the underlying Rust crate.
- Feature flags control what's compiled: `proof-verifying` (default), `proving`, `test-utilities`, `mock-verify`. Some code only exists behind features.
- The `static` crate provides version identifiers via proc macro.

## Step 5: Report

**Your report must include:**

1. **The claim as received** — verbatim
2. **Where you looked** — crate name, file path(s), line numbers
3. **What the source shows** — quote or summarize the relevant Rust code
4. **GitHub links** — full URLs to exact files/lines (e.g., `https://github.com/midnightntwrk/midnight-ledger/blob/main/coin-structure/src/coin.rs#L42`)
5. **Your interpretation** — does the source confirm, refute, or leave the claim inconclusive?

**Report format:**

```
### Source Investigation Report

**Claim:** [verbatim]

**Searched:** [crate(s) and method — octocode-mcp search / local clone]

**Found:**
- Crate: [crate-name]
- File: [path/to/file.rs:line-range]
- Link: [full GitHub URL]
- Content: [relevant Rust code snippet or summary]

**Interpretation:** [Confirmed / Refuted / Inconclusive] — [explanation]
```

If inconclusive, explain:
- What you searched and why it wasn't definitive
- Whether compilation/execution might resolve it (the orchestrator decides whether to dispatch @"midnight-verify:contract-writer (agent)" or @"midnight-verify:zkir-checker (agent)")
