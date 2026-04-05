# Privacy and Cryptography

This is a routing-only reference. There is no `examples/privacy-and-cryptography/` directory. The patterns below are implemented across several other directories — this file tells you exactly where to find each one.

---

## Pattern Catalogue

| Pattern | Location | Description |
|---|---|---|
| Schnorr signature verification (Jubjub) | `modules/crypto/schnorr.compact` | Schnorr verification over the Jubjub curve. Polyfill for `jubjubSchnorrVerify` (not yet in CompactStandardLibrary). `schnorrVerify<#n>(msg, signature, pk)` uses `ecMulGenerator`/`ecMul`/`ecAdd`. A `getSchnorrReduction` witness truncates the 255-bit challenge hash to 248 bits to satisfy Jubjub's scalar field constraint. |
| Generic EC primitives (Pallas/Vesta curve) | `modules/crypto/crypto.compact` | Sign/verify over `CurvePoint` using generic credentials `SignedCredential<T>`. Exports `derive_pk`, `sign<T>`, `verify<T>`, `computeChallenge<T>`, `deterministicK<T>`. Used when the credential type is parameterized (e.g., passport data). |
| Hash-based NFT identity (owner privacy) | `modules/token/NftZk.compact` | Owner identity stored as `Field` hash of `(pk.bytes, localSecret)` via `generateHashKey`. Balance lookups require the caller to provide `getLocalSecret()` or `getSharedSecret()` witness. Raw public keys are never stored in token ownership maps. |
| Shielded token minting and transfer | `tokens/ShieldedERC20.compact` | Uses `mintShieldedToken` and `sendImmediateShielded` from `CompactStandardLibrary`. Tokens are native Midnight shielded coins — balances are hidden from the public ledger. **Archived; not for production** due to inability to enforce custom spend logic or guarantee total supply accounting. |
| Shielded coin with nonce evolution | `tokens/tbtc.compact`, `applications/tbtc/tbtc.compact` | Demonstrates `mintShieldedToken` with `evolveNonce(counter, nonce)` to derive fresh nonces per mint. Coin color is a domain-separated `Bytes<32>` constant (`"brick-towers:coin:tbtc"`). |
| Privacy-preserving ownership (ZOwnablePK) | `modules/access/ZOwnablePK.compact` | Stores a commitment `SHA256(SHA256(pk, nonce), instanceSalt, counter, domain)` instead of the owner's public key. The owner proves identity by providing `wit_secretNonce()` in the `assertOnlyOwner` circuit. Ownership transfers increment the counter, preventing commitment reuse (unlinkability). |
| Passport / identity credential proofs | `modules/identity/passportidentity.compact` | `PassportData` struct mirrors ICAO MRZ fields. `computeChallengeForCredential` and `generateDeterministicK` wrap the generic `Crypto` module for passport-specific Schnorr challenges. |
| ZK credit scoring with attestation | `applications/zkloan/zkloan-credit-scorer.compact` | A lending contract where credit scores are provided by off-chain attestors. The applicant's `Applicant` struct (credit score, monthly income, months as customer) is never disclosed on-chain. The `getAttestedScoringWitness()` returns `[Applicant, SchnorrSignature, providerId]`; the contract verifies the signature from a registered provider's `JubjubPoint` public key and derives a loan decision entirely in-circuit. Uses `schnorr.compact`. |
| Merkle tree authorization | `applications/midnight-rwa/midnight-rwa.compact` | Uses `HistoricMerkleTree<32, Bytes<32>>` for issuer authorizations and `HistoricMerkleTree<32, ZswapCoinPublicKey>` for user authorizations. Witnesses `findIssuerPath` and `findAuthorizationPath` provide Merkle proofs off-chain. The contract verifies membership in-circuit using `MerkleTreePath`. |
| Privacy-preserving real-world asset access | `applications/midnight-rwa/midnight-rwa.compact` | Full privacy-gated RWA contract. Callers prove: (1) they hold a valid passport (via `PassportData` + `SignedCredential`), (2) the issuer is in the authorized Merkle tree, (3) they are in the user authorization Merkle tree, (4) they are of legal age (`dateOfBirth` check against `EIGHTEEN_YEARS_IN_SECONDS`), (5) their nationality matches allowed country codes. The identity proof uses the `Crypto` and `PassportIdentity` modules. |
| NftZk privacy in a full application | `applications/kitties/kitties.compact` | CryptoKitties built on the `Nft` module (not `NftZk`). Compare with `tokens/nft-zk.compact` for the ZK variant. Shows how NFT modules compose with application-specific state (gender, genetics, breeding). |

---

## Witness Roles in Privacy Patterns

Most privacy in Compact is implemented via witnesses — values computed off-chain that are verified in-circuit. Key witnesses across these patterns:

| Witness | File | Purpose |
|---|---|---|
| `wit_secretNonce(): Bytes<32>` | `ZOwnablePK` callers | Private nonce for owner commitment derivation |
| `getLocalSecret(): Bytes<32>` | `NftZk` callers | Secret for deriving owner hash key (self-queries) |
| `getSharedSecret(): Bytes<32>` | `NftZk` callers | Secret for deriving owner hash key (peer queries) |
| `getSchnorrReduction(hash): [Field, Uint<248>]` | `schnorr.compact` | Truncates 255-bit challenge to Jubjub 248-bit scalar |
| `getAttestedScoringWitness()` | `zkloan-credit-scorer.compact` | Returns private applicant data + provider signature |
| `localSecretKey(): Bytes<32>` | `midnight-rwa`, `bboard` | Caller's private key for on-chain key derivation |
| `findIssuerPath(pk)` | `midnight-rwa` | Merkle proof for issuer authorization |
| `findAuthorizationPath(pk)` | `midnight-rwa` | Merkle proof for user authorization |
| `reduceChallenge(r): Field` | `midnight-rwa` | Schnorr challenge reduction workaround |

---

## Cross-references

- For the full `schnorr` and `crypto` module implementations, see [modules.md](modules.md) — Crypto section.
- For the `ZOwnablePK` module, see [modules.md](modules.md) — Access Control section.
- For the `NftZk` module, see [modules.md](modules.md) — Token section.
- For the full applications that combine these patterns, see [applications.md](applications.md).
- For the composed token contracts using shielded primitives, see [tokens.md](tokens.md).
