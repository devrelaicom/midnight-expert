# compact-standard-library Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a `compact-standard-library` skill to the compact-core plugin that serves as the single authoritative index of everything `import CompactStandardLibrary;` provides, with verification guidance woven throughout to prevent hallucination.

**Architecture:** SKILL.md acts as the hub with embedded anti-hallucination protocol, complete export inventory, and summary tables for cross-referenced content. Three reference files provide deep documentation for uncovered content (types, constructors, EC functions, Merkle path functions) and a cross-reference index mapping every export to its authoritative skill.

**Tech Stack:** Markdown skill files following the established compact-core plugin pattern (SKILL.md + references/ directory).

---

### Task 1: Scaffold directory structure

**Files:**
- Create: `plugins/compact-core/skills/compact-standard-library/SKILL.md` (empty placeholder)
- Create: `plugins/compact-core/skills/compact-standard-library/references/` (directory)

**Step 1: Create the directory structure**

```bash
mkdir -p plugins/compact-core/skills/compact-standard-library/references
```

**Step 2: Create a placeholder SKILL.md**

Create `plugins/compact-core/skills/compact-standard-library/SKILL.md` with just the frontmatter:

```markdown
---
name: compact-standard-library
description: This skill should be used when the user asks about the Compact standard library (CompactStandardLibrary), stdlib types (Maybe, Either, CurvePoint, NativePoint, MerkleTreeDigest, MerkleTreePath, ContractAddress, ZswapCoinPublicKey, UserAddress), stdlib constructor functions (some, none, left, right), elliptic curve functions (ecAdd, ecMul, ecMulGenerator, hashToCurve), Merkle tree path verification (merkleTreePathRoot, merkleTreePathRootNoLeafHash), or when the user needs to verify which functions exist in the standard library, prevent hallucination of non-existent stdlib functions, or search the Midnight MCP for stdlib source code.
---

# Compact Standard Library Reference

(Content to follow)
```

**Step 3: Commit**

```bash
git add plugins/compact-core/skills/compact-standard-library/
git commit -m "feat(compact-core): scaffold compact-standard-library skill directory structure"
```

---

### Task 2: Write SKILL.md — Opening + Verification Protocol

**Files:**
- Modify: `plugins/compact-core/skills/compact-standard-library/SKILL.md`

**Step 1: Write the opening paragraph and verification protocol**

Replace the placeholder content in SKILL.md with the frontmatter and the first two sections.

**Opening paragraph** (~5 lines): Scope definition stating this is the single index of everything `import CompactStandardLibrary;` provides. Cross-references to `compact-structure` for contract anatomy, `compact-language-ref` for language mechanics, `compact-ledger` for ADT state design, and `compact-tokens` for token operations. States the verification-first philosophy: "When in doubt, verify — never assume a function exists."

**Verification Protocol** (~25 lines): Hard rules section titled `## Verification Protocol`. Must include:

1. **RULE: Never assume a stdlib function exists.** Before using any function from CompactStandardLibrary, verify it appears in the export inventory below. If a function is not listed, it does not exist.

2. **MCP Verification Techniques** — A table with three techniques:
   - `midnight-search-compact` with the function name — finds real usage in the Compact codebase. If no results, the function likely doesn't exist.
   - `midnight-search-docs` with the function name — finds official API documentation. Cross-check signatures against this skill.
   - `midnight-compile-contract` with a minimal contract using the function — the ultimate verification. If it compiles, the function exists with that signature.

3. **Verification Checklist** — Numbered steps:
   1. Check the export inventory in this skill
   2. Verify the function signature matches (parameter types, return type, generic parameters)
   3. If uncertain, use `midnight-search-compact` to find real usage examples
   4. For critical code, compile a minimal contract with `midnight-compile-contract`

4. **Common Hallucination Traps** — Table of functions that DO NOT EXIST and what to use instead:
   - `public_key(sk)` → `persistentHash<Vector<2, Bytes<32>>>([pad(32, "domain:pk:"), sk])`
   - `hash(value)` → `persistentHash<T>(value)` or `transientHash<T>(value)`
   - `verify(sig, msg, pk)` → Does not exist; build from EC primitives
   - `encrypt(value)` / `decrypt(value)` → Do not exist; use commitments
   - `random()` / `randomBytes()` → Do not exist; use witness functions
   - `counter.value()` → `counter.read()`
   - `map.get(key)` → `map.lookup(key)`
   - `map.has(key)` → `map.member(key)`
   - `map.set(key, value)` → `map.insert(key, value)`
   - `map.delete(key)` → `map.remove(key)`
   - `CurvePoint` (old name) → `NativePoint` (current name, post-camelCase migration)

**Step 2: Commit**

```bash
git add plugins/compact-core/skills/compact-standard-library/SKILL.md
git commit -m "feat(compact-core): add opening and verification protocol to compact-standard-library"
```

---

### Task 3: Write SKILL.md — Complete Export Inventory

**Files:**
- Modify: `plugins/compact-core/skills/compact-standard-library/SKILL.md`

**Step 1: Add the complete export inventory section**

Add `## Complete Export Inventory` after the Verification Protocol. This is a master table organized by category with columns: Name, Kind, Brief Description, Reference Location.

**Categories and exports to include:**

**Types:**
- `Maybe<T>` — type — Optional value container — `references/types-and-constructors.md`
- `Either<L, R>` — type — Disjoint union (sum type) — `references/types-and-constructors.md`
- `NativePoint` — type — Elliptic curve point — `references/types-and-constructors.md`
- `MerkleTreeDigest` — type — Merkle root hash wrapper — `references/types-and-constructors.md`
- `MerkleTreePathEntry` — type — Sibling + direction in path — `references/types-and-constructors.md`
- `MerkleTreePath<N, T>` — type — Path from leaf to root — `references/types-and-constructors.md`
- `ContractAddress` — type — Contract address wrapper — `references/types-and-constructors.md`
- `ZswapCoinPublicKey` — type — Coin public key for shielded ops — `references/types-and-constructors.md`
- `UserAddress` — type — User address wrapper — `references/types-and-constructors.md`
- `ShieldedCoinInfo` — type — Newly created shielded coin — `compact-tokens/references/token-operations.md`
- `QualifiedShieldedCoinInfo` — type — Existing shielded coin with index — `compact-tokens/references/token-operations.md`
- `ShieldedSendResult` — type — Send result with change — `compact-tokens/references/token-operations.md`

**Constructor Circuits:**
- `some<T>` — circuit — Construct Maybe containing value — `references/types-and-constructors.md`
- `none<T>` — circuit — Construct empty Maybe — `references/types-and-constructors.md`
- `left<A, B>` — circuit — Construct left Either variant — `references/types-and-constructors.md`
- `right<A, B>` — circuit — Construct right Either variant — `references/types-and-constructors.md`

**Hashing & Commitment Circuits:**
- `persistentHash<T>` — circuit — SHA-256 hash; stable across upgrades — `compact-language-ref/references/stdlib-functions.md`
- `transientHash<T>` — circuit — Circuit-efficient hash; may change — `compact-language-ref/references/stdlib-functions.md`
- `persistentCommit<T>` — circuit — SHA-256 commitment with randomness — `compact-language-ref/references/stdlib-functions.md`
- `transientCommit<T>` — circuit — Circuit-efficient commitment — `compact-language-ref/references/stdlib-functions.md`
- `degradeToTransient` — circuit — Convert Bytes<32> to Field — `compact-language-ref/references/stdlib-functions.md`
- `upgradeFromTransient` — circuit — Convert Field to Bytes<32> — `compact-language-ref/references/stdlib-functions.md`

**Elliptic Curve Circuits:**
- `ecAdd` — circuit — Add two NativePoints — `references/cryptographic-functions.md`
- `ecMul` — circuit — Scalar multiply NativePoint — `references/cryptographic-functions.md`
- `ecMulGenerator` — circuit — Scalar multiply generator — `references/cryptographic-functions.md`
- `hashToCurve<T>` — circuit — Map value to NativePoint — `references/cryptographic-functions.md`
- `nativePointX` — circuit — Get X coordinate of NativePoint — `references/cryptographic-functions.md`
- `nativePointY` — circuit — Get Y coordinate of NativePoint — `references/cryptographic-functions.md`
- `constructNativePoint` — circuit — Construct NativePoint from X, Y — `references/cryptographic-functions.md`

**Merkle Tree Path Circuits:**
- `merkleTreePathRoot<N, T>` — circuit — Compute root from leaf + path — `references/cryptographic-functions.md`
- `merkleTreePathRootNoLeafHash<N>` — circuit — Compute root from pre-hashed leaf — `references/cryptographic-functions.md`

**Utility Circuits:**
- `pad` — builtin — Create Bytes<N> from string literal — `compact-language-ref/references/stdlib-functions.md`
- `disclose` — builtin — Mark value as publicly visible — `compact-language-ref/references/stdlib-functions.md`
- `assert` — builtin — Abort if condition is false — `compact-language-ref/references/stdlib-functions.md`
- `default<T>` — builtin — Default value for any type — `compact-language-ref/references/stdlib-functions.md`

**Coin Management Circuits:**
- `tokenType` — circuit — Compute token color from domain sep + contract — `compact-tokens/references/token-operations.md`
- `nativeToken` — circuit — Native token color (zero) — `compact-tokens/references/token-operations.md`
- `ownPublicKey` — circuit — Current user's coin public key — `compact-tokens/references/token-operations.md`
- `mintShieldedToken` — circuit — Mint new shielded coin — `compact-tokens/references/token-operations.md`
- `receiveShielded` — circuit — Accept shielded coin — `compact-tokens/references/token-operations.md`
- `sendShielded` — circuit — Send from existing coin — `compact-tokens/references/token-operations.md`
- `sendImmediateShielded` — circuit — Send from just-created coin — `compact-tokens/references/token-operations.md`
- `mergeCoin` — circuit — Merge two existing coins — `compact-tokens/references/token-operations.md`
- `mergeCoinImmediate` — circuit — Merge existing + new coin — `compact-tokens/references/token-operations.md`
- `evolveNonce` — circuit — Derive next nonce — `compact-tokens/references/token-operations.md`
- `shieldedBurnAddress` — circuit — Burn address for shielded coins — `compact-tokens/references/token-operations.md`
- `createZswapInput` — circuit — Low-level zswap input — `compact-tokens/references/token-operations.md`
- `createZswapOutput` — circuit — Low-level zswap output — `compact-tokens/references/token-operations.md`
- `mintUnshieldedToken` — circuit — Mint unshielded token — `compact-tokens/references/token-operations.md`
- `sendUnshielded` — circuit — Send unshielded token — `compact-tokens/references/token-operations.md`
- `receiveUnshielded` — circuit — Receive unshielded token — `compact-tokens/references/token-operations.md`
- `unshieldedBalance` — circuit — Query unshielded balance (exact, use with caution) — `compact-tokens/references/token-operations.md`
- `unshieldedBalanceLt` — circuit — Balance less than comparison — `compact-tokens/references/token-operations.md`
- `unshieldedBalanceGte` — circuit — Balance greater-or-equal comparison — `compact-tokens/references/token-operations.md`
- `unshieldedBalanceGt` — circuit — Balance greater than comparison — `compact-tokens/references/token-operations.md`
- `unshieldedBalanceLte` — circuit — Balance less-or-equal comparison — `compact-tokens/references/token-operations.md`

**Ledger ADT Types:**
- `Counter` — ledger ADT — Numeric counter — `compact-ledger/references/types-and-operations.md`
- `Map<K, V>` — ledger ADT — Key-value store — `compact-ledger/references/types-and-operations.md`
- `Set<T>` — ledger ADT — Unique element collection — `compact-ledger/references/types-and-operations.md`
- `List<T>` — ledger ADT — Ordered sequence — `compact-ledger/references/types-and-operations.md`
- `MerkleTree<N, T>` — ledger ADT — Privacy-preserving set — `compact-ledger/references/types-and-operations.md`
- `HistoricMerkleTree<N, T>` — ledger ADT — MerkleTree with root history — `compact-ledger/references/types-and-operations.md`

**Note:** Before writing this table, verify each export name and category against the MCP sources. Use `midnight-search-compact` with the function name to confirm it exists in the codebase. The `nativePointX`, `nativePointY`, and `constructNativePoint` functions appear in test examples but should be verified as part of the public API. If they do not appear in the official exports.md docs, include them with a note that they are available but not documented in the official API reference.

**Step 2: Commit**

```bash
git add plugins/compact-core/skills/compact-standard-library/SKILL.md
git commit -m "feat(compact-core): add complete export inventory to compact-standard-library"
```

---

### Task 4: Write SKILL.md — Types, Constructor Functions, and Hashing summary sections

**Files:**
- Modify: `plugins/compact-core/skills/compact-standard-library/SKILL.md`

**Step 1: Add the Types section**

Add `## Types` with a summary table of all stdlib-provided types. Each row: type name, generic parameters, fields summary, default value. After the table, add a verification tip:

> **Verification:** Use `midnight-search-compact` with the type name (e.g., `MerkleTreeDigest`) to find real-world usage patterns across the Compact codebase.

Point to `references/types-and-constructors.md` for full field documentation and TypeScript representations.

**Step 2: Add the Constructor Functions section**

Add `## Constructor Functions` with the four functions:

```compact
circuit some<T>(value: T): Maybe<T>;
circuit none<T>(): Maybe<T>;
circuit left<A, B>(value: A): Either<A, B>;
circuit right<A, B>(value: B): Either<A, B>;
```

Include a brief inline example showing construction and inspection:

```compact
const found = some<Field>(42);
if (found.is_some) {
  const v = found.value;  // 42
}

const recipient = left<ZswapCoinPublicKey, ContractAddress>(ownPublicKey());
```

Point to `references/types-and-constructors.md` for full patterns.

**Step 3: Add the Hashing & Commitment Functions section**

Add `## Hashing & Commitment Functions` with a summary table:

| Function | Signature | Domain | Store in Ledger? |
|----------|-----------|--------|-----------------|
| `persistentHash<T>` | `(value: T): Bytes<32>` | Persistent | Yes |
| `transientHash<T>` | `(value: T): Field` | Transient | No |
| `persistentCommit<T>` | `(value: T, rand: Bytes<32>): Bytes<32>` | Persistent | Yes |
| `transientCommit<T>` | `(value: T, rand: Field): Field` | Transient | No |
| `degradeToTransient` | `(x: Bytes<32>): Field` | Conversion | — |
| `upgradeFromTransient` | `(x: Field): Bytes<32>` | Conversion | — |

Add a verification tip:

> **Verification:** Use persistent variants when the result will be stored in ledger state or compared across transactions. Use transient variants for in-circuit intermediates. If mixing domains, use `degradeToTransient`/`upgradeFromTransient`. For deep documentation including disclosure rules and code examples, see `compact-language-ref/references/stdlib-functions.md`.

**Step 4: Commit**

```bash
git add plugins/compact-core/skills/compact-standard-library/SKILL.md
git commit -m "feat(compact-core): add types, constructors, and hashing sections to compact-standard-library"
```

---

### Task 5: Write SKILL.md — EC functions, Merkle path functions, and Utility functions summary sections

**Files:**
- Modify: `plugins/compact-core/skills/compact-standard-library/SKILL.md`

**Step 1: Add the Elliptic Curve Functions section**

Add `## Elliptic Curve Functions` with a summary table:

| Function | Signature | Purpose |
|----------|-----------|---------|
| `ecAdd` | `(a: NativePoint, b: NativePoint): NativePoint` | Add two curve points |
| `ecMul` | `(a: NativePoint, b: Field): NativePoint` | Scalar multiplication |
| `ecMulGenerator` | `(b: Field): NativePoint` | Multiply generator by scalar |
| `hashToCurve<T>` | `(value: T): NativePoint` | Map arbitrary value to curve point |
| `nativePointX` | `(p: NativePoint): Field` | Get X coordinate |
| `nativePointY` | `(p: NativePoint): Field` | Get Y coordinate |
| `constructNativePoint` | `(x: Field, y: Field): NativePoint` | Construct point from coordinates |

Add a brief use-case note: Pedersen commitments, key derivation building blocks, custom signature schemes.

Add a verification tip:

> **Verification:** EC functions operate on `NativePoint`, not the deprecated `CurvePoint`. The type was renamed in the camelCase migration. Always verify with `midnight-compile-contract` when using EC operations, as these are newer additions. See `references/cryptographic-functions.md` for full documentation and examples.

**Step 2: Add the Merkle Tree Path Functions section**

Add `## Merkle Tree Path Functions` with:

```compact
circuit merkleTreePathRoot<#n, T>(path: MerkleTreePath<n, T>): MerkleTreeDigest;
circuit merkleTreePathRootNoLeafHash<#n>(path: MerkleTreePath<n, Bytes<32>>): MerkleTreeDigest;
```

Brief explanation: These verify Merkle tree membership off-chain by recomputing the root from a leaf + path, then comparing with `tree.checkRoot(digest)`. The `NoLeafHash` variant is for when the leaf is already hashed to `Bytes<32>`.

Point to `references/cryptographic-functions.md` for full documentation with off-chain path generation patterns.

**Step 3: Add the Utility Functions section**

Add `## Utility Functions` with a compact summary:

| Function | Signature | Purpose |
|----------|-----------|---------|
| `pad` | `pad(length, value): Bytes<N>` | UTF-8 string to fixed-size bytes (both args must be literals) |
| `disclose` | `disclose(value: T): T` | Mark witness-derived value as publicly visible |
| `assert` | `assert(condition: Boolean, message?: string): []` | Abort transaction if false |
| `default<T>` | `default<T>(): T` | Default value for any type |

> For deep documentation with disclosure rules, assertion patterns, and default value tables, see `compact-language-ref/references/stdlib-functions.md`.

**Step 4: Commit**

```bash
git add plugins/compact-core/skills/compact-standard-library/SKILL.md
git commit -m "feat(compact-core): add EC, Merkle path, and utility sections to compact-standard-library"
```

---

### Task 6: Write SKILL.md — Coin management, Ledger ADTs, Common mistakes, and Reference routing sections

**Files:**
- Modify: `plugins/compact-core/skills/compact-standard-library/SKILL.md`

**Step 1: Add the Coin Management Functions section**

Add `## Coin Management Functions` with a compact summary table of all shielded and unshielded token functions (mint, send, receive, merge, balance queries, token type, etc.). Keep it to names and one-line descriptions — no full signatures.

> For complete signatures, parameters, nonce management, and merge strategies, see the `compact-tokens` skill.

**Step 2: Add the Ledger ADT Operations section**

Add `## Ledger ADT Operations` with a summary table:

| Type | Key Methods | Notes |
|------|------------|-------|
| `Counter` | `increment`, `decrement`, `read`, `lessThan` | Uint<16> step size |
| `Map<K, V>` | `insert`, `lookup`, `member`, `remove`, `size` | All ops visible on-chain |
| `Set<T>` | `insert`, `member`, `remove`, `size` | All ops visible on-chain |
| `List<T>` | `pushFront`, `popFront`, `head`, `length` | Ordered sequence |
| `MerkleTree<N, T>` | `insert`, `checkRoot`, `insertHash`, `isFull` | Insert hides leaf value |
| `HistoricMerkleTree<N, T>` | Same + `resetHistory` | Accepts proofs against past roots |

> For complete ADT operation tables, nested composition, and state design patterns, see the `compact-ledger` skill.

**Step 3: Add the Common Mistakes & Non-Existent Functions section**

Add `## Common Mistakes & Non-Existent Functions` with a wrong/correct/why table including:
- Functions that don't exist (already listed in verification protocol, but include here as a reference table)
- Common misuse patterns (wrong parameter types, missing generics, wrong return type assumptions)
- Deprecated names (CurvePoint → NativePoint, CoinInfo → ShieldedCoinInfo, etc.)

**Step 4: Add the Reference Routing section**

Add `## Reference Routing` with two tables:

**This skill's references:**

| Topic | Reference File |
|-------|---------------|
| Stdlib types (Maybe, Either, NativePoint, MerkleTree types, address types), constructors (some, none, left, right), re-exports | `references/types-and-constructors.md` |
| Elliptic curve functions, Merkle tree path functions, hashing/commitment summary | `references/cryptographic-functions.md` |
| Alphabetical index of every stdlib export with authoritative documentation location | `references/cross-reference-index.md` |

**Cross-references to other skills:**

| Topic | Skill |
|-------|-------|
| Hashing, commitments, pad, disclose, assert, default (deep docs) | `compact-language-ref` |
| Ledger ADT operations, state design, privacy | `compact-ledger` |
| Token types, functions, operations, patterns | `compact-tokens` |
| Contract anatomy, pragma, circuits, witnesses | `compact-structure` |

**Step 5: Commit**

```bash
git add plugins/compact-core/skills/compact-standard-library/SKILL.md
git commit -m "feat(compact-core): add coin management, ADTs, mistakes, and routing to compact-standard-library"
```

---

### Task 7: Write references/types-and-constructors.md

**Files:**
- Create: `plugins/compact-core/skills/compact-standard-library/references/types-and-constructors.md`

**Step 1: Write the complete types and constructors reference**

Create `references/types-and-constructors.md` with the following sections. For each type, verify the exact struct definition against the MCP. Use `midnight-search-docs` with the type name to find the official documentation, and `midnight-search-compact` with the type name to find usage examples.

**Sections to write:**

1. **Stdlib Types Overview** — Introductory paragraph + table listing all types with kind and purpose.

2. **Maybe<T>** — Full documentation:
   - Definition: `struct Maybe<T> { is_some: Boolean; value: T; }`
   - Construction: `some<T>(value)` and `none<T>()`
   - Default: `default<Maybe<T>>` is `none<T>()`
   - Field access: `.is_some`, `.value`
   - Inspection pattern with if/else
   - Common use: return type of `Map.lookup()`, optional witness data
   - TypeScript representation: `{ is_some: boolean, value: T }`
   - Code example:
   ```compact
   const result = myMap.lookup(key);
   if (result.is_some) {
     balance = (balance + result.value) as Uint<64>;
   }
   ```

3. **Either<L, R>** — Full documentation:
   - Definition: `struct Either<L, R> { is_left: Boolean; left: L; right: R; }`
   - Construction: `left<A, B>(value)` and `right<A, B>(value)`
   - Default: `default<Either<L, R>>` is `left` with default values
   - Field access: `.is_left`, `.left`, `.right`
   - Common use: token recipient addressing (`Either<ZswapCoinPublicKey, ContractAddress>` for shielded, `Either<ContractAddress, UserAddress>` for unshielded)
   - Code example:
   ```compact
   const toUser = left<ZswapCoinPublicKey, ContractAddress>(ownPublicKey());
   const toContract = right<ZswapCoinPublicKey, ContractAddress>(kernel.self());
   ```

4. **NativePoint** — Full documentation:
   - Definition: struct with `.x: Field` and `.y: Field` (elliptic curve point on embedded curve)
   - Accessor functions: `nativePointX(p)`, `nativePointY(p)` (preferred over direct `.x`/`.y` access)
   - Constructor: `constructNativePoint(x: Field, y: Field)`
   - Default: `default<NativePoint>` is the identity element
   - Note: Was previously `CurvePoint` in older versions. `CurvePoint` is deprecated.
   - TypeScript representation: `{ x: bigint, y: bigint }`
   - Code example:
   ```compact
   const g = ecMulGenerator(1);          // generator point
   const pk = ecMul(g, secretKey);        // public key derivation
   const combined = ecAdd(pk, hashToCurve<Bytes<32>>(data));
   const x = nativePointX(combined);      // get X coordinate
   ```

5. **MerkleTreeDigest** — Documentation:
   - Definition: `struct MerkleTreeDigest { field: Field; }`
   - A wrapper around a `Field` value representing the root hash of a Merkle tree
   - Used as the return type of `merkleTreePathRoot` and `merkleTreePathRootNoLeafHash`
   - Used as the parameter type of `MerkleTree.checkRoot()` and `HistoricMerkleTree.checkRoot()`
   - Default: `default<MerkleTreeDigest>` is `{ field: 0 }`

6. **MerkleTreePathEntry** — Documentation:
   - Definition: `struct MerkleTreePathEntry { sibling: MerkleTreeDigest; goesLeft: Boolean; }`
   - Represents one step in a Merkle proof path: the sibling hash and direction
   - Used as elements in `MerkleTreePath`

7. **MerkleTreePath<N, T>** — Documentation:
   - Definition: `struct MerkleTreePath<#n, T> { leaf: T; path: Vector<n, MerkleTreePathEntry>; }`
   - A complete Merkle proof: the leaf value and the path of sibling hashes from leaf to root
   - `N` is the tree depth (must match the MerkleTree depth)
   - Constructed off-chain using the compiler output's `findPathForLeaf` and `pathForLeaf` TypeScript functions
   - Passed to `merkleTreePathRoot<N, T>(path)` to recompute the root

8. **Address Types** — Documentation for all three:
   - `ContractAddress`: `struct ContractAddress { bytes: Bytes<32>; }` — obtained via `kernel.self()`
   - `ZswapCoinPublicKey`: `struct ZswapCoinPublicKey { bytes: Bytes<32>; }` — obtained via `ownPublicKey()`
   - `UserAddress`: `struct UserAddress { bytes: Bytes<32>; }` — user wallet address for unshielded tokens

9. **Constructor Functions** — Full signatures and patterns for `some`, `none`, `left`, `right`:
   - `circuit some<T>(value: T): Maybe<T>;`
   - `circuit none<T>(): Maybe<T>;`
   - `circuit left<A, B>(value: A): Either<A, B>;`
   - `circuit right<A, B>(value: B): Either<A, B>;`
   - Note: Type parameters are required — `some(42)` is wrong, `some<Field>(42)` is correct
   - Patterns: checking variants, nested Maybe/Either, using with Map.lookup

10. **Re-Exporting Stdlib Types** — Pattern documentation:
    ```compact
    export { Maybe, Either, ShieldedCoinInfo, QualifiedShieldedCoinInfo };
    ```
    Explains why re-exporting is needed (makes types available in TypeScript-generated code).

**Step 2: Commit**

```bash
git add plugins/compact-core/skills/compact-standard-library/references/types-and-constructors.md
git commit -m "feat(compact-core): add types-and-constructors reference for compact-standard-library"
```

---

### Task 8: Write references/cryptographic-functions.md

**Files:**
- Create: `plugins/compact-core/skills/compact-standard-library/references/cryptographic-functions.md`

**Step 1: Write the cryptographic functions reference**

Create `references/cryptographic-functions.md` with the following sections. For each function, verify the exact signature against the MCP. Use `midnight-search-docs` with the function name for official documentation, and `midnight-search-compact` for usage examples.

**Sections to write:**

1. **Elliptic Curve Functions** — Introductory paragraph explaining that these operate on the proof system's embedded elliptic curve. All inputs and outputs use `NativePoint`.

2. **ecAdd** — Full documentation:
   ```compact
   circuit ecAdd(a: NativePoint, b: NativePoint): NativePoint;
   ```
   - Adds two elliptic curve points (in multiplicative notation)
   - Used for combining Pedersen commitment components, aggregating public keys
   - Code example:
   ```compact
   const blindingCommit = ecMulGenerator(randomness);
   const valueCommit = ecMul(hashToCurve<Bytes<32>>(color), value as Field);
   const pedersenCommit = ecAdd(blindingCommit, valueCommit);
   ```

3. **ecMul** — Full documentation:
   ```compact
   circuit ecMul(a: NativePoint, b: Field): NativePoint;
   ```
   - Multiplies a curve point by a scalar (in multiplicative notation)
   - Note: The point is the first argument, scalar is second (unlike some EC libraries)
   - Used for Pedersen commitments, key derivation

4. **ecMulGenerator** — Full documentation:
   ```compact
   circuit ecMulGenerator(b: Field): NativePoint;
   ```
   - Multiplies the primary group generator of the embedded curve by a scalar
   - Equivalent to `ecMul(G, b)` where G is the generator, but more efficient
   - Used for blinding factors in Pedersen commitments, public key generation

5. **hashToCurve** — Full documentation:
   ```compact
   circuit hashToCurve<T>(value: T): NativePoint;
   ```
   - Maps an arbitrary Compact value to a curve point with unknown discrete logarithm
   - Output is guaranteed to have unknown DL with respect to the generator and any other output
   - Not guaranteed to be unique (same output may be valid for multiple inputs)
   - Used for deriving independent generators in Pedersen commitments (one per token color/segment)

6. **NativePoint Accessors** — Documentation for helper functions:
   ```compact
   circuit nativePointX(p: NativePoint): Field;
   circuit nativePointY(p: NativePoint): Field;
   circuit constructNativePoint(x: Field, y: Field): NativePoint;
   ```
   - `nativePointX`/`nativePointY`: Extract coordinates. Preferred over direct `.x`/`.y` field access (which may become unavailable if NativePoint becomes opaque).
   - `constructNativePoint`: Construct from coordinates. Use with caution — the point is not validated to be on the curve.
   - Verification note: These appear in test examples. If not in the official exports.md, note their status.

7. **Practical Patterns: Pedersen Commitments** — Worked example:
   ```compact
   // Pedersen commitment: C = g^r * h^v
   // where g = generator, h = hashToCurve(color), r = randomness, v = value
   witness get_randomness(): Field;

   circuit pedersenCommit(color: Bytes<32>, value: Field): NativePoint {
     const r = get_randomness();
     const blinding = ecMulGenerator(r);
     const colorBase = hashToCurve<Bytes<32>>(color);
     const valueCommit = ecMul(colorBase, value);
     return ecAdd(blinding, valueCommit);
   }
   ```

8. **Merkle Tree Path Functions** — Header and intro: These functions verify Merkle tree membership by recomputing the tree root from a leaf and its path, then comparing with the on-chain root via `checkRoot()`.

9. **merkleTreePathRoot** — Full documentation:
   ```compact
   circuit merkleTreePathRoot<#n, T>(path: MerkleTreePath<n, T>): MerkleTreeDigest;
   ```
   - Computes the Merkle tree root from a complete path (leaf + sibling hashes)
   - `n` is the tree depth; `T` is the leaf type (must match the MerkleTree declaration)
   - The path is constructed off-chain and passed in via a witness
   - Returns a `MerkleTreeDigest` that can be compared with `tree.checkRoot(digest)`
   - Code example:
   ```compact
   witness get_proof(leafValue: Field): MerkleTreePath<4, Field>;

   export circuit verifyMembership(leafValue: Field): [] {
     const path = get_proof(leafValue);
     const digest = merkleTreePathRoot<4, Field>(path);
     assert(merkleTree.checkRoot(digest), "Not a member");
   }
   ```

10. **merkleTreePathRootNoLeafHash** — Full documentation:
    ```compact
    circuit merkleTreePathRootNoLeafHash<#n>(path: MerkleTreePath<n, Bytes<32>>): MerkleTreeDigest;
    ```
    - Same as `merkleTreePathRoot` but assumes the leaf has already been hashed externally
    - The leaf field in the path must be `Bytes<32>` (the pre-computed hash)
    - Useful when the leaf hash was computed outside the circuit or when working with `insertHash`
    - Real-world example from the dust/zswap system:
    ```compact
    commitment_merkle_tree.checkRoot(
      disclose(merkleTreePathRootNoLeafHash<32>(commitment_path))
    );
    ```

11. **Off-Chain Path Generation** — Brief note on TypeScript integration:
    - Use `findPathForLeaf(index)` from the compiled contract's runtime to get a path
    - Use `pathForLeaf(index, leaf)` for paths with explicit leaf values
    - These return `MerkleTreePath` objects that can be passed to witness functions

12. **Hashing & Commitment Summary** — Compact reference table with signatures linking to `compact-language-ref/references/stdlib-functions.md` for deep documentation. Include the persistent vs transient comparison table.

**Step 2: Commit**

```bash
git add plugins/compact-core/skills/compact-standard-library/references/cryptographic-functions.md
git commit -m "feat(compact-core): add cryptographic-functions reference for compact-standard-library"
```

---

### Task 9: Write references/cross-reference-index.md

**Files:**
- Create: `plugins/compact-core/skills/compact-standard-library/references/cross-reference-index.md`

**Step 1: Write the cross-reference index**

Create `references/cross-reference-index.md` with an alphabetical table of every stdlib export. Columns: Name, Kind, Description (one line), Authoritative Location (skill name + file path).

This is a "phone book" — when an agent encounters an unfamiliar stdlib name, they look it up here. Every single export from CompactStandardLibrary must appear in this index. Include types, circuits, and ledger ADTs.

Sort alphabetically by name. Use the full list from the export inventory (Task 3) as the source. For each entry, the authoritative location should be the most detailed reference:

- Types documented in this skill → `compact-standard-library/references/types-and-constructors.md`
- EC/Merkle functions documented in this skill → `compact-standard-library/references/cryptographic-functions.md`
- Hash/commit/utility functions → `compact-language-ref/references/stdlib-functions.md`
- Token functions/types → `compact-tokens/references/token-operations.md`
- Ledger ADTs → `compact-ledger/references/types-and-operations.md`

**Step 2: Commit**

```bash
git add plugins/compact-core/skills/compact-standard-library/references/cross-reference-index.md
git commit -m "feat(compact-core): add cross-reference-index for compact-standard-library"
```

---

### Task 10: Update plugin manifest

**Files:**
- Modify: `plugins/compact-core/.claude-plugin/plugin.json`

**Step 1: Add standard library keywords**

Add these keywords to the existing keywords array in `plugin.json`:
- `"standard-library"`
- `"stdlib"`
- `"elliptic-curve"`
- `"merkle-tree"`
- `"cryptographic"`

The updated keywords array should be:
```json
"keywords": [
  "midnight",
  "compact",
  "smart-contracts",
  "zero-knowledge",
  "ledger",
  "circuits",
  "witnesses",
  "zk-proofs",
  "tokens",
  "shielded",
  "unshielded",
  "zswap",
  "standard-library",
  "stdlib",
  "elliptic-curve",
  "merkle-tree",
  "cryptographic"
]
```

**Step 2: Commit**

```bash
git add plugins/compact-core/.claude-plugin/plugin.json
git commit -m "feat(compact-core): add standard library keywords to plugin manifest"
```

---

### Task 11: Final review and verification

**Step 1: Review all files for consistency**

Read through all created files and verify:
- Every function mentioned in SKILL.md's export inventory exists in one of the reference files or cross-references to an existing skill
- Every entry in the cross-reference index points to a real file
- All function signatures match the MCP-verified sources
- No hallucinated functions are documented as real
- Verification tips are present throughout SKILL.md
- Cross-references between skills use correct relative paths

**Step 2: Verify against MCP**

Use `midnight-search-compact` and `midnight-search-docs` to spot-check at least 5 function signatures from the reference files against the source.

**Step 3: Fix any issues found**

If any discrepancies are found, fix them in the relevant files.

**Step 4: Final commit if changes were made**

```bash
git add -A plugins/compact-core/
git commit -m "fix(compact-core): address review findings in compact-standard-library"
```
