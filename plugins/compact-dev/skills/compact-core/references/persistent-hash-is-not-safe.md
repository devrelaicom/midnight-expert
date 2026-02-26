---
title: "Gotcha: persistentHash Is Not Safe for Private Data"
type: gotcha
description: persistentHash produces deterministic output that can be reverse-engineered — never use it on witness data when privacy is needed; use transientHash or transientCommit instead.
links:
  - transient-vs-persistent
  - witness-value-tracking
  - disclosure-model
  - commitment-and-nullifier-schemes
  - standard-library-functions
---

# Gotcha: persistentHash Is Not Safe for Private Data

This is the most dangerous privacy misconception in Compact development. `persistentHash` is a deterministic function: the same input always produces the same output. If the input is witness data from a small domain, an attacker can compute hashes for all possible inputs and match them against the on-chain value.

## The Problem

```compact
// DANGEROUS: Using persistentHash on a private vote
witness getVote(): Field;

export circuit commitVote(): [] {
  const vote = getVote();
  const h = persistentHash<Field>(vote);
  voteCommitment = disclose(h);  // Compiles — but attacker can check:
                                  // persistentHash(0) vs h? persistentHash(1) vs h?
}
```

The `disclose()` silences the compiler, but the developer has bypassed the safety system. An attacker who knows the vote is either 0 or 1 computes both hashes and identifies the vote immediately.

## Why the Compiler Warns (But Can't Fully Prevent It)

The compiler's [[witness-value-tracking]] system does NOT remove taint from `persistentHash` outputs — precisely because of this vulnerability. If you try to store a `persistentHash` of witness data without `disclose()`, the compiler correctly errors. The error is telling you: "this operation does not hide the data." However, adding `disclose()` overrides the warning, which is the developer's explicit acceptance of the risk.

Read the error message carefully when the compiler flags a `persistentHash` path to a ledger write. The message traces the full path from witness to disclosure point, as described in [[disclosure-compiler-error]]. If the path includes `persistentHash` of witness data, it's a strong signal to reconsider.

## The Safe Alternative

Use `transientCommit` or `transientHash` from [[standard-library-functions]] instead. These functions produce non-deterministic outputs that break the link between input and output:

```compact
// SAFE: transientCommit breaks the link
witness getVote(): Field;

export circuit commitVote(): [] {
  const vote = getVote();
  const c = transientCommit<Field>(vote);
  voteCommitment = c;  // No disclose needed — taint removed by transientCommit
}
```

The transient operation is both safer and more ergonomic: no `disclose()` required because the compiler recognizes it as privacy-preserving.

## When persistentHash IS Appropriate

`persistentHash` is correct when:
- The input is **already public** (non-witness data)
- You're computing a **deterministic identifier** (like token type from `tokenType()`)
- You're computing a **nullifier** in [[commitment-and-nullifier-schemes]] (nullifiers are *intended* to be deterministic and public — that's how they prevent double-spending)
- The input space is too large to enumerate (e.g., a full `Bytes<32>` secret)

The rule of thumb: if the data came from a witness and you need privacy, use transient. If the data is public or determinism is the goal, use persistent.

## The Nuance: Large vs Small Domains

`persistentHash` of a 256-bit random secret is safe in practice because the input space is too large to enumerate. The danger is specifically with small, guessable domains: votes (0/1), ages (0-150), small balances, boolean flags. The [[transient-vs-persistent]] section provides the full decision framework.
