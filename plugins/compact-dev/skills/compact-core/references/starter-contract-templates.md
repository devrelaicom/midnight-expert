---
title: Starter Contract Templates
type: pattern
description: Minimal and owned contract templates as starting points for new Compact contracts — the simplest viable structures to build upon.
links:
  - contract-file-layout
  - access-control-pattern
  - cell-and-counter
  - constructor-circuit
  - fungible-token-template
---

# Starter Contract Templates

These templates provide the simplest viable starting points for new Compact contracts. Start with the minimal template for experimentation, or the owned template when access control is needed. For a complete token contract, see the [[fungible-token-template]].

## Minimal Contract

The simplest possible Compact contract — a single Cell with getter and setter:

```compact
pragma language_version >= 0.18.0;

contract {
  ledger {
    value: Cell<Field>;
  }

  constructor() {
    ledger.value.write(0);
  }

  export circuit setValue(v: Field): Void {
    ledger.value.write(v);
  }

  export circuit getValue(): Field {
    return ledger.value.read();
  }
}
```

This template demonstrates the essential [[contract-file-layout]] structure: pragma, ledger, constructor, and exported circuits. It uses a single [[cell-and-counter]] for state. There is no access control — anyone can call `setValue`.

**Use as a starting point when:**
- Learning Compact syntax and compilation
- Prototyping a new contract idea
- Building a contract where any user can modify state

## Owned Contract

Adds an owner check so that critical operations are restricted to a single authorized caller:

```compact
pragma language_version >= 0.18.0;
import CompactStandardLibrary;

contract {
  ledger {
    owner: Cell<Field>;
  }

  witness getDeployer(): Field;
  witness getCaller(): Field;

  constructor() {
    ledger.owner = witness getDeployer();
  }

  circuit requireOwner(): Void {
    assert witness getCaller() == ledger.owner.read() "Not owner";
  }

  export circuit ownerAction(): Void {
    requireOwner();
    // owner-only logic here
  }
}
```

This template introduces the [[access-control-pattern]]: the deployer's identity is captured in the [[constructor-circuit]], and a `requireOwner()` helper guard circuit validates the caller before executing protected logic. The guard is an unexported circuit — only the contract itself can call it.

**Use as a starting point when:**
- The contract needs an admin or owner role
- Some operations should be restricted to authorized callers
- You are building toward a more complex contract with role-based access

## Choosing a Template

| Need | Template | Then Add |
|------|----------|----------|
| Quick prototype | Minimal | Ledger fields, circuits as needed |
| Admin-controlled contract | Owned | Domain-specific logic behind `requireOwner()` |
| Token contract | Start with Owned | Minting, sending — see [[fungible-token-template]] |
| Multi-role contract | Start with Owned | Multiple role fields and guard circuits per [[access-control-pattern]] |

Both templates follow the canonical ordering described in [[contract-file-layout]]. As the contract grows, add ledger fields, witness declarations, and circuits in the order prescribed by that layout.
