# FungibleToken

An approximation of ERC-20 written in Compact for the Midnight network. All token units are exactly equal to each other.

## ERC-20 Compatibility Notes

**Changes from ERC-20:**
- Uses `Uint<128>` instead of `uint256` (256-bit integers not supported in Compact)

**Not supported:**
- Events (planned for future Midnight support)
- Uint256 type (ongoing research)
- Interface enforcement (Compact has no interface mechanism)

## Contract-to-Contract Limitations

Transfers and mints to `ContractAddress` are disallowed in safe circuits. Tokens sent to a contract may be locked forever. Use `_unsafe*` variants to experiment with contract recipients (will be deprecated when contract-to-contract calls are supported).

## Usage

### Basic Import and Setup

```compact
pragma language_version >= 0.18.0;

import CompactStandardLibrary;
import "./compact-contracts/node_modules/@openzeppelin-compact/contracts/src/token/FungibleToken"
  prefix FungibleToken_;

constructor(name: Opaque<"string">, symbol: Opaque<"string">, decimals: Uint<8>) {
  FungibleToken_initialize(name, symbol, decimals);
}
```

### Fixed Supply Token

```compact
constructor(
  name: Opaque<"string">, symbol: Opaque<"string">, decimals: Uint<8>,
  recipient: Either<ZswapCoinPublicKey, ContractAddress>,
  fixedSupply: Uint<128>,
) {
  FungibleToken_initialize(name, symbol, decimals);
  FungibleToken__mint(recipient, fixedSupply);
}

export circuit name(): Opaque<"string"> { return FungibleToken_name(); }
export circuit symbol(): Opaque<"string"> { return FungibleToken_symbol(); }
export circuit decimals(): Uint<8> { return FungibleToken_decimals(); }
export circuit totalSupply(): Uint<128> { return FungibleToken_totalSupply(); }

export circuit balanceOf(account: Either<ZswapCoinPublicKey, ContractAddress>): Uint<128> {
  return FungibleToken_balanceOf(account);
}

export circuit allowance(
  owner: Either<ZswapCoinPublicKey, ContractAddress>,
  spender: Either<ZswapCoinPublicKey, ContractAddress>
): Uint<128> {
  return FungibleToken_allowance(owner, spender);
}

export circuit transfer(to: Either<ZswapCoinPublicKey, ContractAddress>, value: Uint<128>): Boolean {
  return FungibleToken_transfer(to, value);
}

export circuit transferFrom(
  from: Either<ZswapCoinPublicKey, ContractAddress>,
  to: Either<ZswapCoinPublicKey, ContractAddress>,
  value: Uint<128>,
): Boolean {
  return FungibleToken_transferFrom(from, to, value);
}

export circuit approve(spender: Either<ZswapCoinPublicKey, ContractAddress>, value: Uint<128>): Boolean {
  return FungibleToken_approve(spender, value);
}
```

### Important: Public circuits require access control

Circuits prefixed with `_` (like `_mint`, `_burn`) are building blocks. Exposing `_mint` without access control allows ANYONE to mint tokens. Always protect with Ownable or AccessControl:

```compact
export circuit mint(account: Either<ZswapCoinPublicKey, ContractAddress>, value: Uint<128>): [] {
  Ownable_assertOnlyOwner();  // or AccessControl_assertOnlyRole(MINTER_ROLE);
  FungibleToken__mint(account, value);
}
```

## API Reference

### Ledger

| Name | Type | Description |
|------|------|-------------|
| `_balances` | `Map<Either<ZswapCoinPublicKey, ContractAddress>, Uint<128>>` | Account balances |
| `_allowances` | `Map<Either<...>, Map<Either<...>, Uint<128>>>` | Owner → spender → allowance |
| `_totalSupply` | `Uint<128>` | Total token supply |
| `_name` | `Opaque<"string">` (sealed) | Immutable token name |
| `_symbol` | `Opaque<"string">` (sealed) | Immutable token symbol |
| `_decimals` | `Uint<8>` (sealed) | Immutable token decimals |

### Witnesses

None.

### Circuits

| Circuit | Signature | Complexity | Description |
|---------|-----------|------------|-------------|
| `initialize` | `(name_: Opaque<"string">, symbol_: Opaque<"string">, decimals_: Uint<8>) → []` | k=10, rows=71 | Initialize name, symbol, decimals. MUST be called in constructor. |
| `name` | `() → Opaque<"string">` | k=10, rows=37 | Returns token name |
| `symbol` | `() → Opaque<"string">` | k=10, rows=37 | Returns token symbol |
| `decimals` | `() → Uint<8>` | k=10, rows=36 | Returns decimals |
| `totalSupply` | `() → Uint<128>` | k=10, rows=36 | Returns total supply |
| `balanceOf` | `(account: Either<...>) → Uint<128>` | k=10, rows=310 | Returns account balance |
| `transfer` | `(to: Either<...>, value: Uint<128>) → Boolean` | k=11, rows=1173 | Transfer tokens. `to` must not be ContractAddress or zero. Caller must have sufficient balance. |
| `_unsafeTransfer` | `(to: Either<...>, value: Uint<128>) → Boolean` | k=11, rows=1170 | Unsafe: allows ContractAddress recipients |
| `allowance` | `(owner: Either<...>, spender: Either<...>) → Uint<128>` | k=10, rows=624 | Returns spender's allowance over owner's tokens |
| `approve` | `(spender: Either<...>, value: Uint<128>) → Boolean` | k=10, rows=452 | Set allowance. Spender must not be zero. |
| `transferFrom` | `(from: Either<...>, to: Either<...>, value: Uint<128>) → Boolean` | k=11, rows=1821 | Transfer with allowance. `to` must not be ContractAddress. Deducts from allowance. |
| `_unsafeTransferFrom` | `(from: Either<...>, to: Either<...>, value: Uint<128>) → Boolean` | k=11, rows=1818 | Unsafe: allows ContractAddress recipients |
| `_transfer` | `(from: Either<...>, to: Either<...>, value: Uint<128>) → []` | k=11, rows=1312 | Internal transfer. No caller check. `to` must not be ContractAddress. |
| `_unsafeUncheckedTransfer` | `(from: Either<...>, to: Either<...>, value: Uint<128>) → []` | k=11, rows=1309 | Unsafe variant of _transfer |
| `_mint` | `(account: Either<...>, value: Uint<128>) → []` | k=10, rows=752 | Create tokens. Account must not be ContractAddress or zero. |
| `_unsafeMint` | `(account: Either<...>, value: Uint<128>) → []` | k=10, rows=749 | Unsafe: allows ContractAddress |
| `_burn` | `(account: Either<...>, value: Uint<128>) → []` | k=10, rows=773 | Destroy tokens. Account must not be zero, must have sufficient balance. |
| `_approve` | `(owner: Either<...>, spender: Either<...>, value: Uint<128>) → []` | k=10, rows=583 | Internal approve. Neither zero. |
| `_spendAllowance` | `(owner: Either<...>, spender: Either<...>, value: Uint<128>) → []` | k=10, rows=931 | Deduct from allowance. Infinite allowance (MAX_UINT128) is not consumed. |
