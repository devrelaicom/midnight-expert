# Reusable Modules

Standalone Compact modules from the OpenZeppelin Compact Contracts library and community contributors. These are building blocks — import them into your own contracts rather than deploying them directly.

All modules use `pragma language_version >= 0.22`. Most include TypeScript witnesses and test suites.

---

## Access Control

| Name | Path | Description | Witnesses | Tests | Complexity |
|---|---|---|---|---|---|
| Ownable | `modules/access/Ownable.compact` | Single-admin access control. Stores owner as `Either<ZswapCoinPublicKey, ContractAddress>`. Key circuits: `initialize`, `owner`, `transferOwnership`, `renounceOwnership`, `assertOnlyOwner`, `_transferOwnership`. Depends on `Initializable` and `Utils`. Ownership transfers to `ContractAddress` are blocked until contract-to-contract calls are supported (unsafe variants provided for experimentation). | `witnesses/OwnableWitnesses.ts` | `test/Ownable.test.ts` | Intermediate |
| ZOwnablePK | `modules/access/ZOwnablePK.compact` | Privacy-preserving single-admin ownership. Never stores the owner's public key on-chain — stores only a commitment `SHA256(SHA256(pk, nonce), instanceSalt, counter, domain)`. Key circuits: `initialize(ownerId, instanceSalt)`, `owner`, `transferOwnership`, `renounceOwnership`, `assertOnlyOwner`, `_computeOwnerCommitment`, `_computeOwnerId`, `_transferOwnership`. Requires a `wit_secretNonce(): Bytes<32>` witness. The `counter` increments on each transfer, providing unlinkability. | `witnesses/ZOwnablePKWitnesses.ts` | `test/ZOwnablePK.test.ts` | Advanced |
| AccessControl | `modules/access/AccessControl.compact` | Role-based access control (RBAC). Roles identified by `Bytes<32>` hash. Ledgers: `_operatorRoles` (nested Map), `_adminRoles`, `DEFAULT_ADMIN_ROLE`. Key circuits: `hasRole`, `assertOnlyRole`, `grantRole`, `revokeRole`, `renounceRole`, `_setRoleAdmin`, `_grantRole`, `_revokeRole`. Roles granted only to `ZswapCoinPublicKey` via main circuits; `_unsafeGrantRole` for `ContractAddress` experimentation. Depends on `Utils`. | `witnesses/AccessControlWitnesses.ts` | `test/AccessControl.test.ts` | Intermediate |

**Test mocks**: `test/mocks/MockOwnable.compact`, `test/mocks/MockZOwnablePK.compact`, `test/mocks/MockAccessControl.compact`

**Test simulators**: `test/simulators/OwnableSimulator.ts`, `test/simulators/ZOwnablePKSimulator.ts`, `test/simulators/AccessControlSimulator.ts`

---

## Security

| Name | Path | Description | Witnesses | Tests | Complexity |
|---|---|---|---|---|---|
| Initializable | `modules/security/Initializable.compact` | One-time initialization guard. Tracks `_isInitialized: Boolean`. Key circuits: `initialize()` (asserts not initialized, sets flag), `assertInitialized()`, `assertNotInitialized()`. Used as a dependency by Ownable, ZOwnablePK, FungibleToken, NonFungibleToken, and MultiToken modules. | `witnesses/InitializableWitnesses.ts` | `test/Initializable.test.ts` | Beginner |
| Pausable | `modules/security/Pausable.compact` | Emergency stop mechanism. Tracks `_isPaused: Boolean`. Key circuits: `isPaused()`, `assertPaused()`, `assertNotPaused()`, `_pause()`, `_unpause()`. Typically composed with Ownable so only the owner can pause. | `witnesses/PausableWitnesses.ts` | `test/Pausable.test.ts` | Beginner |

**Test mocks**: `test/mocks/MockInitializable.compact`, `test/mocks/MockPausable.compact`

**Test simulators**: `test/simulators/InitializableSimulator.ts`, `test/simulators/PausableSimulator.ts`

---

## Token

| Name | Path | Description | Witnesses | Tests | Complexity |
|---|---|---|---|---|---|
| FungibleToken | `modules/token/FungibleToken.compact` | ERC-20-inspired fungible token module. Uses `Uint<128>` balances (not `Uint<256>` due to circuit backend limits). Ledgers: `_balances`, `_allowances`, `_totalSupply`, `_name`, `_symbol`, `_decimals`. Key circuits: `initialize`, `name`, `symbol`, `decimals`, `totalSupply`, `balanceOf`, `transfer`, `transferFrom`, `approve`, `allowance`, `_mint`, `_burn`, `_transfer`, `_approve`. Depends on `Initializable` and `Utils`. | `witnesses/FungibleTokenWitnesses.ts` | `test/FungibleToken.test.ts` | Intermediate |
| NonFungibleToken | `modules/token/NonFungibleToken.compact` | ERC-721-inspired NFT module. Key circuits: `initialize`, `name`, `symbol`, `balanceOf`, `ownerOf`, `tokenURI`, `approve`, `getApproved`, `setApprovalForAll`, `isApprovedForAll`, `transferFrom`, `_mint`, `_burn`, `_transfer`, `_setTokenURI`. Depends on `Initializable` and `Utils`. | `witnesses/NonFungibleTokenWitnesses.ts` | `test/NonFungibleToken.test.ts` | Intermediate |
| MultiToken | `modules/token/MultiToken.compact` | ERC-1155-inspired multi-token module (fungible + NFT in one contract). Uses `Uint<128>` for token IDs and amounts. Key circuits: `initialize`, `uri`, `balanceOf`, `setApprovalForAll`, `isApprovedForAll`, `safeTransferFrom`, `_mint`, `_burn`. No batch operations (Compact lacks dynamic arrays). Depends on `Initializable` and `Utils`. | `witnesses/MultiTokenWitnesses.ts` | `test/MultiToken.test.ts` | Intermediate |
| Nft | `modules/token/Nft.compact` | ZK-capable NFT module using `ZswapCoinPublicKey` for owners (unshielded, public key-indexed). Ledgers: `tokenOwner`, `tokenApprovals`, `ownedTokensCount`, `operatorApprovals`. Key circuits: `balanceOf`, `ownerOf`, `approve`, `getApproved`, `setApprovalForAll`, `isApprovedForAll`, `transfer`, `mint`, `burn`. No `Initializable` dependency. | `witnesses/NftWitnesses.ts` | — | Intermediate |
| NftZk | `modules/token/NftZk.compact` | Privacy-preserving NFT module. Owner identity stored as hashed `Field` (not raw public key). Balances looked up via `generateHashKey(pk.bytes, localSecret)` — the balance map is keyed by a hash, not the raw public key. Uses two witnesses: `getLocalSecret()` for self-queries, `getSharedSecret()` for peer queries. Key circuits: same API as `Nft` but all owner references use hash keys. | `witnesses/NftZkWitnesses.ts` | — | Advanced |

**Test mocks**: `test/mocks/MockFungibleToken.compact`, `test/mocks/MockNonFungibleToken.compact`, `test/mocks/MockMultiToken.compact`

**Test simulators**: `test/simulators/FungibleTokenSimulator.ts`, `test/simulators/NonFungibleTokenSimulator.ts`, `test/simulators/MultiTokenSimulator.ts`

---

## Math

| Name | Path | Description | Witnesses | Tests | Complexity |
|---|---|---|---|---|---|
| Uint64 | `modules/math/Uint64.compact` | Arithmetic for `Uint<64>` values. Operations: `add` (returns `Uint<128>`), `addChecked`, `sub`, `mul` (returns `Uint<128>`), `mulChecked`, `div`, `rem`, `divRem`, `sqrt`, `isMultiple`, `min`, `max`, `toBytes`, `toUnpackedBytes`. Constants: `MAX_UINT8/16/32/64`. Division and sqrt use witnesses for off-chain computation with on-chain verification. Depends on `Bytes8`. | `witnesses/wit_divUint64.ts`, `witnesses/wit_sqrtUint64.ts`, `witnesses/wit_uint64ToUnpackedBytes.ts` | `test/Uint64.test.ts` | Intermediate |
| Uint128 | `modules/math/Uint128.compact` | Arithmetic for `Uint<128>` values. Same operation set as `Uint64` but for 128-bit values. Overflow results in `U256` (from `Types`). Depends on `Bytes32`, `Types`. | `witnesses/wit_divUint128.ts`, `witnesses/wit_sqrtU128.ts` | `test/Uint128.test.ts` | Intermediate |
| Uint256 | `modules/math/Uint256.compact` | Arithmetic for 256-bit unsigned integers represented as `U256` struct (`high: Uint<128>`, `low: Uint<128>`). Operations include comparison (`lt`, `lte`, `gt`, `gte`, `eq`), arithmetic, and conversion. Depends on `Types`, `Uint128`. | `witnesses/wit_divU128.ts` | `test/Uint256.test.ts` | Advanced |
| Bytes8 | `modules/math/Bytes8.compact` | Byte-level operations for `Bytes<8>`. Converts between `Bytes<8>`, `Uint<64>`, and `Vector<8, Uint<8>>`. Circuits: `pack`, `unpack`, `toUint64`. Instantiates `Pack<8>`. Depends on `Pack`. | `witnesses/wit_unpackBytes.ts` | `test/Bytes8.test.ts` | Beginner |
| Bytes32 | `modules/math/Bytes32.compact` | Byte-level operations for `Bytes<32>`. Converts between `Bytes<32>`, `U256`, and `Vector<32, Uint<8>>`. Provides `lt` comparison via `U256`. Circuits: `pack`, `unpack`, `toU256`, `lt`. Depends on `Pack`, `Types`, `Uint256`. | `witnesses/wit_unpackBytes.ts` | `test/Bytes32.test.ts` | Intermediate |
| Field255 | `modules/math/Field255.compact` | Comparison and conversion utilities for BLS12-381 scalar `Field` elements. Conversion chain: `Field → Bytes<32> → U256`. Circuits: `MAX_FIELD`, `toBytes`, `toU256`, `eq`, `lt`, `lte`, `gt`, `gte`, `isZero`. Arithmetic not yet implemented. Depends on `Bytes32`, `Types`. | — | `test/Field255.test.ts` | Intermediate |
| Pack | `modules/math/Pack.compact` | Generic parameterized module `Pack<#N>` for packing/unpacking between `Vector<N, Uint<8>>` and `Bytes<N>`. Circuits: `pack(vec)` (pure, no witness), `unpack(bytes)` (uses `wit_unpackBytes` witness then verifies). No external dependencies. Used by `Bytes8`, `Bytes32`, and indirectly all math modules. | `witnesses/wit_unpackBytes.ts` | `test/Pack.test.ts` | Beginner |
| Types | `modules/math/Types.compact` | Shared type definitions. Exports `U128` struct (`low: Uint<64>`, `high: Uint<64>`) and `U256` struct (`low: U128`, `high: U128`). No circuits, no witnesses. Base dependency for all math modules. | — | — | Beginner |

**Test mocks**: `test/mocks/Uint64.mock.compact`, `test/mocks/Uint128.mock.compact`, `test/mocks/Uint256.mock.compact`, `test/mocks/Bytes8.mock.compact`, `test/mocks/Bytes32.mock.compact`, `test/mocks/Field255.mock.compact`, `test/mocks/Pack.mock.compact`

---

## Crypto

| Name | Path | Description | Witnesses | Tests | Complexity |
|---|---|---|---|---|---|
| schnorr | `modules/crypto/schnorr.compact` | Schnorr signature verification over the Jubjub curve (polyfill until `jubjubSchnorrVerify` is available in CompactStandardLibrary). Exports `SchnorrSignature` struct (`announcement: NativePoint`, `response: Field`). Key circuits: `schnorrVerify<#n>(msg, signature, pk)` — verifies using `ecMulGenerator`, `ecAdd`, `ecMul`; `schnorrChallenge(...)` — computes the hash challenge. Uses `getSchnorrReduction` witness to truncate the 255-bit challenge hash to 248 bits (Jubjub scalar field constraint). | `getSchnorrReduction` witness (inline declaration) | — | Advanced |
| crypto | `modules/crypto/crypto.compact` | Generic elliptic curve crypto primitives over the Pallas/Vesta curve (`CurvePoint`, not `NativePoint`). Exports structs: `Challenge`, `Nonce<T>`, `Signature`, `SignedCredential<T>`. Pure circuits: `derive_pk(sk)`, `computeChallenge<T>(r, pk, credential)`, `sign<T>(credential, sk)`, `deterministicK<T>(nonce)`, `verify<T>(credential, challenge)`. Used by `PassportIdentity` and `midnight-rwa` application. | — | — | Advanced |

---

## Data Structures

| Name | Path | Description | Witnesses | Tests | Complexity |
|---|---|---|---|---|---|
| Queue | `modules/data-structures/Queue.compact` | Generic FIFO queue `Queue<T>` using `Map<Uint<64>, T>` storage with `head` and `tail` counters. Compact's lack of variable-index `Vector` access and loop iteration required this Map-based design. Keys grow indefinitely (sparse) as head/tail increment — no shifting. Circuits: `enqueue(item)`, `dequeue()` (returns `Maybe<T>`), `isEmpty()`. O(1) enqueue and dequeue. | `witnesses/Queue.ts` | `test/queueContract.test.ts` | Intermediate |

**Test mock**: `test/mocks/Queue.mock.compact`

**Test simulator**: `test/simulators/QueueSimulator.ts`

---

## Identity

| Name | Path | Description | Witnesses | Tests | Complexity |
|---|---|---|---|---|---|
| passportidentity | `modules/identity/passportidentity.compact` | Passport data structures and challenge computation for ZK identity proofs. Exports `PassportData` struct (all ICAO MRZ fields as `Field`). Pure circuits: `computeChallengeForCredential(r, pk, credential)`, `generateDeterministicK(sk, credential)`. Wraps the generic `Crypto` module for passport-specific usage. Used by `midnight-rwa` application. | — | — | Advanced |

---

## Utils

| Name | Path | Description | Witnesses | Tests | Complexity |
|---|---|---|---|---|---|
| Utils | `modules/utils/Utils.compact` | Common utilities for `Either<ZswapCoinPublicKey, ContractAddress>` type operations. Pure circuits: `isKeyOrAddressZero`, `isKeyZero`, `isKeyOrAddressEqual`, `isContractAddress`, `emptyString`. Dependency for Ownable, AccessControl, FungibleToken, NonFungibleToken, MultiToken. | `witnesses/UtilsWitnesses.ts` | `test/utils.test.ts` | Beginner |
| ShieldedUtils | `modules/utils/ShieldedUtils.compact` | Extended utilities for shielded token contexts. Circuits: `isKeyOrAddressZero`, `zeroBytes`, `zeroZPK`, `callerZPK`, `thisAddress`, `eitherCaller`, `eitherZeroZPK`, `eitherZeroContractAddress`, `eitherZPK`, `eitherThisAddress`. Used by `ShieldedERC20` / `ShieldedFungibleToken`. | — | — | Beginner |

**Test mock**: `test/mocks/MockUtils.compact`

**Test simulator**: `test/simulators/UtilsSimulator.ts`

---

## Cross-references

- For composed token contracts that import these modules, see [tokens.md](tokens.md).
- For full applications showing how multiple modules compose at scale, see [applications.md](applications.md).
- For privacy patterns using `ZOwnablePK`, `NftZk`, `schnorr`, `crypto`, and `passportidentity`, see [privacy-and-cryptography.md](privacy-and-cryptography.md).
