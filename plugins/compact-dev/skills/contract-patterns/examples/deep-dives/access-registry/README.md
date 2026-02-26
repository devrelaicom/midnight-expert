# Role-Based Access Registry

A comprehensive access control system for Midnight featuring hierarchical roles, Merkle proof verification, and privacy-preserving permission checks.

## Overview

This registry provides:
- **Hierarchical roles** - Roles with levels and inherited permissions
- **Merkle membership** - Gas-efficient verification using Merkle proofs
- **Dynamic permissions** - Update permissions without redeploying
- **Delegation system** - Temporary permission grants with expiry
- **Audit logging** - Track all access control changes

## Files

| File | Purpose |
| ------ | --------- |
| `registry.compact` | Complete access control contract |

## Permission Model

### Permission Bits

| Permission | Bit | Value | Description |
| ------------ | ----- | ------- | ------------- |
| Read | 0 | 1 | View data |
| Write | 1 | 2 | Modify data |
| Delete | 2 | 4 | Remove data |
| Grant | 3 | 8 | Delegate permissions |
| Revoke | 4 | 16 | Remove delegations |
| Admin | 5 | 32 | Manage roles |

### Example Permission Sets

```
Admin:    0b111111 = 63 (all permissions)
Operator: 0b000111 = 7  (read, write, delete)
User:     0b000001 = 1  (read only)
Moderator:0b000011 = 3  (read, write)
```

## Related Patterns

- [Whitelist](../../simple/whitelist.compact) - Simpler membership
- [Multi-Sig](../../simple/multi-sig.compact) - Admin operations
- [Ownership](../../simple/ownership.compact) - Single admin
- [Time Lock](../../simple/time-lock.compact) - Delayed permission changes
