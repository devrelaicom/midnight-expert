---
name: core-concepts:tokenomics
description: This skill should be used when the user asks about Midnight tokens, NIGHT token, DUST resource, token distribution, Glacier Drop, Scavenger Mine, block rewards, tokenomics whitepaper, STAR denomination, token economics, dual-token model, MEV resistance, token supply, or how transaction fees work in Midnight.
version: 0.1.0
---

# Midnight Tokenomics

Midnight uses a dual-token model that separates value storage from transaction fee payment. **NIGHT** is the primary token for holding value and governance, while **DUST** is a continuously generated resource consumed to pay transaction fees. This design eliminates recurring token spend for active users and provides built-in MEV resistance through shielded transactions.

## Dual-Token Model

### NIGHT Token

NIGHT is the primary token of the Midnight network with a fixed supply of **24 billion** tokens.

| Property | Detail |
|----------|--------|
| Total supply | 24,000,000,000 NIGHT (fixed, non-inflationary) |
| Smallest unit | 1 STAR = 0.000001 NIGHT |
| Denomination | 1 NIGHT = 1,000,000 STARs |
| Visibility | Unshielded (public) |
| Chain presence | Native on both Cardano and Midnight |
| Primary functions | Governance, block rewards, DUST generation |

NIGHT tokens exist natively on both Cardano and Midnight, meaning holders do not need to bridge tokens between chains. The same token operates across both networks.

### DUST Resource

DUST is a non-transferable resource that pays for transaction fees on Midnight.

| Property | Detail |
|----------|--------|
| Transferability | Non-transferable between users |
| Visibility | Shielded (private) |
| Generation | Continuously generated from NIGHT holdings |
| Consumption | Consumed when paying transaction fees |
| Decay | Decays when disassociated from NIGHT |
| Metadata leakage | Transactions do not leak fee metadata |

Because DUST is shielded, transaction fee payments do not reveal information about the sender or the transaction. This is a key privacy property that prevents fee-based transaction analysis.

### Token Flow

The core economic loop works as follows:

```
Hold NIGHT --> generates DUST --> pay transaction fees --> DUST consumed
```

**Key insight**: Users who hold NIGHT can transact on the network without recurring token purchases. DUST is continuously regenerated from NIGHT holdings, so holding NIGHT effectively grants ongoing transaction capacity. There is no need to repeatedly buy tokens to pay fees.

## Block Rewards

Block producers receive rewards according to a formula that incentivizes network utilization while maintaining baseline compensation through a subsidy mechanism.

### Reward Formula

```
Actual Reward = Base Reward x [S + (1 - S) x U]
```

Where:
- **S** = subsidy rate (95% at launch)
- **U** = block utilization (target: 50%)

### Reward Scenarios

| Block State | Utilization (U) | Reward Calculation | Producer Receives |
|------------|----------------|-------------------|-------------------|
| Full block | 1.0 | Base x [0.95 + 0.05 x 1.0] | 100% of base reward |
| Target utilization | 0.5 | Base x [0.95 + 0.05 x 0.5] | 97.5% of base reward |
| Empty block | 0.0 | Base x [0.95 + 0.05 x 0.0] | 95% of base reward (subsidy only) |

The remainder (the portion not paid to the block producer) goes to the **Treasury**, which funds ongoing network development and ecosystem growth.

The high subsidy rate at launch (95%) ensures block producers receive near-full rewards even during periods of low network activity, incentivizing early participation and network security.

## Token Distribution

Midnight's token distribution is designed for broad, fair access through three sequential phases. Tokens are distributed for free -- there is no token sale.

### Phase 1: Glacier Drop (60 Days)

The Glacier Drop is the primary distribution event, providing free NIGHT tokens to existing cryptocurrency holders.

| Allocation | Eligible Chain |
|-----------|---------------|
| 50% | Cardano holders |
| 20% | Bitcoin holders |
| 30% | Other chain holders |

**Eligibility requirements:**
- Minimum portfolio value of $100 USD at snapshot time
- Proof of holdings via cryptographic verification
- No purchase required -- tokens are distributed for free

### Phase 2: Scavenger Mine (30 Days)

The Scavenger Mine follows the Glacier Drop and distributes any unclaimed tokens from Phase 1.

- Participants solve computational puzzles to claim tokens
- Designed to reward active engagement with the network
- Unclaimed Glacier Drop tokens form the available pool

### Phase 3: Lost-and-Found (4 Years)

A long-duration secondary distribution phase providing a second chance for eligible participants.

- Runs for 4 years after the Scavenger Mine concludes
- Allows eligible participants who missed earlier phases to claim tokens
- Ensures maximum distribution breadth over time

## Key Differentiators

### 1. No Recurring Token Spend

Unlike networks where users must continuously purchase tokens to pay gas fees, Midnight's DUST generation model means holding NIGHT provides ongoing transaction capacity. Users hold the asset and transact without depleting it for fees.

### 2. MEV Resistance

Because transactions use shielded DUST for fees and transaction details are protected by zero-knowledge proofs, block producers cannot extract value by reordering, front-running, or sandwiching transactions. The shielded nature of DUST payments and transaction contents eliminates the information asymmetry that enables MEV on other networks. See `core-concepts:zero-knowledge` for details on how ZK proofs protect transaction privacy.

### 3. Cross-Chain Native Token

NIGHT exists natively on both Cardano and Midnight without requiring bridges. This eliminates bridge risk, reduces friction for Cardano ecosystem participants, and enables seamless interoperability between the two networks.

### 4. Fair Distribution

The multi-phase distribution model (Glacier Drop, Scavenger Mine, Lost-and-Found) prioritizes broad access over capital concentration. No token sale means no early-investor advantage, and the extended timeline ensures diverse participation.

## Token Operations in Contracts

Smart contracts interact with tokens through the Compact standard library. Shielded token operations use the Zswap protocol to maintain privacy, while unshielded tokens are handled through direct ledger operations. See `compact-core:compact-tokens` for detailed token operation syntax and patterns.

Transaction fees paid in DUST are handled at the protocol level. The fee model and gas costs for contract execution are covered in `compact-core:compact-transaction-model`.

## Shielded and Unshielded Tokens

The dual-token model maps directly to Midnight's data model for shielded and unshielded state. NIGHT operates as an unshielded (public) token, while DUST operates in the shielded (private) domain. This mirrors the broader ledger architecture where contract state can be either public or private. See `core-concepts:data-models` for the full shielded/unshielded data model.
