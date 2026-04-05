# Full Applications

Complete multi-file DApps demonstrating how Compact modules compose into production-style contracts. Each application has its own subdirectory under `examples/applications/`.

---

## Applications

### CryptoKitties (`applications/kitties/`)

| Attribute | Detail |
|---|---|
| Path | `applications/kitties/` |
| Description | CryptoKitties-inspired NFT game on Midnight. Cats have gender, genetic traits, and can breed. NFT ownership and transfer mechanics delegate to the `Nft` module; kitty-specific logic (breeding, gender assignment, genetic hashing) is implemented on top. |
| Files | `kitties.compact`, `Nft.compact`, `witnesses.ts` |
| Witnesses | `witnesses.ts` — implements `getLocalSecret(): Bytes<32>` and other Nft witnesses |
| Complexity | Intermediate |

**`kitties.compact`** imports the local `./Nft` module and adds:
- `Gender` enum (`Male`, `Female`)
- Kitty-specific ledger state (traits, owner mapping)
- `breed`, `createKitty`, and related circuits
- Selectively exports standard NFT circuits (`balanceOf`, `ownerOf`, `approve`, `getApproved`, `setApprovalForAll`, `isApprovedForAll`) without exposing raw `mint`/`burn`

**`Nft.compact`** is a local copy of the `modules/token/Nft` module (not imported from the modules directory).

---

### ZK Loan (`applications/zkloan/`)

| Attribute | Detail |
|---|---|
| Path | `applications/zkloan/` |
| Description | Privacy-preserving lending protocol. Applicants request loans without revealing their credit score, income, or tenure on-chain. Off-chain credit bureaus (providers) attest scores via Schnorr signatures. The contract verifies attestations in-circuit and makes loan decisions based on policy thresholds. |
| Files | `zkloan-credit-scorer.compact`, `schnorr.compact`, `witnesses.ts` |
| Witnesses | `witnesses.ts` — implements `getAttestedScoringWitness(): [Applicant, SchnorrSignature, providerId]` and `getSchnorrReduction(hash): [Field, Uint<248>]` |
| Complexity | Advanced |

**`zkloan-credit-scorer.compact`** defines:
- `LoanStatus` enum (`Approved`, `Rejected`, `Proposed`, `NotAccepted`)
- `LoanApplication` struct (`authorizedAmount: Uint<16>`, `status: LoanStatus`)
- Ledgers: `blacklist: Set<ZswapCoinPublicKey>`, `loans: Map<Bytes<32>, Map<Uint<16>, LoanApplication>>`, `providers: Map<Uint<16>, JubjubPoint>`, `admin: ZswapCoinPublicKey`
- Circuits: `requestLoan(amountRequested, secretPin)`, provider management, blacklist management

**`schnorr.compact`** is a local copy of the `modules/crypto/schnorr` module.

---

### Real-World Assets (`applications/midnight-rwa/`)

| Attribute | Detail |
|---|---|
| Path | `applications/midnight-rwa/` |
| Description | Privacy-gated real-world asset contract. Users must prove passport identity, issuer authorization (via Merkle tree), user authorization (via second Merkle tree), legal age, and nationality — all in zero-knowledge. On success, the user receives shielded tBTC and tHF tokens as reward. |
| Files | `midnight-rwa.compact`, `crypto.compact`, `passportidentity.compact`, `witnesses.ts` |
| Witnesses | `witnesses.ts` — implements `localSecretKey()`, `findIssuerPath(pk)`, `findAuthorizationPath(pk)`, `reduceChallenge(r)` |
| Complexity | Advanced |

**`midnight-rwa.compact`** defines:
- Ledgers: `counter`, `nonce`, `quizHash`, `issuerAuthorizations: HistoricMerkleTree<32, Bytes<32>>`, `authorizations: HistoricMerkleTree<32, ZswapCoinPublicKey>`, `tbtcCoinColor`, `identityProviderPublicKey`, `EIGHTEEN_YEARS_IN_SECONDS`, `ALLOWED_COUNTRY_CODE1/2`, `tHF`, `tBTC`
- `QuizResult` struct
- Multi-step identity proof circuit using `PassportData` + `SignedCredential`, Merkle path verification, age check, and nationality check
- Shielded token rewards via `mintShieldedToken`

**`crypto.compact`** and **`passportidentity.compact`** are local copies of their respective `modules/` counterparts.

---

### tBTC Token (`applications/tbtc/`)

| Attribute | Detail |
|---|---|
| Path | `applications/tbtc/` |
| Description | Minimal standalone shielded tBTC minting contract. Each call to `mint()` increments a counter, evolves the nonce with `evolveNonce(counter, nonce)`, and mints 1000 units of the `"brick-towers:coin:tbtc"` shielded coin to the caller. No access control. |
| Files | `tbtc.compact` |
| Witnesses | None |
| Complexity | Beginner |

**`tbtc.compact`** demonstrates the simplest use of `mintShieldedToken` with nonce evolution. This is the standalone version; the same contract is embedded inside `midnight-rwa` for the reward mechanism.

---

## Architectural Patterns

These applications illustrate several important composition patterns:

1. **Module import + selective re-export** — `kitties.compact` imports `Nft` and re-exports only safe circuits, hiding `mint`/`burn` from external callers.

2. **Local module copies** — Applications like `kitties` and `zkloan` keep local copies of modules (e.g., `Nft.compact`, `schnorr.compact`) rather than importing from `modules/`. This makes them self-contained.

3. **Witness-driven privacy** — `midnight-rwa` uses four separate witnesses to provide off-chain data (secret key, two Merkle paths, challenge reduction), all verified in-circuit.

4. **Merkle tree authorization** — `midnight-rwa` uses `HistoricMerkleTree` for two independent authorization registries, each with a separate Merkle proof witness.

5. **Multi-module DApp** — `midnight-rwa` combines three `.compact` files (`midnight-rwa.compact`, `crypto.compact`, `passportidentity.compact`) in a single deployment.

---

## Cross-references

- For the standalone module versions used in these applications, see [modules.md](modules.md).
- For the privacy and ZK techniques used in `zkloan` and `midnight-rwa`, see [privacy-and-cryptography.md](privacy-and-cryptography.md).
- For the standalone shielded token contracts, see [tokens.md](tokens.md).
