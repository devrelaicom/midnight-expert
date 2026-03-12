# OpenZeppelin Compact Contracts — Library Reference

> Source: [OpenZeppelin/compact-contracts](https://github.com/OpenZeppelin/compact-contracts)
> Version: v0.0.1-alpha.1
> Language version: `pragma language_version >= 0.21.0`
> Compiler compatibility tested: compactc 0.26.0 (lang 0.18.0), 0.28.0 (lang 0.20.0), 0.29.0 (lang 0.21.0)

## Quick File Lookup

All paths below are relative to `examples/` within this skill.

### Example Contracts (full working contracts using the OZ modules)

| File | Pattern | Modules Used |
|---|---|---|
| `SimpleNonFungibleToken.compact` | Basic NFT with URI, approvals, transfers | NonFungibleToken |
| `MultiTokenTwoTypes.compact` | Multi-token (fungible + non-fungible in one contract) | MultiToken |
| `AccessControlledToken.compact` | Fungible token with role-based mint/burn | AccessControl, FungibleToken |
| `FungibleTokenMintablePausableOwnable.compact` | Full ERC-20 with ownership, pausing, minting | Ownable, Pausable, FungibleToken |

### Module Contracts

| File | Description |
|---|---|
| `modules/access/AccessControl.compact` | Role-based access control (RBAC) with admin hierarchies |
| `modules/access/Ownable.compact` | Single-owner access control |
| `modules/access/ZOwnablePK.compact` | Privacy-preserving ownership via commitment scheme |
| `modules/token/FungibleToken.compact` | ERC-20 approximation (Uint<128>) |
| `modules/token/NonFungibleToken.compact` | ERC-721 approximation (Uint<128> token IDs) |
| `modules/token/MultiToken.compact` | ERC-1155 approximation (no batch ops) |
| `modules/security/Initializable.compact` | One-time initialization guard |
| `modules/security/Pausable.compact` | Emergency stop mechanism |
| `modules/utils/Utils.compact` | Address comparison, type checking (all pure circuits) |

### Witnesses

| File | For Module |
|---|---|
| `modules/access/witnesses/AccessControlWitnesses.ts` | AccessControl |
| `modules/access/witnesses/OwnableWitnesses.ts` | Ownable |
| `modules/access/witnesses/ZOwnablePKWitnesses.ts` | ZOwnablePK |
| `modules/token/witnesses/FungibleTokenWitnesses.ts` | FungibleToken |
| `modules/token/witnesses/NonFungibleTokenWitnesses.ts` | NonFungibleToken |
| `modules/token/witnesses/MultiTokenWitnesses.ts` | MultiToken |
| `modules/security/witnesses/InitializableWitnesses.ts` | Initializable |
| `modules/security/witnesses/PausableWitnesses.ts` | Pausable |
| `modules/utils/witnesses/UtilsWitnesses.ts` | Utils |

### Test Mocks (Compact contracts used in tests — show how to wire modules for testing)

| File | Module Under Test |
|---|---|
| `modules/access/test/mocks/MockAccessControl.compact` | AccessControl |
| `modules/access/test/mocks/MockOwnable.compact` | Ownable |
| `modules/access/test/mocks/MockZOwnablePK.compact` | ZOwnablePK |
| `modules/token/test/mocks/MockFungibleToken.compact` | FungibleToken |
| `modules/token/test/mocks/MockNonFungibleToken.compact` | NonFungibleToken |
| `modules/token/test/mocks/MockMultiToken.compact` | MultiToken |
| `modules/security/test/mocks/MockInitializable.compact` | Initializable |
| `modules/security/test/mocks/MockPausable.compact` | Pausable |
| `modules/utils/test/mocks/MockUtils.compact` | Utils |

### Test Simulators (TypeScript `createSimulator` wrappers)

| File | Module Under Test |
|---|---|
| `modules/access/test/simulators/AccessControlSimulator.ts` | AccessControl |
| `modules/access/test/simulators/OwnableSimulator.ts` | Ownable |
| `modules/access/test/simulators/ZOwnablePKSimulator.ts` | ZOwnablePK |
| `modules/token/test/simulators/FungibleTokenSimulator.ts` | FungibleToken |
| `modules/token/test/simulators/NonFungibleTokenSimulator.ts` | NonFungibleToken |
| `modules/token/test/simulators/MultiTokenSimulator.ts` | MultiToken |
| `modules/security/test/simulators/InitializableSimulator.ts` | Initializable |
| `modules/security/test/simulators/PausableSimulator.ts` | Pausable |
| `modules/utils/test/simulators/UtilsSimulator.ts` | Utils |

### Test Files (Vitest)

| File | Module Under Test |
|---|---|
| `modules/access/test/AccessControl.test.ts` | AccessControl |
| `modules/access/test/Ownable.test.ts` | Ownable |
| `modules/access/test/ZOwnablePK.test.ts` | ZOwnablePK |
| `modules/token/test/FungibleToken.test.ts` | FungibleToken |
| `modules/token/test/nonFungibleToken.test.ts` | NonFungibleToken |
| `modules/token/test/MultiToken.test.ts` | MultiToken |
| `modules/security/test/Initializable.test.ts` | Initializable |
| `modules/security/test/Pausable.test.ts` | Pausable |
| `modules/utils/test/utils.test.ts` | Utils |

---

## Module Details

### access/AccessControl

Role-based access control (RBAC). Roles are `Bytes<32>` identifiers with admin hierarchies.

- **Dependencies:** Utils
- **Key circuits:** `hasRole`, `assertOnlyRole`, `grantRole`, `revokeRole`, `renounceRole`, `getRoleAdmin`, `_setRoleAdmin`, `_grantRole`, `_unsafeGrantRole`, `_revokeRole`
- **Ledger:** `_operatorRoles` (Map<Bytes<32>, Map<account, Boolean>>), `_adminRoles` (Map<Bytes<32>, Bytes<32>>), `DEFAULT_ADMIN_ROLE`
- **Pattern:** Define roles as `export sealed ledger MY_ROLE: Bytes<32>`, initialize with `persistentHash`, protect circuits with `assertOnlyRole(MY_ROLE)`

### access/Ownable

Single-owner access control. Owner stored on-chain.

- **Dependencies:** Initializable, Utils
- **Key circuits:** `initialize`, `owner`, `transferOwnership`, `renounceOwnership`, `assertOnlyOwner`, `_transferOwnership`, `_unsafeTransferOwnership`, `_unsafeUncheckedTransferOwnership`
- **Ledger:** `_owner: Either<ZswapCoinPublicKey, ContractAddress>`
- **Pattern:** Call `initialize(owner)` in constructor, guard circuits with `assertOnlyOwner()`

### access/ZOwnablePK

Privacy-preserving ownership. Owner identity never revealed on-chain.

- **Dependencies:** Initializable
- **Witnesses:** `wit_secretNonce(): Bytes<32>` — required for owner verification
- **Key circuits:** `initialize`, `owner`, `transferOwnership`, `renounceOwnership`, `assertOnlyOwner`, `_computeOwnerCommitment`, `_computeOwnerId`, `_transferOwnership`
- **Commitment:** `SHA256(SHA256(pk, nonce), instanceSalt, counter, "ZOwnablePK:shield:")`

### token/FungibleToken

ERC-20 approximation. Uint<128> token sizes.

- **Dependencies:** Initializable, Utils
- **Key circuits:** `initialize`, `name`, `symbol`, `decimals`, `totalSupply`, `balanceOf`, `transfer`, `_unsafeTransfer`, `allowance`, `approve`, `transferFrom`, `_unsafeTransferFrom`, `_transfer`, `_mint`, `_unsafeMint`, `_burn`, `_approve`, `_spendAllowance`
- **Ledger:** `_balances`, `_allowances`, `_totalSupply`, `_name`, `_symbol`, `_decimals`

### token/NonFungibleToken

ERC-721 approximation. Uint<128> token IDs.

- **Dependencies:** Initializable, Utils
- **Key circuits:** `initialize`, `balanceOf`, `ownerOf`, `name`, `symbol`, `tokenURI`, `approve`, `getApproved`, `setApprovalForAll`, `isApprovedForAll`, `transferFrom`, `_unsafeTransferFrom`, `_transfer`, `_mint`, `_unsafeMint`, `_burn`, `_setTokenURI`
- **Ledger:** `_owners`, `_balances`, `_tokenApprovals`, `_operatorApprovals`, `_tokenURIs`, `_name`, `_symbol`

### token/MultiToken

ERC-1155 approximation. No batch operations (no dynamic arrays).

- **Dependencies:** Initializable, Utils
- **Key circuits:** `initialize`, `uri`, `balanceOf`, `setApprovalForAll`, `isApprovedForAll`, `transferFrom`, `_unsafeTransferFrom`, `_transfer`, `_unsafeTransfer`, `_mint`, `_unsafeMint`, `_burn`, `_setURI`, `_setApprovalForAll`
- **Ledger:** `_balances` (Map<id, Map<account, Uint<128>>>), `_operatorApprovals`, `_uri`
- **URI pattern:** Uses `{id}` substitution per EIP-1155

### security/Initializable

One-time initialization guard.

- **Dependencies:** none
- **Key circuits:** `initialize`, `assertInitialized`, `assertNotInitialized`
- **Ledger:** `_isInitialized: Boolean`

### security/Pausable

Emergency stop mechanism.

- **Dependencies:** none
- **Key circuits:** `isPaused`, `assertPaused`, `assertNotPaused`, `_pause`, `_unpause`
- **Ledger:** `_isPaused: Boolean`

### utils/Utils

Address comparison and type checking. All circuits are `pure`.

- **Dependencies:** none
- **Key circuits:** `isKeyOrAddressZero`, `isKeyZero`, `isKeyOrAddressEqual`, `isContractAddress`, `emptyString`

---

## Example Contract Details

### SimpleNonFungibleToken.compact

Basic NFT contract with URI storage, approvals, and transfers.

- **Modules:** NonFungibleToken
- **Constructor:** `(name, symbol, recipient, tokenURI)` — mints token ID 1 to recipient
- **Exported circuits:** `balanceOf`, `ownerOf`, `name`, `symbol`, `tokenURI`, `approve`, `getApproved`, `setApprovalForAll`, `isApprovedForAll`, `transferFrom`

### MultiTokenTwoTypes.compact

Multi-token contract with both fungible and non-fungible token types.

- **Modules:** MultiToken
- **Constructor:** `(_uri, recipient, fungibleFixedSupply)` — mints token 123 (fungible, fixed supply) and token 987 (non-fungible, supply of 1)
- **Exported circuits:** `uri`, `balanceOf`, `setApprovalForAll`, `isApprovedForAll`, `transferFrom`

### AccessControlledToken.compact

Fungible token with role-based minting and burning.

- **Modules:** AccessControl, FungibleToken
- **Constructor:** `(name, symbol, decimals)` — sets up roles, grants deployer `DEFAULT_ADMIN_ROLE`
- **Roles:** `MINTER_ROLE` (hashed), `BURNER_ROLE` (hashed)
- **Exported circuits:** `name`, `symbol`, `decimals`, `totalSupply`, `balanceOf`, `transfer`, `approve`, `mint` (MINTER_ROLE), `burn` (BURNER_ROLE)

### FungibleTokenMintablePausableOwnable.compact

Complete ERC-20 style token combining ownership, pausing, and minting.

- **Modules:** Ownable, Pausable, FungibleToken
- **Constructor:** `(_name, _symbol, _decimals, _owner)`
- **Exported circuits:** `name`, `symbol`, `decimals`, `totalSupply`, `balanceOf`, `allowance`, `transfer` (pause-checked), `transferFrom` (pause-checked), `approve` (pause-checked), `mint` (owner+pause), `isPaused`, `pause` (owner), `unpause` (owner), `owner`, `transferOwnership`, `renounceOwnership`

---

## Language Version Compatibility

All contracts and modules specify `pragma language_version >= 0.21.0`. Syntax verified against:

| Language Version | Compiler Version | Status |
|---|---|---|
| 0.18.0 | compactc 0.26.0 | Syntax valid |
| 0.20.0 | compactc 0.28.0 | Syntax valid |
| 0.21.0 | compactc 0.29.0 | Syntax valid |

### Breaking Change: `from` keyword (compactc 0.28.0+)

`from` became a reserved keyword in compactc 0.28.0 (language 0.20.0). All OZ modules and examples use `fromAddress` as the parameter name in `transferFrom` circuits.

## Key Limitations

- **Token sizes:** `Uint<128>` not `uint256` (circuit backend encoding limits)
- **No contract-to-contract calls:** Safe circuits reject `ContractAddress` recipients; `_unsafe` variants exist for experimentation
- **No events:** Compact does not support events
- **No dynamic arrays:** No batch operations (ERC-1155 batch transfer/mint)
- **No introspection:** No ERC-165 equivalent
