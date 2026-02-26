# Token Escrow Pattern Deep-Dive

Complete guide to implementing multi-party escrow with conditional release on Midnight.

## Overview

The token escrow pattern enables:
- **Multi-party deposits**: Multiple parties can contribute to escrow
- **Conditional release**: Funds release based on predefined conditions
- **Timeout handling**: Automatic refunds if conditions aren't met
- **Dispute resolution**: Arbitrator involvement when needed

## Architecture

```
┌──────────────┐   deposit    ┌─────────────────┐
│   Party A    │─────────────▶│                 │
└──────────────┘              │                 │
                              │  escrow.compact │
┌──────────────┐   deposit    │                 │
│   Party B    │─────────────▶│  - Deposits     │
└──────────────┘              │  - Conditions   │
                              │  - Release      │
┌──────────────┐   arbitrate  │  - Refund       │
│  Arbitrator  │─────────────▶│                 │
└──────────────┘              └─────────────────┘
```

## Key Components

### 1. Escrow State Machine

```
  ┌──────────────┐
  │   Created    │
  └──────┬───────┘
         │ fund()
  ┌──────▼───────┐
  │   Funded     │◀─────────┐
  └──────┬───────┘          │
         │                  │ addDeposit()
  ┌────────┴────────┐      │
  │                 │       │
┌─────▼─────┐    ┌──────▼──────┐
│ Completed │    │  Disputed   │──┘
└───────────┘    └──────┬──────┘
                        │ resolve()
                 ┌──────▼──────┐
                 │  Resolved   │
                 └─────────────┘
```

### 2. Deposit Tracking

```compact
// Track deposits per party with privacy options
ledger deposits: Map<Bytes<32>, Uint<64>>;
ledger totalDeposited: Counter;
ledger escrowState: Cell<EscrowState>;

export circuit deposit(
  partyId: Bytes<32>,
  amount: Uint<64>
): Void {
  // Verify escrow is accepting deposits
  assert escrowState.value == EscrowState.Accepting;

  // Record deposit
  deposits[partyId] = deposits[partyId] + amount;
  totalDeposited.increment(amount);
}
```

### 3. Conditional Release

```compact
ledger releaseConditions: Map<Bytes<32>, Boolean>;
ledger requiredConditions: Set<Bytes<32>>;

export circuit markConditionMet(
  witness arbitratorSecret: Bytes<32>,
  conditionId: Bytes<32>
): Void {
  // Verify arbitrator authority
  assert hash(arbitratorSecret) == arbitratorCommitment;

  // Mark condition as met
  releaseConditions[conditionId] = true;
}

export circuit release(
  recipient: Bytes<32>
): Void {
  // Check all required conditions are met
  for conditionId in requiredConditions {
    assert releaseConditions[conditionId] == true;
  }

  // Execute release
  escrowState.value = EscrowState.Released;
  // Transfer logic here
}
```

### 4. Timeout Refunds

```compact
ledger escrowDeadline: Cell<Uint<64>>;

export circuit refund(
  partyId: Bytes<32>
): Void {
  // Check timeout has passed
  assert currentBlockHeight() > escrowDeadline.value;

  // Check escrow not already released
  assert escrowState.value != EscrowState.Released;

  // Return party's deposit
  const refundAmount = deposits[partyId];
  deposits[partyId] = 0;
  // Transfer refundAmount to party
}
```

## Use Cases

### 1. Simple Two-Party Escrow

Buyer deposits funds, seller delivers goods, arbitrator releases funds.

```compact
// Buyer deposits
deposit(buyerCommitment, purchasePrice);

// Seller confirms delivery
markConditionMet(sellerSecret, deliveryCondition);

// Buyer confirms receipt (or arbitrator decides)
markConditionMet(buyerSecret, receiptCondition);

// Release to seller
release(sellerAddress);
```

### 2. Multi-Party Milestone Escrow

Funds released in stages as milestones complete.

```compact
// Define milestones
setMilestone("milestone1", 25); // 25% of funds
setMilestone("milestone2", 50); // 50% of funds
setMilestone("milestone3", 25); // 25% of funds

// Complete milestones
completeMilestone("milestone1");
releaseMilestone("milestone1", contractorAddress);
```

### 3. Atomic Swap Escrow

Exchange assets between parties atomically.

```compact
// Both parties deposit
depositAssetA(partyA, amountA);
depositAssetB(partyB, amountB);

// Execute swap (all or nothing)
atomicSwap(partyA, partyB);
```

## Privacy Features

### Private Deposit Amounts

```compact
// Deposit amount known only to depositor and contract
export circuit privateDeposit(
  witness amount: Uint<64>,
  witness depositorSecret: Bytes<32>
): Void {
  // Commit to amount without revealing
  const amountCommitment = hash(amount, depositorSecret);
  depositCommitments.insert(amountCommitment);
}
```

### Private Release Conditions

```compact
// Condition details hidden, only satisfaction is public
export circuit satisfyPrivateCondition(
  witness conditionPreimage: Bytes<32>,
  conditionHash: Bytes<32>
): Void {
  assert hash(conditionPreimage) == conditionHash;
  conditionsSatisfied.insert(conditionHash);
}
```

## Security Considerations

### Attack Vectors

1. **Front-running**
   - Mitigated by commit-reveal for sensitive operations
   - Use private witnesses for amounts/conditions

2. **Griefing Attacks**
   - Timeouts prevent indefinite fund locking
   - Minimum deposit requirements discourage spam

3. **Arbitrator Collusion**
   - Multi-arbitrator schemes (M-of-N)
   - Time-delayed arbitration
   - Reputation systems

4. **Reentrancy**
   - State updates before external calls
   - Checks-effects-interactions pattern

### Best Practices

1. **Always include timeouts** for fund recovery
2. **Use commit-reveal** for private conditions
3. **Implement dispute windows** before final release
4. **Log all state transitions** for auditability
5. **Test edge cases** thoroughly (partial deposits, simultaneous actions)

## Integration Example

```typescript
import { escrow } from './escrow-contract';

// Create escrow
const escrowId = await escrow.create({
  parties: [buyerAddress, sellerAddress],
  arbitrator: arbitratorAddress,
  conditions: ['delivery', 'inspection'],
  timeout: blockHeight + 10000,
  releaseDelay: 100 // blocks
});

// Buyer deposits
await escrow.deposit(escrowId, buyerAddress, purchasePrice);

// Seller ships and marks delivery
await escrow.markCondition(escrowId, 'delivery', sellerProof);

// Buyer inspects and approves
await escrow.markCondition(escrowId, 'inspection', buyerProof);

// Funds released after delay
await escrow.release(escrowId, sellerAddress);

// OR: Timeout refund if conditions not met
// await escrow.refund(escrowId, buyerAddress);
```

## Implementation Files

### escrow.compact

Core escrow logic:
- `create()` - Initialize new escrow
- `deposit()` - Add funds to escrow
- `markCondition()` - Mark condition satisfied
- `release()` - Release funds to recipient
- `refund()` - Return funds after timeout
- `dispute()` - Initiate dispute resolution
- `resolve()` - Arbitrator resolution

## Testing Checklist

- [ ] Parties can deposit correct amounts
- [ ] Conditions must be met before release
- [ ] Timeout allows refund
- [ ] Arbitrator can resolve disputes
- [ ] No double-release or double-refund
- [ ] Partial releases work correctly
- [ ] State transitions are atomic
- [ ] Private amounts remain private

## Related Patterns

- **Multi-Sig**: For multi-arbitrator schemes
- **Time Lock**: For release delays
- **Pausable**: For emergency stops
- **Fee Collector**: For escrow service fees
