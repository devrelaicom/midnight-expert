# DUST Beta API

The indexer schema marks a subset of its DUST-generation surface with `@beta` — an explicit contract that these fields are **in-flight and may change without notice**. Consumers should treat them as preview, not as part of the stable surface.

## The `@beta` directive

```text
directive @beta on FIELD_DEFINITION | OBJECT
```

`schema-v4.graphql:1496` — the doc-string explains the intent:

> Marks a schema field or type as in-flight / unstable. Consumers should expect the marked surface to change without notice; stability is signalled by removal of the directive. Currently used for the dust-generation API surface that's in mid-redesign pending #1181. See #1173.

The directive is legal on `FIELD_DEFINITION` and `OBJECT`. It carries no runtime semantics — it is a signal to tooling and consumers only.

## Complete `@beta` inventory

All 17 usages, in line order:

| # | Location / parent | Signature | Line |
|---|-------------------|-----------|------|
| 1 | `type Block` | `dustCommitmentEndIndex: Int! @beta` | 40 |
| 2 | `type Block` | `dustGenerationEndIndex: Int! @beta` | 44 |
| 3 | `type DustGenerationDtimeUpdateItem` *(object-level)* | `type DustGenerationDtimeUpdateItem @beta { … }` | 320 |
| 4 | `type DustGenerationsItem` *(object-level)* | `type DustGenerationsItem @beta { … }` | 417 |
| 5 | `type DustGenerationsProgress` *(object-level)* | `type DustGenerationsProgress @beta { … }` | 463 |
| 6 | `type DustNullifierTransaction` | `nullifierLeBytes: HexEncoded! @beta` | 514 |
| 7 | `type DustNullifierTransaction` | `commitmentLeBytes: HexEncoded! @beta` | 518 |
| 8 | `type DustNullifierTransaction` | `transaction: Transaction! @beta` | 538 |
| 9 | `type Query` | `dustCommitmentMerkleTreeUpdate(startIndex: Int!, endIndex: Int!): MerkleTreeCollapsedUpdate! @beta` | 744 |
| 10 | `type Query` | `dustGenerationMerkleTreeUpdate(startIndex: Int!, endIndex: Int!): MerkleTreeCollapsedUpdate! @beta` | 748 |
| 11 | `type RegularTransaction` | `dustCommitmentStartIndex: Int! @beta` | 915 |
| 12 | `type RegularTransaction` | `dustCommitmentEndIndex: Int! @beta` | 919 |
| 13 | `type RegularTransaction` | `dustGenerationStartIndex: Int! @beta` | 923 |
| 14 | `type RegularTransaction` | `dustGenerationEndIndex: Int! @beta` | 927 |
| 15 | `type ShieldedNullifierTransaction` | `transaction: Transaction! @beta` | 1025 |
| 16 | `type Subscription` | `dustGenerations(dustAddress: DustAddress!, startIndex: Int!, endIndex: Int!): DustGenerationsEvent! @beta` | 1185 |
| 17 | `directive @beta …` *(directive definition itself)* | `directive @beta on FIELD_DEFINITION \| OBJECT` | 1496 |

---

## The `DustGenerationsEvent` union

`schema-v4.graphql:412`:

```text
union DustGenerationsEvent =
    DustGenerationsItem
  | DustGenerationsProgress
  | DustGenerationDtimeUpdateItem
```

All three member types are themselves `@beta` objects. Each serves a distinct role in the streaming wallet-sync protocol:

| Variant | `@beta` line | Role |
|---------|-------------|------|
| `DustGenerationsItem` | 417 | One confirmed DUST generation entry — the main data payload, carries commitment-tree and generation-tree indices, backing NIGHT UTXO, value, optional `MerkleTreeCollapsedUpdate` filling the gap before this entry |
| `DustGenerationsProgress` | 463 | Progress heartbeat — the highest index processed so far plus an optional final collapsed update covering the trailing range |
| `DustGenerationDtimeUpdateItem` | 320 | Dtime (decay-time) update — emitted when the backing Night UTXO is spent and the generation entry's decay time is set; carries the new `dtime` value and a `treeInsertionPath` for local tree maintenance |

### `DustGenerationsItem` fields (`schema-v4.graphql:417–458`)

| Field | Type | Description |
|-------|------|-------------|
| `commitmentMtIndex` | `Int!` | Index in the **dust commitment** Merkle tree |
| `generationMtIndex` | `Int!` | Index in the **dust generation** Merkle tree |
| `owner` | `HexEncoded!` | Hex-encoded dust address |
| `value` | `String!` | Backing NIGHT value in STAR |
| `initialValue` | `String!` | Initial DUST value at creation in SPECK |
| `backingNight` | `HexEncoded!` | Hash of the NIGHT UTXO that backs this output |
| `ctime` | `Int!` | Creation timestamp |
| `transactionId` | `Int!` | Indexer-internal BIGSERIAL (resumption cursor) |
| `transactionHash` | `HexEncoded!` | 32-byte chain transaction hash |
| `collapsedMerkleTree` | `MerkleTreeCollapsedUpdate` | Optional collapsed update bridging the gap before this entry |

### `DustGenerationsProgress` fields (`schema-v4.graphql:463–472`)

| Field | Type | Description |
|-------|------|-------------|
| `highestIndex` | `Int!` | Highest generation-tree index processed so far |
| `collapsedMerkleTree` | `MerkleTreeCollapsedUpdate` | Optional final collapsed update covering the remaining range |

### `DustGenerationDtimeUpdateItem` fields (`schema-v4.graphql:320–351`)

| Field | Type | Description |
|-------|------|-------------|
| `generationMtIndex` | `Int!` | Generation-tree index of the updated entry |
| `owner` | `HexEncoded!` | Hex-encoded dust address |
| `nightUtxoHash` | `HexEncoded!` | Hash of the spent Night UTXO |
| `newDtime` | `Int!` | Updated decay time |
| `transactionId` | `Int!` | Indexer-internal BIGSERIAL |
| `transactionHash` | `HexEncoded!` | 32-byte chain transaction hash |
| `treeInsertionPath` | `HexEncoded!` | Tagged-serialized `TreeInsertionPath<DustGenerationInfo>` — pass to `generating_tree.update_from_evidence(…)` |

---

## Merkle tree index model

The DUST API exposes two parallel Merkle trees: the **commitment tree** and the **generation tree**. Both are indexed from 0. End indices are surfaced in two places with different semantics:

### On `Block` (`schema-v4.graphql:38–44`)

```text
Block.dustCommitmentEndIndex: Int! @beta   # line 40
Block.dustGenerationEndIndex: Int! @beta   # line 44
```

The doc-strings read: *"exclusive, i.e. the next free index."*

A block with `dustGenerationEndIndex = 100` has covered generation-tree indices 0–99.

### On `RegularTransaction` (`schema-v4.graphql:913–927`)

```text
RegularTransaction.dustCommitmentStartIndex: Int! @beta   # line 915
RegularTransaction.dustCommitmentEndIndex:   Int! @beta   # line 919
RegularTransaction.dustGenerationStartIndex: Int! @beta   # line 923
RegularTransaction.dustGenerationEndIndex:   Int! @beta   # line 927
```

The start/end pair brackets the slice of commitment or generation tree entries produced by that transaction. End is exclusive (next free index), consistent with `Block`.

### On the `dustGenerations` subscription (`schema-v4.graphql:1181–1185`)

```text
dustGenerations(
  dustAddress: DustAddress!,
  startIndex: Int!,
  endIndex: Int!
): DustGenerationsEvent! @beta
```

The subscription doc-string states the range is **inclusive** — `[startIndex, endIndex]`. To replay all generation entries for a block, translate the exclusive `Block.dustGenerationEndIndex`:

```text
endIndex argument = Block.dustGenerationEndIndex - 1
```

This off-by-one is the most common error when driving the subscription from block data.

### `MerkleTreeCollapsedUpdate` (non-`@beta`, returned by `@beta` callers)

```text
type MerkleTreeCollapsedUpdate {   # schema-v4.graphql:644
  startIndex: Int!
  endIndex:   Int!
  update:     HexEncoded!
  protocolVersion: Int!
}
```

Returned by both `@beta` query fields and inline in `DustGenerationsItem` / `DustGenerationsProgress`. The `update` value is a hex-encoded collapsed Merkle proof that allows a wallet to fast-forward its local tree state across a range of indices it has already seen or does not need individually.

---

## `@beta` query fields

Two query-root fields let clients fetch collapsed Merkle proofs for arbitrary index ranges on demand (`schema-v4.graphql:742–748`):

| Field | Signature | Line |
|-------|-----------|------|
| `dustCommitmentMerkleTreeUpdate` | `(startIndex: Int!, endIndex: Int!): MerkleTreeCollapsedUpdate! @beta` | 744 |
| `dustGenerationMerkleTreeUpdate` | `(startIndex: Int!, endIndex: Int!): MerkleTreeCollapsedUpdate! @beta` | 748 |

These mirror `zswapMerkleTreeCollapsedUpdate` (stable, line 723) but target the DUST trees. Range conventions match the non-`@beta` zswap peer — confirm with indexer docs before assuming inclusive or exclusive semantics on the query variant.

---

## `@beta` fields on nullifier-match types

Two nullifier-transaction types expose `@beta` fields that were not present in earlier schema versions:

### `DustNullifierTransaction` (`schema-v4.graphql:510–539`)

| Field | Type | Line |
|-------|------|------|
| `nullifierLeBytes` | `HexEncoded! @beta` | 514 |
| `commitmentLeBytes` | `HexEncoded! @beta` | 518 |
| `transaction` | `Transaction! @beta` | 538 |

`nullifierLeBytes` and `commitmentLeBytes` expose the raw 32-byte little-endian form of the nullifier and commitment respectively — the same bytes the wallet matched against via `dustNullifierTransactions`. The `transaction` field backlinks to the full `Transaction` interface, which itself is not `@beta`; the `@beta` here means the *field on this type* is preview.

### `ShieldedNullifierTransaction` (`schema-v4.graphql:998–1026`)

| Field | Type | Line |
|-------|------|------|
| `transaction` | `Transaction! @beta` | 1025 |

The `transaction` back-link on the shielded peer type is also `@beta` (`schema-v4.graphql:1025`). This may reflect that providing a full `Transaction` navigation from a nullifier-match event was added later and may be refactored alongside the DUST redesign.

---

## How to use / caveats

- **Treat all `@beta` fields as preview.** Removal of the `@beta` directive is the stability signal; track issues #1173 and #1181 in the indexer repo for redesign progress.
- **Index arithmetic matters.** `Block.dustGenerationEndIndex` is exclusive; the `dustGenerations` subscription `endIndex` argument is inclusive. Always subtract 1 when driving the subscription from a block.
- **`DustGenerationsItem.collapsedMerkleTree` is nullable.** Not every item has a gap before it; null-check before passing to the wallet tree-update API.
- **`DustGenerationsProgress` signals completion.** When the server has exhausted the requested range it emits a final `DustGenerationsProgress` with any trailing collapsed update. Wallets should treat this as end-of-stream.
- **`DustGenerationDtimeUpdateItem.treeInsertionPath`** is a tagged binary blob opaque to GraphQL clients — deserialize with `generating_tree.update_from_evidence(…)` from the wallet SDK.
- **The `@beta` fields on `DustNullifierTransaction`** (`nullifierLeBytes`, `commitmentLeBytes`, `transaction`) are new additions; existing clients that only use `transactionId`/`transactionHash`/`blockHeight`/`blockHash` are unaffected by their eventual removal or rename.
- For the underlying storage model (how the commitment and generation trees are persisted, nullifier table structure, and DUST/Night relationship), see `midnight-indexer:indexer-data-model` → `references/dust-and-spo-data.md`.

## Cross-references

- `references/graphql-types.md` — stable GraphQL type reference, including the `Block` and `Transaction` interface tables
- `references/pagination-and-offsets.md` — offset and cursor patterns used by sibling subscriptions
- `midnight-indexer:indexer-data-model` → `references/dust-and-spo-data.md` — storage-side detail on the DUST commitment and generation tables
- `core-concepts:tokenomics` — NIGHT/DUST token model, STAR/SPECK denomination, and the broader dual-token design
- `core-concepts:data-models` — UTXO vs. account model, nullifiers, coin commitments, and the Zswap commitment tree
