# Core Concepts Plugin Port — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Port and fact-check the midnight-core-concepts plugin from the knowledgebase repo into `plugins/core-concepts/` in this marketplace.

**Architecture:** Skill-by-skill port with full verification against Midnight MCP, octocode, and Midnight docs repo. Each skill gets a findings report before the corrected version is written. The concept-explainer agent is ported and updated last.

**Tech Stack:** Midnight MCP server, octocode MCP, midnight-fact-checker agent

**Source:** `/Users/aaronbassett/Projects/midnight/midnight-knowledgebase/plugins/midnight-core-concepts/`
**Destination:** `plugins/core-concepts/` (relative to repo root)

---

## Task 0: Scaffold plugin structure

**Files:**
- Create: `plugins/core-concepts/.claude-plugin/plugin.json`

**Step 1: Create plugin.json**

Create the plugin manifest with updated name `core-concepts` (not `midnight-core-concepts`). Keep version at `0.2.0`, update description if fact-checking warrants it.

```json
{
  "name": "core-concepts",
  "version": "0.2.0",
  "description": "Core concepts and patterns for Midnight Network development: UTXO/account models, zero-knowledge proofs, privacy patterns, smart contracts, and protocol architecture",
  "author": {
    "name": "Aaron Bassett"
  },
  "keywords": [
    "midnight",
    "blockchain",
    "zero-knowledge",
    "zk-proofs",
    "privacy",
    "smart-contracts",
    "compact"
  ]
}
```

**Step 2: Create directory skeleton**

```
plugins/core-concepts/
├── .claude-plugin/plugin.json
├── agents/
└── skills/
    ├── data-models/references/
    ├── data-models/examples/
    ├── architecture/references/
    ├── architecture/examples/
    ├── zero-knowledge/references/
    ├── zero-knowledge/examples/
    ├── privacy-patterns/references/
    ├── privacy-patterns/examples/
    ├── smart-contracts/references/
    ├── smart-contracts/examples/
    ├── protocols/references/
    └── protocols/examples/
```

Also create the findings directory:

```
docs/findings/core-concepts/
```

**Step 3: Commit**

```bash
git add plugins/core-concepts/.claude-plugin/plugin.json
git commit -m "feat(core-concepts): scaffold plugin structure"
```

---

## Task 1: Fact-check and port data-models skill

**Source files to verify:**
- `skills/data-models/SKILL.md`
- `skills/data-models/references/utxo-mechanics.md`
- `skills/data-models/references/ledger-structure.md`
- `skills/data-models/examples/token-handling.compact`

**Step 1: Read all source files**

Read all 4 files from the source plugin at `/Users/aaronbassett/Projects/midnight/midnight-knowledgebase/plugins/midnight-core-concepts/skills/data-models/`.

**Step 2: Fact-check against Midnight MCP and docs**

Launch a `midnight-fact-checker` agent to verify every claim in the skill files. Key areas to verify:
- UTXO model description accuracy
- Ledger structure claims (dual-ledger, shielded vs unshielded)
- Token type descriptions and handling patterns
- Nullifier mechanics
- Any code examples in the `.compact` file

Use these verification sources:
- Midnight MCP: `midnight-search-docs`, `midnight-search-compact` for official documentation
- Octocode: search `midnightntwrk` repos for implementation evidence
- Midnight docs repo: `github.com/midnightntwrk` for current documentation

**Step 3: Write findings report**

Save to `docs/findings/core-concepts/data-models.md` with sections:
- Verified Claims
- Inaccuracies Found (with corrections)
- Ambiguities
- Missing Information

**Step 4: Port corrected files**

Write corrected versions to:
- `plugins/core-concepts/skills/data-models/SKILL.md`
- `plugins/core-concepts/skills/data-models/references/utxo-mechanics.md`
- `plugins/core-concepts/skills/data-models/references/ledger-structure.md`
- `plugins/core-concepts/skills/data-models/examples/token-handling.compact`

**Step 5: Commit**

```bash
git add plugins/core-concepts/skills/data-models/ docs/findings/core-concepts/data-models.md
git commit -m "feat(core-concepts): fact-check and port data-models skill"
```

---

## Task 2: Fact-check and port architecture skill

**Source files to verify:**
- `skills/architecture/SKILL.md`
- `skills/architecture/references/cryptographic-binding.md`
- `skills/architecture/references/state-management.md`
- `skills/architecture/references/transaction-deep-dive.md`
- `skills/architecture/examples/transaction-construction.md`

**Step 1: Read all source files**

Read all 5 files from `/Users/aaronbassett/Projects/midnight/midnight-knowledgebase/plugins/midnight-core-concepts/skills/architecture/`.

**Step 2: Fact-check against Midnight MCP and docs**

Launch a `midnight-fact-checker` agent. Key areas to verify:
- Transaction model (guaranteed vs fallible sections)
- Cryptographic binding mechanisms
- State management (public vs private state separation)
- System architecture claims
- Transaction construction flow accuracy

**Step 3: Write findings report**

Save to `docs/findings/core-concepts/architecture.md`.

**Step 4: Port corrected files**

Write corrected versions to `plugins/core-concepts/skills/architecture/`.

**Step 5: Commit**

```bash
git add plugins/core-concepts/skills/architecture/ docs/findings/core-concepts/architecture.md
git commit -m "feat(core-concepts): fact-check and port architecture skill"
```

---

## Task 3: Fact-check and port zero-knowledge skill

**Source files to verify:**
- `skills/zero-knowledge/SKILL.md`
- `skills/zero-knowledge/references/snark-internals.md`
- `skills/zero-knowledge/references/circuit-construction.md`
- `skills/zero-knowledge/examples/circuit-patterns.compact`

**Step 1: Read all source files**

Read all 4 files from `/Users/aaronbassett/Projects/midnight/midnight-knowledgebase/plugins/midnight-core-concepts/skills/zero-knowledge/`.

**Step 2: Fact-check against Midnight MCP and docs**

Launch a `midnight-fact-checker` agent. Key areas to verify:
- SNARK system description (which proof system Midnight uses — Plonk? Groth16?)
- Circuit compilation pipeline
- Witness data handling
- Prover/verifier role descriptions
- Constraint system details
- Any Compact circuit code examples

**Step 3: Write findings report**

Save to `docs/findings/core-concepts/zero-knowledge.md`.

**Step 4: Port corrected files**

Write corrected versions to `plugins/core-concepts/skills/zero-knowledge/`.

**Step 5: Commit**

```bash
git add plugins/core-concepts/skills/zero-knowledge/ docs/findings/core-concepts/zero-knowledge.md
git commit -m "feat(core-concepts): fact-check and port zero-knowledge skill"
```

---

## Task 4: Fact-check and port privacy-patterns skill

**Source files to verify:**
- `skills/privacy-patterns/SKILL.md`
- `skills/privacy-patterns/references/commitment-schemes.md`
- `skills/privacy-patterns/references/merkle-tree-usage.md`
- `skills/privacy-patterns/examples/auth-patterns.compact`
- `skills/privacy-patterns/examples/private-voting.compact`

**Step 1: Read all source files**

Read all 5 files from `/Users/aaronbassett/Projects/midnight/midnight-knowledgebase/plugins/midnight-core-concepts/skills/privacy-patterns/`.

**Step 2: Fact-check against Midnight MCP and docs**

Launch a `midnight-fact-checker` agent. Key areas to verify:
- Commitment scheme descriptions (Pedersen? hash-based?)
- Merkle tree usage patterns and API
- Nullifier construction
- Auth pattern correctness (Compact syntax, stdlib usage)
- Private voting pattern (correctness of the approach)
- Cross-reference with compact-core plugin for consistency

**Step 3: Write findings report**

Save to `docs/findings/core-concepts/privacy-patterns.md`.

**Step 4: Port corrected files**

Write corrected versions to `plugins/core-concepts/skills/privacy-patterns/`.

**Step 5: Commit**

```bash
git add plugins/core-concepts/skills/privacy-patterns/ docs/findings/core-concepts/privacy-patterns.md
git commit -m "feat(core-concepts): fact-check and port privacy-patterns skill"
```

---

## Task 5: Fact-check and port smart-contracts skill

**Source files to verify:**
- `skills/smart-contracts/SKILL.md`
- `skills/smart-contracts/references/compact-syntax.md`
- `skills/smart-contracts/references/impact-vm.md`
- `skills/smart-contracts/references/execution-semantics.md`
- `skills/smart-contracts/examples/counter.compact`
- `skills/smart-contracts/examples/private-vault.compact`

**Step 1: Read all source files**

Read all 6 files from `/Users/aaronbassett/Projects/midnight/midnight-knowledgebase/plugins/midnight-core-concepts/skills/smart-contracts/`.

**Step 2: Fact-check against Midnight MCP and docs**

Launch a `midnight-fact-checker` agent. Key areas to verify:
- Compact syntax accuracy (cross-ref with compact-core plugin and MCP)
- Impact VM description (instruction set, execution model)
- Execution semantics (state transitions, guaranteed vs fallible)
- Counter example (compile-check syntax against current Compact version)
- Private vault example (syntax, stdlib usage, privacy patterns)

**Step 3: Write findings report**

Save to `docs/findings/core-concepts/smart-contracts.md`.

**Step 4: Port corrected files**

Write corrected versions to `plugins/core-concepts/skills/smart-contracts/`.

**Step 5: Commit**

```bash
git add plugins/core-concepts/skills/smart-contracts/ docs/findings/core-concepts/smart-contracts.md
git commit -m "feat(core-concepts): fact-check and port smart-contracts skill"
```

---

## Task 6: Fact-check and port protocols skill

**Source files to verify:**
- `skills/protocols/SKILL.md`
- `skills/protocols/references/kachina-deep-dive.md`
- `skills/protocols/references/zswap-internals.md`
- `skills/protocols/examples/basic-transfer.md`
- `skills/protocols/examples/atomic-swap.md`

**Step 1: Read all source files**

Read all 5 files from `/Users/aaronbassett/Projects/midnight/midnight-knowledgebase/plugins/midnight-core-concepts/skills/protocols/`.

**Step 2: Fact-check against Midnight MCP and docs**

Launch a `midnight-fact-checker` agent. Key areas to verify:
- Kachina protocol description (accuracy against the paper and Midnight implementation)
- Zswap internals (transfer flow, coin structure, merge/split operations)
- Basic transfer flow accuracy
- Atomic swap mechanism
- Protocol interaction model

**Step 3: Write findings report**

Save to `docs/findings/core-concepts/protocols.md`.

**Step 4: Port corrected files**

Write corrected versions to `plugins/core-concepts/skills/protocols/`.

**Step 5: Commit**

```bash
git add plugins/core-concepts/skills/protocols/ docs/findings/core-concepts/protocols.md
git commit -m "feat(core-concepts): fact-check and port protocols skill"
```

---

## Task 7: Port and update concept-explainer agent

**Source file:**
- `agents/concept-explainer.md`

**Step 1: Read source agent definition**

Read from `/Users/aaronbassett/Projects/midnight/midnight-knowledgebase/plugins/midnight-core-concepts/agents/concept-explainer.md`.

**Step 2: Update skill references**

The agent references skills using the old plugin name `midnight-core-concepts:*`. Update all references to use the new name `core-concepts:*`:

- `midnight-core-concepts:data-models` → `core-concepts:data-models`
- `midnight-core-concepts:zero-knowledge` → `core-concepts:zero-knowledge`
- `midnight-core-concepts:privacy-patterns` → `core-concepts:privacy-patterns`
- `midnight-core-concepts:smart-contracts` → `core-concepts:smart-contracts`
- `midnight-core-concepts:protocols` → `core-concepts:protocols`
- `midnight-core-concepts:architecture` → `core-concepts:architecture`

Keep external plugin references (`compact-core:*`, `midnight-dapp:*`, `midnight-proofs:*`) as-is.

**Step 3: Review agent quality**

Check that the agent description, examples, skill routing, and quality standards are still accurate given any corrections made during fact-checking.

**Step 4: Write corrected agent**

Save to `plugins/core-concepts/agents/concept-explainer.md`.

**Step 5: Commit**

```bash
git add plugins/core-concepts/agents/concept-explainer.md
git commit -m "feat(core-concepts): port concept-explainer agent with updated skill refs"
```

---

## Task 8: Final review and summary

**Step 1: Review all findings reports**

Read all 6 findings reports in `docs/findings/core-concepts/` and compile a summary of total changes made.

**Step 2: Verify plugin structure**

Run `find plugins/core-concepts -type f | sort` and confirm the structure matches the design.

**Step 3: Update plugin.json if needed**

If fact-checking revealed the description or keywords should change, update `plugins/core-concepts/.claude-plugin/plugin.json`.

**Step 4: Commit any final adjustments**

```bash
git add plugins/core-concepts/ docs/findings/core-concepts/
git commit -m "feat(core-concepts): finalize plugin port with all verified content"
```
