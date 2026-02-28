# Design: compact-standard-library Skill

## Overview

A comprehensive standard library reference skill for the `compact-core` plugin that serves as the single index of everything `import CompactStandardLibrary;` provides. Covers all stdlib exports with deep documentation for previously uncovered content (elliptic curve functions, Merkle tree path functions, constructor functions, stdlib types) and summary tables with cross-references for content documented in other skills (hashing/commitments, tokens, ledger ADTs).

Embeds verification guidance and anti-hallucination techniques directly into SKILL.md alongside the reference content, with MCP search strategies and a compilation verification protocol.

## Decisions

- **Scope:** Complete reference with summaries — full coverage of all stdlib exports, deep docs for uncovered content, summary tables + cross-refs for existing
- **Verification guidance:** Woven into SKILL.md alongside each section, not a separate reference file
- **Verification position:** Prominently placed as section 2 (immediately after opening paragraph, before export inventory) as hard rules the agent must follow
- **Reference organization:** By domain — 3 reference files (types-and-constructors, cryptographic-functions, cross-reference-index)
- **Examples:** Inline snippets only, no separate example .compact files
- **Existing skills:** No modifications — cross-reference only

## File Structure

```
plugins/compact-core/skills/compact-standard-library/
├── SKILL.md
└── references/
    ├── types-and-constructors.md
    ├── cryptographic-functions.md
    └── cross-reference-index.md
```

## SKILL.md Structure

### Frontmatter

- **name:** compact-standard-library
- **description:** This skill should be used when the user asks about the Compact standard library (CompactStandardLibrary), stdlib types (Maybe, Either, CurvePoint, NativePoint, MerkleTreeDigest, MerkleTreePath, ContractAddress, ZswapCoinPublicKey, UserAddress), stdlib constructor functions (some, none, left, right), elliptic curve functions (ecAdd, ecMul, ecMulGenerator, hashToCurve), Merkle tree path verification (merkleTreePathRoot, merkleTreePathRootNoLeafHash), or when the user needs to verify which functions exist in the standard library, prevent hallucination of non-existent stdlib functions, or search the Midnight MCP for stdlib source code.

### Sections

1. **Opening paragraph** (~5 lines) — Scope: the single index of everything `import CompactStandardLibrary;` provides. Cross-refs to other compact-core skills for deep dives. States the verification-first philosophy.

2. **Verification Protocol** (~25 lines) — Hard rules embedded at the top, before any function documentation:
   - **Rule: Never assume a function exists** — Always verify against this skill's export inventory or use MCP search
   - **MCP Search Techniques** — `midnight-search-compact` for usage examples, `midnight-search-docs` for API docs, `midnight-compile-contract` for compilation validation
   - **Verification Checklist** — Before using any stdlib function: (1) confirm it's in the export inventory below, (2) check signature matches, (3) if uncertain, search MCP, (4) compile to verify
   - **Common hallucination traps** — Functions that don't exist (e.g., `public_key()`, `hash()`, `verify()`, `encrypt()`, `decrypt()`, `random()`, `counter.value()`)

3. **Complete Export Inventory** (~30 lines) — Master table of every stdlib export organized by category (types, constructor circuits, hashing, commitments, conversion, EC, Merkle path, utility, coin management, ledger ADTs). Each row: name, kind (type/circuit), brief description, authoritative reference location.

4. **Types** (~20 lines) — Summary table of all stdlib types with fields and purpose. Points to `references/types-and-constructors.md` for detail. Verification tip: "Use `midnight-search-compact` with the type name to find real-world usage patterns."

5. **Constructor Functions** (~15 lines) — `some<T>`, `none<T>`, `left<A,B>`, `right<A,B>` with signatures and brief examples. Points to `references/types-and-constructors.md`.

6. **Hashing & Commitment Functions** (~15 lines) — Summary table (persistentHash, transientHash, persistentCommit, transientCommit, degradeToTransient, upgradeFromTransient) with signatures. Links to `compact-language-ref/references/stdlib-functions.md` for deep documentation. Verification tip: persistent vs transient choice.

7. **Elliptic Curve Functions** (~15 lines) — `ecAdd`, `ecMul`, `ecMulGenerator`, `hashToCurve` with signatures and brief purpose. Points to `references/cryptographic-functions.md`. Verification tip: "EC functions are newer — always verify with `midnight-compile-contract` before assuming availability."

8. **Merkle Tree Path Functions** (~10 lines) — `merkleTreePathRoot`, `merkleTreePathRootNoLeafHash` with signatures. Points to `references/cryptographic-functions.md`.

9. **Utility Functions** (~10 lines) — Summary of `pad`, `disclose`, `assert`, `default` with links to `compact-language-ref/references/stdlib-functions.md`.

10. **Coin Management Functions** (~10 lines) — Summary of token-related functions with link to `compact-tokens`.

11. **Ledger ADT Operations** (~10 lines) — Summary of Counter, Map, Set, List, MerkleTree, HistoricMerkleTree with link to `compact-ledger`.

12. **Common Mistakes & Non-Existent Functions** (~15 lines) — Table of functions agents commonly hallucinate and what to use instead.

13. **Reference Routing** — Table pointing to three reference files and cross-references to other skills.

## references/types-and-constructors.md

Full documentation of stdlib types and constructor functions.

### Sections

- **Stdlib Types Overview** — All types the stdlib provides, each with full field documentation, default values, and TypeScript representation
- **Maybe<T>** — Fields (`.is_some: Boolean`, `.value: T`), construction via `some<T>(v)` / `none<T>()`, inspection pattern, common use with Map.lookup
- **Either<L, R>** — Fields (`.is_left: Boolean`, `.left: L`, `.right: R`), construction via `left<A,B>(v)` / `right<A,B>(v)`, inspection pattern, common use for recipient addressing
- **CurvePoint / NativePoint** — Structure, use with EC functions, version differences
- **MerkleTreeDigest** — Type alias for `Bytes<32>`, used with `checkRoot()` and `merkleTreePathRoot()`
- **MerkleTreePathEntry** — Structure, role in path verification
- **MerkleTreePath<N>** — Parameterized path type, used with `merkleTreePathRoot()`
- **Address Types** — `ContractAddress`, `ZswapCoinPublicKey`, `UserAddress` with field structures
- **Constructor Functions** — `some`, `none`, `left`, `right` with full signatures, generic type parameter usage, and patterns
- **Re-Exporting Stdlib Types** — `export { Maybe, Either, CoinInfo };` pattern for TypeScript access

## references/cryptographic-functions.md

Deep documentation for EC and Merkle path functions, plus summary of hashing/commitments.

### Sections

- **Elliptic Curve Functions**:
  - `ecAdd(a: NativePoint, b: NativePoint): NativePoint` — Point addition
  - `ecMul(scalar: Field, point: NativePoint): NativePoint` — Scalar multiplication
  - `ecMulGenerator(scalar: Field): NativePoint` — Scalar multiplication with generator point
  - `hashToCurve(data: Bytes<32>): NativePoint` — Hash to curve point
  - Use cases: Pedersen commitments, key derivation, signature verification building blocks
  - Inline examples with verification tips
- **Merkle Tree Path Functions**:
  - `merkleTreePathRoot<N, T>(leaf: T, path: MerkleTreePath<N>): MerkleTreeDigest` — Compute root from leaf + path
  - `merkleTreePathRootNoLeafHash<N>(leafHash: Bytes<32>, path: MerkleTreePath<N>): MerkleTreeDigest` — Compute root from pre-hashed leaf
  - Off-chain path generation patterns, on-chain verification
- **Hashing & Commitment Summary** — Compact summary table of persistentHash, transientHash, persistentCommit, transientCommit, degradeToTransient, upgradeFromTransient. Links to `compact-language-ref/references/stdlib-functions.md` for deep docs.

## references/cross-reference-index.md

Alphabetical index of every stdlib export, each entry containing:

- Name
- Kind (type / circuit / ledger ADT)
- Brief one-line description
- Authoritative location (which skill + reference file has the deep documentation)

Serves as the "phone book" for stdlib lookups — when an agent encounters an unfamiliar stdlib name, they look it up here and are directed to the right reference.

## Plugin Manifest Update

Add standard-library-related keywords to `plugin.json`:

```json
"keywords": [
  ... existing keywords ...,
  "standard-library",
  "stdlib",
  "elliptic-curve",
  "merkle-tree",
  "cryptographic"
]
```
