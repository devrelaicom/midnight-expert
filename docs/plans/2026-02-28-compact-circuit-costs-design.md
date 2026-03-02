# Design: compact-circuit-costs Skill

**Date:** 2026-02-28
**Plugin:** compact-core
**Status:** Approved

## Problem

Writing efficient Compact code requires understanding ZK cost implications, but the existing compact-core skills cover functionality without addressing cost tradeoffs. Developers need guidance on how loops unroll into gates, which hash functions are circuit-cheap vs circuit-expensive, when pure circuits save resources, how the gas model works, and how ledger type choices affect state costs. Without this knowledge, developers write contracts that compile correctly but generate unnecessarily large proofs or incur avoidable costs.

## Scope

**In scope:**
- Circuit/proving costs: gate counts, loop unrolling, hash function costs, pure circuit benefits, vector operation costs, compiler optimizations, proving time benchmarks
- Runtime/gas costs: the four-dimension gas model (readTime, computeTime, bytesWritten, bytesDeleted), CostModel, gas limits
- State costs: ledger type cost comparison, privacy-cost tradeoffs, sealed field benefits, nested ADT implications

**Out of scope:**
- Full ADT operation semantics (covered by compact-ledger)
- Privacy pattern design (covered by compact-privacy-disclosure)
- Stdlib function signatures (covered by compact-standard-library)
- Network-level costs (transaction propagation, block inclusion)

## Audience

Both optimization-focused developers already writing Compact and cost-aware beginners learning the language. SKILL.md provides quick-reference tables and decision trees; reference files provide deep explanations and benchmarks.

## Approach: Cost Dimensions

Organized by the three distinct cost dimensions in Midnight contracts:

1. Circuit/proving cost (gate count, proof generation time)
2. Runtime/gas cost (readTime, computeTime, bytesWritten, bytesDeleted)
3. State cost (ledger storage size, type choice implications)

This mirrors how costs actually decompose in the system and provides a clear mental model.

## Skill Identity

- **Name:** `compact-circuit-costs`
- **Location:** `plugins/compact-core/skills/compact-circuit-costs/`
- **Trigger description:** Covers ZK circuit costs and optimization — gate counts, loop unrolling, hash function tradeoffs, pure circuit benefits, compiler optimizations, runtime gas model, and ledger state cost implications for Compact smart contracts on Midnight.

## File Structure

```
plugins/compact-core/skills/compact-circuit-costs/
├── SKILL.md
└── references/
    ├── circuit-proving-costs.md
    ├── runtime-gas-costs.md
    └── state-costs.md
```

## SKILL.md Content

1. **Opening paragraph** — Positions the skill: costs in Compact means thinking in three dimensions
2. **Three-Dimension Cost Model Overview** — Framing table (dimension, what it affects, key driver)
3. **Circuit Cost Quick Reference** — Inline table: loop unrolling, hash costs, commitment costs, pure circuit benefits, vector ops, compiler optimizations
4. **Gas Model Quick Reference** — The four gas dimensions with descriptions
5. **State Cost Quick Reference** — Ledger type cost ranking with privacy tradeoff notes
6. **Cost Decision Trees** — Hash function selection, circuit expense checklist, ledger type selection
7. **Common Expensive Patterns** — Wrong vs right table (nested loops, persistentHash in tight loops, impure circuits that could be pure, unnecessary ledger reads)
8. **Reference Routing Table** — Links to the three reference files

Cross-references to: compact-language-ref, compact-ledger, compact-standard-library, compact-structure.

## Reference Files

### circuit-proving-costs.md

1. How Compact circuits become ZK proofs — pipeline overview, PLONKish arithmetization
2. Loop unrolling in depth — examples, nested loop multiplication, cost formula
3. Hash and commitment function costs — full comparison table (transientHash vs persistentHash, transientCommit vs persistentCommit), when to use each, degradeToTransient/upgradeFromTransient
4. Pure circuit optimization — definition, benefits (no zkir, no keys, inlinable, no state transcript), declaration, when to refactor
5. Vector operation costs — map/fold/slice unrolling, arrow circuit syntax implications
6. Compiler optimization passes — 7+ passes (copy propagation, constant folding, partial folding, binding elimination, CSE, assert elimination, disabled call elimination), cascade behavior, non-literal vector indexing
7. Proving time benchmarks — PLONK benchmark table (circuit size → times), linear proving/constant verification insight
8. Circuit size estimation heuristics — practical guidance for estimating relative cost

### runtime-gas-costs.md

1. The gas model — four dimensions explained
2. RunningCost structure — SDK type and emptyRunningCost()
3. CostModel — initialCostModel(), per-query measurement
4. Gas limits — setting and enforcement
5. Cost-efficient patterns — minimize reads, batch writes, avoid unnecessary state ops

### state-costs.md

1. Ledger type cost comparison — Counter, Map, Set, List, MerkleTree growth characteristics
2. Privacy-cost tradeoffs by type — operation visibility table, cross-references compact-ledger and compact-privacy-disclosure
3. Sealed fields — cost benefit of immutable config
4. State design for cost — when to use which type from a cost perspective
5. Nested ADT cost implications — when nesting is worth the complexity

## Plugin Integration

Add keywords to plugin.json: `"circuit-costs"`, `"gate-count"`, `"proving-time"`, `"optimization"`, `"gas-model"`, `"loop-unrolling"`, `"transientHash"`, `"persistentHash"`, `"pure-circuit"`, `"compiler-optimization"`

## Design Decisions

| Decision | Rationale |
|----------|-----------|
| Cost Dimensions approach | Matches actual cost architecture; clear mental model |
| All three cost dimensions | Comprehensive coverage for informed decision-making |
| Cost lens only for ADTs | Avoids duplication with compact-ledger; cross-references instead |
| Inline examples only | Keeps file structure simple; matches compact-witness-ts style |
| Both audiences (layered) | Quick-reference tables for experienced devs, explanatory context for newcomers |
| 3 reference files | One per cost dimension; clean separation |

## Research Sources

- Compact compiler documentation: optimize-circuit pass, loop unrolling, circuit inlining
- PLONK legacy benchmarks: circuit size → proving/verification times
- Compact standard library: transientHash/persistentHash/transientCommit/persistentCommit documentation
- Compact language reference: pure circuit definition, vector operations, for loop semantics
- Midnight SDK runtime: RunningCost, CostModel, gasLimit
- Halo2 cost model: PLONKish arithmetization structure
- Example contracts: counter_killer stress tests, formatter nested loops, counter_256 load tests
