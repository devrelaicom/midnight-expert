# Private Voting Pattern Deep-Dive

Complete guide to implementing anonymous, verifiable voting on Midnight.

## Overview

The private voting pattern enables:
- **Anonymous ballot casting**: Votes cannot be linked to voters
- **Eligibility verification**: Only authorized voters can participate
- **Verifiable results**: Anyone can verify the tally is correct
- **Double-vote prevention**: Each voter can only vote once

## Architecture

```
┌─────────────────┐ ┌─────────────────┐
│   voter.compact │────▶│  tally.compact  │
│                 │     │                 │
│ - Registration  │     │ - Aggregation   │
│ - Ballot Cast   │     │ - Result Calc   │
│ - Nullifiers    │     │ - Verification  │
└─────────────────┘     └─────────────────┘
```

## Key Components

### 1. Voter Registration

Voters register with a commitment to their identity:

```compact
// Voter commits to their identity without revealing it
ledger voterCommitments: Set<Bytes<32>>;

export circuit register(
  witness identitySecret: Bytes<32>,
  witness randomness: Bytes<32>
): Void {
  // Compute commitment = hash(identity || randomness)
  const commitment = hash(identitySecret, randomness);

  // Add to registered voters
  voterCommitments.insert(commitment);
}
```

### 2. Ballot Casting

Votes use nullifiers to prevent double-voting:

```compact
ledger usedNullifiers: Set<Bytes<32>>;
ledger voteTally: Map<Uint<8>, Counter>;

export circuit castBallot(
  witness identitySecret: Bytes<32>,
  witness randomness: Bytes<32>,
  witness choice: Uint<8>,
  witness electionId: Bytes<32>
): Void {
  // Recompute commitment to prove eligibility
  const commitment = hash(identitySecret, randomness);
  assert voterCommitments.member(commitment);

  // Compute nullifier = hash(identity || electionId)
  // Same identity + election = same nullifier (prevents double vote)
  // Different elections = different nullifiers (allows multi-election)
  const nullifier = hash(identitySecret, electionId);

  // Ensure this nullifier hasn't been used
  assert !usedNullifiers.member(nullifier);
  usedNullifiers.insert(nullifier);

  // Record vote (choice is private in witness)
  voteTally[choice].increment(1);
}
```

### 3. Result Computation

Tallying reveals only aggregate results:

```compact
export circuit getResults(): Map<Uint<8>, Uint<64>> {
  // Return current tally
  // Individual votes remain private
  return voteTally.snapshot();
}
```

## Privacy Analysis

### What's Public (Ledger)
- Set of voter commitments (not identities)
- Set of used nullifiers (not linked to voters)
- Aggregate vote counts per choice
- Election metadata (start/end times, choices)

### What's Private (Witness)
- Voter identities
- Individual vote choices
- Registration randomness
- Link between voter and their nullifier

### Privacy Guarantees

1. **Voter Anonymity**: Commitments hide identity; nullifiers are unlinkable
2. **Vote Secrecy**: Choice only appears in aggregate tally
3. **Eligibility Proof**: ZK proof shows voter is registered without revealing who

## Implementation Files

### voter.compact

Handles registration and ballot casting:
- `register()` - Add voter commitment
- `castBallot()` - Cast anonymous vote
- `isRegistered()` - Check registration status

### tally.compact

Handles result aggregation:
- `initializeElection()` - Set up new election
- `finalize()` - Lock results
- `getResults()` - Read current tally

## Security Considerations

### Attack Vectors

1. **Double Voting**
   - Mitigated by nullifier tracking
   - Nullifier = hash(identity, electionId)

2. **Voter Impersonation**
   - Prevented by commitment scheme
   - Only commitment owner knows preimage

3. **Vote Buying**
   - Partially mitigated by inability to prove vote choice
   - Voter cannot prove how they voted to third party

4. **Tally Manipulation**
   - Prevented by ZK verification
   - All operations are cryptographically verified

### Best Practices

1. **Use strong randomness** for commitments
2. **Include election ID** in nullifiers for multi-election support
3. **Set registration deadlines** before voting starts
4. **Implement timeouts** for election phases
5. **Consider voter threshold** for valid elections

## Integration Example

```typescript
import { voter, tally } from './voting-contracts';

// Admin: Initialize election
await tally.initializeElection({
  electionId: 'election-2024',
  choices: ['Yes', 'No', 'Abstain'],
  registrationEnd: blockHeight + 1000,
  votingEnd: blockHeight + 2000
});

// Voter: Register (off-chain identity verification assumed)
const identitySecret = generateSecret();
const randomness = generateRandomness();
await voter.register(identitySecret, randomness);

// Voter: Cast ballot
await voter.castBallot(
  identitySecret,
  randomness,
  1, // Vote for choice index 1
  'election-2024'
);

// Anyone: Read results
const results = await tally.getResults();
console.log('Yes:', results[0], 'No:', results[1], 'Abstain:', results[2]);
```

## Testing Checklist

- [ ] Voter can register with valid commitment
- [ ] Registered voter can cast ballot
- [ ] Unregistered voter cannot cast ballot
- [ ] Same voter cannot vote twice (nullifier check)
- [ ] Vote choices are not revealed on-chain
- [ ] Tally correctly aggregates votes
- [ ] Election phases are enforced (registration, voting, finalized)
- [ ] Different elections have independent nullifiers

## Related Patterns

- **Whitelist**: For voter eligibility lists
- **Time Lock**: For election phase management
- **Multi-Sig**: For election administration
- **Merkle Proofs**: For large voter sets (gas optimization)
