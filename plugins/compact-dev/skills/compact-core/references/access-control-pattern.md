---
title: Access Control Pattern
type: pattern
description: Restricting circuit execution to authorized callers using witness-provided credentials verified by assert — the standard way to implement owner-only and role-based access.
links:
  - circuit-witness-boundary
  - witness-functions
  - circuit-declarations
  - disclosure-model
  - commitment-and-nullifier-schemes
  - sealed-ledger-fields
  - cell-and-counter
---

# Access Control Pattern

Access control in Compact works fundamentally differently from Solidity or traditional smart contracts. There is no `msg.sender` available in the circuit — caller identity comes from [[witness-functions]] and must be verified against on-chain state using `assert`. The [[circuit-witness-boundary]] means witness-provided identity is untrusted until proven.

## Basic Owner Check

The simplest pattern stores an owner key and verifies the caller's proof of knowledge:

```compact
export ledger authority: Bytes<32>;
export ledger round: Counter;

witness secretKey(): Bytes<32>;

circuit publicKey(round: Field, sk: Bytes<32>): Bytes<32> {
  return persistentHash<Vector<3, Bytes<32>>>(
    [pad(32, "midnight:myapp:pk"), round as Bytes<32>, sk]);
}

circuit requireOwner(): [] {
  const sk = secretKey();
  const pk = publicKey(round as Field, sk);
  assert pk == authority "Not authorized";
}

export circuit ownerAction(): [] {
  requireOwner();
  // Only the owner can reach this point
}
```

The owner never reveals their secret key — they prove knowledge of it by deriving the public key in the circuit and comparing it against the stored value. The `round` counter allows key rotation.

## Key Rotation

The round counter enables changing the access key without redeploying:

```compact
export circuit rotateKey(): [] {
  requireOwner();                          // Proves current key
  const newSk = secretKey();               // Gets new secret
  authority = disclose(publicKey(
    (round as Field) + 1, newSk));         // Store new public key
  round.increment(1);                       // Advance round
}
```

The round is stored as a [[cell-and-counter]] Counter because it must be concurrency-safe. After rotation, the old key no longer works because `publicKey(newRound, oldSk)` produces a different hash.

## Immutable Admin with Sealed Fields

For admin keys that should never change, use [[sealed-ledger-fields]]:

```compact
sealed ledger admin: Bytes<32>;

constructor(adminKey: Bytes<32>) {
  admin = disclose(adminKey);
}
```

This provides a compile-time guarantee of immutability — stronger than any runtime check.

## Role-Based Access

For multiple roles, use a Map of role identifiers to authorized keys:

```compact
export ledger roles: Map<Bytes<32>, Bytes<32>>;  // role → public key

witness getCallerKey(): Bytes<32>;

circuit requireRole(role: Bytes<32>): [] {
  const callerPk = disclose(getCallerKey());
  const authorizedPk = roles.lookup(role);
  assert callerPk == authorizedPk "Not authorized for this role";
}
```

## Privacy-Preserving Access Control

For anonymous authorization (proving membership in an authorized group without revealing identity), combine access control with [[commitment-and-nullifier-schemes]] and Merkle tree membership proofs. The caller proves they are in the authorized set without revealing which member they are — this is the [[anonymous-membership-proof]] pattern applied to access control.

## Common Mistakes

**Trusting the witness without validation:**
```compact
// WRONG: No assert — any DApp can claim to be the owner
witness isOwner(): Boolean;
export circuit action(): [] {
  if (isOwner()) { ... }  // Any value can be provided
}
```

**Fix:** Always `assert` witness-provided credentials against on-chain state. The [[circuit-witness-boundary]] means witnesses are untrusted by default.
