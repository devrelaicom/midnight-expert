# Initializable & Pausable

## Initializable

Provides a simple mechanism that mimics constructor functionality — enables logic to be performed once and only once to set up initial state. Useful when a constructor cannot be used (e.g., circular dependencies at construction time).

Many OpenZeppelin modules use the initializable pattern internally to ensure:
- Circuit calls are blocked until the contract is initialized
- The contract can only be initialized once

### Usage

```compact
pragma language_version >= 0.21.0;

import CompactStandardLibrary;
import './compact-contracts/node_modules/@openzeppelin-compact/contracts/src/security/Initializable';

export ledger _fieldAfterDeployment: Field;

export circuit doSomethingBeforeInitialized(): [] {
  Initializable_assertNotInitialized();
  // Only callable before initialization
}

export circuit setFieldAfterDeployment(f: Field): [] {
  Initializable_initialize();
  _fieldAfterDeployment = f;
}

export circuit checkFieldAfterDeployment(): Field {
  Initializable_assertInitialized();
  return _fieldAfterDeployment;
}
```

### API Reference

#### Ledger

| Name | Type | Description |
|------|------|-------------|
| `_isInitialized` | `Boolean` | Whether the contract has been initialized |

#### Witnesses

None.

#### Circuits

| Circuit | Signature | Complexity | Description |
|---------|-----------|------------|-------------|
| `initialize` | `() → []` | k=10, rows=38 | Set initialized state. Ensures the calling circuit can only be called once. Requires: not already initialized. |
| `assertInitialized` | `() → []` | k=10, rows=31 | Assert contract is initialized. Throws if not. |
| `assertNotInitialized` | `() → []` | k=10, rows=35 | Assert contract is NOT initialized. Throws if it has been. |

---

## Pausable

Implements an emergency stop mechanism. Useful for:
- Preventing trades until end of evaluation period
- Emergency freeze of all transactions in event of a large bug
- Controlled rollouts

### Usage

Combine with Ownable for access-controlled pause/unpause:

```compact
pragma language_version >= 0.21.0;

import CompactStandardLibrary;
import './compact-contracts/node_modules/@openzeppelin-compact/contracts/src/security/Pausable'
  prefix Pausable_;
import './compact-contracts/node_modules/@openzeppelin-compact/contracts/src/access/Ownable'
  prefix Ownable_;

constructor(initOwner: Either<ZswapCoinPublicKey, ContractAddress>) {
  Ownable_initialize(initOwner);
}

export circuit pause(): [] {
  Ownable_assertOnlyOwner();
  Pausable__pause();
}

export circuit unpause(): [] {
  Ownable_assertOnlyOwner();
  Pausable__unpause();
}

export circuit whenNotPaused(): [] {
  Pausable_assertNotPaused();
  // Only callable when not paused
}

export circuit whenPaused(): [] {
  Pausable_assertPaused();
  // Only callable when paused (e.g., emergency withdraw)
}
```

### API Reference

#### Ledger

| Name | Type | Description |
|------|------|-------------|
| `_isPaused` | `Boolean` | Whether the contract is currently paused |

#### Witnesses

None.

#### Circuits

| Circuit | Signature | Complexity | Description |
|---------|-----------|------------|-------------|
| `isPaused` | `() → Boolean` | k=10, rows=32 | Returns true if paused |
| `assertPaused` | `() → []` | k=10, rows=31 | Revert if not paused |
| `assertNotPaused` | `() → []` | k=10, rows=35 | Revert if paused |
| `_pause` | `() → []` | k=10, rows=38 | Trigger paused state. Requires: not already paused. |
| `_unpause` | `() → []` | k=10, rows=34 | Lift pause. Requires: currently paused. |
