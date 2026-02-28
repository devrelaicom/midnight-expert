# Design: compact-privacy-disclosure Skill

## Overview

A dedicated skill for the `compact-core` plugin covering Midnight's privacy model, the `disclose()` mechanism, privacy-preserving design patterns, and a comprehensive debugging guide for disclosure compiler errors. This skill provides the privacy dimension of Compact programming: understanding what's private by default, when and how to disclose, and how to build contracts that preserve user privacy.

## Decisions

- **Audience:** Developers writing privacy-preserving Compact contracts who need to understand Midnight's privacy model and debug disclosure issues
- **Organization:** Concept-first (privacy model → disclosure mechanics → patterns → debugging)
- **Overlap strategy:** Cross-reference `compact-ledger/references/privacy-and-visibility.md` for basic visibility rules; this skill extends with deeper mechanics, advanced patterns, threat modeling, and debugging
- **Reference files:** Three files (disclosure-mechanics, privacy-patterns, debugging-disclosure)
- **Examples:** 6 complete, commented .compact contracts demonstrating privacy patterns
- **Existing skills:** No modifications to other skills; they can cross-reference this skill for deeper privacy coverage

## File Structure

```
plugins/compact-core/skills/compact-privacy-disclosure/
├── SKILL.md
├── references/
│   ├── disclosure-mechanics.md
│   ├── privacy-patterns.md
│   └── debugging-disclosure.md
└── examples/
    ├── CommitRevealScheme.compact
    ├── NullifierDoubleSpend.compact
    ├── PrivateVoting.compact
    ├── UnlinkableAuth.compact
    ├── SelectiveDisclosure.compact
    └── ShieldedAuction.compact
```

## SKILL.md Structure

### Frontmatter

- **name:** compact-privacy-disclosure
- **description:** This skill should be used when the user asks about Midnight's privacy model, the disclose() function and disclosure rules, how to fix disclosure compiler errors, privacy-by-default design, witness protection program, commitment schemes (persistentCommit, transientCommit), nullifier patterns for double-spend prevention, MerkleTree membership proofs for anonymous authentication, unlinkable actions via round-based keys, selective disclosure, commit-reveal schemes, shielded vs transparent state design, what is visible on-chain, safe stdlib routines (transientCommit hiding witness data), or debugging "potential witness-value disclosure must be declared" errors.

### Sections

1. **Opening paragraph** (~3 lines) — Scope definition: this skill covers the privacy dimension of Compact. Cross-references to `compact-ledger` for visibility rules and ADT operations, `compact-structure` for contract anatomy, `compact-standard-library` for function signatures, `compact-tokens` for shielded token privacy.

2. **Midnight's Privacy Model** (~10 lines) — Privacy is the default. All witness-derived data is private unless explicitly disclosed. The compiler's "Witness Protection Program" enforces this via abstract interpretation. Disclosure is an intentional annotation, not a runtime operation.

3. **Privacy Decision Tree** (~15 lines) — Table mapping developer intent to approach:
   | What to protect | Approach | Key primitives |
   | Hide a value on-chain | Commitment | persistentCommit / transientCommit |
   | Prove membership anonymously | MerkleTree + ZK path | HistoricMerkleTree + merkleTreePathRoot |
   | Prevent double-actions | Nullifier | Hash(domain + secret) → Set |
   | Hide who is acting | Unlinkable auth | Counter + rotated hash |
   | Multi-step hidden value | Commit-reveal | Commit phase → reveal phase |
   | Private token balances | Shielded tokens | zswap infrastructure |
   | Share specific data only | Selective disclosure | disclose() targeted fields |

4. **Disclosure Rules Quick Reference** (~20 lines) — When disclose() is required (ledger writes, conditionals, returns, cross-contract) vs when it's not (pure computation). Safe stdlib routines: transientCommit clears witness taint; transientHash does NOT.

5. **Common Disclosure Mistakes** (~15 lines) — Quick-reference mistake table similar to other skills' format.

6. **Reference Routing Table** — Links to the three reference files.

7. **Examples Routing Table** — Lists the 6 example contracts with one-line descriptions.

## Reference Files

### references/disclosure-mechanics.md

Deep dive into `disclose()`:

1. **What disclose() actually does** — Compiler annotation, not runtime operation. Tells the compiler to treat wrapped expression as non-witness data.
2. **The Witness Protection Program** — Abstract interpreter tracking witness data flow. Halts with error on undeclared disclosure.
3. **Disclosure contexts (exhaustive)**:
   - Ledger writes (direct assignment, ADT method arguments)
   - Conditionals (if, ternary, assert)
   - Returns from exported circuits
   - Cross-contract calls
   - Constructor parameters to sealed fields
4. **Where to place disclose()** — Best practice: close to disclosure point. For structs, only disclose witness-containing portions.
5. **Safe stdlib routines** — transientCommit and persistentCommit clear witness taint. transientHash and persistentHash do NOT.
6. **Indirect disclosure tracking** — How compiler traces through arithmetic, struct fields, circuit calls, type casts, lambdas.
7. **Exported circuit parameters** — Parameters to exported circuits are also treated as witness data (they come from the transaction submitter).

### references/privacy-patterns.md

Advanced patterns beyond compact-ledger's basic coverage:

1. **Commitment Schemes** — persistentCommit vs transientCommit, binding properties, when to use each domain, salt/randomness requirements
2. **Nullifier Construction** — Domain separation best practices, deriving nullifiers so they can't be correlated with commitments, multi-round nullifiers
3. **Merkle Tree Anonymous Auth** — HistoricMerkleTree for late proofs, full on-chain/off-chain dance, path witness implementation considerations
4. **Round-Based Unlinkability** — Key rotation mechanism, when rounds reset, combining with nullifiers
5. **Multi-Phase Protocols** — Commit-reveal with multiple participants, ordering considerations, timeout handling
6. **Selective Disclosure** — Proving properties without revealing values, range proofs via assertion patterns
7. **Threat Model** — What an on-chain observer can see, correlation attacks (timing, amount patterns, tree size), MerkleTree leaf guessing, metadata leakage
8. **Anti-Patterns** — Common mistakes that leak privacy (disclosing too early, Set where MerkleTree needed, missing domain separators, reusing nullifier derivation across contracts)

### references/debugging-disclosure.md

Step-by-step guide for fixing disclosure compiler errors:

1. **Anatomy of a disclosure error** — Breaking down the error message: witness source, nature of disclosure, path through program
2. **5-step debugging process**:
   - Step 1: Identify the witness source
   - Step 2: Trace the data flow path (compiler provides this)
   - Step 3: Determine if disclosure is intentional
   - Step 4: If intentional → place disclose() at right location
   - Step 5: If unintentional → restructure to avoid leak
3. **Common error patterns with fixes** (6-8 patterns):
   - Direct ledger write without disclose
   - Indirect via arithmetic / type cast chain
   - Conditional on witness value
   - Return from exported circuit
   - Struct field containing witness data
   - Lambda/closure capturing witness value
   - Standard library call with witness argument
4. **Where NOT to put disclose()** — Avoiding over-disclosure, keeping disclose() narrow
5. **Using MCP to verify** — midnight-compile-contract for testing, midnight-search-compact for finding patterns in official examples

## Example Contracts

Each example is a complete, compilable contract with:
- Header comment describing pattern, privacy properties, and threat model
- Full pragma/import/ledger/witness/circuit structure
- Inline comments on every disclose() explaining why and what it reveals
- Privacy Analysis comment section at bottom

### 1. CommitRevealScheme.compact
Two-phase hidden-then-revealed value with salt-based commitments. Demonstrates: persistentCommit for hiding, salt management via witness, reveal verification, prevention of front-running.

### 2. NullifierDoubleSpend.compact
Commitment + nullifier for single-use authorization tokens. Demonstrates: HistoricMerkleTree for hidden commitments, nullifier derivation with domain separation, double-spend prevention via Set, the full spend cycle.

### 3. PrivateVoting.compact
Anonymous ballot casting with commit-then-reveal. Demonstrates: MerkleTree membership proofs for voter eligibility, separate commitment and reveal nullifiers, vote commitment via MerkleTree insert (hidden), vote reveal with proof verification. Most complex example — combines multiple patterns.

### 4. UnlinkableAuth.compact
Round-based key rotation for transaction unlinkability. Demonstrates: Counter-based round tracking, key derivation incorporating round number, authority rotation on each action, breaking linkability between successive transactions.

### 5. SelectiveDisclosure.compact
Proving a property about private data without revealing the value. Demonstrates: asserting witness-derived comparisons, disclosing boolean results but not underlying values, threshold checks, range-like proofs.

### 6. ShieldedAuction.compact
Sealed-bid auction combining commit-reveal with time constraints. Demonstrates: bid commitment phase, reveal phase with time bounds (blockTimeGte/Lt), winner determination, combining multiple privacy patterns in one contract.

## Plugin Manifest Update

Add keywords to plugin.json:
```json
"privacy", "disclosure", "disclose", "witness-protection", "commitment",
"nullifier", "zero-knowledge-proof", "selective-disclosure", "commit-reveal",
"anonymous-auth", "merkle-proof"
```

## Cross-References

### This skill references:
- `compact-ledger/references/privacy-and-visibility.md` — visibility rules per ledger operation
- `compact-structure/references/patterns.md` — basic pattern implementations
- `compact-standard-library` — function signatures (persistentHash, persistentCommit, etc.)
- `compact-tokens` — shielded token privacy model

### Other skills can reference this for:
- Deep disclosure mechanics and debugging
- Advanced privacy patterns and threat modeling
- Complete privacy pattern examples
