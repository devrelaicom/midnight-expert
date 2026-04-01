# Core-Concepts Plugin Rework

**Date:** 2026-04-01
**Status:** Approved
**Context:** Fast-check of the plugin found 25 refuted claims out of 68 verified (36.8% error rate). Most errors stem from citing implementation artifacts (Rust struct field names, exact formulas, type signatures) that were derived from spec pseudocode rather than source. The plugin is too deep for a "concepts" plugin and overlaps heavily with compact-core.

## Goal

Rework core-concepts into a high-level explainer about Midnight Network concepts, architecture, and mental models. Remove implementation-level detail. Fix verified errors. Eliminate overlap with compact-core.

## Decisions

| Decision | Choice |
|----------|--------|
| Audience | Progressive disclosure: SKILL.md approachable, references go deeper |
| compact-core overlap | Remove `smart-contracts/` and `protocol-schemas/` entirely |
| Internal overlap between skills | Each skill owns its angle; repetition OK for self-containment |
| Zero-knowledge skill | Keep with full scope |
| Error handling | Fix where conceptually important, remove implementation trivia |
| Approach | Surgical edit (rewrite in place, don't restructure from scratch) |

## Skills: Keep (6)

### architecture
- **Angle:** System structure — how a transaction flows through Midnight
- **SKILL.md focus:** The guaranteed/fallible split, how Zswap/Kachina/Impact fit together, what the ledger looks like at a high level
- **Reference changes:**
  - `cryptographic-binding.md` — rewrite: explain what Pedersen/Schnorr/ZK binding achieve, not struct fields or formulas. Remove wrong Pedersen formula (claim-025), wrong Schnorr struct (claim-028), "one proof per tx" (claim-026), and "contract zero net value" (claim-027).
  - `state-management.md` — thin: describe state transitions conceptually, remove Rust field name catalogue (claim-013 errors)
  - `transaction-deep-dive.md` — rewrite significantly: had the most errors (claims 033-035, all field names wrong). Describe the transaction flow without cataloguing struct fields.
- **Remove:** `examples/transaction-construction.md`

### data-models
- **Angle:** Data & state — what coins, commitments, nullifiers, and tokens *are*
- **SKILL.md focus:** UTXO model, commitment tree, shielded vs unshielded, token types
- **Reference changes:**
  - `ledger-structure.md` — thin: remove Rust type mappings (claim-048 error about "only root stored"), keep conceptual structure
  - `utxo-mechanics.md` — keep mostly as-is, content is already conceptual
- **Remove:** `examples/token-handling.compact`

### privacy-patterns
- **Angle:** Developer patterns — which privacy tool for which job
- **SKILL.md focus:** When to use commitments vs hashes, nullifier construction, Merkle membership, selective disclosure
- **Reference changes:**
  - `commitment-schemes.md` — keep, already conceptual. The fact-check confirmed persistentCommit/persistentHash/transientCommit/transientHash signatures are correct. No changes needed unless content references Rust types.
  - `merkle-tree-usage.md` — keep, good pattern guide
- **Remove:** `examples/auth-patterns.compact`, `examples/private-voting.compact`

### protocols
- **Angle:** Protocol mechanics — what Kachina and Zswap *do*
- **SKILL.md focus:** Two-state model, transcripts, concurrency, offers, merging, atomic swaps
- **Reference changes:**
  - `kachina-deep-dive.md` — keep, conceptual protocol description
  - `zswap-internals.md` — thin: remove struct field catalogues (claim-082 error about 3-generator formula), keep offer/merge/balance mental model
- **Remove:** `examples/basic-transfer.md`, `examples/atomic-swap.md`

### tokenomics
- **Angle:** Economics — the NIGHT/DUST dual model
- **SKILL.md focus:** Token purposes, distribution phases, block rewards, MEV resistance
- **Reference changes:** None (no references exist)
- **Remove:** Nothing

### zero-knowledge
- **Angle:** ZK foundations — why Midnight uses SNARKs and how they work
- **SKILL.md focus:** What SNARKs are, how circuits map to Compact, proof lifecycle, PLONK conceptually, performance
- **Reference changes:**
  - `circuit-construction.md` — thin: keep "what becomes constraints" conceptually, remove gate-level arithmetic detail
  - `snark-internals.md` — thin: keep PLONK conceptual description, remove polynomial commitment mechanics
- **Remove:** Nothing

## Skills: Remove (2)

### smart-contracts (entire directory)
- **Reason:** Owned by compact-core, which has dedicated skills for language reference, compilation, transaction model, structure, deployment, testing, and debugging
- **Delete:** SKILL.md, all references (compact-syntax.md, execution-semantics.md, impact-vm.md), all examples

### protocol-schemas (entire directory)
- **Reason:** JSON schemas with no real utility. The schemas describe formats that may not correspond to actual protocol artifacts. No one loads this skill to write code.
- **Delete:** SKILL.md, all reference JSON files

## Content Principles

These guide every rewrite decision:

1. **No Rust struct fields or type names** — describe behavior, not implementation. "Each contract stores its current state and a set of verifier keys" not "ContractState has data: ChargedState"
2. **No exact formulas unless conceptually essential** — "commitments are homomorphic, meaning they can be added together" matters. The generator-point formula doesn't.
3. **Describe behavior, not implementation** — "nullifiers are computed from the coin data and spending key, making them unlinkable to the original commitment" not "Nullifier = Hash<(CoinInfo, CoinSecretKey)>"
4. **Fix refuted claims where the concept matters** — correct the description of proof verification phases; remove the wrong struct field catalogues entirely
5. **References build mental models, not source code knowledge** — deeper understanding of *why* things work, not *how the Rust implements them*

## Refuted Claims: Disposition

| Claim | Action |
|-------|--------|
| claim-001 to claim-003 (transaction field names) | Remove field-level detail; describe transaction structure conceptually |
| claim-007 (fallible coin ops timing) | Fix: clarify that fallible coin ops are validated but applied in their own phase |
| claim-011 (entry_point type) | Remove type-level detail |
| claim-013 (ledger field names/types) | Remove field catalogue; describe ledger conceptually |
| claim-014, claim-015 (ImpactValue, SNARKVerifierKey) | Remove invented type names |
| claim-017, claim-018 (proof verification phase) | Fix: proofs are verified during well-formedness but require state access for verifier key lookup |
| claim-020 (merge constraint) | Fix: remove false constraint about empty contract calls |
| claim-022 (token type hash arg order) | Fix if formula retained, otherwise remove |
| claim-025 (Pedersen formula) | Remove formula; describe homomorphic property conceptually |
| claim-026 to claim-028 (Schnorr proof details) | Remove struct-level detail; describe purpose of Schnorr proof conceptually |
| claim-033 to claim-035 (Input/Output/Transcript fields) | Remove field catalogues entirely |
| claim-048 (MerkleTree stores only root) | Fix: tree structure is stored, but leaf preimages are hidden |
| claim-082 (3-generator Pedersen) | Remove formula; describe multi-asset balance verification conceptually |
| claim-084 (SendResult return type) | Remove from this plugin (belongs in compact-core) |
| claim-142 to claim-144 (Impact VM details) | Remove (smart-contracts skill being deleted) |

## Agent Update

Update `agents/concept-explainer.md`:
- Remove `core-concepts:smart-contracts` from preloaded skills
- Keep remaining 5 skills + zero-knowledge (6 total)
- Update description to reflect conceptual focus

## Plugin Manifest Update

Update `.claude-plugin/plugin.json`:
- Remove smart-contracts and protocol-schemas skill entries
- Update plugin description to emphasize conceptual orientation
- Bump version to 0.3.0
