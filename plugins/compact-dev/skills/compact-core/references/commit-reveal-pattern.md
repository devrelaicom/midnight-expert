---
title: Commit-Reveal Pattern
type: pattern
description: A two-phase protocol where data is committed (hidden) in phase one and revealed (proven) in phase two — used for voting, auctions, and sealed-bid systems.
links:
  - commitment-and-nullifier-schemes
  - transient-vs-persistent
  - state-machine-pattern
  - disclosure-model
  - witness-functions
  - standard-library-functions
  - merkle-trees
---

# Commit-Reveal Pattern

The commit-reveal pattern is a two-phase protocol for situations where actions must be hidden until a deadline, then provably revealed. It is the foundation of sealed-bid auctions, private voting, and any protocol where front-running is a concern.

## The Two Phases

**Phase 1 — Commit**: Each participant hashes their secret data and submits the hash on-chain. The hash reveals nothing about the data (when using `transientCommit` as recommended in [[transient-vs-persistent]]).

**Phase 2 — Reveal**: After the commit deadline, each participant provides their original data via [[witness-functions]]. The circuit verifies that `commit(data) == stored_commitment` and processes the data.

## Implementation

```compact
export enum Phase { Committing, Revealing, Closed }

export ledger phase: Phase;
export ledger commitments: Map<Bytes<32>, Field>;  // committer → commitment
export ledger reveals: Map<Bytes<32>, Field>;       // committer → revealed value

witness getMyCommitment(): Field;
witness getMyValue(): Field;
witness getMySalt(): Bytes<32>;
witness getCaller(): Bytes<32>;

export circuit commit(): [] {
  assert phase == Phase.Committing "Not in commit phase";
  const caller = disclose(getCaller());
  const commitment = getMyCommitment();
  commitments.insert(caller, commitment);
}

export circuit reveal(): [] {
  assert phase == Phase.Revealing "Not in reveal phase";
  const caller = disclose(getCaller());
  const value = getMyValue();
  const salt = getMySalt();

  // Verify the revealed value matches the commitment
  const expected = transientCommit<Vector<2, Field>>([value, salt as Field]);
  const stored = commitments.lookup(caller);
  assert expected == stored "Commitment mismatch";

  reveals.insert(caller, disclose(value));
}
```

The salt prevents brute-force attacks on low-entropy values (like a vote of 0 or 1). The phase enum uses the [[state-machine-pattern]] to enforce ordering.

## Phase Transitions

The commit and reveal phases are typically managed by a contract owner or by time-based conditions using block time functions from [[standard-library-functions]]:

```compact
export circuit closeCommitPhase(): [] {
  assert phase == Phase.Committing "Already closed";
  blockTimeGte(commitDeadline);
  phase = Phase.Revealing;
}
```

## Privacy Guarantees

The privacy of the commit phase depends entirely on using [[transient-vs-persistent]] correctly:
- `transientCommit` — Safe: the commitment cannot be reverse-engineered
- `persistentHash` — Unsafe: if the value space is small, the hash can be brute-forced

This is why the commit-reveal pattern always uses `transientCommit()` from [[commitment-and-nullifier-schemes]] for the commit step. The reveal step uses `disclose()` from the [[disclosure-model]] because the revealed value intentionally becomes public.

## Storing in Merkle Trees

For anonymous commit-reveal (where the committer's identity should also be hidden), store commitments in a [[merkle-trees]] instead of a Map. During reveal, the participant proves their commitment exists in the tree via a Merkle path without revealing which leaf is theirs.
