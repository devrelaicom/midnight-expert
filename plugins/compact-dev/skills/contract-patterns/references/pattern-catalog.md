# Contract Pattern Catalog

Quick reference for all Compact contract patterns in this skill.

## Simple Patterns

### 1. Counter Pattern

**File**: `examples/simple/counter.compact`

**Purpose**: Demonstrates basic state management with increment/decrement operations.

**Key Concepts**:
- Public ledger state
- Simple arithmetic operations
- Access control basics

**When to Use**:
- Tracking counts or totals
- Sequential ID generation
- Basic state machine steps

---

### 2. Ownership Pattern

**File**: `examples/simple/ownership.compact`

**Purpose**: Single-owner control with transfer capability.

**Key Concepts**:
- Owner verification
- Ownership transfer
- Guard clauses

**When to Use**:
- Contract administration
- Asset ownership
- Single-authority operations

---

### 3. Time Lock Pattern

**File**: `examples/simple/time-lock.compact`

**Purpose**: Actions that can only execute after a specified time.

**Key Concepts**:
- Block height comparisons
- Scheduled execution
- Lock/unlock mechanics

**When to Use**:
- Vesting schedules
- Delayed withdrawals
- Governance timeouts

---

### 4. Whitelist Pattern

**File**: `examples/simple/whitelist.compact`

**Purpose**: Membership verification using sets.

**Key Concepts**:
- Set membership
- Add/remove operations
- Access gating

**When to Use**:
- KYC verification
- Allowlists
- Tiered access

---

### 5. Rate Limit Pattern

**File**: `examples/simple/rate-limit.compact`

**Purpose**: Throttle actions to prevent abuse.

**Key Concepts**:
- Time-based windows
- Counter resets
- Cooldown periods

**When to Use**:
- API rate limiting
- Withdrawal limits
- Anti-spam measures

---

### 6. Multi-Sig Pattern

**File**: `examples/simple/multi-sig.compact`

**Purpose**: N-of-M approval for sensitive operations.

**Key Concepts**:
- Signature aggregation
- Threshold verification
- Proposal lifecycle

**When to Use**:
- Treasury management
- Critical updates
- Shared custody

---

### 7. Pausable Pattern

**File**: `examples/simple/pausable.compact`

**Purpose**: Emergency stop mechanism for contracts.

**Key Concepts**:
- Circuit breaker
- Admin controls
- State preservation

**When to Use**:
- Emergency response
- Maintenance windows
- Bug mitigation

---

### 8. Upgradeable Pattern

**File**: `examples/simple/upgradeable.compact`

**Purpose**: Pattern for contract logic migration.

**Key Concepts**:
- Proxy delegation
- State migration
- Version tracking

**When to Use**:
- Bug fixes
- Feature additions
- Protocol upgrades

---

### 9. Fee Collector Pattern

**File**: `examples/simple/fee-collector.compact`

**Purpose**: Collect and distribute fees from operations.

**Key Concepts**:
- Fee calculation
- Balance tracking
- Distribution logic

**When to Use**:
- Protocol fees
- Service charges
- Revenue sharing

---

### 10. Random Selection Pattern

**File**: `examples/simple/random-selection.compact`

**Purpose**: Fair random selection using commit-reveal.

**Key Concepts**:
- Commit-reveal scheme
- Hash-based randomness
- Manipulation resistance

**When to Use**:
- Lottery systems
- Random assignment
- Fair selection

---

## Deep-Dive Systems

### Private Voting System

**Directory**: `examples/deep-dives/private-voting/`

**Components**:
- `voter.compact` - Voter registration and ballot casting
- `tally.compact` - Vote aggregation and result computation
- `README.md` - System documentation

**Privacy Features**:
- Anonymous ballot casting
- Hidden vote choices
- Verifiable tallying

**Reference**: [Private Voting Deep-Dive](private-voting.md)

---

### Token Escrow System

**Directory**: `examples/deep-dives/token-escrow/`

**Components**:
- `escrow.compact` - Core escrow logic
- `README.md` - Integration guide

**Features**:
- Multi-party deposits
- Conditional release
- Timeout handling
- Dispute resolution

**Reference**: [Token Escrow Deep-Dive](token-escrow.md)

---

### Access Registry System

**Directory**: `examples/deep-dives/access-registry/`

**Components**:
- `registry.compact` - Role and permission management
- `README.md` - Implementation guide

**Features**:
- Role hierarchy
- Merkle proof verification
- Dynamic permissions
- Audit logging

**Reference**: [Access Registry Deep-Dive](access-registry.md)

---

## Pattern Combinations

Common pattern combinations for complex use cases:

| Use Case | Patterns |
| ---------- | ---------- |
| DAO Treasury | Multi-Sig + Time Lock + Pausable |
| Token Sale | Whitelist + Rate Limit + Fee Collector |
| NFT Mint | Counter + Ownership + Random Selection |
| Governance | Voting + Time Lock + Multi-Sig |
| Staking | Time Lock + Fee Collector + Counter |

## Privacy Considerations

### Public Data (Ledger State)
- Counter values
- Owner addresses
- Timestamps
- Merkle roots

### Private Data (Witness)
- Vote choices
- Membership proofs
- Signature preimages
- Personal identifiers

### Mixed Patterns
- Commitments (public hash, private preimage)
- Nullifiers (prevents double-use without revealing identity)
- Range proofs (prove value in range without revealing exact value)
