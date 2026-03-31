# Utils

Provides miscellaneous circuits and common utilities for Compact contract development. Focused on address comparison and type checking operations.

## Usage

```compact
pragma language_version >= 0.22.0;

import CompactStandardLibrary;
import './compact-contracts/node_modules/@openzeppelin-compact/contracts/src/utils/Utils'
  prefix Utils_;

export circuit performActionWhenEqual(
  a: Either<ZswapCoinPublicKey, ContractAddress>,
  b: Either<ZswapCoinPublicKey, ContractAddress>,
): [] {
  const isEqual = Utils_isKeyOrAddressEqual(a, b);
  if (isEqual) {
    // Do something when addresses match
  } else {
    // Do something else
  }
}

export circuit validateNotZero(
  addr: Either<ZswapCoinPublicKey, ContractAddress>,
): [] {
  const isZero = Utils_isKeyOrAddressZero(addr);
  assert(!isZero, "Address must not be zero");
}

export circuit onlyUsers(
  addr: Either<ZswapCoinPublicKey, ContractAddress>,
): [] {
  const isContract = Utils_isContractAddress(addr);
  assert(!isContract, "Contracts not allowed");
}
```

## Zero Address Convention

Midnight's burn address is represented as `left<ZswapCoinPublicKey, ContractAddress>(default<ZswapCoinPublicKey>)` in Compact. The Utils module uses this same representation as the "zero address".

## API Reference

### Ledger

None.

### Witnesses

None.

### Circuits

| Circuit | Signature | Description |
|---------|-----------|-------------|
| `isKeyOrAddressZero` | `(keyOrAddress: Either<ZswapCoinPublicKey, ContractAddress>) → Boolean` | Returns whether the value is the zero address |
| `isKeyZero` | `(key: ZswapCoinPublicKey) → Boolean` | Returns whether the key is the zero address |
| `isKeyOrAddressEqual` | `(keyOrAddress: Either<...>, other: Either<...>) → Boolean` | Returns whether two addresses are equal. Assumes ZswapCoinPublicKey and ContractAddress can never be equal. |
| `isContractAddress` | `(keyOrAddress: Either<ZswapCoinPublicKey, ContractAddress>) → Boolean` | Returns whether the value is a ContractAddress type |
| `emptyString` | `() → Opaque<"string">` | Returns the empty string `""` |

> Note: Circuit complexity constraints are not available for Utils circuits at this time.
