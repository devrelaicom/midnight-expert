# MultiToken

An approximation of ERC-1155 written in Compact for the Midnight network. Manages multiple token types within a single contract — both fungible and non-fungible tokens can coexist.

## ERC-1155 Compatibility Notes

**Changes from ERC-1155:**
- Uses `Uint<128>` for values and IDs (256-bit not supported)

**Not supported:**
- Events (planned)
- Uint256 type (research ongoing)
- Interface enforcement
- Batch mint, burn, transfer (no dynamic array support — would require fixed-size `Vector<n>`)
- Batched balance queries (same limitation)
- Introspection / ERC-165
- Safe transfers (requires introspection)

## Usage

### Basic Multi-Token Contract

```compact
pragma language_version >= 0.22.0;

import CompactStandardLibrary;
import "./compact-contracts/node_modules/@openzeppelin-compact/contracts/src/token/MultiToken"
  prefix MultiToken_;

constructor(
  _uri: Opaque<"string">,
  recipient: Either<ZswapCoinPublicKey, ContractAddress>,
  fungibleFixedSupply: Uint<128>,
) {
  MultiToken_initialize(_uri);

  // Token id 123 = fungible (fixed supply)
  const fungibleTokenId = 123;
  MultiToken__mint(recipient, fungibleTokenId, fungibleFixedSupply);

  // Token id 987 = non-fungible (supply of 1)
  const nonFungibleTokenId = 987;
  MultiToken__mint(recipient, nonFungibleTokenId, 1);
}

export circuit uri(id: Uint<128>): Opaque<"string"> {
  return MultiToken_uri(id);
}

export circuit balanceOf(account: Either<ZswapCoinPublicKey, ContractAddress>, id: Uint<128>): Uint<128> {
  return MultiToken_balanceOf(account, id);
}

export circuit setApprovalForAll(
  operator: Either<ZswapCoinPublicKey, ContractAddress>, approved: Boolean
): [] {
  return MultiToken_setApprovalForAll(operator, approved);
}

export circuit isApprovedForAll(
  account: Either<ZswapCoinPublicKey, ContractAddress>,
  operator: Either<ZswapCoinPublicKey, ContractAddress>
): Boolean {
  return MultiToken_isApprovedForAll(account, operator);
}

export circuit transferFrom(
  fromAddress: Either<ZswapCoinPublicKey, ContractAddress>,
  to: Either<ZswapCoinPublicKey, ContractAddress>,
  id: Uint<128>, value: Uint<128>,
): [] {
  return MultiToken_transferFrom(fromAddress, to, id, value);
}
```

### URI Substitution

The URI uses the ERC-1155 token type ID substitution mechanism. The same URI is returned for all token types. Clients replace `\{id\}` in the URI with the actual token type ID.

Example: `https://token-cdn-domain/\{id\}.json` → `https://token-cdn-domain/000...04cce0.json` for token 0x4cce0.

## API Reference

### Ledger

| Name | Type | Description |
|------|------|-------------|
| `_balances` | `Map<Uint<128>, Map<Either<...>, Uint<128>>>` | Token ID → account → balance |
| `_operatorApprovals` | `Map<Either<...>, Map<Either<...>, Boolean>>` | Account → operator → approved |
| `_uri` | `Opaque<"string">` | Base URI for all token types |

### Witnesses

None.

### Circuits

| Circuit | Signature | Complexity | Description |
|---------|-----------|------------|-------------|
| `initialize` | `(uri_: Opaque<"string">) → []` | k=10, rows=45 | Set base URI. MUST call in constructor. |
| `uri` | `(id: Uint<128>) → Opaque<"string">` | k=10, rows=90 | Returns same URI for all types. Clients substitute `\{id\}`. |
| `balanceOf` | `(account: Either<...>, id: Uint<128>) → Uint<128>` | k=10, rows=439 | Balance of token type for account |
| `setApprovalForAll` | `(operator: Either<...>, approved: Boolean) → []` | k=10, rows=404 | Set operator approval. Operator must not be zero. |
| `isApprovedForAll` | `(account: Either<...>, operator: Either<...>) → Boolean` | k=10, rows=619 | Check operator approval |
| `transferFrom` | `(fromAddress: Either<...>, to: Either<...>, id: Uint<128>, value: Uint<128>) → []` | k=11, rows=1882 | Transfer. Caller must be `fromAddress` or approved. `to` must not be ContractAddress or zero. |
| `_transfer` | `(fromAddress: Either<...>, to: Either<...>, id: Uint<128>, value: Uint<128>) → []` | k=11, rows=1487 | Internal transfer. No caller check. `to` must not be ContractAddress. |
| `_unsafeTransferFrom` | `(fromAddress: Either<...>, to: Either<...>, id: Uint<128>, value: Uint<128>) → []` | k=11, rows=1881 | Unsafe: allows ContractAddress |
| `_unsafeTransfer` | `(fromAddress: Either<...>, to: Either<...>, id: Uint<128>, value: Uint<128>) → []` | k=11, rows=1486 | Unsafe variant of _transfer |
| `_setURI` | `(newURI: Opaque<"string">) → []` | k=10, rows=39 | Update base URI |
| `_mint` | `(to: Either<...>, id: Uint<128>, value: Uint<128>) → []` | k=10, rows=912 | Mint tokens. `to` must not be ContractAddress or zero. |
| `_unsafeMint` | `(to: Either<...>, id: Uint<128>, value: Uint<128>) → []` | k=10, rows=911 | Unsafe: allows ContractAddress |
| `_burn` | `(fromAddress: Either<...>, id: Uint<128>, value: Uint<128>) → []` | k=10, rows=688 | Burn tokens. `fromAddress` must not be zero, must have sufficient balance. |
| `_update` | `(fromAddress: Either<...>, to: Either<...>, id: Uint<128>, value: Uint<128>) → []` | k=11, rows=1482 | Low-level: mints if `fromAddress` is zero, burns if `to` is zero. |
| `_setApprovalForAll` | `(owner: Either<...>, operator: Either<...>, approved: Boolean) → []` | k=10, rows=518 | Internal operator approval. Operator must not be zero. |
