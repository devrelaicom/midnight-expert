---
name: compact-core:compact-patterns
description: This skill should be used when the user asks about Compact contract design patterns, reusable building blocks, or how to combine patterns. Covers access control (owner-only, RBAC, pausable, initializable), state management (state machine, time-locked), commitment schemes (commit-reveal, sealed-bid auction), value handling (escrow, treasury), governance (multi-sig, voting), identity and membership (registry, credential, anonymous Merkle membership), and privacy (unlinkability, selective disclosure).
version: 0.1.0
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
| 7 | Commit-Reveal | Commitment | Intermediate | Hide a value, prove it later | `persistentHash`, salt management |
| 8 | Sealed-Bid Auction | Commitment | Advanced | Private bidding with fair resolution | Commit-reveal + escrow + time-lock |
| 9 | Escrow | Value | Intermediate | Hold funds until conditions are met | `receiveShielded`, `sendShielded` |
| 10 | Treasury / Pot | Value | Intermediate | Manage pooled funds with controlled withdrawal | `QualifiedShieldedCoinInfo`, `mergeCoinImmediate` |
| 11 | Multi-Party Auth (Multi-Sig) | Governance | Advanced | Require M-of-N approvals for actions | `Map` approvals, `Counter` threshold |
| 12 | Voting / Governance | Governance | Advanced | Democratic decision-making with privacy | Commit-reveal + nullifiers + HistoricMerkleTree |
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
