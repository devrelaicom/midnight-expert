<p align="center">
  <img src="assets/mascot.png" alt="midnight-status-codes mascot" width="200" />
</p>

# midnight-status-codes

Catalog and lookup for all Midnight ecosystem error codes, status codes,
and error types across the node, ledger, indexer, wallet, SDK, compiler,
compact runtime, proof server, and DApp connector. Use it when you hit a bare numeric
code, a tagged Effect error, a compiler diagnostic, or an HTTP status
from a Midnight service and need to know what produced it and how to
fix it — without grepping nine repos by hand.

## Skills

### midnight-status-codes:status-codes

Decision-tree router for identifying Midnight errors. Given an error
code, message, or type, it routes to the correct reference file based
on the error's source and shape. Covers numeric node error codes
(0-255), TypeScript SDK error classes, Effect tagged wallet errors,
Compact compiler diagnostics, Compact runtime `CompactError` throws,
ZK proof errors, ledger validation errors, proof server HTTP errors,
indexer GraphQL errors, and DApp Connector API errors.

#### References

| Name | Description |
|------|-------------|
| [node-errors.md](skills/status-codes/references/node-errors.md) | `LedgerApiError` codes surfaced via `InvalidTransaction::Custom(u8)` |
| [sdk-errors.md](skills/status-codes/references/sdk-errors.md) | `@midnight-ntwrk/midnight-js-*` and `compact-js` error classes and Effect typed errors |
| [wallet-errors.md](skills/status-codes/references/wallet-errors.md) | Effect `Data.TaggedError` instances from the wallet SDK (`Wallet.*` tags) |
| [compiler-errors.md](skills/status-codes/references/compiler-errors.md) | Compact compiler diagnostics, exit codes, and source-located messages |
| [zk-errors.md](skills/status-codes/references/zk-errors.md) | PLONK, ZKIR, constraint system, and proof verification errors |
| [ledger-errors.md](skills/status-codes/references/ledger-errors.md) | Rust-level transaction validation and malformed-transaction errors |
| [runtime-errors.md](skills/status-codes/references/runtime-errors.md) | `@midnight-ntwrk/compact-runtime` `CompactError` subclasses and assertion / type-error throws at contract execution time |
| [proof-server-errors.md](skills/status-codes/references/proof-server-errors.md) | HTTP status codes and job queue errors from the proof server (port 6300) |
| [indexer-errors.md](skills/status-codes/references/indexer-errors.md) | GraphQL and HTTP errors from the Midnight indexer (port 8088) |
| [dapp-connector-errors.md](skills/status-codes/references/dapp-connector-errors.md) | DApp Connector `APIError` codes (`Disconnected`, `Rejected`, etc.) |

### midnight-status-codes:status-codes-lookup

Fast script-based lookup over a single `codes.json` catalog spanning
every component above. Supports exact code/name/alias matching, regex
search, listing by source or category, and a sources index with entry
counts. Detailed matches include severity, ordered fix suggestions,
aliases, and cross-references; large result sets fall back to a compact
table. Requires `jq`.

## `codes.json` schema

Each entry in `codes.json` has the following fields:

| Field | Type | Required | Description |
|---|---|---|---|
| `code` | string | yes | The code, name, or identifier the user pastes (e.g. `"166"`, `"400/JobNotPending"`, `"ContractRuntimeError"`). |
| `name` | string | yes | Canonical name. |
| `source` | string | yes | One of `midnight-node`, `substrate`, `jsonrpc-2.0`, `partner-chains`, `compact-compiler`, `compact-runtime`, `compact-js-sdk`, `midnight-js`, `midnight-wallet`, `midnight-indexer`, `proof-server`, `dapp-connector`. |
| `category` | string | yes | Used by `--category` filter. |
| `group` | object | yes | `{ name, description }` shown in detailed match output. |
| `description` | string | yes | What the error means. |
| `fixes` | array of string | yes | Ordered remediation suggestions. |
| `aliases` | array of string | yes | Alternative names the lookup matches against. |
| `severity` | string | yes | `error` \| `warning` \| `info`. |
| `see_also` | array of string | yes | Related entry codes. |
| `verified_against` | object | yes | `{ source_repo, ref, anchor, anchor_modified, verified_at }`. May also carry optional `toolchain` and `package_version` fields documenting the exact build the entry was checked against. |
| `verified_against.extra_refs` | array of `{ source_repo, ref, anchor, anchor_modified }` | no | Additional upstream sources cross-referenced when an entry's behavior is co-determined by more than one repo (e.g. an indexer entry whose 400 paths come from `async-graphql-axum`). |
| `status` | string | no | `"active"` (default, may be omitted) or `"retired"`. A retired entry is one no current emitter produces but older deployed components may still surface; lookup continues to return it. |
| `superseded_by` | array of string | no | Code values that replaced a retired umbrella. Lookup output prints `Superseded by:` when present. |
| `class` | string \| null | no | For SDK/JS sources only: the JS class name (`"TaggedError:WalletError"`, `"Error"`, `"TypeError"`, or `null` for untagged throws). |
| `phase` | string | conditional | Required for `compact-compiler` entries. One of `lexer`, `parser`, `frontend`, `name-res`, `type-check`, `witness`, `purity`, `zkir`, `exit`, `runtime`, `external`. Validated by `check-schema.sh`. |
| `id` | string | no | Stable identifier slug. For `compact-compiler` entries the format is `compiler.<phase>.<slug>` and is validated for shape and uniqueness by `check-schema.sh`. |
| `reference_anchor` | string | no | `<plugin-relative-path>#<slug>` pointing at a heading in a reference markdown file (e.g. `skills/status-codes/references/runtime-errors.md#compacterror`). Lookup output stitches the section's body verbatim into the match. The slug must round-trip through `resolve-anchor.sh --slug`; use `bin/anchor-for-heading.sh` to compute it (the algorithm diverges from GitHub's slugger). |

## Command

### /midnight-status-codes:lookup

Wrapper command around the lookup script. Accepts either structured
flags (`--code`, `--search`, `--source`, `--sources`, `--category`) or
freeform natural language, which the command interprets and routes to
the right flag.

Two global flags work across every mode:

- `--json` — emit a JSON array of matched entries verbatim from
  `codes.json` instead of the human/agent-friendly `=== MATCH ===`
  format. Intended for downstream tooling.
- `--status active|retired|all` — filter by entry `.status`
  (default: `all`). Use `active` to suppress retired umbrella entries
  when working on new code paths. Entries without a `.status` field
  are treated as active.

## Example usage

Look up a specific numeric code from a node transaction rejection:

```
/midnight-status-codes:lookup 166
```

Find every error related to dust spending across all components:

```
/midnight-status-codes:lookup --search "dust.*spend"
```

List every error code emitted by the Compact compiler:

```
/midnight-status-codes:lookup --source compact-compiler
```

Or hand it freeform — the command will interpret and route:

```
/midnight-status-codes:lookup what does ContractRuntimeError mean
/midnight-status-codes:lookup all codes from the indexer
```

## Coverage

The catalog spans these sources (the values that appear in each entry's
`source` field in `codes.json`):

- `midnight-node` — numeric `LedgerApiError` codes (`InvalidTransaction::Custom(u8)`) and Rust-level transaction-validation errors
- `substrate` — upstream Substrate JSON-RPC envelopes (`AUTHOR`/`SYSTEM`/`CHAIN`/`STATE` 1xxx–8xxx) and DispatchError envelopes
- `jsonrpc-2.0` — JSON-RPC standard `-326XX` codes
- `partner-chains` — partner-chain bridge inherent and federated-authority errors surfaced through the node runtime
- `midnight-indexer` — GraphQL and HTTP errors
- `midnight-wallet` — Effect tagged wallet errors
- `compact-js-sdk` — `@midnight-ntwrk/compact-js` Effect errors
- `midnight-js` — `@midnight-ntwrk/midnight-js-*` error classes
- `compact-compiler` — Compact compiler diagnostics, exit codes, and ZK/PLONK/ZKIR proof errors surfaced at compile time
- `compact-runtime` — `@midnight-ntwrk/compact-runtime` `CompactError` subclasses and assertion / type-error throws raised when a contract executes
- `proof-server` — HTTP status and job queue errors (including proof-generation failures)
- `dapp-connector` — DApp Connector `APIError` codes

Note: the reference markdown files (`ledger-errors.md`, `zk-errors.md`,
etc.) are organised by topic for human readers and do not map 1:1 to
`source` enum values — for example, ledger validation errors are sourced
from `midnight-node`, and ZK proof errors are sourced from
`compact-compiler` or `proof-server` depending on where they surface.

## Authoring `reference_anchor` values

The slug algorithm in `resolve-anchor.sh` deliberately diverges from GitHub's
slugger (drops underscores, em-dashes, slashes; collapses runs of hyphens).
Compute slugs through the helper rather than guessing:

```
skills/status-codes-lookup/scripts/bin/anchor-for-heading.sh "Heading text"
# -> heading-text

skills/status-codes-lookup/scripts/bin/anchor-for-heading.sh \
  skills/status-codes/references/foo.md "Heading text"
# -> skills/status-codes/references/foo.md#heading-text
```

`check-schema.sh` round-trips every `reference_anchor` through the resolver and
fails CI if a slug doesn't reproduce from its target heading.

## Tests

Run all fast checks (schema, lookup, resolver, renderer) with the single entry
point:

```
bash skills/status-codes-lookup/scripts/tests/run.sh
```

Add `--with-coverage` to also run `tests/test-coverage.sh`, which clones the
upstream compiler (multi-MB).

## Provenance (`verified_against`)

Every entry in `codes.json` carries a `verified_against` block recording the
source repo, ref, anchor file, that anchor's last-modified date, and the
audit date this entry was last checked. Lookup output surfaces this as a
`Verified:` line so users know how fresh the data is. Reference markdown
files carry a matching banner block under their first heading. To re-verify
an entry, refetch the anchor and confirm the variant/code is still present
at the recorded path.

## Install

```
claude plugin install --scope user midnight-status-codes@midnight-expert
```

## Related plugins

| Need | Plugin / Skill |
|------|----------------|
| Debug a Compact contract error in context | `compact-core:debug-contract` |
| Diagnose Compact CLI / toolchain issues | `midnight-tooling:doctor`, `midnight-tooling:troubleshooting` |
| Wallet SDK reference | `midnight-wallet:wallet-sdk` |
| DApp Connector (Lace) integration | `midnight-dapp-dev:dapp-connector` |
