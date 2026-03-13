# compact-patterns Skill Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create a comprehensive catalog of 18 reusable Compact contract design patterns as a skill in the compact-core plugin.

**Architecture:** A single skill with a SKILL.md lookup surface and 7 category-grouped reference files containing full Compact code examples inline. Self-contained — no dependency on other skills for code.

**Tech Stack:** Compact (Midnight smart contract language), Markdown for skill files

**Design doc:** `docs/plans/2026-02-28-compact-patterns-design.md`

**MCP Research:** Use Midnight MCP server tools (`midnight-search-compact`, `midnight-get-latest-syntax`, `midnight-compile-contract`) to verify Compact code correctness.

**Compact Syntax Notes:**
- Pragma: `pragma language_version >= 0.16 && <= 0.18;`
- Import: `import CompactStandardLibrary;`
- `public_key()` is NOT a builtin — use `persistentHash<Vector<2, Bytes<32>>>([pad(32, "domain:pk:"), sk])`
- Return type `[]` not `Void`
- No `Cell<T>` wrapper (deprecated)
- Counter uses `.read()` not `.value()`
- Witnesses are declarations only (no body in Compact)
- `blockTimeGte(time: Uint<64>): Boolean` and `blockTimeLt(time: Uint<64>): Boolean` are stdlib functions
- Time arg needs `disclose()` when passed: `blockTimeGte(disclose(deadline))`

---

### Task 1: Scaffold directory structure

**Files:**
- Create: `plugins/compact-core/skills/compact-patterns/` (directory)
- Create: `plugins/compact-core/skills/compact-patterns/references/` (directory)

**Step 1: Create directories**

```bash
mkdir -p plugins/compact-core/skills/compact-patterns/references
```

**Step 2: Verify structure**

```bash
ls -la plugins/compact-core/skills/compact-patterns/
```

Expected: `references/` directory exists

No commit yet — wait for SKILL.md.

---

### Task 2: Write SKILL.md

**Files:**
- Create: `plugins/compact-core/skills/compact-patterns/SKILL.md`

**Step 1: Create SKILL.md with the following complete content:**

````markdown
---
name: compact-patterns
description: This skill should be used when the user asks about Compact contract design patterns, reusable contract building blocks, access control patterns (owner-only, RBAC, multi-sig), pausable or emergency stop patterns, initializable contracts, state machine patterns, time-locked operations, commit-reveal schemes, sealed-bid auctions, escrow patterns, treasury or pot management, multi-party authorization, voting or governance contracts, registry or allowlist patterns, credential verification, domain-separated identity, anonymous membership with Merkle proofs, round-based unlinkability, selective disclosure, or how to combine multiple patterns together.
---

# Compact Contract Patterns

A comprehensive catalog of 18 reusable contract design patterns for Midnight Compact smart contracts. This skill is the central patterns reference. For token-specific patterns (FungibleToken, NFT, ShieldedToken), see `compact-tokens`. For privacy mechanics deep dives (Witness Protection Program, disclosure debugging), see `compact-privacy-disclosure`. For contract anatomy, see `compact-structure`.

## Pattern Quick Reference

| # | Pattern | Category | Complexity | When to Use | Key Primitives |
|---|---------|----------|-----------|-------------|----------------|
| 1 | Owner-Only | Access Control | Beginner | Single administrator contract | `sealed ledger`, `persistentHash` |
| 2 | Role-Based Access Control | Access Control | Intermediate | Multiple roles with different permissions | `Map<Bytes<32>, Role>`, `enum` |
| 3 | Pausable / Emergency Stop | Access Control | Intermediate | Need to halt operations in emergencies | `Boolean` flag, guard circuits |
| 4 | Initializable | Access Control | Beginner | One-time setup without constructor | `Boolean` flag, `initialize()` guard |
| 5 | State Machine | State Mgmt | Beginner | Multi-phase protocols with ordered transitions | `enum` phases, transition functions |
| 6 | Time-Locked Operations | State Mgmt | Intermediate | Enforce deadlines on actions | `blockTimeGte`, `sealed ledger` |
| 7 | Commit-Reveal | Commitment | Intermediate | Hide a value, prove it later | `persistentCommit`, salt management |
| 8 | Sealed-Bid Auction | Commitment | Advanced | Private bidding with fair resolution | Commit-reveal + escrow + time-lock |
| 9 | Escrow | Value | Intermediate | Hold funds until conditions are met | `receiveShielded`, `sendShielded` |
| 10 | Treasury / Pot | Value | Intermediate | Manage pooled funds with controlled withdrawal | `QualifiedShieldedCoinInfo`, `mergeCoin` |
| 11 | Multi-Party Auth (Multi-Sig) | Governance | Advanced | Require M-of-N approvals for actions | `Map` approvals, `Counter` threshold |
| 12 | Voting / Governance | Governance | Advanced | Democratic decision-making with privacy | Commit-reveal + nullifiers + MerkleTree |
| 13 | Registry / Allowlist | Identity | Beginner | Managed membership lists | `Set<Bytes<32>>`, admin gates |
| 14 | Credential Verification | Identity | Intermediate | Prove properties without revealing data | `persistentCommit`, threshold checks |
| 15 | Domain-Separated Identity | Identity | Beginner | Multi-purpose keys from single secret | `persistentHash` + domain prefixes |
| 16 | Anonymous Membership | Identity | Advanced | Prove membership without revealing who | `HistoricMerkleTree`, `checkRoot` |
| 17 | Round-Based Unlinkability | Privacy | Intermediate | Break transaction linkability | `Counter`-rotated authority hash |
| 18 | Selective Disclosure | Privacy | Intermediate | Prove properties without revealing values | `disclose()` on boolean results only |

## Pattern Combination Guide

When you need to combine patterns, use this table to find the right combination. Each row describes a common contract need and which patterns to compose.

| Need | Combine | Key Integration Points |
|------|---------|----------------------|
| Time-locked multi-sig | #6 + #11 + #5 | State machine tracks approval count; time-lock enforces execution window |
| Private auction | #8 + #9 + #16 | Merkle auth for anonymous bidders; escrow holds bid deposits |
| Governed token | #2 + #3 + Token patterns | Admin controls pause; roles control mint/burn. See `compact-tokens` |
| DAO voting | #12 + #10 + #6 | Token-gated votes; treasury releases funds on passing proposals |
| KYC-gated access | #14 + #13 | Verify credential ZK proof, then add to allowlist |
| Private membership club | #16 + #2 + #9 | Anonymous members; admin manages roles; dues held in escrow |
| Phased crowdfund | #5 + #9 + #6 | Registration phase, funding phase (escrow), time-locked release |
| Anonymous credential | #14 + #16 + nullifiers | Commit credential to tree; prove membership anonymously; nullifier prevents reuse |
| Upgradeable contract | #4 + #2 + #5 | Initializable for setup; RBAC for upgrade authority; state machine for migration phases |
| Emergency-stoppable DEX | #3 + #9 + #2 | Admin can pause all trades; held funds safe during pause |

### Composition Principles

When mixing patterns:

1. **Auth before action.** Access control checks (Owner-Only, RBAC) go at the top of every circuit, before any state mutation.
2. **State checks after auth.** State machine phase assertions come after auth checks: "Am I allowed?" then "Is it the right phase?"
3. **Privacy stacks.** When combining a privacy pattern (Merkle Auth) with a governance pattern (Voting), verify that the governance operations don't inadvertently `disclose()` values that the privacy pattern intended to keep hidden.
4. **Shared identity circuits.** If multiple patterns need `get_public_key(sk)`, define it once and reuse. Use consistent domain separators across the contract.
5. **Test the combination.** Each individual pattern has test considerations. When combining, also test the interaction: Can a paused contract still process escrow refunds? Does time-lock interact correctly with multi-sig approval counting?

## Best Practices

1. **Start Simple** — Use simple patterns as building blocks. Start with Owner-Only before moving to RBAC. Use State Machine before building full Voting. Each pattern in this catalog is designed to be a composable unit.

2. **Understand Privacy** — Every pattern includes a Privacy Considerations section. Read it. Know what an on-chain observer can see. Every `disclose()` call is an intentional decision to make data public. When in doubt, keep data private and disclose only boolean results.

3. **Test Thoroughly** — Each pattern includes test considerations with specific edge cases. Pay special attention to: access control boundaries (can unauthorized users bypass?), state transition edges (what happens at phase boundaries?), and arithmetic overflow (cast results back to target types).

4. **Combine Carefully** — When mixing patterns, verify privacy guarantees still hold. Adding Pausable to an escrow contract must not leak information about held funds. Adding RBAC to a Merkle-auth contract must not reveal which member triggered the role check.

5. **Document Intent** — Add comments explaining business logic. Future readers (and agents) need to understand WHY a pattern was chosen, not just WHAT it does. Comment the domain separators, the phase transition rules, and the privacy trade-offs.

## Reference Routing

| Topic | Reference File |
|-------|---------------|
| Owner-Only, RBAC, Pausable, Initializable | `references/access-control-patterns.md` |
| State Machine, Time-Locked Operations | `references/state-management-patterns.md` |
| Commit-Reveal, Sealed-Bid Auction | `references/commitment-patterns.md` |
| Escrow, Treasury / Pot Management | `references/value-handling-patterns.md` |
| Multi-Party Auth (Multi-Sig), Voting / Governance | `references/governance-patterns.md` |
| Registry / Allowlist, Credential Verification, Domain-Separated Identity, Anonymous Membership | `references/identity-membership-patterns.md` |
| Round-Based Unlinkability, Selective Disclosure | `references/privacy-patterns.md` |

## Cross-Skill References

| Need | Skill |
|------|-------|
| Token patterns (FungibleToken, NFT, MultiToken, ShieldedToken) | `compact-tokens` |
| Privacy deep dive (Witness Protection, disclosure debugging, threat model) | `compact-privacy-disclosure` |
| Ledger ADT types and state design | `compact-ledger` |
| Contract anatomy, circuit/witness design | `compact-structure` |
| Standard library function signatures | `compact-standard-library` |
| TypeScript witness implementation | `compact-witness-ts` |
| Language syntax reference | `compact-language-ref` |
````

**Step 2: Verify file was created**

```bash
cat plugins/compact-core/skills/compact-patterns/SKILL.md | head -5
```

Expected: Shows frontmatter with `name: compact-patterns`

**Step 3: Commit**

```bash
git add plugins/compact-core/skills/compact-patterns/SKILL.md
git commit -m "feat(compact-core): add SKILL.md for compact-patterns"
```

---

### Task 3: Write access-control-patterns.md

**Files:**
- Create: `plugins/compact-core/skills/compact-patterns/references/access-control-patterns.md`

**Step 1: Create file with the following complete content:**

````markdown
# Access Control Patterns

Patterns for controlling who can call which circuits. These are foundational
building blocks — most contracts need at least one access control pattern.

## Owner-Only

**Purpose:** Restrict circuit execution to a single administrator.
**Complexity:** Beginner
**Key Primitives:** `sealed ledger`, `persistentHash`, `assert`

### When to Use

- Single admin who deploys and manages the contract
- Simple contracts where one person controls all operations
- Starting point before adding more complex access control

### Implementation

```compact
pragma language_version >= 0.16 && <= 0.18;
import CompactStandardLibrary;

// Owner set at deployment, immutable
export sealed ledger owner: Bytes<32>;

witness local_secret_key(): Bytes<32>;

// Derive a public key from a secret key via hashing
// public_key() is NOT a builtin — this is the standard pattern
circuit get_public_key(sk: Bytes<32>): Bytes<32> {
  return persistentHash<Vector<2, Bytes<32>>>([
    pad(32, "myapp:pk:"), sk
  ]);
}

constructor() {
  // Set the deployer as owner (sealed = immutable after constructor)
  owner = disclose(get_public_key(local_secret_key()));
}

// Guard circuit — reuse in any owner-only operation
circuit requireOwner(): [] {
  const sk = local_secret_key();
  const caller = get_public_key(sk);
  assert(disclose(caller == owner), "Not authorized");
}

// Example: owner-only action
export circuit adminAction(value: Field): [] {
  requireOwner();
  // ... perform admin-only logic
}
```

### Privacy Considerations

- The `owner` field is `sealed`, meaning it is set once at deployment and visible
  on-chain. The owner's public key hash is therefore public.
- The `assert(disclose(caller == owner))` reveals whether the caller matched, but
  since the circuit fails on mismatch, in practice only the owner can call it.
- An observer can see that an admin action occurred but cannot learn the owner's
  secret key from the hash.

### Test Considerations

- Verify owner can call admin circuits successfully
- Verify non-owner gets assertion failure
- Verify owner field cannot be changed after construction (sealed guarantee)
- Test with a second user who has a different secret key

### Common Mistakes

| Wrong | Correct | Why |
|-------|---------|-----|
| `export ledger owner: Bytes<32>` | `export sealed ledger owner: Bytes<32>` | Without `sealed`, owner can be reassigned |
| `assert(caller == owner, "msg")` | `assert(disclose(caller == owner), "msg")` | Witness-derived comparison needs `disclose()` |
| `public_key(sk)` | `get_public_key(sk)` using `persistentHash` | `public_key` is not a builtin |

---

## Role-Based Access Control (RBAC)

**Purpose:** Support multiple roles with different permission levels.
**Complexity:** Intermediate
**Key Primitives:** `Map<Bytes<32>, Role>`, `enum`, `assert`

### When to Use

- Multiple users with different permission levels
- Need to grant and revoke roles dynamically
- Contracts with admin, operator, and viewer tiers

### Implementation

```compact
pragma language_version >= 0.16 && <= 0.18;
import CompactStandardLibrary;

export enum Role { admin, operator, viewer }
export ledger roles: Map<Bytes<32>, Role>;

witness local_secret_key(): Bytes<32>;

circuit get_public_key(sk: Bytes<32>): Bytes<32> {
  return persistentHash<Vector<2, Bytes<32>>>([
    pad(32, "myapp:pk:"), sk
  ]);
}

// Initialize deployer as admin
constructor() {
  const pk = get_public_key(local_secret_key());
  roles.insert(disclose(pk), Role.admin);
}

// Guard: require caller to have a specific role
circuit requireRole(required: Role): [] {
  const sk = local_secret_key();
  const caller = get_public_key(sk);
  assert(disclose(roles.member(caller)), "No role assigned");
  assert(disclose(roles.lookup(caller) == required), "Insufficient permissions");
}

// Admin-only: grant a role to another user
export circuit grantRole(target: Bytes<32>, role: Role): [] {
  requireRole(Role.admin);
  roles.insert(disclose(target), disclose(role));
}

// Admin-only: revoke a role
export circuit revokeRole(target: Bytes<32>): [] {
  requireRole(Role.admin);
  roles.remove(disclose(target));
}

// Example: operator-only action
export circuit operatorAction(): [] {
  requireRole(Role.operator);
  // ... operator-only logic
}

// Example: admin-only action
export circuit adminAction(): [] {
  requireRole(Role.admin);
  // ... admin-only logic
}
```

### Privacy Considerations

- The `roles` Map is public on-chain. All role assignments (who has which role)
  are visible. The public key hashes used as keys are observable.
- An observer can see how many roles are assigned and when grants/revocations occur.
- For private role management, consider using `MerkleTree` with committed role
  identifiers instead of a `Map`. See the Anonymous Membership pattern.

### Test Considerations

- Verify admin can grant and revoke roles
- Verify operator can call operator circuits but not admin circuits
- Verify unregistered user (no role) cannot call any guarded circuit
- Verify admin cannot accidentally remove their own admin role (consider adding a self-revocation check)
- Test role transition: grant operator, then upgrade to admin

### Common Mistakes

| Wrong | Correct | Why |
|-------|---------|-----|
| `roles.lookup(caller) == Role.admin` without `disclose()` | `disclose(roles.lookup(caller) == required)` | Witness comparison needs disclosure |
| Checking role without checking `member()` first | Check `roles.member(caller)` before `roles.lookup(caller)` | `lookup` on non-existent key returns default, which may silently match |

---

## Pausable / Emergency Stop

**Purpose:** Allow halting all contract operations in an emergency.
**Complexity:** Intermediate
**Key Primitives:** `Boolean` ledger field, guard circuits

### When to Use

- DeFi contracts where a vulnerability may require halting trades
- Any contract that benefits from an emergency stop mechanism
- Contracts handling valuable assets where caution is warranted

### Implementation

```compact
pragma language_version >= 0.16 && <= 0.18;
import CompactStandardLibrary;

export sealed ledger owner: Bytes<32>;
export ledger isPaused: Boolean;

witness local_secret_key(): Bytes<32>;

circuit get_public_key(sk: Bytes<32>): Bytes<32> {
  return persistentHash<Vector<2, Bytes<32>>>([
    pad(32, "myapp:pk:"), sk
  ]);
}

constructor() {
  owner = disclose(get_public_key(local_secret_key()));
  isPaused = false;
}

circuit requireOwner(): [] {
  const sk = local_secret_key();
  const caller = get_public_key(sk);
  assert(disclose(caller == owner), "Not authorized");
}

// Guard: only callable when NOT paused
circuit assertNotPaused(): [] {
  assert(!isPaused, "Contract is paused");
}

// Guard: only callable when paused
circuit assertPaused(): [] {
  assert(isPaused, "Contract is not paused");
}

// Owner can pause the contract
export circuit pause(): [] {
  requireOwner();
  assertNotPaused();
  isPaused = true;
}

// Owner can unpause the contract
export circuit unpause(): [] {
  requireOwner();
  assertPaused();
  isPaused = false;
}

// Example: guarded circuit
export circuit normalOperation(): [] {
  assertNotPaused();
  // ... normal logic that should be halted in emergencies
}
```

### Privacy Considerations

- `isPaused` is a public Boolean on-chain. Anyone can see whether the contract
  is currently paused.
- Pause/unpause transactions are visible, including their timing.
- This is intentional: users need to know if a contract is paused before
  attempting transactions.

### Test Considerations

- Verify `normalOperation` works when not paused
- Verify `normalOperation` fails when paused
- Verify only owner can pause and unpause
- Verify double-pause fails (already paused)
- Verify double-unpause fails (not paused)
- Test that pause state persists across multiple transactions

### Common Mistakes

| Wrong | Correct | Why |
|-------|---------|-----|
| Forgetting to add `assertNotPaused()` to new circuits | Add to every user-facing circuit | New circuits silently bypass the pause mechanism |
| Pausing without an unpause path | Always include `unpause()` | Permanent pause locks all contract funds |

---

## Initializable

**Purpose:** One-time setup guard for contracts that cannot use constructors.
**Complexity:** Beginner
**Key Primitives:** `Boolean` ledger field

### When to Use

- Contracts deployed via factory patterns (no constructor args available)
- Multi-step initialization that cannot fit in a constructor
- Modular contracts where initialization happens after deployment

### Implementation

```compact
pragma language_version >= 0.16 && <= 0.18;
import CompactStandardLibrary;

export ledger isInitialized: Boolean;
export ledger adminPk: Bytes<32>;

witness local_secret_key(): Bytes<32>;

circuit get_public_key(sk: Bytes<32>): Bytes<32> {
  return persistentHash<Vector<2, Bytes<32>>>([
    pad(32, "myapp:pk:"), sk
  ]);
}

// Guard: ensure initialization has happened
circuit assertInitialized(): [] {
  assert(isInitialized, "Contract not initialized");
}

// Guard: ensure initialization has NOT happened
circuit assertNotInitialized(): [] {
  assert(!isInitialized, "Already initialized");
}

// One-time setup — can only be called once
export circuit initialize(config: Bytes<32>): [] {
  assertNotInitialized();
  adminPk = disclose(get_public_key(local_secret_key()));
  // ... set up other initial state using config
  isInitialized = true;
}

// Example: circuit that requires initialization
export circuit doSomething(): [] {
  assertInitialized();
  // ... logic that depends on initialization
}
```

### Privacy Considerations

- `isInitialized` is public on-chain. Anyone can see whether the contract has
  been initialized.
- The initialization transaction itself is visible, including when it occurred.

### Test Considerations

- Verify `initialize()` can be called once successfully
- Verify second call to `initialize()` fails
- Verify guarded circuits fail before initialization
- Verify guarded circuits succeed after initialization

### Common Mistakes

| Wrong | Correct | Why |
|-------|---------|-----|
| Using `initialize()` without `assertNotInitialized()` | Always check `assertNotInitialized()` first | Without the guard, anyone can re-initialize and overwrite state |
| Forgetting `assertInitialized()` on operational circuits | Add to every circuit that depends on init state | Circuits may operate on uninitialized (default) state |
````

**Step 2: Commit**

```bash
git add plugins/compact-core/skills/compact-patterns/references/access-control-patterns.md
git commit -m "feat(compact-core): add access-control-patterns reference for compact-patterns"
```

---

### Task 4: Write state-management-patterns.md

**Files:**
- Create: `plugins/compact-core/skills/compact-patterns/references/state-management-patterns.md`

**Step 1: Create file with the following complete content:**

````markdown
# State Management Patterns

Patterns for controlling the lifecycle and timing of contract operations.

## State Machine

**Purpose:** Enforce ordered phase transitions in multi-step protocols.
**Complexity:** Beginner
**Key Primitives:** `enum`, `assert`, transition functions

### When to Use

- Multi-phase protocols (registration, active, completed)
- Auctions, voting, crowdfunding with distinct phases
- Any workflow where operations are only valid in certain states

### Implementation

```compact
pragma language_version >= 0.16 && <= 0.18;
import CompactStandardLibrary;

export enum Phase { registration, active, completed }
export ledger phase: Phase;
export sealed ledger owner: Bytes<32>;
export ledger participants: Set<Bytes<32>>;

witness local_secret_key(): Bytes<32>;

circuit get_public_key(sk: Bytes<32>): Bytes<32> {
  return persistentHash<Vector<2, Bytes<32>>>([
    pad(32, "myapp:pk:"), sk
  ]);
}

constructor() {
  phase = Phase.registration;
  owner = disclose(get_public_key(local_secret_key()));
}

circuit requireOwner(): [] {
  const sk = local_secret_key();
  assert(disclose(get_public_key(sk) == owner), "Not authorized");
}

// Phase-specific operations
export circuit register(participant: Bytes<32>): [] {
  assert(phase == Phase.registration, "Registration closed");
  participants.insert(disclose(participant));
}

// Auth-gated phase transition
export circuit activate(): [] {
  requireOwner();
  assert(phase == Phase.registration, "Can only activate from registration");
  assert(disclose(!participants.isEmpty()), "No participants registered");
  phase = Phase.active;
}

export circuit complete(): [] {
  requireOwner();
  assert(phase == Phase.active, "Not in active phase");
  phase = Phase.completed;
  // ... finalization logic
}
```

### Privacy Considerations

- The `phase` enum is public on-chain. Everyone can see the current phase.
- Phase transitions are visible transactions. An observer sees exactly when each
  phase change occurred.
- Participant registration (via `Set.insert`) is public. All registered public
  key hashes are visible on-chain.

### Test Considerations

- Verify each phase only allows its designated operations
- Verify phase transitions follow the correct order (registration -> active -> completed)
- Verify skipping a phase fails (e.g., registration -> completed)
- Verify backward transitions fail
- Verify only the owner can advance phases
- Test edge: activate with empty participants set should fail

### Common Mistakes

| Wrong | Correct | Why |
|-------|---------|-----|
| Not asserting the current phase | `assert(phase == Phase.registration, "msg")` | Without checks, operations run in wrong phases |
| Allowing any user to advance phases | Gate transitions with `requireOwner()` | Unauthorized phase changes break protocol |

---

## Time-Locked Operations

**Purpose:** Enforce deadlines on contract actions using block time.
**Complexity:** Intermediate
**Key Primitives:** `blockTimeGte`, `blockTimeLt`, `sealed ledger`

### When to Use

- Auctions with bid deadlines
- Vesting schedules that unlock funds over time
- Commit-reveal protocols with phase deadlines
- Any operation that should only execute after (or before) a certain time

### Implementation

```compact
pragma language_version >= 0.16 && <= 0.18;
import CompactStandardLibrary;

// Deadlines set at deployment (Unix epoch seconds as Uint<64>)
export sealed ledger lockEndTime: Uint<64>;
export sealed ledger owner: Bytes<32>;
export ledger isExecuted: Boolean;

witness local_secret_key(): Bytes<32>;

circuit get_public_key(sk: Bytes<32>): Bytes<32> {
  return persistentHash<Vector<2, Bytes<32>>>([
    pad(32, "myapp:pk:"), sk
  ]);
}

constructor(endTime: Uint<64>) {
  lockEndTime = disclose(endTime);
  owner = disclose(get_public_key(local_secret_key()));
  isExecuted = false;
}

circuit requireOwner(): [] {
  const sk = local_secret_key();
  assert(disclose(get_public_key(sk) == owner), "Not authorized");
}

// Can only be called AFTER the lock period ends
export circuit executeAfterLock(): [] {
  requireOwner();
  assert(!isExecuted, "Already executed");
  assert(blockTimeGte(lockEndTime), "Lock period not over");
  isExecuted = true;
  // ... perform the time-locked action
}

// Can only be called BEFORE the deadline
export circuit submitBeforeDeadline(value: Bytes<32>): [] {
  assert(blockTimeLt(lockEndTime), "Deadline passed");
  // ... accept submission
}
```

### Combining with State Machine

Time-locks are most powerful when combined with a state machine:

```compact
export enum Phase { commit, reveal, finalized }
export ledger phase: Phase;
export sealed ledger commitDeadline: Uint<64>;
export sealed ledger revealDeadline: Uint<64>;

export circuit advanceToReveal(): [] {
  assert(phase == Phase.commit, "Not in commit phase");
  assert(blockTimeGte(commitDeadline), "Commit phase not over");
  phase = Phase.reveal;
}

export circuit finalize(): [] {
  assert(phase == Phase.reveal, "Not in reveal phase");
  assert(blockTimeGte(revealDeadline), "Reveal phase not over");
  phase = Phase.finalized;
  // ... tally results, distribute funds
}
```

### Privacy Considerations

- Deadlines stored in `sealed ledger` are visible on-chain at deployment time.
  Everyone can see when phases start and end.
- `blockTimeGte` / `blockTimeLt` compare against the block time, which is
  approximate (determined by block production, not wall clock). Allow buffer
  time for block time variability.

### Test Considerations

- Verify action fails before the deadline
- Verify action succeeds after the deadline
- Test at the exact boundary (equal to deadline) — `blockTimeGte` includes equality
- Verify `blockTimeLt` excludes the boundary
- Test with multiple time-locked phases in sequence
- Account for block time granularity (not precise to the second)

### Common Mistakes

| Wrong | Correct | Why |
|-------|---------|-----|
| `blockTimeGte(deadline)` with witness-derived deadline | `blockTimeGte(lockEndTime)` using ledger value | Deadline should be on-chain, not witness-provided (could be spoofed) |
| Tight time windows (seconds) | Use hours or larger windows | Block time is approximate; tight windows cause race conditions |
| Forgetting `disclose()` on witness-derived time values | `blockTimeGte(disclose(time))` | Time arguments from witnesses need disclosure |
````

**Step 2: Commit**

```bash
git add plugins/compact-core/skills/compact-patterns/references/state-management-patterns.md
git commit -m "feat(compact-core): add state-management-patterns reference for compact-patterns"
```

---

### Task 5: Write commitment-patterns.md

**Files:**
- Create: `plugins/compact-core/skills/compact-patterns/references/commitment-patterns.md`

**Step 1: Create file with the following complete content:**

````markdown
# Commitment Patterns

Patterns for hiding values on-chain and revealing them later with proof.

## Commit-Reveal

**Purpose:** Hide a value on-chain, then prove it later without tampering.
**Complexity:** Intermediate
**Key Primitives:** `persistentCommit`, `persistentHash`, witness storage

### When to Use

- Sealed-bid mechanisms where bids must be hidden until reveal
- Games where players must commit moves simultaneously
- Any protocol where premature disclosure creates unfair advantages

### Implementation

Single-participant commit-reveal:

```compact
pragma language_version >= 0.16 && <= 0.18;
import CompactStandardLibrary;

export ledger commitment: Bytes<32>;
export ledger revealedValue: Field;
export ledger isRevealed: Boolean;

witness local_secret_key(): Bytes<32>;
witness storeSecretValue(v: Field): [];
witness getSecretValue(): Field;

// Compute commitment using persistentHash with salt
circuit computeCommitment(value: Field, salt: Bytes<32>): Bytes<32> {
  const valueBytes = (value as Field) as Bytes<32>;
  return persistentHash<Vector<2, Bytes<32>>>([valueBytes, salt]);
}

// Phase 1: Commit — store hash on-chain, value off-chain
export circuit commit(value: Field): [] {
  const salt = local_secret_key();
  storeSecretValue(value);
  commitment = disclose(computeCommitment(value, salt));
  isRevealed = false;
}

// Phase 2: Reveal — prove stored value matches commitment
export circuit reveal(): Field {
  const salt = local_secret_key();
  const value = getSecretValue();
  const expected = computeCommitment(value, salt);
  assert(disclose(expected == commitment), "Value does not match commitment");
  assert(disclose(!isRevealed), "Already revealed");
  revealedValue = disclose(value);
  isRevealed = true;
  return disclose(value);
}
```

### Multi-Participant Variant

When multiple users commit and reveal:

```compact
export enum Phase { commit, reveal, finalized }
export ledger phase: Phase;
export ledger commitments: Map<Bytes<32>, Bytes<32>>;
export ledger reveals: Map<Bytes<32>, Field>;

witness local_secret_key(): Bytes<32>;
witness get_randomness(): Bytes<32>;
witness storeOpening(id: Bytes<32>, salt: Bytes<32>, value: Field): [];
witness getOpening(): [Bytes<32>, Field];

circuit get_public_key(sk: Bytes<32>): Bytes<32> {
  return persistentHash<Vector<2, Bytes<32>>>([
    pad(32, "myapp:pk:"), sk
  ]);
}

// Each participant submits a commitment
export circuit submitCommitment(value: Field): [] {
  assert(phase == Phase.commit, "Not in commit phase");
  const sk = local_secret_key();
  const pk = get_public_key(sk);
  const salt = get_randomness();
  const valueBytes = (value as Field) as Bytes<32>;
  const c = persistentHash<Vector<2, Bytes<32>>>([valueBytes, salt]);
  storeOpening(pk, salt, value);
  commitments.insert(disclose(pk), disclose(c));
}

// Each participant reveals their value
export circuit revealValue(): Field {
  assert(phase == Phase.reveal, "Not in reveal phase");
  const sk = local_secret_key();
  const pk = get_public_key(sk);
  assert(disclose(commitments.member(pk)), "No commitment found");
  const opening = getOpening();
  const salt = opening.0;
  const value = opening.1;
  const valueBytes = (value as Field) as Bytes<32>;
  const expected = persistentHash<Vector<2, Bytes<32>>>([valueBytes, salt]);
  assert(disclose(expected == commitments.lookup(pk)), "Commitment mismatch");
  reveals.insert(disclose(pk), disclose(value));
  return disclose(value);
}
```

### Privacy Considerations

- During the commit phase, only the hash is on-chain. The actual value is hidden.
- During the reveal phase, the actual value becomes public via `disclose()`.
- The commitment hash itself may leak information if the value space is small
  (e.g., only 10 possible values). In that case, use `persistentCommit` with
  random blinding instead of `persistentHash`.
- Each participant's public key is visible in the `commitments` Map.

### Test Considerations

- Verify commit stores the correct hash
- Verify reveal with wrong value fails
- Verify reveal with wrong salt fails
- Verify double-reveal fails
- Verify reveal before commit fails
- For multi-participant: verify one user cannot reveal another's commitment
- Test with identical values from different users (should have different commitments due to different salts)

### Common Mistakes

| Wrong | Correct | Why |
|-------|---------|-----|
| `persistentHash(value)` without salt | `persistentHash([value, salt])` | Without salt, identical values produce identical hashes (leaks information) |
| Reusing salt across commitments | Fresh salt per commitment via witness | Same salt + same value = identical commitment = broken hiding |
| Revealing without verifying commitment exists | Check `commitments.member(pk)` first | Prevent reveals for non-existent commitments |

---

## Sealed-Bid Auction

**Purpose:** Private bidding where bids are hidden until simultaneous reveal.
**Complexity:** Advanced
**Key Primitives:** Commit-reveal + escrow + time-lock + state machine

### When to Use

- Auctions where bid privacy matters
- Procurement where competitive bids should not be visible
- Any scenario requiring fair, simultaneous bid revelation

### Implementation

```compact
pragma language_version >= 0.16 && <= 0.18;
import CompactStandardLibrary;

export enum AuctionPhase { bidding, revealing, finalized }
export ledger auctionPhase: AuctionPhase;
export sealed ledger bidDeadline: Uint<64>;
export sealed ledger revealDeadline: Uint<64>;
export sealed ledger organizer: Bytes<32>;

// Bid commitments: bidder_pk -> commitment_hash
export ledger bidCommitments: Map<Bytes<32>, Bytes<32>>;
// Revealed bids: bidder_pk -> bid_amount
export ledger revealedBids: Map<Bytes<32>, Uint<64>>;
// Track highest bid
export ledger highestBid: Uint<64>;
export ledger highestBidder: Bytes<32>;

witness local_secret_key(): Bytes<32>;
witness get_randomness(): Bytes<32>;
witness storeBidOpening(salt: Bytes<32>, amount: Uint<64>): [];
witness getBidOpening(): [Bytes<32>, Uint<64>];

circuit get_public_key(sk: Bytes<32>): Bytes<32> {
  return persistentHash<Vector<2, Bytes<32>>>([
    pad(32, "myapp:auction:pk:"), sk
  ]);
}

constructor(bidEnd: Uint<64>, revealEnd: Uint<64>) {
  auctionPhase = AuctionPhase.bidding;
  bidDeadline = disclose(bidEnd);
  revealDeadline = disclose(revealEnd);
  organizer = disclose(get_public_key(local_secret_key()));
  highestBid = 0;
}

// Submit a sealed bid (commitment only)
export circuit submitBid(bidAmount: Uint<64>): [] {
  assert(auctionPhase == AuctionPhase.bidding, "Bidding closed");
  assert(blockTimeLt(bidDeadline), "Bid deadline passed");
  const sk = local_secret_key();
  const pk = get_public_key(sk);
  assert(disclose(!bidCommitments.member(pk)), "Already submitted a bid");
  const salt = get_randomness();
  const amountBytes = (disclose(bidAmount) as Field) as Bytes<32>;
  const commitment = persistentHash<Vector<2, Bytes<32>>>([amountBytes, salt]);
  storeBidOpening(salt, bidAmount);
  bidCommitments.insert(disclose(pk), disclose(commitment));
}

// Advance to reveal phase (anyone can call after deadline)
export circuit advanceToReveal(): [] {
  assert(auctionPhase == AuctionPhase.bidding, "Not in bidding phase");
  assert(blockTimeGte(bidDeadline), "Bidding still open");
  auctionPhase = AuctionPhase.revealing;
}

// Reveal a previously committed bid
export circuit revealBid(): [] {
  assert(auctionPhase == AuctionPhase.revealing, "Not in reveal phase");
  assert(blockTimeLt(revealDeadline), "Reveal deadline passed");
  const sk = local_secret_key();
  const pk = get_public_key(sk);
  assert(disclose(bidCommitments.member(pk)), "No bid commitment found");
  assert(disclose(!revealedBids.member(pk)), "Already revealed");
  const opening = getBidOpening();
  const salt = opening.0;
  const amount = opening.1;
  const amountBytes = (disclose(amount) as Field) as Bytes<32>;
  const expected = persistentHash<Vector<2, Bytes<32>>>([amountBytes, salt]);
  assert(disclose(expected == bidCommitments.lookup(pk)), "Bid commitment mismatch");
  revealedBids.insert(disclose(pk), disclose(amount));
  // Track highest bid
  if (disclose(amount) > highestBid) {
    highestBid = disclose(amount);
    highestBidder = disclose(pk);
  }
}

// Finalize auction after reveal deadline
export circuit finalizeAuction(): [] {
  assert(auctionPhase == AuctionPhase.revealing, "Not in reveal phase");
  assert(blockTimeGte(revealDeadline), "Reveal phase not over");
  auctionPhase = AuctionPhase.finalized;
  // Winner is highestBidder with highestBid
}
```

### Privacy Considerations

- During bidding, only commitment hashes are visible. Bid amounts are hidden.
- After reveal, all bid amounts and bidder identities become public.
- The number of bidders is visible from the `bidCommitments` Map size.
- Bidders who do not reveal forfeit (their bids remain hidden but they cannot win).
- For anonymous bidding, combine with Merkle Auth pattern — bidders prove
  membership in an authorized set without revealing their identity.

### Test Considerations

- Verify bids cannot be submitted after deadline
- Verify reveals match original commitments
- Verify reveals with wrong salt fail
- Verify reveals with wrong amount fail
- Verify highest bidder tracking is correct
- Test with equal bid amounts
- Verify phase transitions respect deadlines
- Test: what happens if no one reveals?
- Test: what happens if only one person reveals?

### Common Mistakes

| Wrong | Correct | Why |
|-------|---------|-----|
| Allowing bid updates during bidding phase | Check `!bidCommitments.member(pk)` | Bid updates leak information about strategy |
| No deadline on reveal phase | Enforce `revealDeadline` | Without deadline, auction never finalizes |
| Using `persistentCommit` for bids | Use `persistentHash` with salt for bids | Both work, but `persistentHash` with explicit salt gives more control over the opening proof |
````

**Step 2: Commit**

```bash
git add plugins/compact-core/skills/compact-patterns/references/commitment-patterns.md
git commit -m "feat(compact-core): add commitment-patterns reference for compact-patterns"
```

---

### Task 6: Write value-handling-patterns.md

**Files:**
- Create: `plugins/compact-core/skills/compact-patterns/references/value-handling-patterns.md`

**Step 1: Create file with the following complete content:**

````markdown
# Value Handling Patterns

Patterns for managing shielded tokens, escrow, and pooled funds.

## Escrow

**Purpose:** Hold funds in a contract until conditions are met, then release or refund.
**Complexity:** Intermediate
**Key Primitives:** `receiveShielded`, `sendShielded`, `QualifiedShieldedCoinInfo`, state machine

### When to Use

- Two-party trades where funds must be held until delivery
- Conditional payments that depend on off-chain events
- Dispute resolution with refund paths

### Implementation

```compact
pragma language_version >= 0.16 && <= 0.18;
import CompactStandardLibrary;

export enum EscrowState { awaiting_deposit, funded, released, refunded }
export ledger escrowState: EscrowState;
export ledger heldFunds: QualifiedShieldedCoinInfo;
export ledger hasFunds: Boolean;
export sealed ledger depositor: Bytes<32>;
export sealed ledger beneficiary: Bytes<32>;
export sealed ledger arbiter: Bytes<32>;

witness local_secret_key(): Bytes<32>;

circuit get_public_key(sk: Bytes<32>): Bytes<32> {
  return persistentHash<Vector<2, Bytes<32>>>([
    pad(32, "myapp:escrow:pk:"), sk
  ]);
}

constructor(beneficiaryPk: Bytes<32>, arbiterPk: Bytes<32>) {
  escrowState = EscrowState.awaiting_deposit;
  depositor = disclose(get_public_key(local_secret_key()));
  beneficiary = disclose(beneficiaryPk);
  arbiter = disclose(arbiterPk);
  hasFunds = false;
}

// Depositor funds the escrow
export circuit deposit(coin: ShieldedCoinInfo): [] {
  assert(escrowState == EscrowState.awaiting_deposit, "Not awaiting deposit");
  const sk = local_secret_key();
  assert(disclose(get_public_key(sk) == depositor), "Only depositor can fund");
  receiveShielded(disclose(coin));
  heldFunds.writeCoin(disclose(coin),
    right<ZswapCoinPublicKey, ContractAddress>(kernel.self()));
  hasFunds = true;
  escrowState = EscrowState.funded;
}

// Arbiter releases funds to beneficiary
export circuit release(): ShieldedCoinInfo {
  assert(escrowState == EscrowState.funded, "Not funded");
  const sk = local_secret_key();
  assert(disclose(get_public_key(sk) == arbiter), "Only arbiter can release");
  const result = sendShielded(heldFunds,
    left<ZswapCoinPublicKey, ContractAddress>(
      ZswapCoinPublicKey{ bytes: beneficiary }),
    heldFunds.value);
  hasFunds = false;
  escrowState = EscrowState.released;
  return result.sent;
}

// Arbiter refunds to depositor
export circuit refund(): ShieldedCoinInfo {
  assert(escrowState == EscrowState.funded, "Not funded");
  const sk = local_secret_key();
  assert(disclose(get_public_key(sk) == arbiter), "Only arbiter can refund");
  const result = sendShielded(heldFunds,
    left<ZswapCoinPublicKey, ContractAddress>(
      ZswapCoinPublicKey{ bytes: depositor }),
    heldFunds.value);
  hasFunds = false;
  escrowState = EscrowState.refunded;
  return result.sent;
}
```

### Privacy Considerations

- The escrow state (`EscrowState`) is public. Everyone sees whether funds are
  held, released, or refunded.
- Depositor, beneficiary, and arbiter public keys are `sealed` and visible on-chain.
- The held amount is visible through the `QualifiedShieldedCoinInfo` value field.
- For private escrow (hidden amounts), use shielded tokens with the contract as
  a temporary holder and avoid storing the coin info in public ledger state.

### Test Considerations

- Verify deposit only works in `awaiting_deposit` state
- Verify only depositor can deposit
- Verify only arbiter can release or refund
- Verify release sends to beneficiary
- Verify refund sends to depositor
- Verify double-release fails (state already released)
- Test with zero-value coins (should be rejected)

### Common Mistakes

| Wrong | Correct | Why |
|-------|---------|-----|
| Not calling `receiveShielded` before holding | Call `receiveShielded(coin)` first | Contract must explicitly accept the coin |
| Releasing without checking escrow state | Always assert `escrowState == EscrowState.funded` | Prevents double-release or release of unfunded escrow |

---

## Treasury / Pot Management

**Purpose:** Manage pooled funds with controlled deposits and withdrawals.
**Complexity:** Intermediate
**Key Primitives:** `QualifiedShieldedCoinInfo`, `mergeCoinImmediate`, `sendShielded`

### When to Use

- DAOs with a shared treasury
- Games with a shared pot (stakes pooled from multiple players)
- Any contract that accumulates funds from multiple sources

### Implementation

```compact
pragma language_version >= 0.16 && <= 0.18;
import CompactStandardLibrary;

export ledger pot: QualifiedShieldedCoinInfo;
export ledger potHasCoin: Boolean;
export sealed ledger owner: Bytes<32>;

witness local_secret_key(): Bytes<32>;

circuit get_public_key(sk: Bytes<32>): Bytes<32> {
  return persistentHash<Vector<2, Bytes<32>>>([
    pad(32, "myapp:treasury:pk:"), sk
  ]);
}

constructor() {
  owner = disclose(get_public_key(local_secret_key()));
  potHasCoin = false;
}

circuit requireOwner(): [] {
  const sk = local_secret_key();
  assert(disclose(get_public_key(sk) == owner), "Not authorized");
}

// Anyone can contribute funds to the pot
export circuit contribute(coin: ShieldedCoinInfo): [] {
  receiveShielded(disclose(coin));
  if (!potHasCoin) {
    // First contribution: initialize pot
    pot.writeCoin(disclose(coin),
      right<ZswapCoinPublicKey, ContractAddress>(kernel.self()));
    potHasCoin = true;
  } else {
    // Subsequent contributions: merge into existing pot
    pot.writeCoin(mergeCoinImmediate(pot, disclose(coin)),
      right<ZswapCoinPublicKey, ContractAddress>(kernel.self()));
  }
}

// Owner can withdraw a specific amount from the pot
export circuit withdraw(recipient: ZswapCoinPublicKey, amount: Uint<128>): ShieldedCoinInfo {
  requireOwner();
  assert(potHasCoin, "Treasury is empty");
  const result = sendShielded(pot, left<ZswapCoinPublicKey, ContractAddress>(
    disclose(recipient)), disclose(amount));
  // Update pot with change (if any)
  if (disclose(result.change.is_some)) {
    pot.writeCoin(result.change.value,
      right<ZswapCoinPublicKey, ContractAddress>(kernel.self()));
  } else {
    potHasCoin = false;
  }
  return result.sent;
}
```

### Privacy Considerations

- The pot amount is stored in `QualifiedShieldedCoinInfo.value`, which is public
  on-chain. Everyone can see the total treasury balance.
- Contribution amounts are visible (coins must be disclosed to `receiveShielded`).
- Withdrawal amounts and recipients are visible.
- For a more private treasury, consider holding funds in a shielded address
  controlled by the contract rather than in public ledger state.

### Test Considerations

- Verify first contribution initializes the pot correctly
- Verify subsequent contributions merge correctly (total increases)
- Verify withdrawal sends correct amount to recipient
- Verify withdrawal updates pot with remaining change
- Verify full withdrawal sets `potHasCoin = false`
- Verify withdrawal fails on empty treasury
- Test with multiple contributions from different users
- Test withdrawal of more than pot balance fails

### Common Mistakes

| Wrong | Correct | Why |
|-------|---------|-----|
| `receiveShielded(coin)` without `disclose()` | `receiveShielded(disclose(coin))` | Coin info from witness needs disclosure |
| Not tracking `potHasCoin` flag | Use a boolean to track first vs subsequent contributions | First contribution uses `writeCoin`, subsequent use `mergeCoinImmediate` |
| Ignoring `result.change` after `sendShielded` | Always handle the change coin | Unhandled change means lost funds |
````

**Step 2: Commit**

```bash
git add plugins/compact-core/skills/compact-patterns/references/value-handling-patterns.md
git commit -m "feat(compact-core): add value-handling-patterns reference for compact-patterns"
```

---

### Task 7: Write governance-patterns.md

**Files:**
- Create: `plugins/compact-core/skills/compact-patterns/references/governance-patterns.md`

**Step 1: Create file with the following complete content:**

````markdown
# Governance Patterns

Patterns for multi-party decision-making and authorization.

## Multi-Party Authorization (Multi-Sig)

**Purpose:** Require M-of-N approvals before executing an action.
**Complexity:** Advanced
**Key Primitives:** `Map<Bytes<32>, Boolean>`, `Counter`, threshold checking

### When to Use

- Treasury withdrawals requiring multiple signers
- Contract upgrades needing board approval
- Any critical action that should not depend on a single person

### Implementation

```compact
pragma language_version >= 0.16 && <= 0.18;
import CompactStandardLibrary;

export ledger signers: Set<Bytes<32>>;
export ledger approvals: Map<Bytes<32>, Boolean>;
export ledger approvalCount: Counter;
export sealed ledger threshold: Uint<64>;
export ledger proposalActive: Boolean;
export ledger proposalData: Bytes<32>;

witness local_secret_key(): Bytes<32>;

circuit get_public_key(sk: Bytes<32>): Bytes<32> {
  return persistentHash<Vector<2, Bytes<32>>>([
    pad(32, "myapp:multisig:pk:"), sk
  ]);
}

constructor(requiredApprovals: Uint<64>) {
  // Deployer is the first signer
  const pk = get_public_key(local_secret_key());
  signers.insert(disclose(pk));
  threshold = disclose(requiredApprovals);
  proposalActive = false;
}

circuit requireSigner(): Bytes<32> {
  const sk = local_secret_key();
  const pk = get_public_key(sk);
  assert(disclose(signers.member(pk)), "Not an authorized signer");
  return pk;
}

// Any signer can add another signer (in a real system, this would
// itself require multi-sig approval)
export circuit addSigner(newSigner: Bytes<32>): [] {
  requireSigner();
  signers.insert(disclose(newSigner));
}

// Create a new proposal
export circuit propose(data: Bytes<32>): [] {
  requireSigner();
  assert(!proposalActive, "Proposal already active");
  proposalData = disclose(data);
  approvals.resetToDefault();
  approvalCount.resetToDefault();
  proposalActive = true;
}

// Approve the current proposal
export circuit approve(): [] {
  const pk = requireSigner();
  assert(proposalActive, "No active proposal");
  assert(disclose(!approvals.member(pk)), "Already approved");
  approvals.insert(disclose(pk), true);
  approvalCount.increment(1);
}

// Execute the proposal if enough approvals
export circuit execute(): [] {
  requireSigner();
  assert(proposalActive, "No active proposal");
  assert(!approvalCount.lessThan(threshold), "Not enough approvals");
  proposalActive = false;
  // ... execute the approved action using proposalData
}
```

### Privacy Considerations

- All signer identities (public key hashes) are public in the `signers` Set.
- All approvals are public — who approved and when is visible on-chain.
- The proposal data is public. For private proposals, store a commitment instead
  and reveal during execution.
- The threshold is `sealed` and visible at deployment.

### Test Considerations

- Verify proposal creation works
- Verify each signer can approve once
- Verify double-approval fails
- Verify execution fails below threshold
- Verify execution succeeds at exactly threshold
- Verify non-signer cannot approve
- Test with threshold = 1 (single-sig equivalent)
- Test with threshold = total signers (unanimity)
- Verify new proposal resets approvals

### Common Mistakes

| Wrong | Correct | Why |
|-------|---------|-----|
| Not resetting approvals on new proposal | `approvals.resetToDefault()` in `propose()` | Old approvals carry over to new proposal |
| Using `approvalCount.lessThan(threshold)` alone | `!approvalCount.lessThan(threshold)` means count >= threshold | `lessThan` returns true if count < threshold, so negate it |

---

## Voting / Governance

**Purpose:** Democratic decision-making with optional privacy.
**Complexity:** Advanced
**Key Primitives:** Commit-reveal + nullifiers + MerkleTree + state machine

### When to Use

- DAO governance votes
- Community proposals with anonymous or transparent voting
- Any decision requiring collective input with privacy guarantees

### Implementation

This pattern combines state machine, commit-reveal, and nullifiers for a complete
anonymous voting system:

```compact
pragma language_version >= 0.16 && <= 0.18;
import CompactStandardLibrary;

export enum VotePhase { setup, commit, reveal, finalized }
export ledger phase: VotePhase;
export sealed ledger organizer: Bytes<32>;
export ledger topic: Bytes<32>;

// Voter registry and vote tracking
export ledger eligibleVoters: HistoricMerkleTree<10, Bytes<32>>;
export ledger committedVotes: MerkleTree<10, Bytes<32>>;
export ledger committed: Set<Bytes<32>>;
export ledger revealed: Set<Bytes<32>>;
export ledger yesVotes: Counter;
export ledger noVotes: Counter;

witness local_secret_key(): Bytes<32>;
witness local_vote_cast(): Maybe<Boolean>;
witness local_record_vote(vote: Boolean): [];
witness local_advance_state(): [];
witness get_voter_path(pk: Bytes<32>): Maybe<MerkleTreePath<10, Bytes<32>>>;
witness get_vote_path(cm: Bytes<32>): Maybe<MerkleTreePath<10, Bytes<32>>>;

circuit get_public_key(sk: Bytes<32>): Bytes<32> {
  return persistentHash<Vector<2, Bytes<32>>>([
    pad(32, "myapp:vote:pk:"), sk
  ]);
}

circuit commitment_nullifier(sk: Bytes<32>): Bytes<32> {
  return disclose(persistentHash<Vector<2, Bytes<32>>>([
    pad(32, "myapp:vote:cm-nul:"), sk
  ]));
}

circuit reveal_nullifier(sk: Bytes<32>): Bytes<32> {
  return disclose(persistentHash<Vector<2, Bytes<32>>>([
    pad(32, "myapp:vote:rv-nul:"), sk
  ]));
}

circuit commit_with_sk(ballot: Bytes<32>, sk: Bytes<32>): Bytes<32> {
  return disclose(persistentHash<Vector<2, Bytes<32>>>([ballot, sk]));
}

constructor() {
  phase = VotePhase.setup;
  organizer = disclose(get_public_key(local_secret_key()));
}

circuit requireOrganizer(): [] {
  const sk = local_secret_key();
  assert(disclose(get_public_key(sk) == organizer), "Not organizer");
}

// Setup: add eligible voters
export circuit addVoter(voterPk: Bytes<32>): [] {
  requireOrganizer();
  assert(phase == VotePhase.setup, "Setup phase closed");
  eligibleVoters.insert(disclose(voterPk));
}

// Setup: set topic and advance to commit phase
export circuit startVoting(voteTopic: Bytes<32>): [] {
  requireOrganizer();
  assert(phase == VotePhase.setup, "Not in setup phase");
  topic = disclose(voteTopic);
  phase = VotePhase.commit;
}

// Commit: voter commits to a vote anonymously
export circuit voteCommit(ballot: Boolean): [] {
  assert(phase == VotePhase.commit, "Not in commit phase");
  const sk = local_secret_key();
  const pk = get_public_key(sk);
  const comNul = commitment_nullifier(sk);
  assert(!committed.member(comNul), "Already committed");

  // Prove voter eligibility via Merkle proof
  const path = get_voter_path(pk);
  assert(disclose(path.is_some) &&
    eligibleVoters.checkRoot(
      disclose(merkleTreePathRoot<10, Bytes<32>>(path.value))) &&
    pk == path.value.leaf,
    "Not an eligible voter");

  // Commit the vote
  local_record_vote(ballot);
  const cm = commit_with_sk(
    ballot ? pad(32, "yes") : pad(32, "no"), sk);
  committedVotes.insert(cm);
  committed.insert(comNul);
  local_advance_state();
}

// Organizer advances to reveal phase
export circuit advanceToReveal(): [] {
  requireOrganizer();
  assert(phase == VotePhase.commit, "Not in commit phase");
  phase = VotePhase.reveal;
}

// Reveal: voter reveals their committed vote
export circuit voteReveal(): [] {
  assert(phase == VotePhase.reveal, "Not in reveal phase");
  const sk = local_secret_key();
  const revNul = reveal_nullifier(sk);
  assert(!revealed.member(revNul), "Already revealed");

  const vote = local_vote_cast();
  assert(disclose(vote.is_some), "No vote recorded");

  // Verify the revealed vote matches the commitment
  const cm = commit_with_sk(
    vote.value ? pad(32, "yes") : pad(32, "no"), sk);
  const path = get_vote_path(cm);
  assert(disclose(path.is_some) &&
    committedVotes.checkRoot(
      disclose(merkleTreePathRoot<10, Bytes<32>>(path.value))) &&
    cm == path.value.leaf,
    "Vote commitment not found");

  // Tally the vote
  if (disclose(vote.value)) {
    yesVotes.increment(1);
  } else {
    noVotes.increment(1);
  }
  revealed.insert(revNul);
  local_advance_state();
}

// Finalize the vote
export circuit finalizeVote(): [] {
  requireOrganizer();
  assert(phase == VotePhase.reveal, "Not in reveal phase");
  phase = VotePhase.finalized;
}
```

### Privacy Considerations

- **Voter anonymity:** During commit, the voter proves membership in the eligible
  voter tree via a Merkle proof without revealing which voter they are. The
  observer sees a valid proof and a new nullifier but cannot link them to a
  specific voter.
- **Vote privacy during commit:** The vote is hidden behind a hash commitment.
- **Vote privacy during reveal:** The actual vote (yes/no) becomes public.
  However, it cannot be linked to a specific voter because the commitment and
  reveal nullifiers are derived with different domain separators.
- **Tally privacy:** The running tally (yesVotes, noVotes) is public on-chain.
  Each reveal increments a counter, so the vote direction is visible at reveal time.

### Test Considerations

- Verify only eligible voters can commit
- Verify the same voter cannot commit twice (nullifier check)
- Verify the same voter cannot reveal twice
- Verify reveal with wrong vote fails (commitment mismatch)
- Verify non-eligible voter is rejected
- Verify phase transitions are enforced
- Verify final tally matches individual reveals
- Test with a single voter
- Test with the maximum number of voters (2^10 = 1024 for depth 10)

### Common Mistakes

| Wrong | Correct | Why |
|-------|---------|-----|
| Same domain separator for commit and reveal nullifiers | `"myapp:vote:cm-nul:"` vs `"myapp:vote:rv-nul:"` | Same domain enables linking commit to reveal |
| Using `Set` for voter eligibility | Use `MerkleTree` + ZK path proof | Set reveals which element is being checked; MerkleTree preserves anonymity |
| Not storing vote off-chain | Use `local_record_vote()` witness to store | Vote must be retrievable during reveal phase |
````

**Step 2: Commit**

```bash
git add plugins/compact-core/skills/compact-patterns/references/governance-patterns.md
git commit -m "feat(compact-core): add governance-patterns reference for compact-patterns"
```

---

### Task 8: Write identity-membership-patterns.md

**Files:**
- Create: `plugins/compact-core/skills/compact-patterns/references/identity-membership-patterns.md`

**Step 1: Create file with the following complete content:**

````markdown
# Identity & Membership Patterns

Patterns for managing identities, membership lists, and credentials.

## Registry / Allowlist

**Purpose:** Maintain a managed list of authorized entities.
**Complexity:** Beginner
**Key Primitives:** `Set<Bytes<32>>`, admin gates

### When to Use

- Whitelisting addresses for token sales or airdrops
- Managing a list of authorized service providers
- Gating access to contract features based on registration

### Implementation

```compact
pragma language_version >= 0.16 && <= 0.18;
import CompactStandardLibrary;

export ledger allowlist: Set<Bytes<32>>;
export sealed ledger admin: Bytes<32>;

witness local_secret_key(): Bytes<32>;

circuit get_public_key(sk: Bytes<32>): Bytes<32> {
  return persistentHash<Vector<2, Bytes<32>>>([
    pad(32, "myapp:registry:pk:"), sk
  ]);
}

constructor() {
  admin = disclose(get_public_key(local_secret_key()));
}

circuit requireAdmin(): [] {
  const sk = local_secret_key();
  assert(disclose(get_public_key(sk) == admin), "Not admin");
}

// Guard: require caller to be on the allowlist
circuit requireAllowlisted(): [] {
  const sk = local_secret_key();
  const pk = get_public_key(sk);
  assert(disclose(allowlist.member(pk)), "Not on allowlist");
}

// Admin adds an address to the allowlist
export circuit addToAllowlist(pk: Bytes<32>): [] {
  requireAdmin();
  allowlist.insert(disclose(pk));
}

// Admin removes an address from the allowlist
export circuit removeFromAllowlist(pk: Bytes<32>): [] {
  requireAdmin();
  allowlist.remove(disclose(pk));
}

// Example: allowlisted-only action
export circuit restrictedAction(): [] {
  requireAllowlisted();
  // ... only allowlisted users can do this
}
```

### Privacy Considerations

- The `allowlist` Set is public on-chain. All registered public key hashes are
  visible. Anyone can see who is on the list and the total list size.
- Adding and removing entries is visible.
- For private membership, use the Anonymous Membership (Merkle Auth) pattern
  instead, which hides individual member identity.

### Test Considerations

- Verify admin can add and remove entries
- Verify non-admin cannot modify the list
- Verify allowlisted user can call restricted circuits
- Verify non-allowlisted user is rejected
- Verify removing a user prevents further access
- Test adding the same user twice (should be idempotent)

### Common Mistakes

| Wrong | Correct | Why |
|-------|---------|-----|
| Not checking membership before lookup | Always use `member()` before acting on membership | Avoids acting on default/absent values |
| Using `Map` when only membership matters | Use `Set` for boolean membership | `Set` is simpler and more appropriate when you only need to track existence |

---

## Credential Verification

**Purpose:** Prove a property about private data without revealing the data itself.
**Complexity:** Intermediate
**Key Primitives:** `persistentCommit`, threshold checks, `disclose()` on booleans

### When to Use

- Age verification without revealing exact age
- Income verification without revealing exact income
- KYC compliance without storing personal data on-chain
- Verifiable credentials with selective disclosure

### Implementation

```compact
pragma language_version >= 0.16 && <= 0.18;
import CompactStandardLibrary;

export ledger credentialCommitment: Bytes<32>;
export ledger isCredentialSet: Boolean;

witness getCredentialValue(): Field;
witness getCredentialSalt(): Bytes<32>;
witness storeCredential(value: Field, salt: Bytes<32>): [];

// Issue a credential: commit the value on-chain, store value off-chain
export circuit issueCredential(value: Field): [] {
  assert(!isCredentialSet, "Credential already issued");
  const salt = getCredentialSalt();
  const commitment = persistentCommit<Field>(value, salt);
  storeCredential(value, salt);
  credentialCommitment = disclose(commitment);
  isCredentialSet = true;
}

// Verify: prove the credential value meets a threshold
// Only the boolean result is disclosed — NOT the actual value
export circuit verifyThreshold(threshold: Field): Boolean {
  assert(isCredentialSet, "No credential issued");
  const value = getCredentialValue();
  const salt = getCredentialSalt();

  // Verify the witness value matches the on-chain commitment
  const expected = persistentCommit<Field>(value, salt);
  assert(disclose(expected == credentialCommitment), "Invalid credential");

  // Disclose only the boolean result, NOT the value
  return disclose(value >= threshold);
}

// Verify: prove the credential value is within a range
export circuit verifyRange(minimum: Field, maximum: Field): Boolean {
  assert(isCredentialSet, "No credential issued");
  const value = getCredentialValue();
  const salt = getCredentialSalt();
  const expected = persistentCommit<Field>(value, salt);
  assert(disclose(expected == credentialCommitment), "Invalid credential");

  // Disclose the combined range check as a single boolean
  return disclose(value >= minimum && value <= maximum);
}
```

### Privacy Considerations

- The credential commitment is public on-chain but reveals nothing about the
  actual value (due to the blinding factor in `persistentCommit`).
- Threshold checks (`value >= threshold`) disclose only the boolean result.
  The actual value stays private within the ZK proof.
- An observer sees: (1) that a credential exists, (2) whether it meets
  the threshold, (3) when checks were performed.
- The observer does NOT see: the actual credential value or the salt.

### Test Considerations

- Verify credential issuance stores correct commitment
- Verify threshold check passes when value >= threshold
- Verify threshold check fails when value < threshold
- Verify range check works for values within and outside range
- Verify tampered credential (wrong value or salt) fails commitment check
- Verify credential cannot be re-issued (double issuance guard)

### Common Mistakes

| Wrong | Correct | Why |
|-------|---------|-----|
| `return disclose(value)` | `return disclose(value >= threshold)` | Disclosing the value defeats the purpose — only disclose the boolean result |
| Using `persistentHash` for credentials | Use `persistentCommit` with salt | Hash doesn't hide the value if the value space is small; commit with random blinding does |

---

## Domain-Separated Identity

**Purpose:** Derive multiple distinct keys from a single secret using domain separators.
**Complexity:** Beginner
**Key Primitives:** `persistentHash`, `pad`, domain prefix strings

### When to Use

- Contracts where one user needs multiple identities for different purposes
- Preventing cross-contract identity linking
- Deriving nullifiers, public keys, and commitment keys independently

### Implementation

```compact
pragma language_version >= 0.16 && <= 0.18;
import CompactStandardLibrary;

witness local_secret_key(): Bytes<32>;

// Generic domain-separated key derivation
circuit deriveKey(domain: Bytes<32>, sk: Bytes<32>): Bytes<32> {
  return persistentHash<Vector<2, Bytes<32>>>([domain, sk]);
}

// Specific key derivations with distinct domains
circuit publicKey(sk: Bytes<32>): Bytes<32> {
  return deriveKey(pad(32, "myapp:pk:"), sk);
}

circuit nullifierKey(sk: Bytes<32>): Bytes<32> {
  return deriveKey(pad(32, "myapp:nul:"), sk);
}

circuit commitmentKey(sk: Bytes<32>): Bytes<32> {
  return deriveKey(pad(32, "myapp:commit:"), sk);
}

// Multi-contract domain separation
circuit contractSpecificKey(contractName: Bytes<32>, sk: Bytes<32>): Bytes<32> {
  return persistentHash<Vector<3, Bytes<32>>>([
    pad(32, "myapp:contract:"),
    contractName,
    sk
  ]);
}
```

### Domain Separator Guidelines

| Domain | Format | Purpose |
|--------|--------|---------|
| Public key | `pad(32, "myapp:pk:")` | Identity verification |
| Nullifier | `pad(32, "myapp:nul:")` | Double-action prevention |
| Commitment | `pad(32, "myapp:commit:")` | Value hiding |
| Round-specific | Include round counter in vector | Unlinkability |
| Cross-contract | Include contract name in vector | Prevent cross-contract linking |

**Rules:**
1. Every domain separator MUST be unique within the contract
2. Use your app/contract name as a prefix (e.g., `"myapp:"`)
3. Keep separators human-readable for debugging
4. Never reuse a domain separator for two different purposes

### Privacy Considerations

- Each derived key is independent — knowing one key reveals nothing about
  others derived from the same secret (due to hash preimage resistance).
- An observer cannot determine that two different keys came from the same secret.
- The domain separator strings are embedded in the ZK circuit but are NOT
  visible on-chain unless explicitly disclosed.

### Test Considerations

- Verify different domains produce different keys from the same secret
- Verify same domain + same secret always produces the same key (deterministic)
- Verify different secrets with the same domain produce different keys
- Verify derived keys cannot be reverse-engineered to find the secret

### Common Mistakes

| Wrong | Correct | Why |
|-------|---------|-----|
| Same domain for public key and nullifier | Distinct domains: `"pk:"` vs `"nul:"` | Same domain enables linking public keys to nullifiers |
| No app-level prefix | `pad(32, "myapp:pk:")` with app name | Prevents cross-application domain collisions |
| Short domain strings without padding | `pad(32, "...")` for consistent 32-byte input | `persistentHash` expects consistent input sizes |

---

## Anonymous Membership (Merkle Auth)

**Purpose:** Prove membership in a group without revealing which member you are.
**Complexity:** Advanced
**Key Primitives:** `HistoricMerkleTree`, `merkleTreePathRoot`, `checkRoot`, nullifiers

### When to Use

- Anonymous voting where voter identity must be hidden
- Private club access where membership is verified but identity is not
- Any scenario where "prove you belong" matters but "prove who you are" must be avoided

### Implementation

```compact
pragma language_version >= 0.16 && <= 0.18;
import CompactStandardLibrary;

export ledger members: HistoricMerkleTree<16, Bytes<32>>;
export ledger usedNullifiers: Set<Bytes<32>>;
export sealed ledger admin: Bytes<32>;

witness local_secret_key(): Bytes<32>;
witness getMemberPath(pk: Bytes<32>): MerkleTreePath<16, Bytes<32>>;

circuit get_public_key(sk: Bytes<32>): Bytes<32> {
  return persistentHash<Vector<2, Bytes<32>>>([
    pad(32, "myapp:member:pk:"), sk
  ]);
}

constructor() {
  admin = disclose(get_public_key(local_secret_key()));
}

// Admin adds a member (leaf value is hidden on-chain by MerkleTree)
export circuit addMember(memberPk: Bytes<32>): [] {
  const sk = local_secret_key();
  assert(disclose(get_public_key(sk) == admin), "Not admin");
  members.insert(disclose(memberPk));
}

// Member proves membership anonymously and performs a one-time action
export circuit memberAction(): [] {
  const sk = local_secret_key();
  const pk = get_public_key(sk);

  // Step 1: Get Merkle proof from off-chain state
  const path = getMemberPath(pk);

  // Step 2: Compute root from leaf + path
  const digest = merkleTreePathRoot<16, Bytes<32>>(path);

  // Step 3: Verify against on-chain tree
  assert(members.checkRoot(disclose(digest)), "Not a member");

  // Step 4: Nullifier prevents reuse
  const nul = persistentHash<Vector<2, Bytes<32>>>([
    pad(32, "myapp:member:act-nul:"), sk
  ]);
  assert(disclose(!usedNullifiers.member(nul)), "Already acted");
  usedNullifiers.insert(disclose(nul));

  // ... perform the action
}
```

### Why HistoricMerkleTree

Use `HistoricMerkleTree<N, T>` instead of `MerkleTree<N, T>` when members are
added over time. `HistoricMerkleTree.checkRoot()` accepts proofs against any
prior version of the tree, so a proof generated before new members were added
remains valid. With plain `MerkleTree`, each insertion changes the root and
invalidates all existing proofs.

### Capacity Planning

| Depth (N) | Max Members | Proof Size |
|-----------|-------------|------------|
| 10 | 1,024 | 10 hashes |
| 16 | 65,536 | 16 hashes |
| 20 | 1,048,576 | 20 hashes |

Deeper trees support more members but increase circuit cost. Choose based on
expected membership size.

### Privacy Considerations

- **The observer sees:** A valid membership proof was presented and a new nullifier
  appeared, but NOT which member acted.
- **Leaf guessing caveat:** If the set of possible members is small (e.g., 10
  candidates), an observer can verify guesses. Mitigate by using committed
  values (with randomness) as leaves instead of raw public keys.
- **Nullifier timing:** When a nullifier appears reveals when the member acted.
  If registration order is known, timing can correlate identities to nullifiers.
- **Tree size:** The number of insertions is observable (index increments), so
  the member count is visible even though individual members are hidden.

### Test Considerations

- Verify member can prove membership with valid Merkle path
- Verify non-member is rejected (invalid path)
- Verify nullifier prevents double-action
- Verify proof works after new members are added (HistoricMerkleTree)
- Test at tree capacity boundary (2^N members)
- Verify stale proofs still work (historic root checking)

### Common Mistakes

| Wrong | Correct | Why |
|-------|---------|-----|
| Using `Set` for private membership | Use `MerkleTree` + ZK path | Set reveals which element is checked via `member()` |
| Using `MerkleTree` instead of `HistoricMerkleTree` | `HistoricMerkleTree` when members added over time | Plain MerkleTree invalidates proofs on insertion |
| Disclosing the Merkle leaf | Only `disclose()` the root digest | Disclosing the leaf reveals which member is acting |
````

**Step 2: Commit**

```bash
git add plugins/compact-core/skills/compact-patterns/references/identity-membership-patterns.md
git commit -m "feat(compact-core): add identity-membership-patterns reference for compact-patterns"
```

---

### Task 9: Write privacy-patterns.md

**Files:**
- Create: `plugins/compact-core/skills/compact-patterns/references/privacy-patterns.md`

**Step 1: Create file with the following complete content:**

````markdown
# Privacy Patterns

Patterns for preserving user privacy in contract interactions.

## Round-Based Unlinkability

**Purpose:** Break the link between successive transactions from the same user.
**Complexity:** Intermediate
**Key Primitives:** `Counter`, `persistentHash` with round input, authority rotation

### When to Use

- Single-user authorization where you want to hide that the same user
  authorized multiple transactions
- Contracts where transaction linkability is a privacy concern
- Any scenario where an observer should not be able to correlate transactions
  to the same actor

### Implementation

```compact
pragma language_version >= 0.16 && <= 0.18;
import CompactStandardLibrary;

export ledger authority: Bytes<32>;
export ledger round: Counter;

witness local_secret_key(): Bytes<32>;

// Round-specific public key derivation
circuit publicKey(currentRound: Field, sk: Bytes<32>): Bytes<32> {
  return persistentHash<Vector<3, Bytes<32>>>([
    pad(32, "myapp:round-pk:"),
    (currentRound as Field) as Bytes<32>,
    sk
  ]);
}

constructor() {
  const sk = local_secret_key();
  authority = disclose(publicKey(0, sk));
  round.increment(1);
}

export circuit authorize(): [] {
  const sk = local_secret_key();
  const currentRound = round.read() as Field;
  const pk = publicKey(currentRound, sk);

  // Verify caller matches current round authority
  assert(disclose(authority == pk), "Not authorized");

  // Rotate to next round
  round.increment(1);
  const nextRound = round.read() as Field;
  authority = disclose(publicKey(nextRound, sk));
}
```

### How It Works

Each transaction:
1. Reads the current round counter
2. Derives the expected public key for this round (incorporating the counter)
3. Asserts it matches the stored authority
4. Increments the round counter
5. Computes and stores the next round's authority

The observer sees a different authority hash with each transaction. Without
knowing the secret key, they cannot determine that the same user authorized
all transactions.

### Privacy Considerations

- **Transaction unlinkability:** Each transaction shows a different authority
  hash. An observer cannot link them without the secret key.
- **Deployment linkability:** The constructor sets the first authority. This
  is a unique event and can be linked to the deployer. Subsequent transactions
  are unlinkable to each other.
- **Round counter visibility:** The `Counter` is public. The observer can see
  how many authorizations have occurred (the total count).
- **No backward linkability:** An observer who sees the current authority cannot
  compute previous authorities without the secret key.

### Test Considerations

- Verify authorization succeeds with correct secret key
- Verify authority rotates after each authorization
- Verify old authority values cannot be reused
- Verify different secret keys produce different authority chains
- Verify the round counter increments correctly

### Common Mistakes

| Wrong | Correct | Why |
|-------|---------|-----|
| Fixed public key without round | Include round counter in derivation | Fixed key links all transactions together |
| Forgetting to increment round after authorization | Always increment and rotate | Without rotation, the pattern provides no unlinkability |
| Using the same domain separator as other contracts | Unique domain: `"myapp:round-pk:"` | Cross-contract domain reuse enables linking |

---

## Selective Disclosure

**Purpose:** Prove properties about private data without revealing the data itself.
**Complexity:** Intermediate
**Key Primitives:** `disclose()` on boolean results, `persistentCommit`

### When to Use

- Age verification ("over 18") without revealing exact age
- Balance checks ("sufficient funds") without revealing exact balance
- Credential proofs ("qualified") without revealing qualification details
- Any scenario where the question is boolean but the underlying data is private

### Implementation

```compact
pragma language_version >= 0.16 && <= 0.18;
import CompactStandardLibrary;

export ledger credentialCommitment: Bytes<32>;

witness getCredentialValue(): Field;
witness getCredentialSalt(): Bytes<32>;

// Verify the witness value matches the on-chain commitment,
// then disclose ONLY the boolean result of the comparison
circuit verifyCredential(): Field {
  const value = getCredentialValue();
  const salt = getCredentialSalt();
  const expected = persistentCommit<Field>(value, salt);
  assert(disclose(expected == credentialCommitment), "Invalid credential");
  return value;
}

// Threshold check: prove value >= threshold
export circuit meetsThreshold(threshold: Field): Boolean {
  const value = verifyCredential();
  // ONLY the boolean result is disclosed, NOT the value
  return disclose(value >= threshold);
}

// Range check: prove value is within bounds
export circuit withinRange(minimum: Field, maximum: Field): Boolean {
  const value = verifyCredential();
  return disclose(value >= minimum && value <= maximum);
}

// Equality check: prove value equals a specific target
export circuit equalsValue(target: Field): Boolean {
  const value = verifyCredential();
  return disclose(value == target);
}

// Selective field disclosure from a multi-field profile
witness getProfile(): [Bytes<32>, Field, Field];

export circuit proveAgeAbove(minAge: Field): Boolean {
  const profile = getProfile();
  // profile.0 = name (NOT disclosed)
  // profile.1 = age (comparison result disclosed)
  // profile.2 = income (NOT disclosed)
  return disclose(profile.1 >= minAge);
}

export circuit proveIncomeInRange(minIncome: Field, maxIncome: Field): Boolean {
  const profile = getProfile();
  // Only the income range check is disclosed
  return disclose(profile.2 >= minIncome && profile.2 <= maxIncome);
}
```

### The Key Technique

The critical distinction:

```compact
// WRONG: reveals the actual value
return disclose(value);

// CORRECT: reveals only whether the condition is met
return disclose(value >= threshold);
```

The observer learns "yes, the condition is met" or "no, it is not." They do NOT
learn the actual value. This is the fundamental building block of zero-knowledge
proofs in practice.

### Privacy Considerations

- The observer sees the boolean result and the threshold/range parameters.
- The observer does NOT see the actual credential value.
- The threshold parameters are public (they come from the circuit call). If
  the threshold itself should be private, derive it from a witness.
- Multiple checks with different thresholds can narrow down the actual value.
  For example, checking "age >= 18" then "age >= 21" tells the observer the
  age is at least 21. Consider this in protocol design.

### Test Considerations

- Verify threshold check returns true when value >= threshold
- Verify threshold check returns false when value < threshold
- Verify range check works at boundaries (exactly at minimum and maximum)
- Verify invalid credential (wrong salt) is rejected
- Verify the actual value is not visible in the transaction
- Test with multiple selective disclosure checks on the same credential

### Common Mistakes

| Wrong | Correct | Why |
|-------|---------|-----|
| `return disclose(value)` | `return disclose(value >= threshold)` | Disclosing the value exposes the private data |
| Not verifying credential commitment first | Always check `expected == credentialCommitment` | Without verification, witness could provide any value |
| Using `persistentHash` for credential commitment | Use `persistentCommit` with salt | Hash is brute-forceable on small value spaces; commit with blinding is not |
````

**Step 2: Commit**

```bash
git add plugins/compact-core/skills/compact-patterns/references/privacy-patterns.md
git commit -m "feat(compact-core): add privacy-patterns reference for compact-patterns"
```

---

### Task 10: Update plugin.json with new keywords

**Files:**
- Modify: `plugins/compact-core/.claude-plugin/plugin.json`

**Step 1: Add pattern-related keywords to the existing keywords array**

Add these keywords to the existing array in `plugin.json`:

```json
"patterns",
"access-control",
"owner-only",
"rbac",
"pausable",
"initializable",
"state-machine",
"time-lock",
"commit-reveal",
"auction",
"escrow",
"treasury",
"multi-sig",
"voting",
"governance",
"registry",
"allowlist",
"credential",
"merkle-auth",
"unlinkability",
"selective-disclosure",
"design-patterns"
```

**Step 2: Verify plugin.json is valid JSON**

```bash
python3 -c "import json; json.load(open('plugins/compact-core/.claude-plugin/plugin.json'))"
```

Expected: No output (valid JSON)

**Step 3: Commit**

```bash
git add plugins/compact-core/.claude-plugin/plugin.json
git commit -m "feat(compact-core): add compact-patterns keywords to plugin.json"
```

---

## Summary

| Task | File | Description |
|------|------|-------------|
| 1 | Directory scaffold | Create `compact-patterns/` and `references/` |
| 2 | `SKILL.md` | Master lookup table, combination guide, best practices |
| 3 | `access-control-patterns.md` | Owner-Only, RBAC, Pausable, Initializable |
| 4 | `state-management-patterns.md` | State Machine, Time-Locked Operations |
| 5 | `commitment-patterns.md` | Commit-Reveal, Sealed-Bid Auction |
| 6 | `value-handling-patterns.md` | Escrow, Treasury/Pot Management |
| 7 | `governance-patterns.md` | Multi-Sig, Voting/Governance |
| 8 | `identity-membership-patterns.md` | Registry, Credential, Domain Identity, Merkle Auth |
| 9 | `privacy-patterns.md` | Round-Based Unlinkability, Selective Disclosure |
| 10 | `plugin.json` | Add pattern keywords |

Total: 9 files created, 1 file modified, 10 commits.
