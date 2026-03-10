# Fact-Check Findings: privacy-patterns skill

**Date:** 2026-03-10
**Claims verified:** 51
**Valid:** 30 | Ambiguous: 6 | Partially Valid: 5 | Invalid: 5 | Undetermined: 5

## Critical Issues (Invalid)

### 1. `.value` field does not exist on `MerkleTreePath`
- **File**: privacy-and-visibility.md, line 124
- **Claimed:** `merkleTreePathRoot<10, Bytes<32>>(path.value)`
- **Correct:** `MerkleTreePath<n, T>` has fields `leaf: T` and `path: Vector<n, MerkleTreePathEntry>`. No `.value` field. Pass the whole struct: `merkleTreePathRoot<10, Bytes<32>>(path)`. Result must be wrapped in `disclose()` before `checkRoot()`.

### 2. `>=`/`<=` operators applied to `Field` type (three locations)
- **File**: privacy-patterns.md, lines 430, 449, 467
- **Claimed:** `verifyThreshold`, `verifyRange`, `proveAgeAbove` circuits use `>=`/`<=` on `Field` values
- **Correct:** Comparison operators only work on `Uint<N>`. Change witnesses to return `Uint<64>` instead of `Field`.

### 3. `data > 0` on `Field` type
- **File**: privacy-and-visibility.md, line 181
- **Claimed:** `assert(disclose(data > 0), ...)` where `data` from `witness getData(): Field;`
- **Correct:** Same as #2. Change to `Uint<64>`.

### 4. Direct `Uint<64> as Bytes<32>` cast is invalid
- **File**: privacy-patterns.md, lines 113-114
- **Claimed:** `round as Bytes<32>` in `deriveNullifier`
- **Correct:** Must use two-step cast: `(round as Field) as Bytes<32>`.

### 5. All code examples missing `pragma` and `import` headers
- **File**: Both files, all code examples
- **Correct:** Every Compact file needs `pragma language_version >= 0.16 && <= 0.18;` and `import CompactStandardLibrary;`.

## Partially Valid

### 1. `persistentHash<T>` generic signature
- File correctly shows generic `T`. But should note it accepts any serializable type, countering official conceptual docs that misleadingly say "limited to Bytes<32>".

### 2. `transientCommit` "not ledger-safe" wording
- Correct in spirit, but "not ledger-safe" could be misread. Should say: "algorithm may change between compiler versions, so outputs must not be stored in ledger state."

### 3. `persistentHash` "witness taint preserved" column header
- Column header "Hides Input from Disclosure" conflates cryptographic hiding with taint tracking. Should be "Clears Witness Taint (skips `disclose()` requirement)".

### 4. Zerocash domain separator naming
- `derive_nullifier` uses domain `"lares:zerocash:commit"` — confusing but intentional. Needs explanatory comment.

### 5. `disclose()` usage inconsistency
- Sometimes wraps comparisons in `disclose()`, sometimes not. Both correct (depends on whether values are witness-derived or public ledger), but needs comments explaining the distinction.

## Ambiguous

1. SHA-256 for persistent vs MCP tool saying Poseidon — authoritative stdlib says SHA-256, MCP is wrong
2. `path` variable name shadows `MerkleTreePath.path` field — rename suggested
3. "Map and Set arguments are public" — true but omits MerkleTree exception
4. "Each round produces distinct nullifier" — correct only if round is on-chain state
5. Anti-pattern "Using Set for private membership" — overstated; only an issue with private identities
6. Comment "commitment clears witness taint" — ambiguous about which call clears it

## Verified Claims

1. `persistentCommit<T>(value: T, rand: Bytes<32>): Bytes<32>` correct
2. `persistentHash<T>(value: T): Bytes<32>` correct
3. `Set.member(value)`, `Set.insert(value)`, `Map.member(key)`, `Map.lookup(key)`, `Map.insert(key, value)` all correct
4. `MerkleTree.insert(value)` correct; hides leaf on-chain
5. `HistoricMerkleTree.checkRoot(digest)` correct
6. `merkleTreePathRoot<N, T>(path)` correct signature
7. `MerkleTreePath` and `MerkleTreePathEntry` struct fields correct
8. `disclose()` requirement correctly described
9. `persistentHash` uses SHA-256 per authoritative stdlib
10. Nullifiers in `Set<Bytes<32>>` correct pattern
11. Domain separation prevents cross-contract correlation
12. Enum dot-notation `Phase.commit` correct
13. `Counter.read()` returns `Uint<64>` correct
14. `export enum` and `export sealed ledger` syntax correct
15. Merkle membership proof four-step flow correct
16. TypeScript `findPathForLeaf`/`pathForLeaf` APIs correct

## Cross-Cutting Issues (from previous skills)

These issues from data-models, architecture, and zero-knowledge findings also apply:
- Deprecated `ledger { }` block syntax → use individual `export ledger`
- `Void` return type → use `[]`
- `export witness name(...) { body }` → declaration-only witnesses
- `.member(value, path)` for MerkleTree → use `merkleTreePathRoot()` + `checkRoot()`
