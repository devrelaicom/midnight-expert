# Proof Server Proving Pipeline

The proof server pipeline takes a versioned proof preimage, runs an optional pre-proving check, then generates a PLONK proof. All work executes on a worker-pool thread; the HTTP endpoints (`/check` and `/prove`) are thin wrappers.

## Flow

```text
Client
  │
  ├──POST /check──→ ProofPreimageVersioned (+ optional WrappedIr)
  │                         │
  │                         ▼
  │                 versioned_ir::check(ppi, ir)
  │                         │
  │                         ▼
  │                 Vec<Option<u64>>            ← omitted-block / padding info
  │                         │
  │                    (returned to client)
  │
  └──POST /prove──→ ProofPreimageVersioned (+ optional ProvingKeyMaterial)
                            │
                            ▼
                    versioned_ir::prove(ppi, ir_source, resolver)
                            │
                            ▼
                    ProofVersioned::V2(Proof)   ← PLONK proof
                            │
                       (returned to client)
```

## `check` — Branch-Omission and Zero-Padding

`check` runs the circuit to determine which public-input "blocks" were omitted by untaken branches and how many zero-padding elements each omitted block requires.

Because Compact circuits compile to JavaScript, untaken branch paths are not evaluated. This means the JavaScript circuit target omits public inputs that occurred inside an untaken branch. The statement vector must still include those positions, padded with zero elements.

`check` groups the statement vector into *blocks*, one block per VM instruction. It returns `Vec<Option<usize>>` (the internal Rust type; serialized as `Vec<Option<u64>>` on the wire — see `proof-server:proof-server-api` → binary-serialization):

| Value | Meaning |
|-------|---------|
| `Some(n)` | Block was omitted (untaken branch); `n` = number of public inputs skipped, to be zero-padded |
| `None` | Block was present (branch taken); its public inputs are in the statement vector |

Source: `transient-crypto/src/proofs.rs` ~155–170.

`check` is proving-preparation — it resolves the shape of the public input vector before `prove` runs. It is **not** a per-constraint pass/fail validator.

## `prove` — PLONK Proof Generation

`prove` generates the PLONK proof for the circuit. It:

1. Resolves the proving key via the `Resolver` chain (see key-material.md).
2. Selects the public-parameter set keyed on the circuit's `k` (the polynomial-commitment degree bound).
3. Calls `ProofPreimage::prove` with `OsRng`, `PUBLIC_PARAMS`, and the resolver.
4. Returns `(Proof, Vec<Option<usize>>)` — the proof and the skips computed internally via `check`.

The endpoint wraps the result as `ProofVersioned::V2(proof)` before serializing the response.

## ZKIR Dispatch — `versioned_ir.rs`

`versioned_ir.rs` inspects the raw IR bytes to determine which ZKIR format is in use and dispatches accordingly. This is the IR-format layer and is independent of the proof-version enum.

```text
ir bytes
    │
    ├──zkir_v2::IrSource::load_from_tagged(...)  ← default; always compiled in
    │          │
    │          └──→ dispatch to zkir_v2 path
    │
    └──(experimental only)
       tagged_deserialize::<zkir_v3::IrSource>(...)
                  │
                  └──→ dispatch to zkir_v3 path
```

| Feature state | ZKIR formats accepted |
|---------------|-----------------------|
| default (no features) | `zkir_v2` only |
| `--features experimental` | `zkir_v2` + `zkir_v3` |

The `experimental` Cargo feature gates the optional `zkir-v3` crate dependency:

```
# proof-server/Cargo.toml
experimental = ["dep:zkir-v3"]
```

The default feature set does **not** include `experimental`, so `zkir_v3` support is **off by default**. Production builds use `zkir_v2` exclusively.

The `ProofVersioned` and `ProofPreimageVersioned` enums are a separate, binary-serialization concept (currently both have only a `V2` variant). They are unrelated to the ZKIR IR-format dispatch described here. See `proof-server:proof-server-api` → binary-serialization for the wire format.

## Resolvers

Key material is supplied to `prove` by three cooperating components:

| Component | Role |
|-----------|------|
| `Resolver` | Top-level resolver; wraps public params + dust resolver + optional custom key closure |
| `DustResolver` | Resolves DUST-specific proving keys using `DUST_EXPECTED_FILES` |
| `MidnightDataProvider` | Fetches key material from the network (`FetchMode::OnDemand`) on first use |

See `proof-server:proof-server-architecture` → key-material for startup prefetch behaviour and the full resolver composition diagram.

## Cross-references

- `proof-server:proof-server-api` → binary-serialization — `ProofVersioned` / `ProofPreimageVersioned` wire format and discriminant encoding
- `proof-server:proof-server-architecture` → key-material — resolver construction, prefetch ranges, and on-demand key fetch
- `compact-core:compact-circuit-costs` — how circuit structure determines `k` and overall proof cost
- `midnight-verify:verify-by-zkir-checker` — end-to-end ZK proof pipeline verification using the PLONK checker
