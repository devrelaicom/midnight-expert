# Kachina Protocol Deep Dive

## Formal Definition

Kachina is a protocol for data-protecting smart contracts that:
- Enables confidential, general-purpose computation
- Maintains decentralization
- Uses only non-interactive zero-knowledge proofs

## Security Model

### Universal Composability (UC)

Kachina operates within the UC framework:
- Protocols proven secure in isolation remain secure when composed
- Can be safely combined with other UC-secure protocols
- Formal security guarantees

### Ideal Functionality

Kachina realizes an ideal functionality where:
- Honest parties' private inputs remain hidden
- Contract execution is correct
- Adversary learns only public outputs

## Architecture Details

### Two-State Model

```text
┌─────────────────────────────────────┐
│         Public State                │
│  - Stored on blockchain             │
│  - Visible to all                   │
│  - Updated via transactions         │
│  - Contains: public fields,         │
│    Merkle roots, nullifier sets     │
└─────────────────────────────────────┘
              ^
         ZK Proofs
              |
┌─────────────────────────────────────┐
│         Private State               │
│  - Stored locally                   │
│  - Visible only to owner            │
│  - Never transmitted                │
│  - Contains: secrets, balances,     │
│    Merkle paths, witnesses          │
└─────────────────────────────────────┘
```

### Transcript System

Users maintain transcripts of contract interactions:

```text
Transcript = [(Query1, Response1), (Query2, Response2), ...]
```

**Purpose**:
- Record expected behavior
- Enable ZK proof of correct execution
- Support offline computation

### Proof of Transcript Validity

When submitting a transaction:
1. User provides transcript (public effects)
2. User provides ZK proof that:
   - Private inputs exist
   - Executing contract with those inputs produces transcript
   - All contract rules satisfied

## Concurrency Model

### No Global Locking

Unlike traditional smart contracts:
- Multiple users can act simultaneously
- No transaction ordering at user level
- Conflicts resolved at consensus level

### Conflict Resolution

When transactions conflict:
1. Consensus orders transactions
2. Later transactions may be reordered
3. Invalid transactions (due to conflict) rejected
4. Minimal information leaked about conflicts

### Optimistic Execution

Users assume their transaction will succeed:
1. Generate proof based on current state
2. Submit transaction
3. If state changed: transaction may fail
4. Retry with updated state

## Privacy Guarantees

### What's Hidden

| Component | Hidden From |
|-----------|-------------|
| Private state | Everyone except owner |
| Witness inputs | Everyone |
| Which public state accessed | Nobody (visible) |
| Timing of operations | Partially (transaction visible) |

### Information Leakage

Kachina minimizes but doesn't eliminate leakage:
- Transaction submission is public
- Public state changes are visible
- Transaction timing is observable

### Mitigations

- Batch transactions to hide patterns
- Use cover traffic
- Randomize timing

## Contract Model

### Reactive State Machines

Contracts are state machines that:
- Respond to user commands
- Update public state
- Require authorization via ZK proofs

### Authorization Model

```text
To perform action:
1. Prove right to perform action (via ZK)
2. Prove action follows contract rules (via ZK)
3. Submit proof + public effects
```

### State Separation

Contract designers choose:
- What's public (regulatory requirements, coordination)
- What's private (user data, sensitive values)
- Privacy/functionality trade-offs

## Implementation Considerations

### Proof Characteristics

Proof sizes are sublinear with respect to circuit complexity. Verification time is constant per proof (milliseconds), regardless of the computation proven.

### User Requirements

Users must:
- Store private state locally
- Generate proofs (computationally expensive)
- Track public state changes
- Maintain Merkle paths

## Use Case Suitability

### Good Fits

- DeFi with private balances
- Voting with secret ballots
- Supply chain with confidential details
- Healthcare with patient privacy
- Any computation mixing public and private

### Challenges

- Real-time requirements (proof generation takes time)
- High-frequency updates (state synchronization)
- Large private state (proof complexity)
