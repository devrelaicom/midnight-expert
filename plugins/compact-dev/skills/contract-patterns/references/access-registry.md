# Access Registry Pattern Deep-Dive

Complete guide to implementing role-based access control with Merkle proofs on Midnight.

## Overview

The access registry pattern enables:
- **Role hierarchy**: Nested roles with inheritance
- **Merkle proof verification**: Gas-efficient membership checks
- **Dynamic permissions**: Add/remove roles at runtime
- **Privacy-preserving access**: Prove membership without revealing identity

## Architecture

```
┌─────────────────────────────────────────┐
│            registry.compact             │
│                                         │
│  ┌─────────────┐    ┌────────────────┐  │
│  │   Roles     │───▶│  Permissions   │  │
│  │             │    │                │  │
│  │ - Admin     │    │ - canMint      │  │
│  │ - Operator  │    │ - canBurn      │  │
│  │ - User      │    │ - canTransfer  │  │
│  └─────────────┘    └────────────────┘  │
│                                         │
│  ┌─────────────────────────────────┐    │
│  │      Merkle Membership         │    │
│  │                                 │    │
│  │  Root Hash ◄── Proof Path      │    │
│  │       │                        │    │
│  │     [H01]  [H23]              │    │
│  │     /  \    /  \               │    │
│  │   [A] [B] [C] [D]  ◄── Members│    │
│  └─────────────────────────────────┘    │
└─────────────────────────────────────────┘
```

## Key Components

### 1. Role Definition

```compact
// Role hierarchy with permission inheritance
enum Role {
  None, // No access
  User, // Basic access
  Operator,  // Extended access
  Admin // Full access
}

// Permission flags
struct Permissions {
  canRead: Boolean,
  canWrite: Boolean,
  canDelete: Boolean,
  canGrant: Boolean,
  canRevoke: Boolean
}

// Role to permissions mapping
ledger rolePermissions: Map<Role, Permissions>;
```

### 2. Merkle Membership

```compact
// Store only root hash for gas efficiency
ledger membershipRoots: Map<Role, Bytes<32>>;
ledger membershipVersions: Map<Role, Uint<64>>;

export circuit verifyMembership(
  witness member: Bytes<32>,
  witness proof: Vector<Bytes<32>>,
  witness proofFlags: Vector<Boolean>,
  role: Role
): Boolean {
  // Compute leaf from member
  const leaf = hash(member);

  // Walk up the Merkle tree
  var current = leaf;
  for i in 0..proof.length {
    if proofFlags[i] {
      current = hash(proof[i], current);
    } else {
      current = hash(current, proof[i]);
    }
  }

  // Verify against stored root
  return current == membershipRoots[role];
}
```

### 3. Role Management

```compact
ledger adminCommitment: Cell<Bytes<32>>;

export circuit grantRole(
  witness adminSecret: Bytes<32>,
  member: Bytes<32>,
  role: Role,
  newRoot: Bytes<32>
): Void {
  // Verify admin authority
  assert hash(adminSecret) == adminCommitment.value;

  // Update membership root
  membershipRoots[role] = newRoot;
  membershipVersions[role] = membershipVersions[role] + 1;
}

export circuit revokeRole(
  witness adminSecret: Bytes<32>,
  role: Role,
  newRoot: Bytes<32>
): Void {
  // Verify admin authority
  assert hash(adminSecret) == adminCommitment.value;

  // Update membership root (excluding revoked member)
  membershipRoots[role] = newRoot;
  membershipVersions[role] = membershipVersions[role] + 1;
}
```

### 4. Permission Checks

```compact
export circuit checkPermission(
  witness memberSecret: Bytes<32>,
  witness proof: Vector<Bytes<32>>,
  witness proofFlags: Vector<Boolean>,
  role: Role,
  permission: PermissionType
): Boolean {
  // Verify membership
  const member = hash(memberSecret);
  assert verifyMembership(member, proof, proofFlags, role);

  // Check permission for role
  const perms = rolePermissions[role];

  match permission {
    PermissionType.Read => perms.canRead,
    PermissionType.Write => perms.canWrite,
    PermissionType.Delete => perms.canDelete,
    PermissionType.Grant => perms.canGrant,
    PermissionType.Revoke => perms.canRevoke
  }
}
```

## Role Hierarchy Examples

### Simple Hierarchy

```
Admin
  ├── canRead, canWrite, canDelete, canGrant, canRevoke
  │
  ▼
Operator
  ├── canRead, canWrite, canDelete
  │
  ▼
User
  └── canRead
```

### Complex Hierarchy

```
SuperAdmin ─────────────────────┐
    │                           │
    ▼                           ▼
ContentAdmin              FinanceAdmin
    │                           │
    ▼                           ▼
ContentModerator            Accountant
    │                           │
    └───────────┬───────────────┘
                │
                ▼
              User
```

## Privacy Features

### Anonymous Role Verification

```compact
// Prove role membership without revealing identity
export circuit proveRoleAnonymously(
  witness identity: Bytes<32>,
  witness randomness: Bytes<32>,
  witness merkleProof: Vector<Bytes<32>>,
  role: Role
): Bytes<32> {
  // Compute nullifier for this verification
  const nullifier = hash(identity, "role-check", role);

  // Verify membership
  const commitment = hash(identity, randomness);
  assert verifyMembership(commitment, merkleProof, role);

  // Return nullifier (can be used to rate-limit checks)
  return nullifier;
}
```

### Private Permission Delegation

```compact
// Delegate permissions without revealing delegator
export circuit delegatePermission(
  witness delegatorSecret: Bytes<32>,
  witness delegatorProof: Vector<Bytes<32>>,
  delegateeCommitment: Bytes<32>,
  permission: PermissionType,
  expiry: Uint<64>
): Bytes<32> {
  // Verify delegator has grant permission
  assert checkPermission(delegatorSecret, delegatorProof, Role.Admin, PermissionType.Grant);

  // Create delegation token
  const delegation = hash(delegateeCommitment, permission, expiry);
  activeDelegations.insert(delegation);

  return delegation;
}
```

## Merkle Tree Operations

### Building the Tree (Off-chain)

```typescript
function buildMerkleTree(members: Bytes32[]): MerkleTree {
  // Sort members for deterministic tree
  const sorted = members.sort();

  // Hash each member to create leaves
  const leaves = sorted.map(m => hash(m));

  // Build tree bottom-up
  let level = leaves;
  const tree = [level];

  while (level.length > 1) {
    const nextLevel = [];
    for (let i = 0; i < level.length; i += 2) {
      const left = level[i];
      const right = level[i + 1] || left; // Duplicate if odd
      nextLevel.push(hash(left, right));
    }
    tree.push(nextLevel);
    level = nextLevel;
  }

  return { root: level[0], tree };
}
```

### Generating Proofs (Off-chain)

```typescript
function generateProof(tree: MerkleTree, memberIndex: number): MerkleProof {
  const proof = [];
  const flags = [];

  let index = memberIndex;
  for (const level of tree.tree.slice(0, -1)) {
    const isLeft = index % 2 === 0;
    const siblingIndex = isLeft ? index + 1 : index - 1;

    if (siblingIndex < level.length) {
      proof.push(level[siblingIndex]);
      flags.push(isLeft);
    }

    index = Math.floor(index / 2);
  }

  return { proof, flags };
}
```

## Security Considerations

### Attack Vectors

1. **Proof Replay**
   - Mitigated by including version in verification
   - Update version on any membership change

2. **Root Manipulation**
   - Only admin can update roots
   - Log all root changes for auditing

3. **Membership Leak**
   - Use commitments instead of raw identities
   - Implement anonymous verification

4. **Permission Escalation**
   - Strict role hierarchy validation
   - Cannot grant permissions you don't have

### Best Practices

1. **Version all membership roots** for replay protection
2. **Log role changes** for audit trails
3. **Use time-limited delegations** to reduce risk
4. **Implement role hierarchy** in code, not just documentation
5. **Regular membership audits** with off-chain verification

## Integration Example

```typescript
import { registry } from './registry-contract';

// Setup: Build initial membership tree
const admins = [adminCommitment1, adminCommitment2];
const adminTree = buildMerkleTree(admins);

// Deploy with admin root
await registry.initialize({
  adminRoot: adminTree.root,
  rolePermissions: defaultPermissions
});

// Grant operator role
const operators = [operatorCommitment1];
const operatorTree = buildMerkleTree(operators);

await registry.grantRole(
  adminSecret,
  operatorCommitment1,
  Role.Operator,
  operatorTree.root
);

// Verify permission in another contract
const proof = generateProof(operatorTree, 0);
const hasPermission = await registry.checkPermission(
  operatorSecret,
  proof.proof,
  proof.flags,
  Role.Operator,
  PermissionType.Write
);
```

## Implementation Files

### registry.compact

Core registry logic:
- `initialize()` - Set up initial roles and permissions
- `grantRole()` - Add member to role
- `revokeRole()` - Remove member from role
- `checkPermission()` - Verify permission
- `verifyMembership()` - Merkle proof verification
- `delegate()` - Temporary permission delegation
- `updateRolePermissions()` - Modify role capabilities

## Testing Checklist

- [ ] Admin can grant/revoke roles
- [ ] Merkle proofs verify correctly
- [ ] Invalid proofs are rejected
- [ ] Permission inheritance works
- [ ] Version updates prevent replay
- [ ] Anonymous verification works
- [ ] Delegation expires correctly
- [ ] Cannot escalate permissions

## Related Patterns

- **Whitelist**: Simpler membership (no hierarchy)
- **Multi-Sig**: For admin operations
- **Time Lock**: For permission changes
- **Ownership**: For single-admin scenarios
