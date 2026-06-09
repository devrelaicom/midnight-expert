# Proof Server Binary Serialization

The proof server uses a custom **tagged** binary encoding from the `midnight-serialize` crate (`serialize = { path = "../serialize", package = "midnight-serialize" }` in `proof-server/Cargo.toml`). Endpoints call `tagged_serialize` / `tagged_deserialize` from that crate; the request and response bodies are raw binary, not JSON.

## Tagged-frame format

Each payload begins with a header tag (a UTF-8 string prefix embedded in the binary frame). If the body is empty or the tag does not match, `tagged_deserialize` returns a 400 error with a plain-text message:

```text
expected header tag '<tag>', got ''
```

…when the body is missing or empty, and:

```text
expected header tag '<tag>', got '<received>'
```

…when a body is present but has the wrong tag. The exact format string is in `serialize/src/deserializable.rs:109`.

## Per-endpoint wire shapes

| Endpoint | Request body | Response body |
|----------|-------------|---------------|
| `POST /prove` | `(ProofPreimageVersioned, Option<ProvingKeyMaterial>, Option<Fr>)` | `ProofVersioned` |
| `POST /prove-tx` *(deprecated)* | `(Transaction, HashMap<String, ProvingKeyMaterial>)` | `Transaction` (proofs filled in) |
| `POST /check` | `(ProofPreimageVersioned, Option<WrappedIr>)` | `Vec<Option<u64>>` |
| `POST /k` | `IrSource` (tagged ZKIR bytes) | `u8` (plain text) |

**`/check` response semantics:** the `Vec<Option<u64>>` values carry branch-omission and padding information from the circuit check, **not** a constraint pass/fail result. See `proof-server:proof-server-integration` → `proving-pipeline.md` for interpretation.

**`/prove-tx` deprecation:** this endpoint uses the initial (pre-final) cost model and lacks the `Option<Fr>` binding-input parameter. Use `/prove` for all new work.

**`/k` request:** the raw bytes are a tagged ZKIR IR frame. The v2 format (`zkir_v2::IrSource`, tag `ir-source[v2-generic]`) uses `load_from_tagged`; v3 uses `tagged_deserialize`. Both paths are handled transparently by the server via `versioned_ir::k` (`proof-server/src/versioned_ir.rs`).

## Versioning note

`ProofVersioned` and `ProofPreimageVersioned` are both `#[non_exhaustive]` enums with a single `V2` variant today (defined in `ledger/src/structure.rs` lines 289 and 227 respectively). The tagged-frame design allows new variants to be added without breaking clients that were compiled against an older version of the enum.

```text
ProofPreimageVersioned  tag: "proof-preimage-versioned"  (structure.rs:225)
ProofVersioned          tag: "proof-versioned"            (structure.rs:287)
```

## Practical note

Clients rarely construct these bytes by hand. The wallet SDK (`httpClientProofProvider`) serializes and deserializes them automatically. If you are writing a custom client or debugging raw traffic, see `proof-server:proof-server-integration` for end-to-end assembly examples and `examples/constructing-a-prove-request.md` for a worked walkthrough.

## Cross-references

- `proof-server:proof-server-api` — endpoint reference with status codes and error messages
- `proof-server:proof-server-integration` — SDK integration and proving-pipeline walkthrough
- `midnight-status-codes:status-codes` — full Midnight ecosystem error code reference
