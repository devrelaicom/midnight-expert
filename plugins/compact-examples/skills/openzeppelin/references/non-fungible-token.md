# NonFungibleToken

An approximation of ERC-721 written in Compact for the Midnight network. Each token is unique and distinct.

## ERC-721 Compatibility Notes

**Changes from ERC-721:**
- Uses `Uint<128>` for tokenIds (256-bit not supported)
- No `_baseURI()` support — native string concatenation not available. Uses URI storage approach instead where each NFT can have a unique URI.

**Not supported:**
- Events (planned)
- Uint256 type (research ongoing)
- Interface enforcement
- ERC-165 standard interface detection
- Safe transfers (requires ERC-165)

## Contract-to-Contract Limitations

Transfers and mints to `ContractAddress` are disallowed in safe circuits. `_unsafe*` variants exist for experimentation.

## Usage

### Simple NFT Contract

```compact
pragma language_version >= 0.21.0;

import CompactStandardLibrary;
import "./compact-contracts/node_modules/@openzeppelin-compact/contracts/src/token/NonFungibleToken"
  prefix NonFungibleToken_;

constructor(
  name: Opaque<"string">, symbol: Opaque<"string">,
  recipient: Either<ZswapCoinPublicKey, ContractAddress>,
  tokenURI: Opaque<"string">,
) {
  const tokenId = 1 as Uint<128>;
  NonFungibleToken_initialize(name, symbol);
  NonFungibleToken__mint(recipient, tokenId);
  NonFungibleToken__setTokenURI(tokenId, tokenURI);
}

export circuit balanceOf(owner: Either<ZswapCoinPublicKey, ContractAddress>): Uint<128> {
  return NonFungibleToken_balanceOf(owner);
}

export circuit ownerOf(tokenId: Uint<128>): Either<ZswapCoinPublicKey, ContractAddress> {
  return NonFungibleToken_ownerOf(tokenId);
}

export circuit name(): Opaque<"string"> { return NonFungibleToken_name(); }
export circuit symbol(): Opaque<"string"> { return NonFungibleToken_symbol(); }

export circuit tokenURI(tokenId: Uint<128>): Opaque<"string"> {
  return NonFungibleToken_tokenURI(tokenId);
}

export circuit approve(to: Either<ZswapCoinPublicKey, ContractAddress>, tokenId: Uint<128>): [] {
  NonFungibleToken_approve(to, tokenId);
}

export circuit getApproved(tokenId: Uint<128>): Either<ZswapCoinPublicKey, ContractAddress> {
  return NonFungibleToken_getApproved(tokenId);
}

export circuit setApprovalForAll(
  operator: Either<ZswapCoinPublicKey, ContractAddress>, approved: Boolean
): [] {
  NonFungibleToken_setApprovalForAll(operator, approved);
}

export circuit isApprovedForAll(
  owner: Either<ZswapCoinPublicKey, ContractAddress>,
  operator: Either<ZswapCoinPublicKey, ContractAddress>
): Boolean {
  return NonFungibleToken_isApprovedForAll(owner, operator);
}

export circuit transferFrom(
  from: Either<ZswapCoinPublicKey, ContractAddress>,
  to: Either<ZswapCoinPublicKey, ContractAddress>,
  tokenId: Uint<128>
): [] {
  NonFungibleToken_transferFrom(from, to, tokenId);
}
```

## API Reference

### Ledger

| Name | Type | Description |
|------|------|-------------|
| `_name` | `Opaque<"string">` (sealed) | Immutable token name |
| `_symbol` | `Opaque<"string">` (sealed) | Immutable token symbol |
| `_owners` | `Map<Uint<128>, Either<...>>` | Token ID → owner mapping |
| `_balances` | `Map<Either<...>, Uint<128>>` | Account → token count |
| `_tokenApprovals` | `Map<Uint<128>, Either<...>>` | Token ID → approved address |
| `_operatorApprovals` | `Map<Either<...>, Map<Either<...>, Boolean>>` | Owner → operator → approved |
| `_tokenURIs` | `Map<Uint<128>, Opaque<"string">>` | Token ID → metadata URI |

### Witnesses

None.

### Circuits

| Circuit | Signature | Complexity | Description |
|---------|-----------|------------|-------------|
| `initialize` | `(name_: Opaque<"string">, symbol_: Opaque<"string">) → []` | k=10, rows=65 | Initialize name and symbol. MUST call in constructor. |
| `balanceOf` | `(owner: Either<...>) → Uint<128>` | k=10, rows=309 | Token count for owner |
| `ownerOf` | `(tokenId: Uint<128>) → Either<...>` | k=10, rows=290 | Owner of token. Token must exist. |
| `name` | `() → Opaque<"string">` | k=10, rows=36 | Returns name |
| `symbol` | `() → Opaque<"string">` | k=10, rows=36 | Returns symbol |
| `tokenURI` | `(tokenId: Uint<128>) → Opaque<"string">` | k=10, rows=296 | Returns URI. Empty if none set. Token must exist. |
| `_setTokenURI` | `(tokenId: Uint<128>, tokenURI: Opaque<"string">) → []` | k=10, rows=253 | Set URI. Token must exist. |
| `approve` | `(to: Either<...>, tokenId: Uint<128>) → []` | k=10, rows=966 | Approve transfer. Caller must own or be operator. |
| `getApproved` | `(tokenId: Uint<128>) → Either<...>` | k=10, rows=409 | Get approved for token. Token must exist. |
| `setApprovalForAll` | `(operator: Either<...>, approved: Boolean) → []` | k=10, rows=409 | Set operator approval |
| `isApprovedForAll` | `(owner: Either<...>, operator: Either<...>) → Boolean` | k=10, rows=621 | Check operator approval |
| `transferFrom` | `(from: Either<...>, to: Either<...>, tokenId: Uint<128>) → []` | k=11, rows=1966 | Transfer. `to` must not be ContractAddress or zero. Token must be owned by `from`. Caller must be authorized. |
| `_unsafeTransferFrom` | `(from: Either<...>, to: Either<...>, tokenId: Uint<128>) → []` | k=11, rows=1963 | Unsafe variant allowing ContractAddress |
| `_ownerOf` | `(tokenId: Uint<128>) → Either<...>` | k=10, rows=253 | Owner without revert |
| `_getApproved` | `(tokenId: Uint<128>) → Either<...>` | k=10, rows=253 | Approved without revert |
| `_isAuthorized` | `(owner: Either<...>, spender: Either<...>, tokenId: Uint<128>) → Boolean` | k=11, rows=1098 | Check authorization |
| `_checkAuthorized` | `(owner: Either<...>, spender: Either<...>, tokenId: Uint<128>) → []` | k=11, rows=1121 | Revert if not authorized |
| `_mint` | `(to: Either<...>, tokenId: Uint<128>) → []` | k=10, rows=1013 | Mint. Token must not exist. `to` not ContractAddress or zero. |
| `_unsafeMint` | `(to: Either<...>, tokenId: Uint<128>) → []` | k=10, rows=1010 | Unsafe: allows ContractAddress |
| `_burn` | `(tokenId: Uint<128>) → []` | k=10, rows=479 | Burn. Clears approval. Token must exist. |
| `_transfer` | `(from: Either<...>, to: Either<...>, tokenId: Uint<128>) → []` | k=11, rows=1224 | Internal transfer. No caller check. |
| `_unsafeTransfer` | `(from: Either<...>, to: Either<...>, tokenId: Uint<128>) → []` | k=11, rows=1221 | Unsafe variant |
| `_approve` | `(to: Either<...>, tokenId: Uint<128>, auth: Either<...>) → []` | k=11, rows=1109 | Internal approve with auth check |
| `_setApprovalForAll` | `(owner: Either<...>, operator: Either<...>, approved: Boolean) → []` | k=10, rows=524 | Internal operator approval |
| `_requireOwned` | `(tokenId: Uint<128>) → Either<...>` | k=10, rows=288 | Revert if token doesn't exist. Returns owner. |
