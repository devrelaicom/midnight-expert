# compact-patterns Skill Design

## Overview

A comprehensive catalog of 18 reusable Compact contract design patterns for the compact-core plugin. Serves as the central patterns reference, filling the gap between the existing privacy-disclosure and tokens skills.

## Decisions

- **Self-contained:** All patterns include full Compact code examples inline in reference files. No dependency on loading other skills for code, though cross-references are provided for deep dives.
- **Organized by category:** 7 reference files grouped by functional area (access control, state management, commitment, value handling, governance, identity/membership, privacy).
- **Combination guidance:** Lookup table mapping common needs to pattern combinations, plus short prose on safe composition principles.
- **18 patterns** covering access control, state management, commitment schemes, value handling, governance, identity/membership, and privacy.

## File Structure

```
plugins/compact-core/skills/compact-patterns/
  SKILL.md
  references/
    access-control-patterns.md
    state-management-patterns.md
    commitment-patterns.md
    value-handling-patterns.md
    governance-patterns.md
    identity-membership-patterns.md
    privacy-patterns.md
```

## SKILL.md Structure

1. **Intro** — Scope, relationship to other skills
2. **Pattern Quick Reference Table** — One row per pattern: name, category, complexity, when to use, key primitives
3. **Pattern Combination Guide** — Lookup table mapping needs to pattern combos + prose on safe composition
4. **Best Practices** — Start Simple, Understand Privacy, Test Thoroughly, Combine Carefully, Document Intent
5. **Reference Routing** — Maps each pattern to its reference file
6. **Cross-Skill References** — Links to compact-tokens, compact-privacy-disclosure, etc.

## Pattern Catalog

### Access Control (access-control-patterns.md)

1. **Owner-Only** (Beginner) — Single admin via `sealed ledger owner` + hash-based auth. Constructor sets owner. Circuits check caller's secret key hash against stored owner.
2. **Role-Based Access Control** (Intermediate) — Multiple roles via `Map<Bytes<32>, Role>` + enum. `requireRole()` guard circuit. Role granting restricted to admin. Based on OpenZeppelin AccessControl patterns found in the ecosystem.
3. **Pausable / Emergency Stop** (Intermediate) — Boolean `_isPaused` flag. Guard circuits `assertNotPaused()`/`assertPaused()`. Admin-only `_pause()`/`_unpause()`. Based on OpenZeppelin Pausable module.
4. **Initializable** (Beginner) — Boolean `_isInitialized` flag. `initialize()` sets it once. `assertInitialized()` guard for all operational circuits. Based on OpenZeppelin Initializable module.

### State Management (state-management-patterns.md)

5. **State Machine** (Beginner) — Enum-based phases (`registration`, `active`, `completed`). Circuits assert current phase before acting. Transition functions enforce valid paths. Auth-gated phase advancement.
6. **Time-Locked Operations** (Intermediate) — `blockTimeGte(deadline)`/`blockTimeLt(deadline)` for enforcing deadlines. `sealed ledger` for deadline fields. Combines with state machine for phased protocols.

### Commitment (commitment-patterns.md)

7. **Commit-Reveal** (Intermediate) — Two-phase: commit hidden value via `persistentCommit`, reveal with proof. Off-chain salt storage via witness. Multi-participant variant with Map of commitments.
8. **Sealed-Bid Auction** (Advanced) — Commit-reveal + time phases + value escrow. Bidders commit hashed bids during commit phase, reveal during reveal phase, winner determined in finalization.

### Value Handling (value-handling-patterns.md)

9. **Escrow** (Intermediate) — `receiveShielded` to hold funds. Condition-based release via `sendShielded`. Refund paths for failed conditions. State machine tracks escrow lifecycle.
10. **Treasury / Pot Management** (Intermediate) — Pooled funds via `QualifiedShieldedCoinInfo`. `mergeCoin`/`mergeCoinImmediate` for aggregation. Controlled withdrawal with auth checks. Based on micro-dao pot pattern.

### Governance (governance-patterns.md)

11. **Multi-Party Authorization (Multi-Sig)** (Advanced) — M-of-N approval tracking via Counter or Map. Proposal lifecycle: propose, approve, execute. Threshold enforcement before execution.
12. **Voting / Governance** (Advanced) — Full lifecycle: register voters, commit votes, reveal votes, tally. Token-gated voting (burn token to vote). Merkle-based anonymous voting with nullifiers to prevent double-voting. Based on micro-dao and election examples.

### Identity & Membership (identity-membership-patterns.md)

13. **Registry / Allowlist** (Beginner) — `Set<Bytes<32>>` for transparent membership. Admin-managed insertion/removal. Registration gates for other circuits.
14. **Credential Verification** (Intermediate) — ZK proofs of credentials without revealing values. Commitment-based storage. Threshold checks via `disclose(value >= threshold)`. Based on proofshare and zkBadge patterns.
15. **Domain-Separated Identity** (Beginner) — Key derivation via `persistentHash<Vector<2, Bytes<32>>>([pad(32, "domain:"), sk])`. Multi-purpose keys from single secret using different domain prefixes.
16. **Anonymous Membership (Merkle Auth)** (Advanced) — `HistoricMerkleTree<N, Bytes<32>>` for hidden membership. Off-chain path witness. `merkleTreePathRoot` + `checkRoot` verification. Nullifier integration for one-time actions.

### Privacy (privacy-patterns.md)

17. **Round-Based Unlinkability** (Intermediate) — Counter-rotated authority hash. Each transaction derives round-specific key, breaking linkability between transactions.
18. **Selective Disclosure** (Intermediate) — Proving properties without revealing values. `disclose()` only the boolean result of comparisons. Range proofs, threshold checks, selective field disclosure.

## Pattern Combination Guide (in SKILL.md)

Lookup table of ~10 common combinations:

| Need | Combine | Key Integration Points |
|------|---------|----------------------|
| Time-locked multi-sig | Time-Lock + Multi-Sig + State Machine | State machine tracks approval count; time-lock enforces execution window |
| Private auction | Sealed-Bid Auction + Escrow + Merkle Auth | Merkle auth for anonymous bidders; escrow holds bid deposits |
| Governed token | RBAC + Pausable + Token patterns | Admin controls pause; roles control mint/burn |
| DAO voting | Voting + Treasury + Time-Lock | Token-gated votes; treasury releases funds on passing proposals |
| KYC-gated access | Credential Verification + Registry | Verify credential ZK proof, then add to allowlist |
| Private membership club | Merkle Auth + RBAC + Escrow | Anonymous members; admin manages roles; dues held in escrow |
| Phased crowdfund | State Machine + Escrow + Time-Lock | Registration phase, funding phase (escrow), time-locked release |
| Anonymous credential | Credential + Merkle Auth + Nullifier | Commit credential to tree; prove membership anonymously; nullifier prevents reuse |
| Upgradeable contract | Initializable + RBAC + State Machine | Initializable for setup; RBAC for upgrade authority; state machine for migration phases |
| Emergency-stoppable DEX | Pausable + Escrow + RBAC | Admin can pause all trades; held funds safe during pause |

## Per-Pattern Structure (in reference files)

Each pattern follows this template:

```
## Pattern Name

**Purpose:** One-line description
**Complexity:** Beginner | Intermediate | Advanced
**Key Primitives:** `type`, `function`, etc.

### When to Use
- Bullet list of scenarios

### Ledger State
Description + code block showing ledger declarations

### Circuit Logic
Core implementation with annotated Compact code

### Privacy Considerations
What's public vs private, what an observer sees

### Test Considerations
Edge cases, attack vectors, integration points

### Common Mistakes
| Wrong | Correct | Why |
```

## Best Practices (in SKILL.md)

1. **Start Simple** — Use simple patterns as building blocks. Owner-Only before RBAC. State Machine before full Voting.
2. **Understand Privacy** — Know what's public vs private in each pattern. Every `disclose()` is intentional. Check the Privacy Considerations section.
3. **Test Thoroughly** — Each pattern includes test considerations. Verify edge cases, especially around phase transitions and access control boundaries.
4. **Combine Carefully** — When mixing patterns, verify privacy guarantees still hold. Adding Pausable to an escrow contract must not leak information about held funds.
5. **Document Intent** — Add comments explaining business logic. Future readers (and agents) need to understand WHY a pattern was chosen, not just WHAT it does.

## Plugin.json Updates

Add these keywords to the compact-core plugin.json:

```
"patterns", "access-control", "owner-only", "rbac", "pausable",
"initializable", "state-machine", "time-lock", "commit-reveal",
"auction", "escrow", "treasury", "multi-sig", "voting",
"governance", "registry", "allowlist", "credential",
"merkle-auth", "unlinkability", "selective-disclosure",
"design-patterns"
```

## MCP Research Sources

Patterns derived from analysis of:
- OpenZeppelin/compact-contracts (AccessControl, Pausable, Initializable, FungibleToken, MultiToken)
- midnightntwrk/compact-export (micro-dao, election, coracle, welcome, zerocash examples)
- nel349/midnight-bank (multi-party auth, encrypted balances)
- midnightntwrk/example-proofshare (credential verification)
- Imdavyking/zkbadge (ZK credentials, access control)
- midnames/core (DID patterns, controller authorization)
- midnightntwrk/midnight-reserve-contracts (proxy pattern, two-stage upgrades)
- Midnight official documentation (Compact language reference, privacy model)
