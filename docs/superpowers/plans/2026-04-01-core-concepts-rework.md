# Core-Concepts Plugin Rework Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rework core-concepts into a high-level conceptual explainer by removing implementation-level detail, fixing 25 fact-checked errors, eliminating overlap with compact-core, and deleting 2 skills.

**Architecture:** Surgical edit of an existing plugin. Delete 2 skill directories and all example files. Rewrite 6 SKILL.md files and 8 reference files to remove Rust struct fields, type names, and formulas while preserving conceptual accuracy. Update agent and manifest.

**Tech Stack:** Markdown content files, JSON manifest

**Spec:** `docs/superpowers/specs/2026-04-01-core-concepts-rework-design.md`
**Fact-check report:** `.midnight-expert/fact-checker/04-26/fast-run-core-concepts-qoMk/report.md`

**Content principles (apply to ALL rewrite tasks):**
1. No Rust struct fields or type names (describe behavior, not implementation)
2. No exact formulas unless conceptually essential (homomorphism matters, generator points don't)
3. Describe behavior, not implementation ("nullifiers are unlinkable to commitments" not `Nullifier = Hash<(CoinInfo, CoinSecretKey)>`)
4. Fix refuted claims where the concept matters, remove where it's trivia
5. References build mental models, not source code knowledge

**Plugin root:** `plugins/core-concepts/`

---

### Task 1: Delete smart-contracts and protocol-schemas skills

**Files:**
- Delete: `plugins/core-concepts/skills/smart-contracts/` (entire directory)
- Delete: `plugins/core-concepts/skills/protocol-schemas/` (entire directory)

- [ ] **Step 1: Delete smart-contracts skill directory**

```bash
rm -rf plugins/core-concepts/skills/smart-contracts/
```

This removes: SKILL.md, references/compact-syntax.md, references/execution-semantics.md, references/impact-vm.md, examples/counter.compact, examples/counter-witnesses.ts, examples/private-vault.compact

- [ ] **Step 2: Delete protocol-schemas skill directory**

```bash
rm -rf plugins/core-concepts/skills/protocol-schemas/
```

This removes: SKILL.md, references/compact-ast-schema.json, references/transaction-schema.json, references/zk-proof-schema.json

- [ ] **Step 3: Verify deletions**

```bash
ls plugins/core-concepts/skills/
```

Expected: architecture, data-models, privacy-patterns, protocols, tokenomics, zero-knowledge (6 directories)

- [ ] **Step 4: Commit**

```bash
git add -A plugins/core-concepts/skills/smart-contracts/ plugins/core-concepts/skills/protocol-schemas/
git commit -m "refactor(core-concepts): remove smart-contracts and protocol-schemas skills

These skills overlap with compact-core which owns implementation detail.
smart-contracts covered Compact syntax, execution semantics, Impact VM.
protocol-schemas contained JSON schemas of questionable provenance.

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 2: Delete all example files

**Files:**
- Delete: `plugins/core-concepts/skills/architecture/examples/transaction-construction.md`
- Delete: `plugins/core-concepts/skills/data-models/examples/token-handling.compact`
- Delete: `plugins/core-concepts/skills/privacy-patterns/examples/auth-patterns.compact`
- Delete: `plugins/core-concepts/skills/privacy-patterns/examples/private-voting.compact`
- Delete: `plugins/core-concepts/skills/protocols/examples/atomic-swap.md`
- Delete: `plugins/core-concepts/skills/protocols/examples/basic-transfer.md`
- Delete: `plugins/core-concepts/skills/zero-knowledge/examples/circuit-patterns.compact`

- [ ] **Step 1: Delete all example directories**

```bash
find plugins/core-concepts/skills/ -type d -name examples -exec rm -rf {} + 2>/dev/null
```

- [ ] **Step 2: Verify no examples remain**

```bash
find plugins/core-concepts/skills/ -name examples -type d
```

Expected: no output

- [ ] **Step 3: Commit**

```bash
git add -A plugins/core-concepts/skills/
git commit -m "refactor(core-concepts): remove example files

Compact code examples belong in compact-core which has proper testing
and compilation verification. Conceptual plugin should explain, not demo code.

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 3: Rewrite architecture/SKILL.md

**Files:**
- Modify: `plugins/core-concepts/skills/architecture/SKILL.md`

**Errors to fix:** claim-001 (guaranteed_zswap_offer name/always present), claim-002 (fallible_zswap_offer is HashMap not Option), claim-003 (contract_calls_or_deploys doesn't exist), claim-007 (fallible coin ops timing), claim-013 (ledger field names), claim-014 (ImpactValue/SNARKVerifierKey don't exist), claim-015 (compile-time depth), claim-017 (proof verification not purely stateless), claim-020 (merge constraint), claim-022 (token type hash arg order)

**What to keep:** System overview diagram, guaranteed/fallible concept, building blocks section (conceptually), transaction integrity section (conceptually), balance verification formulas, component integration diagrams, practical patterns section.

**What to remove/rewrite:**
- Transaction anatomy pseudocode struct (lines 37-43) → replace with prose description
- ContractCall pseudocode struct (lines 77-84) → replace with prose
- Ledger structure pseudocode (lines 114-123) → replace with prose
- ContractState pseudocode (lines 130-136) → replace with prose
- Address derivation Hash notation (lines 201-219) → conceptual description
- Merging rules bullet about "empty contract calls" (line 193) → remove false constraint
- Execution flow: fix "ZK proof verification" placement (line 146) → note it requires state access
- Line 55 about fallible coin ops → fix timing description

- [ ] **Step 1: Read current file**

Read `plugins/core-concepts/skills/architecture/SKILL.md` in full.

- [ ] **Step 2: Rewrite the file**

Replace the entire file. Key changes:

**Transaction Anatomy section** — Replace pseudocode struct with:
> A Midnight transaction combines three concerns: token operations (via Zswap offers), smart contract interactions (via contract calls), and cryptographic binding that ties everything together. The transaction has a guaranteed section whose effects always persist and one or more fallible sections whose effects are rolled back if they fail. Fees are collected in the guaranteed section, ensuring the network is paid even if optional operations fail.

**Building Blocks > Contract Calls** — Remove pseudocode struct, describe conceptually:
> Each contract call targets a specific contract and entry point, carrying both a guaranteed and a fallible transcript. A ZK proof attests that the declared effects match what the contract logic actually computed.

**State Architecture > Ledger Structure** — Remove pseudocode, describe conceptually:
> The global ledger has two parts. The Zswap state tracks all coin commitments in an append-only Merkle tree, a set of spent nullifiers (also append-only, for double-spend prevention), and a time-windowed history of past Merkle roots. The contract map associates each deployed contract with its current state and the verification keys for its entry points.

**State Architecture > Contract State** — Remove ImpactValue/SNARKVerifierKey:
> Each contract stores its current state data and a set of verification keys — one per entry point — that the network uses to verify ZK proofs submitted by callers.

**Execution Flow** — Fix proof verification description:
> Proof verification happens during the well-formedness check, but it is not purely stateless — the network needs to look up the contract's verification keys from the ledger.

**Merging Rules** — Remove false constraint:
> Transactions can be merged when their coin sets don't overlap and their combined values balance. Merging enables atomic swaps where each party constructs their half independently.

**Address Derivation** — Replace Hash<> notation with prose:
> Contract addresses are derived by hashing the initial contract state with a nonce, ensuring unique addresses even for identical code. Token types are derived by hashing a domain separator with the issuing contract's address. Coin commitments hash the coin data with the owner's public key. Nullifiers hash the coin data with the owner's secret key — critically, not with the commitment, making nullifiers unlinkable to the coins they spend.

**References section** — Remove the examples line.

- [ ] **Step 3: Verify no Rust types, struct fields, or Hash<> notation remain**

```bash
grep -n 'ImpactValue\|SNARKVerifierKey\|commitment_tree_first_free\|Set<Coin\|Map<String\|Hash<(' plugins/core-concepts/skills/architecture/SKILL.md
```

Expected: no output

- [ ] **Step 4: Commit**

```bash
git add plugins/core-concepts/skills/architecture/SKILL.md
git commit -m "refactor(core-concepts): rewrite architecture SKILL.md to conceptual level

Remove pseudocode structs, Rust type names, Hash<> notation.
Fix 10 fact-checked errors (claims 001-003, 007, 013-015, 017, 020, 022).
Describe behavior and purpose, not implementation artifacts.

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 4: Rewrite architecture/references/cryptographic-binding.md

**Files:**
- Modify: `plugins/core-concepts/skills/architecture/references/cryptographic-binding.md` (189 lines)

**Errors to fix:** claim-025 (Pedersen formula wrong), claim-026 (not one Schnorr per tx), claim-027 (Schnorr purpose wrong), claim-028 (SchnorrProof fields wrong)

**What to keep:** The conceptual explanation of what each binding mechanism achieves, the attack prevention section, the verification order concept.

**What to remove:** The Pedersen formula `Commit(v) = v*G + r*H`, the SchnorrProof struct, the specific "one per transaction" claim, the "contract zero net value" characterization.

- [ ] **Step 1: Read current file**

Read `plugins/core-concepts/skills/architecture/references/cryptographic-binding.md` in full.

- [ ] **Step 2: Rewrite the file**

Key changes:

**Pedersen Commitments section** — Replace formula with conceptual description:
> Pedersen commitments are elliptic-curve-based commitments that hide the committed value while allowing arithmetic on commitments. Their key property is homomorphism: you can add two commitments together and get a valid commitment to the sum of their values. This lets the network verify that transaction inputs and outputs balance without learning any individual value. The commitment incorporates the token type, so multi-asset balancing works naturally — each token type is verified independently.

**Schnorr Proof section** — Fix characterization:
> Each contract interaction segment carries a Schnorr proof that demonstrates the prover knows the randomness used in the Pedersen binding commitment. This binds the contract's effects to the rest of the transaction, preventing anyone from injecting unauthorized value. The proof uses the Fiat-Shamir transform to be non-interactive.

Remove: the SchnorrProof struct definition, the "one per transaction" claim, "zero net value" framing.

**Balance Verification** — Keep the conceptual explanation but remove the per-field breakdown.

**Attack Prevention** — Keep conceptually (value injection, proof reuse, double-spend prevention).

- [ ] **Step 3: Verify no struct definitions or formulas remain**

```bash
grep -n 'struct\|v\*G\|r\*H\|commitment (Point)\|challenge (Scalar)' plugins/core-concepts/skills/architecture/references/cryptographic-binding.md
```

Expected: no output

- [ ] **Step 4: Commit**

```bash
git add plugins/core-concepts/skills/architecture/references/cryptographic-binding.md
git commit -m "refactor(core-concepts): rewrite cryptographic-binding to conceptual level

Fix Pedersen formula (claim-025), Schnorr proof count (claim-026),
Schnorr purpose (claim-027), SchnorrProof fields (claim-028).
Describe what binding achieves, not implementation structs.

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 5: Rewrite architecture/references/state-management.md

**Files:**
- Modify: `plugins/core-concepts/skills/architecture/references/state-management.md` (185 lines)

**Errors to fix:** claim-013 (field names throughout)

**What to keep:** Conceptual description of state transitions, zswap state operations, pruning concepts.

**What to remove:** All Rust field names, type annotations, pseudocode struct definitions.

- [ ] **Step 1: Read current file**

Read `plugins/core-concepts/skills/architecture/references/state-management.md` in full.

- [ ] **Step 2: Rewrite the file**

Replace pseudocode struct definitions with prose. For example, the Global State Structure section should describe:
> The global state has two parts: the Zswap state (which tracks all coin commitments and nullifiers) and the contract map (which stores each contract's data and verification keys).

For the Zswap State section, describe the four components conceptually:
> The Zswap state maintains: (1) an append-only Merkle tree of coin commitments, (2) a running index tracking the next free position in that tree, (3) a permanent set of all spent nullifiers, and (4) a time-windowed set of recent Merkle roots that spending proofs can reference.

Remove all `type: Type` annotations, Compact-to-state-representation tables with implementation types, and pseudocode.

- [ ] **Step 3: Verify cleanup**

```bash
grep -n 'ImpactValue\|SNARKVerifierKey\|commitment_tree_first_free\|u32\|u64\|HashMap\|Set<' plugins/core-concepts/skills/architecture/references/state-management.md
```

Expected: no output

- [ ] **Step 4: Commit**

```bash
git add plugins/core-concepts/skills/architecture/references/state-management.md
git commit -m "refactor(core-concepts): rewrite state-management to conceptual level

Remove Rust field names and type annotations (claim-013 errors).
Describe state components and transitions as mental models.

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 6: Rewrite architecture/references/transaction-deep-dive.md

**Files:**
- Modify: `plugins/core-concepts/skills/architecture/references/transaction-deep-dive.md` (269 lines)

**Errors to fix:** claim-033 (Input fields wrong), claim-034 (Output fields wrong), claim-035 (Transcript fields wrong), claim-018 (proof verification phase)

This file had the most errors in the fact-check. Every struct definition uses invented field names.

- [ ] **Step 1: Read current file**

Read `plugins/core-concepts/skills/architecture/references/transaction-deep-dive.md` in full.

- [ ] **Step 2: Rewrite the file**

This file needs a complete rewrite. Replace struct-field catalogues with flow-oriented descriptions:

**Zswap Offer Details** — Instead of listing Input/Output struct fields, describe what each component *does*:
> An input represents a coin being spent. The spender provides a nullifier (proving they own the coin without revealing which one), a proof that the coin exists in the commitment tree, and a value commitment for balance checking. An output represents a new coin being created, carrying a commitment that hides the coin's value and owner, a value commitment for balance checking, and optionally encrypted data so the recipient can discover the coin.

**Contract Call Section** — Describe the flow, not the struct:
> A contract call targets a specific contract entry point. It carries two transcripts — guaranteed and fallible — separated by a checkpoint boundary. Each transcript declares the effects it will produce (state changes, coin operations), and a ZK proof attests that executing the contract logic with the prover's private inputs produces exactly those effects.

**Transcript Structure** — Describe purpose, not fields:
> A transcript is the public record of what a contract execution claims to do. It declares a gas budget, lists the coin operations (nullifiers to consume, commitments to create, tokens to mint), and includes the contract program that will be re-executed on-chain to verify the declared effects match.

**Validation Order** — Fix proof verification:
> Well-formedness checking validates the transaction structure, verifies Zswap proofs (inputs and outputs), checks the Schnorr binding proof, and — requiring state access to look up verification keys — verifies contract call proofs. It also checks balance constraints and Merkle root validity.

- [ ] **Step 3: Verify no struct definitions remain**

```bash
grep -n 'type_value_commit\|received_commitments\|spent_commitments\|contract_calls_claimed\|gas_bound' plugins/core-concepts/skills/architecture/references/transaction-deep-dive.md
```

Expected: no output

- [ ] **Step 4: Commit**

```bash
git add plugins/core-concepts/skills/architecture/references/transaction-deep-dive.md
git commit -m "refactor(core-concepts): rewrite transaction-deep-dive to conceptual level

Replace all struct-field catalogues with flow descriptions.
Fix claims 033-035 (all field names were wrong) and claim-018 (proof phase).

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 7: Thin data-models/SKILL.md and references

**Files:**
- Modify: `plugins/core-concepts/skills/data-models/SKILL.md` (120 lines)
- Modify: `plugins/core-concepts/skills/data-models/references/ledger-structure.md` (140 lines)
- Keep as-is: `plugins/core-concepts/skills/data-models/references/utxo-mechanics.md` (143 lines, already conceptual)

**Errors to fix:** claim-048 (MerkleTree stores only root — wrong, full tree stored with hidden leaf preimages), claim-022 echo (token type hash arg order in data-models)

- [ ] **Step 1: Read current files**

Read `plugins/core-concepts/skills/data-models/SKILL.md` and `plugins/core-concepts/skills/data-models/references/ledger-structure.md`.

- [ ] **Step 2: Edit data-models/SKILL.md**

Changes:
1. Remove the `Hash<(CoinInfo, ZswapCoinPublicKey)>` notation from Core Mechanics (line 32) → "a cryptographic commitment that hides the coin's value, type, and owner"
2. Remove the `Hash<(CoinInfo, ZswapCoinSecretKey)>` notation from Nullifier Innovation (line 42) → "a hash derived from the coin data and spending key"
3. Remove `CoinInfo = { value, type, nonce }` (line 45) → "The coin's value, token type, and a unique nonce"
4. In Ledger Structure section (lines 87-95), remove type annotations like `MerkleTree<CoinCommitment>`, `u32`, `Set<CoinNullifier>`, `TimeFilterMap<MerkleTreeRoot>` → describe each component in prose
5. Remove `Hash(contract_address, domain_separator)` (line 101) → "derived from the issuing contract's address and a domain separator"
6. Remove the compact code block (lines 103-109) → this belongs in compact-core
7. Remove Examples section (lines 117-120)

- [ ] **Step 3: Edit ledger-structure.md**

Changes:
1. Remove all type annotation lists (State types table with "Field → direct value", "MerkleTree → only root" etc.)
2. Fix claim-048: replace "stores only the root on-chain" with "stores the tree structure on-chain, but leaf preimages are hidden — an observer sees the tree shape but not what was inserted"
3. Remove Rust-style type mappings
4. Keep the conceptual descriptions of adding/spending coins and updating contract state

- [ ] **Step 4: Verify cleanup**

```bash
grep -n 'Hash<\|CoinInfo =\|MerkleTree<\|TimeFilterMap<\|Set<Coin\|u32\|u64' plugins/core-concepts/skills/data-models/SKILL.md plugins/core-concepts/skills/data-models/references/ledger-structure.md
```

Expected: no output

- [ ] **Step 5: Commit**

```bash
git add plugins/core-concepts/skills/data-models/
git commit -m "refactor(core-concepts): thin data-models to conceptual level

Remove Hash<> notation, type annotations, Compact code blocks.
Fix claim-048 (MerkleTree stores full tree, not just root).
Keep UTXO mechanics reference as-is (already conceptual).

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 8: Thin protocols/references/zswap-internals.md

**Files:**
- Modify: `plugins/core-concepts/skills/protocols/references/zswap-internals.md` (239 lines)
- Keep as-is: `plugins/core-concepts/skills/protocols/SKILL.md` (219 lines — review for any struct fields but mostly conceptual)
- Keep as-is: `plugins/core-concepts/skills/protocols/references/kachina-deep-dive.md` (conceptual)

**Errors to fix:** claim-082 (3-generator Pedersen formula wrong, type_value_commit field doesn't exist), claim-084 echo (SendResult → ShieldedSendResult, but this belongs in compact-core so remove)

- [ ] **Step 1: Read current files**

Read `plugins/core-concepts/skills/protocols/references/zswap-internals.md` and skim `plugins/core-concepts/skills/protocols/SKILL.md` for struct fields.

- [ ] **Step 2: Edit zswap-internals.md**

Changes:
1. Remove the Input/Output struct definitions → describe what each component carries conceptually
2. Remove the `type_value_commit = type*G_t + value*G_v + randomness*G_r` formula → "Each input and output carries a separate Pedersen value commitment used for balance verification. These are homomorphic, so the network can check that inputs and outputs balance without learning individual values."
3. Remove stdlib function signatures (receiveShielded, sendShielded, mintUnshieldedToken) → these belong in compact-core
4. Keep the merge protocol description, offer structure concept, balance verification concept, security properties, and performance characteristics

- [ ] **Step 3: Edit protocols/SKILL.md if needed**

Check for any struct fields or Hash<> notation and remove. The SKILL.md is mostly conceptual already but may have some type annotations in the Offer description.

- [ ] **Step 4: Verify cleanup**

```bash
grep -n 'type_value_commit\|G_t\|G_v\|G_r\|receiveShielded\|sendShielded\|mintUnshielded\|struct' plugins/core-concepts/skills/protocols/references/zswap-internals.md plugins/core-concepts/skills/protocols/SKILL.md
```

Expected: no output (or only conceptual mentions of "shielded" in prose, not function signatures)

- [ ] **Step 5: Commit**

```bash
git add plugins/core-concepts/skills/protocols/
git commit -m "refactor(core-concepts): thin protocols to conceptual level

Remove Pedersen 3-generator formula (claim-082), struct definitions,
stdlib function signatures. Keep offer/merge/balance mental models.

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 9: Thin zero-knowledge references

**Files:**
- Modify: `plugins/core-concepts/skills/zero-knowledge/references/circuit-construction.md` (143 lines)
- Modify: `plugins/core-concepts/skills/zero-knowledge/references/snark-internals.md` (135 lines)
- Keep as-is: `plugins/core-concepts/skills/zero-knowledge/SKILL.md` (already conceptual)

- [ ] **Step 1: Read current files**

Read both reference files.

- [ ] **Step 2: Edit circuit-construction.md**

Keep:
- The compilation pipeline concept (Compact → Circuit IR → ZKIR → Keys)
- The "what becomes constraints" conceptual mapping (assert → equality constraint, arithmetic → gates, if/else → selection)
- The witness vs public input distinction
- Circuit size impact on proving/verification
- Debugging section on common compiler errors

Remove:
- Gate-level arithmetic detail
- Wire routing mechanics
- Specific constraint encoding formats

- [ ] **Step 3: Edit snark-internals.md**

Keep:
- PLONK conceptual description (gate-based arithmetization, universal setup)
- Universal SRS concept and per-circuit key derivation
- Prove/Verify conceptual signatures
- Proof size and verification time characteristics
- Cryptographic primitive descriptions (persistent vs transient)
- Midnight's SNARK usage overview

Remove:
- Polynomial commitment evaluation mechanics
- Pairing check details
- Grand product check internals
- Any Rust type names

- [ ] **Step 4: Verify cleanup**

```bash
grep -n 'struct\|pairing\|polynomial\|grand product\|wire routing' plugins/core-concepts/skills/zero-knowledge/references/circuit-construction.md plugins/core-concepts/skills/zero-knowledge/references/snark-internals.md
```

Expected: no output (or only conceptual mentions like "polynomial commitments" in a high-level description)

- [ ] **Step 5: Commit**

```bash
git add plugins/core-concepts/skills/zero-knowledge/
git commit -m "refactor(core-concepts): thin ZK references to conceptual level

Keep compilation pipeline, constraint mapping, PLONK overview.
Remove gate-level arithmetic, polynomial mechanics, pairing internals.

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 10: Review and thin privacy-patterns

**Files:**
- Review: `plugins/core-concepts/skills/privacy-patterns/SKILL.md`
- Review: `plugins/core-concepts/skills/privacy-patterns/references/commitment-schemes.md`
- Review: `plugins/core-concepts/skills/privacy-patterns/references/merkle-tree-usage.md`

The fact-check confirmed most privacy-patterns claims are correct. This task is a review pass, not a rewrite.

- [ ] **Step 1: Read all three files**

Read SKILL.md, commitment-schemes.md, and merkle-tree-usage.md.

- [ ] **Step 2: Review for implementation-level detail**

Check for:
- Rust type names or struct field annotations
- Compact code examples (these should be removed — compact-core territory)
- Any Hash<> notation that should be prose instead

The privacy-patterns SKILL.md likely contains Compact code examples showing commit/hash usage patterns. These should be removed since compact-core owns code examples. Keep the conceptual pattern descriptions (when to use commit vs hash, nullifier patterns, Merkle membership flow).

- [ ] **Step 3: Edit if needed**

Remove any Compact code blocks. Replace with conceptual descriptions of the patterns. Keep the decision tables (when to use commit vs hash, etc.) and the threat model section.

- [ ] **Step 4: Commit (if changes were made)**

```bash
git add plugins/core-concepts/skills/privacy-patterns/
git commit -m "refactor(core-concepts): review privacy-patterns, remove code examples

Keep pattern selection guides and threat model.
Remove Compact code blocks (belong in compact-core).

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 11: Update agent and manifest

**Files:**
- Modify: `plugins/core-concepts/agents/concept-explainer.md`
- Modify: `plugins/core-concepts/.claude-plugin/plugin.json`

- [ ] **Step 1: Update concept-explainer.md**

In the frontmatter `skills:` line, remove `core-concepts:smart-contracts`:

Change:
```
skills: core-concepts:data-models, core-concepts:zero-knowledge, core-concepts:privacy-patterns, core-concepts:smart-contracts, core-concepts:protocols, core-concepts:architecture
```

To:
```
skills: core-concepts:data-models, core-concepts:zero-knowledge, core-concepts:privacy-patterns, core-concepts:protocols, core-concepts:tokenomics, core-concepts:architecture
```

Note: also adds `core-concepts:tokenomics` which was missing from the original agent.

In the body, update the Skill Lookup section:
- Remove the `smart-contracts` bullet ("When explaining Compact language, Impact VM...")
- Update the description to emphasize conceptual synthesis rather than implementation detail

- [ ] **Step 2: Update plugin.json**

```json
{
  "name": "core-concepts",
  "version": "0.3.0",
  "description": "Conceptual foundations for understanding the Midnight Network: architecture, data models, privacy patterns, protocols, tokenomics, and zero-knowledge proofs",
  "author": {
    "name": "Aaron Bassett"
  },
  "keywords": [
    "midnight",
    "blockchain",
    "zero-knowledge",
    "zk-proofs",
    "privacy",
    "architecture",
    "concepts"
  ]
}
```

Changes: version bump to 0.3.0, description reworded for conceptual focus, removed "smart-contracts" and "compact" keywords, added "architecture" and "concepts".

- [ ] **Step 3: Commit**

```bash
git add plugins/core-concepts/agents/concept-explainer.md plugins/core-concepts/.claude-plugin/plugin.json
git commit -m "refactor(core-concepts): update agent and manifest for v0.3.0

Remove smart-contracts from agent skills, add tokenomics.
Bump version, update description for conceptual focus.

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 12: Final review and SKILL.md description updates

**Files:**
- Modify: All 6 remaining SKILL.md frontmatter `description` fields

After the rewrites, each SKILL.md `description` field needs to accurately reflect the new conceptual scope. The descriptions drive skill triggering.

- [ ] **Step 1: Review each SKILL.md description**

Read each file's frontmatter and verify the description matches the rewritten content. Remove any references to implementation detail that was removed.

- [ ] **Step 2: Update descriptions as needed**

For example, the architecture description currently mentions "cryptographic binding (Pedersen commitments, Schnorr proofs, ZK-SNARKs)" — this is fine conceptually. But if it mentions "ledger field types" or "Impact state values", remove those references.

- [ ] **Step 3: Verify all SKILL.md files have consistent frontmatter**

```bash
grep -A2 'name:' plugins/core-concepts/skills/*/SKILL.md
```

Check that all 6 skills have name, description, and version fields.

- [ ] **Step 4: Commit**

```bash
git add plugins/core-concepts/skills/*/SKILL.md
git commit -m "refactor(core-concepts): update skill descriptions for conceptual scope

Ensure all 6 skill descriptions accurately reflect rewritten content.

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 13: Run fast-check to verify

**Files:** None (verification only)

- [ ] **Step 1: Run fast-check on the reworked plugin**

```
/midnight-fact-check:fast-check @plugins/core-concepts/
```

- [ ] **Step 2: Review results**

The rewrite should dramatically reduce the error rate. Remaining claims should be:
- Conceptual descriptions (harder to refute from source)
- Confirmed stdlib signatures (already verified in the first run)
- Tokenomics claims (not code-verifiable, but that's expected)

If any new errors appear, fix them before considering the rework complete.

- [ ] **Step 3: Final commit if fixes needed**

```bash
git add plugins/core-concepts/
git commit -m "fix(core-concepts): address fact-check findings from post-rework verification

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```
