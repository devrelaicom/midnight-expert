# Ownable & ZOwnablePK

## Ownable

The most common form of access control: a single owner account that can perform administrative tasks.

### Usage

```compact
pragma language_version >= 0.18.0;

import CompactStandardLibrary;
import "./compact-contracts/node_modules/@openzeppelin-compact/contracts/src/access/Ownable"
  prefix Ownable_;

constructor(initialOwner: Either<ZswapCoinPublicKey, ContractAddress>) {
  Ownable_initialize(initialOwner);
}

// Protect sensitive circuits
export circuit mySensitiveCircuit(): [] {
  Ownable_assertOnlyOwner();
  // Do something
}

// Expose ownership management
export circuit owner(): Either<ZswapCoinPublicKey, ContractAddress> {
  return Ownable_owner();
}

export circuit transferOwnership(newOwner: Either<ZswapCoinPublicKey, ContractAddress>): [] {
  Ownable_transferOwnership(newOwner);
}

export circuit renounceOwnership(): [] {
  Ownable_renounceOwnership();
}
```

### Ownership Transfers

Ownership can only be transferred to `ZswapCoinPublicKey` through the safe transfer circuits. Transfers to `ContractAddress` are disallowed because Compact does not yet support contract-to-contract calls — if a contract is granted ownership, the owner contract cannot directly call the protected circuit.

### Experimental Unsafe Circuits

`_unsafeTransferOwnership` and `_unsafeUncheckedTransferOwnership` allow ownership to be granted to contract addresses. These will be deprecated once contract-to-contract calls are supported.

### Ownable API Reference

#### Ledger

| Name | Type | Description |
|------|------|-------------|
| `_owner` | `Either<ZswapCoinPublicKey, ContractAddress>` | The current owner |

#### Witnesses

None.

#### Circuits

| Circuit | Signature | Complexity | Description |
|---------|-----------|------------|-------------|
| `initialize` | `(initialOwner: Either<ZswapCoinPublicKey, ContractAddress>) → []` | k=10, rows=258 | Set initial owner. Must be called in constructor. Requires: not already initialized, not a ContractAddress, not zero address. |
| `owner` | `() → Either<ZswapCoinPublicKey, ContractAddress>` | k=10, rows=84 | Returns current owner. Requires: initialized. |
| `transferOwnership` | `(newOwner: Either<ZswapCoinPublicKey, ContractAddress>) → []` | k=10, rows=338 | Transfer ownership. Requires: initialized, caller is owner, newOwner not ContractAddress, not zero. |
| `_unsafeTransferOwnership` | `(newOwner: Either<ZswapCoinPublicKey, ContractAddress>) → []` | k=10, rows=335 | Unsafe variant allowing ContractAddress. Requires: initialized, caller is owner, not zero. |
| `renounceOwnership` | `() → []` | k=10, rows=124 | Remove owner permanently. Requires: initialized, caller is owner. |
| `assertOnlyOwner` | `() → []` | k=10, rows=115 | Revert if caller is not owner. Requires: initialized, caller is owner. |
| `_transferOwnership` | `(newOwner: Either<ZswapCoinPublicKey, ContractAddress>) → []` | k=10, rows=219 | Transfer without caller permission check. Requires: initialized, not ContractAddress. |
| `_unsafeUncheckedTransferOwnership` | `(newOwner: Either<ZswapCoinPublicKey, ContractAddress>) → []` | k=10, rows=216 | Unsafe variant of _transferOwnership. Requires: initialized. |

---

## ZOwnablePK — Shielded Ownership

Privacy-preserving access control where the owner's public key is never revealed on-chain. The contract stores only a cryptographic commitment that proves ownership without exposing the underlying identity.

### Commitment Scheme

**Owner ID**: `id = SHA256(pk, nonce)` where pk is the owner's public key and nonce is a secret value.

**Owner Commitment**: `commitment = SHA256(id, instanceSalt, counter, pad(32, "ZOwnablePK:shield:"))` where:
- `id`: privacy-preserving owner identifier
- `instanceSalt`: unique per-deployment salt preventing cross-contract collisions
- `counter`: incremented with each transfer for unlinkability
- Domain separator: padded to 32 bytes

### Nonce Generation Strategies

**Random Nonce** (strongest privacy):
```typescript
const randomNonce = crypto.getRandomValues(new Uint8Array(32));
const ownerId = ZOwnablePK._computeOwnerId(publicKey, randomNonce);
```
Requires secure backup of both private key and nonce. Loss = permanent loss of ownership.

**Deterministic Nonce** (recoverable):
```typescript
import { scryptSync } from 'node:crypto';
const deterministicNonce = scryptSync(
  userPassphrase,
  publicKey + ":ZOwnablePK:nonce:v1",
  32,
  { N: 16384, r: 8, p: 1 }
);
```

### Air-Gapped Public Key (AGPK)

For maximum privacy, use a dedicated key exclusively for contract ownership:
- Never used before on any blockchain
- Never used elsewhere during its lifetime
- Never used again after ownership transfer/renunciation

### Usage

```compact
pragma language_version >= 0.18.0;

import CompactStandardLibrary;
import "./compact-contracts/node_modules/@openzeppelin-compact/contracts/src/access/ZOwnablePK"
  prefix ZOwnablePK_;

constructor(initOwnerCommitment: Bytes<32>, instanceSalt: Bytes<32>) {
  ZOwnablePK_initialize(initOwnerCommitment, instanceSalt);
}

export circuit owner(): Bytes<32> { return ZOwnablePK_owner(); }

export circuit transferOwnership(newOwnerCommitment: Bytes<32>): [] {
  return ZOwnablePK_transferOwnership(disclose(newOwnerCommitment));
}

export circuit renounceOwnership(): [] { return ZOwnablePK_renounceOwnership(); }

export circuit mySensitiveCircuit(): [] {
  ZOwnablePK_assertOnlyOwner();
  // Do something
}
```

### Computing Owner ID Off-Chain

```typescript
import { CompactTypeBytes, CompactTypeVector, persistentHash } from '@midnight-ntwrk/compact-runtime';
import { getRandomValues } from 'node:crypto';

const generateId = (pk: Uint8Array, nonce: Uint8Array): Uint8Array => {
  const rt_type = new CompactTypeVector(2, new CompactTypeBytes(32));
  return persistentHash(rt_type, [pk, nonce]);
};

const generateInstanceSalt = (): Uint8Array => getRandomValues(new Uint8Array(32));
```

### ZOwnablePK API Reference

#### Ledger

| Name | Type | Description |
|------|------|-------------|
| `_ownerCommitment` | `Bytes<32>` | Hashed commitment representing the owner. Zero = unowned. |
| `_counter` | `Counter` | Internal transfer counter for commitment uniqueness. |
| `_instanceSalt` | `Bytes<32>` (sealed) | Per-instance salt for namespacing commitments. Immutable. |

#### Witnesses

| Name | Signature | Description |
|------|-----------|-------------|
| `wit_secretNonce` | `() → Bytes<32>` | Private nonce for deriving shielded owner identity. Combined with public key as SHA256(pk, nonce). |

#### Circuits

| Circuit | Signature | Complexity | Description |
|---------|-----------|------------|-------------|
| `initialize` | `(ownerId: Bytes<32>, instanceSalt: Bytes<32>) → []` | k=14, rows=14933 | Set initial owner via precomputed ownerId and instanceSalt. ownerId MUST use SHA256. |
| `owner` | `() → Bytes<32>` | k=10, rows=57 | Returns current commitment. |
| `transferOwnership` | `(newOwnerId: Bytes<32>) → []` | k=16, rows=39240 | Transfer to new owner. Caller must be current owner. |
| `renounceOwnership` | `() → []` | k=15, rows=24442 | Remove owner permanently. |
| `assertOnlyOwner` | `() → []` | k=15, rows=24437 | Revert if caller's SHA256(pk, nonce) doesn't match stored commitment. |
| `_computeOwnerCommitment` | `(id: Bytes<32>, counter: Uint<64>) → Bytes<32>` | k=14, rows=14853 | Compute commitment from id and counter. |
| `_computeOwnerId` | `(pk: Either<ZswapCoinPublicKey, ContractAddress>, nonce: Bytes<32>) → Bytes<32>` | — | Compute id = SHA256(pk, nonce). Currently ZswapCoinPublicKey only. |
| `_transferOwnership` | `(newOwnerId: Bytes<32>) → []` | k=14, rows=14823 | Transfer without caller permission check. |
