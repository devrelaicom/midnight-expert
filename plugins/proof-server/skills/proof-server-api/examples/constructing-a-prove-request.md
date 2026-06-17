# Constructing a `/prove` Request

In practice, the wallet SDK (`httpClientProofProvider`) builds and serializes this body automatically — you rarely construct it by hand. This example shows what that serialization produces and how a raw `/prove` request is assembled, using the integration test pipeline as evidence.

For the wire format specification, see `proof-server:proof-server-api` (binary-serialization).

---

## Request shape

`POST /prove` accepts a single binary body: a `tagged_serialize`-encoded tuple of three fields.

| Position | Rust type | Description |
|----------|-----------|-------------|
| 0 | `ProofPreimageVersioned` | Circuit inputs and witness data (V2 today) |
| 1 | `Option<ProvingKeyMaterial>` | Custom proving key — `None` to use the built-in key |
| 2 | `Option<Fr>` | Binding input (field element for randomisation) — `None` for standard proving |

The response (200) is a `tagged_serialize`-encoded `ProofVersioned`.

---

## Construction path (Rust)

The integration test `prove_endpoint::processes_valid_request` assembles the request in three steps.

**Step 1 — Build the proof preimage.**

```rust
// proof-server/tests/integration_tests.rs — create_zswap_output_proof_preimage()
let mut rng = StdRng::seed_from_u64(0x42);
let sks = zswap::keys::SecretKeys::from_rng_seed(&mut rng);
let coin = coin::Info::new(&mut rng, 100, Default::default());

let output = zswap::Output::<_, InMemoryDB>::new(
    &mut rng,
    &coin,
    None,
    &sks.coin_public_key(),
    Some(sks.enc_public_key()),
)
.expect("Failed to create output");

let ppi = (*output.proof).clone();
let versioned_ppi = ProofPreimageVersioned::V2(Arc::new(ppi));
```

This creates a single zswap output `ProofPreimageVersioned::V2` — the most common preimage type sent by the wallet SDK for shielded transfers.

**Step 2 — Serialise the tuple into the request body.**

```rust
// proof-server/tests/integration_tests.rs — prove_endpoint::processes_valid_request()
let data: Option<ProvingKeyMaterial> = None;
let binding_input: Option<transient_crypto::curve::Fr> = None;

let mut body = Vec::new();
tagged_serialize(&(versioned_ppi, data, binding_input), &mut body)
    .expect("Failed to serialize prove request");
```

`tagged_serialize` (from `midnight-serialize`) writes a UTF-8 header tag followed by the CBOR-like binary payload. The tag for this tuple is:

```text
midnight:(proof-preimage-versioned,option(proving-data),option(fr-bls)):
```

This tag is what the server's deserializer expects to see at the start of every `/prove` body. If it is absent or wrong, the server returns 400 (see [Invalid body responses](#invalid-body-responses) below).

**Step 3 — POST the body.**

```rust
let response = client
    .post(format!("{}/prove", server.base_url()))
    .body(body)
    .send()
    .await
    .expect("Request failed");

assert_eq!(response.status(), 200);

let bytes = response.bytes().await.expect("Failed to get response bytes");
let _proof: ledger::structure::ProofVersioned =
    tagged_deserialize(&bytes[..]).expect("Failed to deserialize proof");
```

The 200 response is a `tagged_serialize`-encoded `ProofVersioned::V2`.

---

## Executed evidence

**Integration test — `prove_endpoint::processes_valid_request` — PASS**

Run against a freshly compiled `midnight-proof-server` v8.1.0 from source at `/tmp/mn-audit/midnight-ledger`:

```text
cargo test -p midnight-proof-server 'prove_endpoint::processes_valid_request' -- --nocapture
```

Relevant output (truncated):

```text
[INFO  midnight_base_crypto::data_provider] Missing zero-knowledge proving key for Zswap outputs.
    Attempting to download from https://srs.midnight.network/ - this is not a trusted service, the data will be verified.
[INFO  midnight_base_crypto::data_provider] Fetching zero-knowledge proving key for Zswap outputs - finished.
[INFO  midnight_base_crypto::data_provider] Fetching zero-knowledge proving key for Zswap outputs - verified correct.
[INFO  midnight_base_crypto::data_provider] Fetching zero-knowledge verifying key for Zswap outputs - finished.
[INFO  midnight_base_crypto::data_provider] Fetching zero-knowledge verifying key for Zswap outputs - verified correct.
[INFO  midnight_base_crypto::data_provider] Fetching ZKIR source for Zswap outputs - finished.
[INFO  midnight_base_crypto::data_provider] Fetching ZKIR source for Zswap outputs - verified correct.
[INFO  actix_web::middleware::logger] 127.0.0.1 POST /prove HTTP/1.1; took 3.787549s
[INFO  integration_tests::prove_endpoint] Prove response: 4860 bytes

test prove_endpoint::processes_valid_request ... ok

test result: ok. 1 passed; 0 failed; 0 ignored; 0 measured; 29 filtered out; finished in 3.79s
```

Key observations:
- Key material was fetched on-demand from `srs.midnight.network` (content-addressed, verified).
- Proof generation took **3.79 s** end-to-end (including key download on first run; subsequent runs are faster once keys are cached).
- The 200 response body was **4860 bytes** of `ProofVersioned::V2`.
- The test deserialised the response back into `ledger::structure::ProofVersioned` successfully.

> **Note on `proves_valid_transaction` (`/prove-tx`):** that test requires `MIDNIGHT_LEDGER_TEST_STATIC_DIR` pointing to Nix-built circuit artifacts and cannot run outside the Nix environment. The `/prove` test above exercises the same proof pipeline and does not need those artifacts.

---

## Invalid body responses

These responses were captured from a live `midnightntwrk/proof-server:8.1.0` container at `http://localhost:6300`.

**Empty body:**

```bash
printf '' | curl -s -w ' [%{http_code}]\n' \
  --data-binary @- \
  -H 'Content-Type: application/octet-stream' \
  http://localhost:6300/prove
```

```text
expected header tag 'midnight:(proof-preimage-versioned,option(proving-data),option(fr-bls)):', got '' [400]
```

**Body with wrong tag:**

```bash
printf 'not-a-valid-frame' | curl -s -w ' [%{http_code}]\n' \
  --data-binary @- \
  -H 'Content-Type: application/octet-stream' \
  http://localhost:6300/prove
```

```text
expected header tag 'midnight:(proof-preimage-versioned,option(proving-data),option(fr-bls)):', got 'not-a-valid-frame' [400]
```

Both responses confirm that the request reaches the prove handler and that deserialization is the first thing to fail when the body is malformed.

---

## Cross-references

- `proof-server:proof-server-api` — endpoint reference with status codes and full wire-type table
- `proof-server:proof-server-integration` — SDK integration, wallet SDK usage, and end-to-end proving pipeline
