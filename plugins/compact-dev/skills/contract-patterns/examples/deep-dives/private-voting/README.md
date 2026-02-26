# Private Voting System

A complete anonymous voting system for Midnight using zero-knowledge proofs.

## Overview

This system provides:
- **Anonymous voter registration** - Voters register with commitments, hiding their identity
- **Secret ballot casting** - Vote choices are never revealed on-chain
- **Double-vote prevention** - Cryptographic nullifiers prevent voting twice
- **Verifiable results** - Anyone can verify the tally is correct

## Files

| File | Purpose |
| ------ | --------- |
| `voter.compact` | Voter registration and ballot casting |
| `tally.compact` | Result computation and verification |

## Election Lifecycle

### Phase 1: Setup
Admin initializes the election with configuration.

### Phase 2: Registration
Voters register by committing to their identity. Only `hash(identitySecret, randomness)` is stored on-chain.

### Phase 3: Voting
Registered voters cast anonymous ballots. Choice is in the witness (never published). Nullifier prevents double-voting without revealing who voted.

### Phase 4: Finalization
After voting ends, results are computed. Only aggregate tallies are public.

## Privacy Analysis

### What's Public (On-Chain)
- Voter commitments (not identities)
- Used nullifiers (not linked to voters)
- Aggregate tallies
- Election metadata

### What's Private (Witness Only)
- Voter identities
- Individual votes
- Registration randomness
- Identity-nullifier link

## Related Patterns

- [Whitelist](../../simple/whitelist.compact) - Voter eligibility
- [Time Lock](../../simple/time-lock.compact) - Phase management
- [Multi-Sig](../../simple/multi-sig.compact) - Election administration
