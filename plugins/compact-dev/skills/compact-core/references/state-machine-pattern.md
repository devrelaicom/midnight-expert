---
title: State Machine Pattern
type: pattern
description: Modeling contract lifecycle through enum-based states with guarded transitions — the standard approach for multi-phase protocols in Compact.
links:
  - type-system
  - cell-and-counter
  - export-and-visibility
  - circuit-declarations
  - naming-conventions
  - commit-reveal-pattern
  - both-branches-execute
  - standard-library-functions
---

# State Machine Pattern

Many contracts follow a lifecycle: created → active → completed, or bidding → revealing → settled. The state machine pattern models this with an enum stored in a Cell, where each circuit asserts the current state before performing its action and transitions to the next state.

## Basic Structure

```compact
export enum Phase { Setup, Active, Completed }

export ledger phase: Phase;

constructor() {
  phase = Phase.Setup;
}

export circuit activate(): [] {
  assert phase == Phase.Setup "Already activated";
  // ... initialization logic
  phase = Phase.Active;
}

export circuit complete(): [] {
  assert phase == Phase.Active "Not active";
  // ... finalization logic
  phase = Phase.Completed;
}
```

The enum is declared with `export` because it appears in exported circuit assertions — the [[export-and-visibility]] rules require exported types for exported signatures. By [[naming-conventions]], both the enum name and variants use PascalCase.

## Guards and Transitions

Every exported circuit that participates in the state machine begins with a state guard:

```compact
export circuit bid(amount: Uint<0..1000000>): [] {
  assert phase == Phase.Bidding "Not in bidding phase";
  // ... bidding logic
}
```

Transitions happen by simple assignment to the phase field, which is stored as a [[cell-and-counter]] Cell. Only one transition should happen per circuit call to keep the state machine predictable.

## Time-Based Transitions

Use block time functions from [[standard-library-functions]] to enforce deadlines:

```compact
sealed ledger bidDeadline: Uint<0..4294967295>;

export circuit closeBidding(): [] {
  assert phase == Phase.Bidding "Not in bidding phase";
  blockTimeGte(bidDeadline);  // Asserts current time ≥ deadline
  phase = Phase.Revealing;
}
```

This combines the state machine with the [[commit-reveal-pattern]] where bidding closes at a deadline and revealing begins.

## Default State

The first declared enum variant is the default value in Compact's [[type-system]]. This means if you declare `enum Phase { Setup, Active, Completed }`, an uninitialized phase field defaults to `Phase.Setup`. Design your enum with the initial state as the first variant to avoid needing explicit constructor initialization.

## Multi-Phase Protocols

Complex protocols may have more than two or three phases:

```compact
export enum AuctionState {
  Registration,   // Default: accepting participants
  Committing,     // Sealed bids
  Revealing,      // Opening bids
  Settling,       // Determining winner
  Closed          // Final state
}
```

Each [[circuit-declarations]] is responsible for one transition and asserts its precondition. This creates a clear, auditable flow through the contract's lifecycle.

## Both Branches Warning

When writing state-dependent logic, remember that [[both-branches-execute]] in ZK circuits. This means code like:

```compact
if (phase == Phase.Active) {
  counter.increment(1);
}
```

will increment the counter regardless of the phase in the circuit's constraint system. Use the assert-at-top pattern instead:

```compact
export circuit incrementWhenActive(): [] {
  assert phase == Phase.Active "Not active";
  counter.increment(1);
}
```

The `assert` causes the entire proof to fail if the condition isn't met, which is the correct behavior for state machine guards.
