# Ledger Protocol Verification and Testing — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add ledger/protocol verification domain to the midnight-verify plugin and ledger-testing skill to the midnight-cq plugin.

**Architecture:** Two new skill files in midnight-verify (domain routing + Rust crate-level source investigation method). Four new files in midnight-cq (one skill + three references). Nine modifications to existing agents and skills for ledger-specific dispatch, source routing, and execution guidance. No new agents.

**Tech Stack:** Markdown skill/agent files following existing midnight-verify and midnight-cq patterns. No runtime code.

**Spec:** `docs/superpowers/specs/2026-03-31-ledger-verification-design.md`

---

## File Map

### midnight-verify plugin (`plugins/midnight-verify/`)

| Action | File | Responsibility |
|--------|------|----------------|
| Create | `skills/verify-ledger/SKILL.md` | Domain skill — claim classification and routing table for ledger/protocol claims |
| Create | `skills/verify-by-ledger-source/SKILL.md` | Method skill — Rust crate-level source investigation guidance, 24-crate routing table |
| Modify | `agents/verifier.md` | Add ledger domain, dispatch rules, examples |
| Modify | `skills/verify-correctness/SKILL.md` | Add Ledger/Protocol to domain classification, verdict qualifiers |
| Modify | `agents/source-investigator.md` | Add ledger example, verify-by-ledger-source skill reference |
| Modify | `skills/verify-by-type-check/SKILL.md` | Add Ledger API Execution Mode section |
| Modify | `skills/verify-by-execution/SKILL.md` | Add Ledger Execution Mode section |

### midnight-cq plugin (`plugins/midnight-cq/`)

| Action | File | Responsibility |
|--------|------|----------------|
| Create | `skills/ledger-testing/SKILL.md` | Testing code that uses ledger-v8 and onchain-runtime |
| Create | `skills/ledger-testing/references/transaction-construction-patterns.md` | Proof staging, Intent construction, well-formedness |
| Create | `skills/ledger-testing/references/ledger-state-patterns.md` | ZswapLocalState, DustLocalState, serialization |
| Create | `skills/ledger-testing/references/crypto-fixture-patterns.md` | Hex fixture generation, crypto function testing |
| Modify | `.claude-plugin/plugin.json` | Add ledger keywords |
| Modify | `README.md` | Document ledger-testing skill |
| Modify | `agents/cq-runner.md` | Detect ledger-v8 in dependencies |
| Modify | `agents/cq-reviewer.md` | Audit ledger test quality patterns |

---

## Important Context for Implementers

### Plugin paths

All midnight-verify files are relative to `plugins/midnight-verify/`.
All midnight-cq files are relative to `plugins/midnight-cq/`.

### Existing pattern to follow

**Skill files** use YAML frontmatter (`name`, `description`, `version`) then markdown body. See any existing `SKILL.md` for the pattern.

**Agent files** use YAML frontmatter (`name`, `description`, `skills`, `model`, `color`) then markdown body. See `agents/verifier.md` for the orchestrator pattern.

**Reference files** are plain markdown (no frontmatter) under `skills/<skill-name>/references/`.

### Key repos

- Primary: `midnightntwrk/midnight-ledger` — Rust workspace, 24 crates, produces WASM bindings
- npm packages: `@midnight-ntwrk/ledger-v8`, `@midnight-ntwrk/zkir-v2`, `@midnight-ntwrk/onchain-runtime`

### Clone protocol

Always use SSH (`git@github.com:`) not HTTPS for cloning repos.

---

## Task 1: Create verify-ledger domain skill

**Files:**
- Create: `plugins/midnight-verify/skills/verify-ledger/SKILL.md`

- [ ] **Step 1: Create the skill directory**

```bash
mkdir -p plugins/midnight-verify/skills/verify-ledger
```

- [ ] **Step 2: Write the domain skill file**

Create `plugins/midnight-verify/skills/verify-ledger/SKILL.md` with this exact content:

```markdown
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
```

- [ ] **Step 3: Verify the file was created correctly**

```bash
head -5 plugins/midnight-verify/skills/verify-ledger/SKILL.md
```

Expected: YAML frontmatter with `name: midnight-verify:verify-ledger`.

- [ ] **Step 4: Commit**

```bash
git add plugins/midnight-verify/skills/verify-ledger/SKILL.md
git commit -m "feat(midnight-verify): add verify-ledger domain skill

Routing table for ledger/protocol claim classification. Covers
transaction structure, token mechanics, cost model, VM, contracts,
crypto primitives, TypeScript API, and formal properties.

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

## Task 2: Create verify-by-ledger-source method skill

**Files:**
- Create: `plugins/midnight-verify/skills/verify-by-ledger-source/SKILL.md`

- [ ] **Step 1: Create the skill directory**

```bash
mkdir -p plugins/midnight-verify/skills/verify-by-ledger-source
```

- [ ] **Step 2: Write the method skill file**

Create `plugins/midnight-verify/skills/verify-by-ledger-source/SKILL.md` with this exact content:

```markdown
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
- Whether compilation/execution might resolve it (the verifier orchestrator decides whether to dispatch contract-writer or zkir-checker)
```

- [ ] **Step 3: Verify the file was created correctly**

```bash
head -5 plugins/midnight-verify/skills/verify-by-ledger-source/SKILL.md
```

Expected: YAML frontmatter with `name: midnight-verify:verify-by-ledger-source`.

- [ ] **Step 4: Commit**

```bash
git add plugins/midnight-verify/skills/verify-by-ledger-source/SKILL.md
git commit -m "feat(midnight-verify): add verify-by-ledger-source method skill

Rust crate-level source investigation guidance for the source-investigator
agent. 24-crate routing table, dependency graph, search strategy, and
strict evidence rules.

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

## Task 3: Update verifier orchestrator agent

**Files:**
- Modify: `plugins/midnight-verify/agents/verifier.md`

- [ ] **Step 1: Add ledger examples to the description**

In the YAML frontmatter `description` field, after the existing Example 9 about wallet SDK architecture claims, add:

```yaml

  Example 10: User runs /verify "SyntheticCost has 5 dimensions" — the
  orchestrator classifies this as a ledger/protocol cost model claim,
  dispatches the source-investigator (primary) to inspect the Rust source,
  and optionally the contract-writer (secondary) to compile a contract and
  measure its cost.

  Example 11: User runs /verify "coinCommitment returns a hex string" — the
  orchestrator classifies this as a ledger TypeScript API claim, dispatches
  the type-checker (pre-flight) and source-investigator (primary), and
  optionally runs ledger-v8 execution to call the function and observe output.
```

- [ ] **Step 2: Add verify-ledger to the skills list**

In the frontmatter `skills:` field, append `, midnight-verify:verify-ledger` to the end of the comma-separated list.

- [ ] **Step 3: Add ledger to the domain routing in the body**

In the body section listing domain routing (the numbered list under "Based on the claim domain:"), after the bullet for "Wallet SDK claims", add:

```markdown
   - Ledger/Protocol claims → load `midnight-verify:verify-ledger`
```

- [ ] **Step 4: Add ledger dispatch rules to the body**

In the body section "## Dispatching Sub-Agents", after the wallet SDK verification subsection and before "**When multiple methods are needed...**", add:

```markdown
**Ledger/Protocol verification:**
- Source investigation (primary) → dispatch `midnight-verify:source-investigator` with instruction to load `midnight-verify:verify-by-ledger-source`
- Type-check (pre-flight, TS API claims only) → dispatch `midnight-verify:type-checker` (uses existing sdk-workspace, ledger-v8 already installed)
- Compilation/execution (secondary) → dispatch `midnight-verify:contract-writer` with instruction to extract ledger-level evidence (cost data, well-formedness, balance checks)
- ZKIR inspection (secondary) → dispatch `midnight-verify:zkir-checker` with instruction to inspect compiled circuit structure for VM/opcode claims
- Ledger-v8 execution (secondary) → dispatch `midnight-verify:type-checker` in ledger execution mode to call ledger-v8 functions and observe output

**For ledger claims, source investigation always runs.** Secondary methods provide corroborating evidence. Dispatch source-investigator first; dispatch secondary agents concurrently if the claim is testable.
```

- [ ] **Step 5: Commit**

```bash
git add plugins/midnight-verify/agents/verifier.md
git commit -m "feat(midnight-verify): add ledger domain to verifier orchestrator

Add ledger/protocol dispatch rules, examples, and skill reference.
Ledger claims dispatch source-investigator as primary with contract-writer,
zkir-checker, and type-checker as secondary methods.

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

## Task 4: Update verify-correctness hub skill

**Files:**
- Modify: `plugins/midnight-verify/skills/verify-correctness/SKILL.md`

- [ ] **Step 1: Add Ledger/Protocol to the domain classification table**

In "### 1. Classify the Domain", add a new row to the table after the "Wallet SDK" row:

```markdown
| **Ledger/Protocol** | Transaction structure (intents, segments, offers, binding), token mechanics (Night UTXO, Zswap commitment/nullifier, Dust generation), cost model (SyntheticCost, fee pricing, block limits), on-chain VM (opcodes, StateValue, stack machine), contract execution (deployment, calls, effects, transcripts), cryptographic primitives (Pedersen, Fiat-Shamir, signatures, Merkle trees), @midnight-ntwrk/ledger-v8 API, well-formedness rules, FAB encoding, formal security properties | Load `midnight-verify:verify-ledger` |
```

- [ ] **Step 2: Add ledger dispatch rules to section 3**

In "### 3. Dispatch Sub-Agents", after the wallet SDK verification subsection and before "**Multiple methods needed**", add:

```markdown
**Ledger/Protocol verification:**
- Source investigation (primary, always runs) → dispatch `midnight-verify:source-investigator` agent with instruction to load `midnight-verify:verify-by-ledger-source`
- Type-check (pre-flight, TS API claims only) → dispatch `midnight-verify:type-checker` agent (uses existing sdk-workspace)
- Compilation/execution (secondary) → dispatch `midnight-verify:contract-writer` agent with instruction to extract ledger-level evidence
- ZKIR inspection (secondary) → dispatch `midnight-verify:zkir-checker` agent for VM/opcode claims
- Ledger-v8 execution (secondary) → dispatch `midnight-verify:type-checker` agent in ledger execution mode

**For ledger claims, source investigation always runs.** Secondary methods provide corroborating evidence and are dispatched concurrently when the claim is testable.
```

- [ ] **Step 3: Add ledger verdict qualifiers to section 4**

In "### 4. Synthesize the Verdict", in the verdict options table, after the wallet SDK rows, add:

```markdown
| **Confirmed** | (source-verified) | Rust source confirms the ledger/protocol claim |
| **Confirmed** | (source-verified + tested) | Rust source confirmed, compilation/execution also confirms (ledger domain) |
| **Confirmed** | (tested) | Compilation/execution directly confirms (e.g., cost model output, well-formedness check) (ledger domain) |
| **Refuted** | (source-verified) | Rust source contradicts the ledger/protocol claim |
| **Refuted** | (tested) | Compilation/execution contradicts the claim (ledger domain) |
| **Inconclusive** | — | Source investigation insufficient, no execution path available (ledger domain) |
```

- [ ] **Step 4: Commit**

```bash
git add plugins/midnight-verify/skills/verify-correctness/SKILL.md
git commit -m "feat(midnight-verify): add ledger domain to verify-correctness hub

Add Ledger/Protocol to domain classification table, dispatch rules,
and verdict qualifiers including Confirmed (tested) for direct
compilation/execution evidence.

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

## Task 5: Update source-investigator agent

**Files:**
- Modify: `plugins/midnight-verify/agents/source-investigator.md`

- [ ] **Step 1: Add ledger example to description**

In the YAML frontmatter `description` field, after the existing Example 4 about wallet SDK, add:

```yaml

  Example 5: Claim "CoinCommitment = Hash<(CoinInfo, CoinPublicKey)>" — searches
  midnightntwrk/midnight-ledger coin-structure crate for the CoinCommitment
  type definition. Uses verify-by-ledger-source for Rust crate-level routing.
```

- [ ] **Step 2: Add verify-by-ledger-source to the skills list**

In the frontmatter, find the `skills:` line and append `, midnight-verify:verify-by-ledger-source`.

The line currently reads:
```
skills: midnight-verify:verify-by-source, midnight-verify:verify-by-wallet-source
```

Change it to:
```
skills: midnight-verify:verify-by-source, midnight-verify:verify-by-wallet-source, midnight-verify:verify-by-ledger-source
```

- [ ] **Step 3: Add ledger routing to the body**

In the body, after the existing paragraph about wallet SDK routing ("**When the claim domain is wallet SDK**..."), add:

```markdown
**When the claim domain is ledger/protocol**, load `midnight-verify:verify-by-ledger-source` instead of `midnight-verify:verify-by-source`. The ledger source skill provides Rust crate-level routing across the 24-crate workspace, dependency graph context, and guidance on tracing WASM bindings back to Rust implementations. The general verify-by-source skill is for Compact compiler and DApp SDK source — not ledger internals.
```

- [ ] **Step 4: Commit**

```bash
git add plugins/midnight-verify/agents/source-investigator.md
git commit -m "feat(midnight-verify): add ledger to source-investigator agent

Load verify-by-ledger-source for ledger/protocol claims. Adds example
and Rust crate-level routing for the 24-crate workspace.

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

## Task 6: Update verify-by-type-check with Ledger API Execution Mode

**Files:**
- Modify: `plugins/midnight-verify/skills/verify-by-type-check/SKILL.md`

- [ ] **Step 1: Add Ledger API Execution Mode section**

In `skills/verify-by-type-check/SKILL.md`, after the existing "## Wallet SDK Workspace Mode" section (which ends with the mode selection bullet points) and before "## Step 2: Determine the Mode", add:

```markdown
## Ledger API Execution Mode

When the verifier passes `domain: 'ledger'` context and the claim is about behavioral output of a `@midnight-ntwrk/ledger-v8` function (not just its type signature), go beyond type-checking — write a script that calls the function and observes the output.

**This uses the existing sdk-workspace** (ledger-v8 is already installed there). No separate workspace needed.

**When to use this mode:**
- Claim is about what a ledger-v8 function *returns* (not just its signature)
- Examples: "nativeToken() returns [0,0,...,0]", "coinCommitment produces a 64-char hex string", "CostModel.initialCostModel() has specific default values"

**Script pattern:**

```bash
cat > .midnight-expert/verify/sdk-workspace/jobs/$JOB_ID/ledger-exec.mjs << 'EXEC_EOF'
// Import the specific function being tested
import { nativeToken, coinCommitment, CostModel } from '@midnight-ntwrk/ledger';

// Call the function and capture output
const result = nativeToken();

// Output structured JSON for interpretation
console.log(JSON.stringify({
  result: typeof result === 'bigint' ? result.toString() : result,
  type: typeof result
}));
EXEC_EOF
```

Run it:

```bash
cd .midnight-expert/verify/sdk-workspace/jobs/$JOB_ID
node ledger-exec.mjs
```

**Report this as "ledger-v8 execution" evidence**, not as type-checking evidence. Include the script source, output, and interpretation in your report.

**Mode selection summary:**
- `domain: 'wallet-sdk'` → use `.midnight-expert/verify/wallet-sdk-workspace/`
- `domain: 'ledger'` + behavioral claim → use sdk-workspace + ledger execution script
- `domain: 'ledger'` + type claim → use sdk-workspace + normal tsc type assertions
- Otherwise → use `.midnight-expert/verify/sdk-workspace/` (existing behavior)
```

- [ ] **Step 2: Commit**

```bash
git add plugins/midnight-verify/skills/verify-by-type-check/SKILL.md
git commit -m "feat(midnight-verify): add ledger API execution mode to type-checker

Ledger-v8 behavioral claims can be verified by calling exported functions
and observing output. Uses existing sdk-workspace (ledger-v8 already
installed).

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

## Task 7: Update verify-by-execution with Ledger Execution Mode

**Files:**
- Modify: `plugins/midnight-verify/skills/verify-by-execution/SKILL.md`

- [ ] **Step 1: Add Ledger Execution Mode section**

In `skills/verify-by-execution/SKILL.md`, after the existing "## Step 7: Clean Up" section (the last section, ending at line 225), append:

```markdown
## Ledger Execution Mode

When dispatched for a ledger/protocol claim, you compile and execute a Compact contract as usual, but after execution you extract **ledger-level evidence** — cost data, transaction properties, well-formedness results — in addition to the normal runtime output.

**When to use this mode:** The verifier dispatches you with a ledger claim that is testable via compilation. Examples:
- "Fee calculation uses max(read, compute, block) + write + churn" → compile a contract, compute its cost
- "Well-formedness rejects overlapping inputs" → build a transaction with overlapping inputs, check wellFormed() rejects
- "Counter increment costs N bytes of block usage" → compile counter, measure SyntheticCost.block_usage

**What to extract after compilation and execution:**

| Claim type | What to extract | How |
|---|---|---|
| Cost model claims | SyntheticCost breakdown | Import CostModel from ledger-v8, call `cost()` on the compiled transaction |
| Well-formedness claims | Acceptance/rejection | Call `wellFormed()` on the transaction, capture result |
| Balance claims | Per-segment per-token balance | Inspect transaction structure after construction |
| Transaction structure | Intent/offer properties | Read compiled transaction fields |
| Proof staging | Stage transitions | Construct UnprovenTransaction, call `prove()`, observe state change |

**Extended runner script pattern:**

After the normal circuit execution (Step 5), add ledger-level evidence extraction:

```javascript
import { CostModel, WellFormedStrictness } from '@midnight-ntwrk/ledger';

// ... normal circuit execution from Step 5 ...

// Extract cost data
const cost = transaction.cost();
console.log(JSON.stringify({
  circuitResult: result,
  cost: {
    read_time: cost.read_time?.toString(),
    compute_time: cost.compute_time?.toString(),
    block_usage: cost.block_usage?.toString(),
    bytes_written: cost.bytes_written?.toString(),
    bytes_churned: cost.bytes_churned?.toString(),
  },
  wellFormed: transaction.wellFormed(WellFormedStrictness.default()),
}));
```

**Include the ledger-level evidence in your report** alongside the normal execution report. The verifier orchestrator uses both to synthesize the verdict.
```

- [ ] **Step 2: Commit**

```bash
git add plugins/midnight-verify/skills/verify-by-execution/SKILL.md
git commit -m "feat(midnight-verify): add ledger execution mode to contract-writer

Ledger claims testable via Compact compilation now extract ledger-level
evidence: cost data, well-formedness, balance checks, and proof staging.

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

## Task 8: Create ledger-testing skill and references (midnight-cq)

**Files:**
- Create: `plugins/midnight-cq/skills/ledger-testing/SKILL.md`
- Create: `plugins/midnight-cq/skills/ledger-testing/references/transaction-construction-patterns.md`
- Create: `plugins/midnight-cq/skills/ledger-testing/references/ledger-state-patterns.md`
- Create: `plugins/midnight-cq/skills/ledger-testing/references/crypto-fixture-patterns.md`

- [ ] **Step 1: Create the directories**

```bash
mkdir -p plugins/midnight-cq/skills/ledger-testing/references
```

- [ ] **Step 2: Write the main skill file**

Create `plugins/midnight-cq/skills/ledger-testing/SKILL.md`. The plan file at `docs/superpowers/plans/2026-03-31-ledger-verification.md` is this file — use the spec at `docs/superpowers/specs/2026-03-31-ledger-verification-design.md` section 2.1 for the content outline. The skill file should follow the same pattern as the wallet-testing skill at `plugins/midnight-cq/skills/wallet-testing/SKILL.md`.

The SKILL.md must include:
- YAML frontmatter with `name: ledger-testing` and description triggering on: write ledger tests, test transaction construction, test proof staging, test ZswapLocalState, test DustLocalState, test cost model, test coinCommitment, test ledger-v8, test onchain-runtime, test well-formedness
- Decision guide table (when to use this vs compact-testing, wallet-testing, etc.)
- The 5 core testing challenges from the spec: proof staging type parameters, hex string types, state immutability, time-dependent Dust, cost model assertions
- Code examples for each challenge showing correct and incorrect patterns
- Anti-patterns table
- Reference file index

- [ ] **Step 3: Write transaction-construction-patterns.md reference**

Create `plugins/midnight-cq/skills/ledger-testing/references/transaction-construction-patterns.md` with content covering:

- Proof staging lifecycle with code examples:
  - Creating UnprovenTransaction (Transaction<SignatureEnabled, PreProof, PreBinding>)
  - Calling `prove()` to transition to Transaction<SignatureEnabled, Proof, PreBinding>
  - Calling `bind()` to transition to Transaction<SignatureEnabled, Proof, FiatShamirPedersen>
  - Erasing proofs/signatures for storage
- Building Intents with `addCall()`, `addDeploy()`, merging intents
- Testing well-formedness:
  ```typescript
  import { WellFormedStrictness } from '@midnight-ntwrk/ledger';
  
  it('should be well-formed', () => {
    const result = transaction.wellFormed(WellFormedStrictness.default());
    expect(result).toBe(true);
  });
  
  it('should reject overlapping inputs', () => {
    const result = invalidTransaction.wellFormed(WellFormedStrictness.default());
    expect(result).toBe(false);
  });
  ```
- Testing transaction merging
- Testing fee calculation via CostModel

- [ ] **Step 4: Write ledger-state-patterns.md reference**

Create `plugins/midnight-cq/skills/ledger-testing/references/ledger-state-patterns.md` with content covering:

- ZswapLocalState patterns:
  ```typescript
  it('should return new state after spend', () => {
    const original = zswapState;
    const updated = original.spend(coinInfo);
    // Assert on updated, NOT original — state is immutable
    expect(updated).not.toBe(original);
    expect(updated.coins.length).toBe(original.coins.length - 1);
  });
  ```
- ZswapLocalState: apply(), applyFailed(), revertTransaction(), replayEvents(), watchFor(), clearPending()
- DustLocalState with time control:
  ```typescript
  it('should calculate time-dependent balance', () => {
    const fixedTime = new Date('2026-01-01T00:00:00Z');
    const balance = dustState.walletBalance(fixedTime);
    expect(balance).toBeDefined();
  });
  ```
- DustLocalState: spend(), replayEvents(), processTtls(), generationInfo()
- Serialization round-trips:
  ```typescript
  it('should survive serialize/deserialize', () => {
    const serialized = state.serialize();
    const restored = ZswapLocalState.deserialize(serialized);
    // Compare relevant properties
    expect(restored.coins.length).toBe(state.coins.length);
  });
  ```
- LedgerState.apply() for on-chain state testing

- [ ] **Step 5: Write crypto-fixture-patterns.md reference**

Create `plugins/midnight-cq/skills/ledger-testing/references/crypto-fixture-patterns.md` with content covering:

- Using sample functions for test fixtures:
  ```typescript
  import {
    sampleCoinPublicKey,
    sampleContractAddress,
    sampleRawTokenType,
    sampleSigningKey,
    sampleEncryptionPublicKey,
    sampleIntentHash,
    sampleUserAddress,
    sampleDustSecretKey,
  } from '@midnight-ntwrk/ledger';
  
  // GOOD: Use sample functions for valid test data
  const pk = sampleCoinPublicKey();
  const contractAddr = sampleContractAddress();
  
  // BAD: Arbitrary strings that may not be valid hex
  const pk = '0xdeadbeef'; // Wrong length, may fail validation
  ```
- Testing coinCommitment and coinNullifier:
  ```typescript
  it('should produce deterministic commitment', () => {
    const coin = createShieldedCoinInfo(tokenType, value);
    const commitment1 = coinCommitment(coin, pk);
    const commitment2 = coinCommitment(coin, pk);
    expect(commitment1).toBe(commitment2); // Deterministic
    expect(typeof commitment1).toBe('string'); // Hex string
    expect(commitment1.length).toBe(64); // 32 bytes hex-encoded
  });
  ```
- Testing token type functions:
  ```typescript
  it('should distinguish token types', () => {
    const night = nativeToken();
    const fee = feeToken();
    const shielded = shieldedToken(rawType);
    const unshielded = unshieldedToken(rawType);
    expect(night).not.toBe(fee);
  });
  ```
- Encode/decode round-trip testing:
  ```typescript
  it('should round-trip CoinPublicKey encoding', () => {
    const pk = sampleCoinPublicKey();
    const encoded = encodeCoinPublicKey(pk);
    const decoded = decodeCoinPublicKey(encoded);
    expect(decoded).toBe(pk);
  });
  ```
- Testing signData and verifySignature

- [ ] **Step 6: Commit**

```bash
git add plugins/midnight-cq/skills/ledger-testing/
git commit -m "feat(midnight-cq): add ledger-testing skill with references

Testing guide for code using @midnight-ntwrk/ledger-v8 and
onchain-runtime. Covers proof staging, state management, time-dependent
Dust, cost model assertions, crypto fixtures, and serialization.

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

## Task 9: Update midnight-cq plugin metadata and documentation

**Files:**
- Modify: `plugins/midnight-cq/.claude-plugin/plugin.json`
- Modify: `plugins/midnight-cq/README.md`

- [ ] **Step 1: Update plugin.json keywords**

In `plugins/midnight-cq/.claude-plugin/plugin.json`, add these keywords to the existing `keywords` array:

```json
"ledger",
"ledger-v8",
"transaction",
"zswap",
"onchain-runtime",
"proof-staging",
"cost-model"
```

- [ ] **Step 2: Update README.md**

In `plugins/midnight-cq/README.md`, after the existing `### dapp-connector-testing` section and before `### quality-check`, add:

```markdown
### ledger-testing

Write tests for code that uses `@midnight-ntwrk/ledger-v8` and `@midnight-ntwrk/onchain-runtime` directly. Covers proof staging lifecycle (UnprovenTransaction → proved → erased), ZswapLocalState and DustLocalState management, time-dependent Dust balance assertions, CostModel fee calculations, cryptographic fixture generation via `sample*` functions, and serialization round-trip testing.

**Triggers on**: write ledger tests, test transaction construction, test proof staging, test ZswapLocalState, test DustLocalState, test cost model, test coinCommitment, test ledger-v8, test onchain-runtime, test well-formedness
```

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-cq/.claude-plugin/plugin.json plugins/midnight-cq/README.md
git commit -m "docs(midnight-cq): add ledger-testing to metadata and README

Update plugin.json keywords and README documentation for the new
ledger-testing skill.

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

## Task 10: Update midnight-cq agents to recognize ledger projects

**Files:**
- Modify: `plugins/midnight-cq/agents/cq-runner.md`
- Modify: `plugins/midnight-cq/agents/cq-reviewer.md`

- [ ] **Step 1: Update cq-runner agent**

In `plugins/midnight-cq/agents/cq-runner.md`, in the body's "### Step 1: Detect Project Type" section, add this row to the detection table after the existing DApp Connector row:

```markdown
| `@midnight-ntwrk/ledger-v8` or `@midnight-ntwrk/onchain-runtime` in `package.json` deps | Ledger project — check for proof staging, state management, and crypto fixture patterns |
```

- [ ] **Step 2: Update cq-reviewer agent**

In `plugins/midnight-cq/agents/cq-reviewer.md`:

**Change 1:** In "### Step 1 — Load Skills", after the dapp-connector-testing bullet, add:

```markdown
- `midnight-cq:ledger-testing` — defines correct proof staging patterns, state immutability, time-dependent Dust testing, cost model assertions, and crypto fixture generation for ledger projects
```

**Change 2:** In "### Step 2 — Scan Tooling Presence", add these rows to the tooling inventory checklist after the Effect test patterns row:

```markdown
| Ledger deps | `Grep @midnight-ntwrk/ledger-v8 in package.json` | Determines if Ledger project |
| Onchain runtime deps | `Grep @midnight-ntwrk/onchain-runtime in package.json` | Determines if Onchain Runtime project |
| Ledger sample fixtures | `Grep sampleCoinPublicKey in **/*.test.ts` | If ledger project — using proper fixtures |
```

**Change 3:** In "### Step 5 — Assess Test Quality", after the DApp Connector test quality checks table, add:

```markdown
**Ledger test quality checks (if ledger project):**

| Check | Good Pattern | Bad Pattern | Severity |
|-------|-------------|------------|---------|
| sample* functions used for fixtures | `sampleCoinPublicKey()`, `sampleContractAddress()` | Arbitrary hex strings like `'0xdeadbeef'` | Warning |
| Proof staging transitions tested | `prove()` → `bind()` → `eraseProofs()` in sequence | Skipping stages or only testing final state | Warning |
| State immutability respected | Assertions on returned state, not original | Asserting on original after mutation | Critical |
| Time controlled in Dust tests | Fixed `Date` passed to `walletBalance()` | `Date.now()` or no time parameter | Critical |
| Cost model checks specific dimensions | `expect(cost.block_usage).toBe(...)` | `expect(cost).toBeDefined()` | Warning |
| Well-formedness negative tests | Building invalid tx, asserting rejection | Only testing valid transactions | Suggestion |
| Serialization round-trips tested | `serialize()` → `deserialize()` → assert equality | No persistence tests | Suggestion |
```

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-cq/agents/cq-runner.md plugins/midnight-cq/agents/cq-reviewer.md
git commit -m "feat(midnight-cq): update agents to recognize ledger projects

cq-runner detects ledger-v8 and onchain-runtime dependencies.
cq-reviewer loads ledger-testing skill and audits proof staging,
state immutability, time control, cost model, and fixture quality.

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

## Task 11: Final verification

- [ ] **Step 1: Verify all new files exist**

```bash
echo "=== midnight-verify new files ==="
ls -la plugins/midnight-verify/skills/verify-ledger/SKILL.md
ls -la plugins/midnight-verify/skills/verify-by-ledger-source/SKILL.md

echo "=== midnight-cq ledger-testing ==="
ls -la plugins/midnight-cq/skills/ledger-testing/SKILL.md
ls -la plugins/midnight-cq/skills/ledger-testing/references/transaction-construction-patterns.md
ls -la plugins/midnight-cq/skills/ledger-testing/references/ledger-state-patterns.md
ls -la plugins/midnight-cq/skills/ledger-testing/references/crypto-fixture-patterns.md
```

Expected: all 6 files exist.

- [ ] **Step 2: Verify YAML frontmatter is valid**

```bash
for f in \
  plugins/midnight-verify/skills/verify-ledger/SKILL.md \
  plugins/midnight-verify/skills/verify-by-ledger-source/SKILL.md \
  plugins/midnight-cq/skills/ledger-testing/SKILL.md; do
  echo "--- $f ---"
  head -3 "$f"
  echo ""
done
```

Expected: each file starts with `---` and has a `name:` field.

- [ ] **Step 3: Count commits**

```bash
git log --oneline HEAD~11..HEAD
```

Expected: 11 commits (1 spec + 10 implementation).

- [ ] **Step 4: Verify git status is clean**

```bash
git status
```

Expected: clean working tree.
