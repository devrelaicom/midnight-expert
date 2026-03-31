# AccessControl

Role-based access control mechanism where roles represent sets of permissions, providing flexibility to create different levels of account authorization.

## Overview

While Ownable is sufficient for single-admin contracts, AccessControl offers granular permissions through multiple roles. Each role:
- Is identified by a `Bytes<32>` value (typically a hash)
- Can be granted to and revoked from accounts
- Has an admin role that controls who can grant/revoke it
- Defaults to `DEFAULT_ADMIN_ROLE` as its admin

## Usage

### Defining Roles

Roles are defined as sealed ledger values initialized with hash digests:

```compact
pragma language_version >= 0.22.0;

import CompactStandardLibrary;
import "./compact-contracts/node_modules/@openzeppelin-compact/contracts/src/access/AccessControl"
  prefix AccessControl_;
import "./compact-contracts/node_modules/@openzeppelin-compact/contracts/src/token/FungibleToken"
  prefix FungibleToken_;

export sealed ledger MINTER_ROLE: Bytes<32>;
export sealed ledger BURNER_ROLE: Bytes<32>;

constructor(
  name: Opaque<"string">, symbol: Opaque<"string">, decimals: Uint<8>,
  minter: Either<ZswapCoinPublicKey, ContractAddress>,
  burner: Either<ZswapCoinPublicKey, ContractAddress>
) {
  FungibleToken_initialize(name, symbol, decimals);
  MINTER_ROLE = persistentHash<Bytes<32>>(pad(32, "MINTER_ROLE"));
  BURNER_ROLE = persistentHash<Bytes<32>>(pad(32, "BURNER_ROLE"));
  AccessControl__grantRole(MINTER_ROLE, minter);
  AccessControl__grantRole(BURNER_ROLE, burner);
}

export circuit mint(recipient: Either<ZswapCoinPublicKey, ContractAddress>, value: Uint<128>): [] {
  AccessControl_assertOnlyRole(MINTER_ROLE);
  FungibleToken__mint(recipient, value);
}

export circuit burn(recipient: Either<ZswapCoinPublicKey, ContractAddress>, value: Uint<128>): [] {
  AccessControl_assertOnlyRole(BURNER_ROLE);
  FungibleToken__burn(recipient, value);
}
```

### Using DEFAULT_ADMIN_ROLE

Grant the deployer the default admin role for dynamic role management:

```compact
constructor(
  name: Opaque<"string">, symbol: Opaque<"string">, decimals: Uint<8>,
) {
  FungibleToken_initialize(name, symbol, decimals);
  MINTER_ROLE = persistentHash<Bytes<32>>(pad(32, "MINTER_ROLE"));
  BURNER_ROLE = persistentHash<Bytes<32>>(pad(32, "BURNER_ROLE"));
  // Grant deployer admin role — they can grant/revoke any role
  AccessControl__grantRole(
    AccessControl_DEFAULT_ADMIN_ROLE,
    left<ZswapCoinPublicKey, ContractAddress>(ownPublicKey())
  );
}
```

Now the admin can dynamically grant/revoke minter and burner roles using `grantRole` and `revokeRole` without needing them assigned at construction time.

### Granting and Revoking Roles

By default, accounts with a role cannot grant it or revoke it from other accounts. Only accounts with the role's admin role can call `grantRole` and `revokeRole`.

Complex role hierarchies can be created using `_setRoleAdmin`:
```compact
// Set MINTER_ADMIN as the admin for MINTER_ROLE
AccessControl__setRoleAdmin(MINTER_ROLE, MINTER_ADMIN);
```

### Experimental: _unsafeGrantRole

Allows granting roles to contract addresses. Unsafe because contract-to-contract calls are not supported. Will be deprecated.

## API Reference

### Ledger

| Name | Type | Description |
|------|------|-------------|
| `_operatorRoles` | `Map<Bytes<32>, Map<Either<ZswapCoinPublicKey, ContractAddress>, Boolean>>` | Role → account → permission mapping |
| `_adminRoles` | `Map<Bytes<32>, Bytes<32>>` | Role → admin role mapping |
| `DEFAULT_ADMIN_ROLE` | `Bytes<32>` | Default admin role (zero bytes) |

### Witnesses

None.

### Circuits

| Circuit | Signature | Complexity | Description |
|---------|-----------|------------|-------------|
| `hasRole` | `(roleId: Bytes<32>, account: Either<...>) → Boolean` | k=10, rows=487 | Check if account has role |
| `assertOnlyRole` | `(roleId: Bytes<32>) → []` | k=10, rows=345 | Revert if caller missing role. Caller must not be ContractAddress. |
| `_checkRole` | `(roleId: Bytes<32>, account: Either<...>) → []` | k=10, rows=467 | Revert if account missing role |
| `getRoleAdmin` | `(roleId: Bytes<32>) → Bytes<32>` | k=10, rows=207 | Get admin role for a role |
| `grantRole` | `(roleId: Bytes<32>, account: Either<...>) → []` | k=10, rows=994 | Grant role. Caller must have admin role. Account must not be ContractAddress. |
| `revokeRole` | `(roleId: Bytes<32>, account: Either<...>) → []` | k=10, rows=827 | Revoke role. Caller must have admin role. |
| `renounceRole` | `(roleId: Bytes<32>, callerConfirmation: Either<...>) → []` | k=10, rows=640 | Self-revoke role. Caller must match callerConfirmation. Not for contracts. |
| `_setRoleAdmin` | `(roleId: Bytes<32>, adminRole: Bytes<32>) → []` | k=10, rows=209 | Set admin role for a role |
| `_grantRole` | `(roleId: Bytes<32>, account: Either<...>) → Boolean` | k=10, rows=734 | Internal grant. No caller check. Account must not be ContractAddress. |
| `_unsafeGrantRole` | `(roleId: Bytes<32>, account: Either<...>) → Boolean` | k=10, rows=733 | Unsafe: allows ContractAddress |
| `_revokeRole` | `(roleId: Bytes<32>, account: Either<...>) → Boolean` | k=10, rows=563 | Internal revoke. No caller check. |
