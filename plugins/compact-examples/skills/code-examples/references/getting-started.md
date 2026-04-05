# Getting Started Examples

Two minimal contracts designed for learning Compact. Both use `pragma language_version >= 0.22` and import `CompactStandardLibrary`.

## Examples

| Name | Path | Description | Witnesses | Complexity |
|---|---|---|---|---|
| Counter | `getting-started/counter/counter.compact` | Single public ledger state (`round: Counter`) with one `increment()` circuit. The simplest possible stateful contract — no witnesses, no constructor, no private state. | None (`witnesses.ts` is empty) | Beginner |
| Bulletin Board | `getting-started/bboard/bboard.compact` | One-at-a-time message board with ownership enforced via public key derivation. State machine with `VACANT`/`OCCUPIED` enum, `Opaque<"string">` message, and sequence counter. Ownership uses `persistentHash` over secret key + sequence, never exposing the secret on-chain. | `localSecretKey(): Bytes<32>` (in `witnesses.ts`) | Beginner |

## File Details

### counter

- `getting-started/counter/counter.compact` — Exports `round: Counter` ledger and `increment()` circuit. Demonstrates the `Counter` type from `CompactStandardLibrary`.
- `getting-started/counter/witnesses.ts` — Empty witness implementation (no witnesses required).

### bboard

- `getting-started/bboard/bboard.compact` — Exports `state`, `message`, `sequence`, `owner` ledgers. Circuits: `post(newMessage)`, `takeDown()`, `publicKey(sk, sequence)`. Uses `disclose()`, `Maybe`, `Opaque`, `some`/`none`, and `persistentHash`.
- `getting-started/bboard/witnesses.ts` — Implements `localSecretKey()` returning the caller's private key bytes.

## Key Patterns Illustrated

- `Counter` type for monotonically increasing state
- `Maybe<T>` for optional values (`some`/`none`)
- `Opaque<"string">` for off-chain string values passed through the circuit
- `disclose()` to move witness-provided values into public ledger state
- `persistentHash` for deterministic, on-chain key derivation
- Public key derivation without exposing the secret key

## Cross-references

For more advanced patterns built on these primitives, see [modules.md](modules.md) — particularly `Ownable` and `ZOwnablePK` for production-grade ownership, and `Initializable` for constructor guards.
