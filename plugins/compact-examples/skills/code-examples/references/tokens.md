# Token Contracts

Complete, deployable token contracts that compose the reusable modules from `modules/`. Each file is a top-level contract (not a module) — it has a `constructor`, exports circuits directly, and can be deployed as-is.

All use `pragma language_version >= 0.22` or `>= 0.22.0`.

---

## Contracts

| Name | Path | Description | Witnesses | Complexity |
|---|---|---|---|---|
| AccessControlledToken | `tokens/AccessControlledToken.compact` | Fungible token with role-based minting and burning. Constructor initialises `FungibleToken` and seeds `AccessControl` with `MINTER_ROLE`, `BURNER_ROLE`, and `DEFAULT_ADMIN_ROLE` (granted to deployer). Only addresses with `MINTER_ROLE` can mint; only `BURNER_ROLE` can burn. Composes `AccessControl` + `FungibleToken`. | None (inherited from module witnesses) | Intermediate |
| FungibleTokenMintablePausableOwnable | `tokens/FungibleTokenMintablePausableOwnable.compact` | Fungible token with owner-controlled minting and pausing. Constructor takes `_name`, `_symbol`, `_decimals`, `_owner`. Circuits: standard `FungibleToken` interface plus owner-only `mint` and `pause`/`unpause`. Composes `Ownable` + `Pausable` + `FungibleToken`. | None (inherited) | Intermediate |
| SimpleNonFungibleToken | `tokens/SimpleNonFungibleToken.compact` | Basic NFT with URI storage, approvals, and transfers. Constructor mints token ID `1` to `recipient` and sets a `tokenURI`. Delegates all circuits to `NonFungibleToken` module. Composes `NonFungibleToken` only. | None (inherited) | Beginner |
| MultiTokenTwoTypes | `tokens/MultiTokenTwoTypes.compact` | Multi-token contract with one fungible token (ID `123`, fixed supply) and one NFT (ID `987`, supply `1`) minted at construction. Delegates to `MultiToken` module. Demonstrates mixed fungible/non-fungible in a single contract. | None (inherited) | Intermediate |
| nft.compact | `tokens/nft.compact` | Top-level NFT contract wrapping the `Nft` module. Exports selected circuits (`balanceOf`, `ownerOf`, `approve`, `getApproved`, `setApprovalForAll`, `isApprovedForAll`, `transfer`, etc.) while intentionally omitting `mint` and `burn` (no authorization checks on those in the base module). | None (inherited) | Intermediate |
| nft-zk.compact | `tokens/nft-zk.compact` | Top-level privacy-preserving NFT wrapping the `NftZk` module. Same selective export pattern as `nft.compact` but owner identity is stored as a hash — callers prove ownership via `getLocalSecret()` witness. | `witnesses/nft-zk-witnesses.ts` | Advanced |
| ShieldedERC20 | `tokens/ShieldedERC20.compact` | Shielded token module (archived / not for production). Uses Midnight's native `mintShieldedToken` / `sendImmediateShielded` infrastructure. Circuits: `initialize`, `name`, `symbol`, `decimals`, `totalSupply`, `tokenType`, `mint`, `burn`. **Warning**: current network limitations mean total supply accounting can be broken by manual burns; no custom spend logic is enforceable. Marked `DO NOT USE IN PRODUCTION`. | None | Advanced |
| ShieldedFungibleToken | `tokens/ShieldedFungibleToken.compact` | Complete shielded fungible token contract wrapping `ShieldedERC20`. Constructor accepts `nonce_`, `name_`, `symbol_`, `domain_`; sets `decimals = 18`. Exports `name`, `symbol`, `decimals`, `totalSupply`, `tokenType`, `mint(recipient, amount)`, `burn(coin, amount)`. Inherits all ShieldedERC20 limitations. | None | Advanced |
| tbtc.compact | `tokens/tbtc.compact` | Minimal shielded tBTC token. Constructor sets initial `nonce`. `mint()` circuit increments counter, evolves nonce with `evolveNonce`, and calls `mintShieldedToken` with the `"brick-towers:coin:tbtc"` coin color, minting `1000` units per call to the caller. No access control on minting. | None | Intermediate |

---

## Witness Files

| Path | Used by |
|---|---|
| `tokens/witnesses/nft-witnesses.ts` | `tokens/nft.compact` |
| `tokens/witnesses/nft-zk-witnesses.ts` | `tokens/nft-zk.compact` |

---

## Module Dependencies

| Contract | Imported modules |
|---|---|
| `AccessControlledToken` | `modules/access/AccessControl`, `modules/token/FungibleToken` |
| `FungibleTokenMintablePausableOwnable` | `modules/access/Ownable`, `modules/security/Pausable`, `modules/token/FungibleToken` |
| `SimpleNonFungibleToken` | `modules/token/NonFungibleToken` |
| `MultiTokenTwoTypes` | `modules/token/MultiToken` |
| `nft.compact` | `modules/token/Nft` |
| `nft-zk.compact` | `modules/token/NftZk` |
| `ShieldedFungibleToken` | `tokens/ShieldedERC20` (local) |
| `ShieldedERC20` | `CompactStandardLibrary` (shielded coin primitives), `modules/utils/ShieldedUtils` |
| `tbtc.compact` | `CompactStandardLibrary` (shielded coin primitives) |

## Cross-references

- For the standalone module implementations used above, see [modules.md](modules.md).
- For the `tbtc` shielded token used inside a full DApp, see [applications.md](applications.md) (midnight-rwa and tbtc application directories).
- For privacy patterns in `ShieldedERC20`, `ShieldedFungibleToken`, and `nft-zk`, see [privacy-and-cryptography.md](privacy-and-cryptography.md).
