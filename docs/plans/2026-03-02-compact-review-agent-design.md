# Compact Code Review Agent — Design Document

**Date:** 2026-03-02
**Status:** Approved
**Plugin:** compact-core

## Overview

A comprehensive code review system for Midnight Compact smart contracts, their TypeScript witness implementations, and associated tests. The system identifies issues across 11 review categories with privacy concerns surfaced first, given Midnight's privacy-first design philosophy.

## Architecture

Three components work together:

```
┌─────────────────────────────────────────────────┐
│  /compact-core:review-compact  (COMMAND)        │
│  Orchestrates the review, detects agent teams   │
│                                                 │
│  if CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS:       │
│    → Creates agent team with reviewers          │
│    → Teammates claim tasks from shared list     │
│    → Teammates can challenge each other         │
│                                                 │
│  else:                                          │
│    → Spawns parallel subagents (Agent tool)     │
│    → Each returns findings to command           │
│    → Command consolidates                       │
└──────────────────┬──────────────────────────────┘
                   │
         ┌─────────┴─────────┐
         │                   │
    ┌────▼────┐        ┌────▼────┐
    │reviewer │  x11   │reviewer │
    │ agent   │───────▶│ agent   │
    └─────────┘        └─────────┘
         │                   │
    loads compact-review     loads compact-review
    skill + reference        skill + reference
    for assigned category    for assigned category
```

### Component 1: `compact-review` Skill (Knowledge Layer)

**Location:** `plugins/compact-core/skills/compact-review/`

The skill SKILL.md acts as a routing table, directing agents to the correct reference file based on their assigned review category. Each reference file contains:

1. A checklist of specific issues to look for
2. Guidance on patterns and anti-patterns
3. Severity classification criteria for that category
4. Example findings showing what good output looks like

**Reference files (11 total):**

| File | Category | Key Focus |
|------|----------|-----------|
| `privacy-review.md` | Privacy & Disclosure | Unnecessary `disclose()`, witness data leaking to public ledger, `Set` vs `MerkleTree` for private membership, `persistentHash` vs `persistentCommit` confusion, salt reuse, conditional disclosure leaks, selective disclosure overexposure |
| `security-review.md` | Security & Cryptographic Correctness | Access control on exported circuits, persistent vs transient hash/commit usage, domain separation, nullifier construction, commitment schemes, Merkle path verification, error message leakage |
| `token-security-review.md` | Token & Economic Security | Double-spend via nullifier reuse, `Uint<64>` vs `Uint<128>` overflow, unsafe transfer/mint patterns, missing `receiveShielded`, balance manipulation, authorization checks |
| `concurrency-review.md` | Concurrency & Contention | Read-then-write patterns, Counter `read()+set()` vs `increment()`, simultaneous user interactions, transaction conflict potential |
| `compilation-review.md` | Compilation & Type Safety | Deprecated syntax, wrong return types (`Void` vs `[]`), implicit disclosure errors, invalid casts, missing generics, `include` vs `import` |
| `performance-review.md` | Performance & Circuit Efficiency | Proof generation cost, excessive ledger reads, MerkleTree depth oversizing, redundant computations, loop impact, unnecessary type conversions |
| `witness-consistency-review.md` | Witness-Contract Consistency | TS witness names matching Compact declarations, type mapping correctness (`Field`→`bigint`, `Bytes<N>`→`Uint8Array`), private state immutability, `WitnessContext` usage, `Maybe`/`Either` mapping |
| `architecture-review.md` | Architecture, State Design & Composability | ADT selection, MerkleTree depth planning, constructor initialization, `sealed` vs `export`, module usage, contract decomposition, circuit vs witness boundary |
| `code-quality-review.md` | Code Quality & Best Practices | Naming conventions, circuit complexity, dead code, stdlib usage (avoiding hallucinated functions), Compact idioms, duplication |
| `testing-review.md` | Testing Adequacy | Edge case coverage, negative testing, private state testing, witness mock correctness, integration test patterns |
| `documentation-review.md` | Documentation | Circuit documentation, witness contracts, ledger state semantics, constructor docs |

### Component 2: `reviewer` Agent (Execution Layer)

**Location:** `plugins/compact-core/agents/reviewer.md`

A reusable agent that performs focused review of a single category. Same base prompt, different category assignment each time.

**Frontmatter:**
```yaml
name: reviewer
description: "Specialized Compact code reviewer for a single review category.
  Dispatched by the review-compact command with a category assignment.
  Not intended for direct user invocation."
skills: compact-core:compact-structure, compact-core:compact-ledger,
  compact-core:compact-privacy-disclosure, compact-core:compact-tokens,
  compact-core:compact-language-ref, compact-core:compact-standard-library,
  compact-core:compact-witness-ts, compact-core:compact-review,
  devs:code-review, devs:typescript-core, devs:security-core
model: sonnet
color: blue
```

**Skills loaded (10 total):**
- All 7 compact-core skills for domain knowledge
- `compact-core:compact-review` for category-specific checklists
- `devs:code-review`, `devs:typescript-core`, `devs:security-core` for general review capabilities

**Persona:** Midnight/Compact domain expert with deep knowledge of zero-knowledge proof systems, privacy-preserving smart contracts, and the Compact language.

**Review methodology:**
1. Receive assignment (category name + file list)
2. Load the `compact-review` skill → routed to correct reference file
3. Read all assigned files
4. Systematically apply each checklist item from the reference
5. Classify findings by severity
6. Format structured output with file:line references and fix suggestions
7. Highlight positive aspects

**Severity classifications:**

| Level | Criteria |
|-------|----------|
| **Critical** | Will cause loss of funds, data breach, or contract exploitation |
| **High** | Security vulnerability or privacy leak exploitable under certain conditions |
| **Medium** | Correctness issue, compilation problem, or significant performance concern |
| **Low** | Code quality, style, or minor best practice deviation |
| **Suggestion** | Enhancement opportunity, not a problem |

**Output format per finding:**
```markdown
### [Severity]

- **[Issue title]** (`file:line`)
  - **Problem:** Description of the issue
  - **Impact:** Why it matters
  - **Fix:** Suggested fix with code example
```

### Component 3: `/compact-core:review-compact` Command (Orchestration Layer)

**Location:** `plugins/compact-core/commands/review-compact.md`

**Frontmatter:**
```yaml
description: Comprehensive review of Compact smart contract code covering privacy,
  security, tokens, performance, and more. Supports agent teams when available.
allowed-tools: Bash, Agent, Read, Glob, Grep, TaskCreate, TaskUpdate, TaskList,
  AskUserQuestion
argument-hint: [path/to/contract.compact or directory]
```

**Command flow:**

#### Step 1: Identify Files

- If user provides a path argument, use it
- Otherwise, find all `.compact` files, companion witness `.ts` files, and test files in the project
- Group files by contract

#### Step 2: Check for Agent Teams

```bash
echo "${CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS:-not_set}"
```

#### Step 3a: Agent Teams Mode

When `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` is set, create an agent team:

```
Create an agent team to review Compact code. Spawn 11 reviewer teammates,
one for each review category. Each teammate should:

1. Load the compact-core:compact-review skill
2. Read their assigned reference file for their category
3. Read the contract files: [file list]
4. Apply the checklist from their reference
5. Report findings in the structured format

Assign teammates as follows:
- Teammate 1: Privacy & Disclosure (reference: privacy-review.md)
- Teammate 2: Security & Cryptographic Correctness (reference: security-review.md)
- [... all 11 categories ...]

Use sonnet model for each teammate.
Wait for all teammates to complete before synthesizing.
```

#### Step 3b: Subagent Mode (concurrent execution)

When agent teams are not available, spawn all 11 subagents in a SINGLE message:

```
You MUST launch ALL 11 reviewer agents in a SINGLE message using 11 Agent
tool calls. This ensures they run concurrently. Do NOT call them one at a
time — that would make them sequential.

In ONE message, make these 11 Agent tool calls simultaneously:

Agent call 1:
  subagent_type: "compact-core:reviewer"
  description: "Review privacy & disclosure"
  prompt: "You are reviewing category: Privacy & Disclosure.
    Files to review: [file list].
    Load the compact-core:compact-review skill and read the
    privacy-review.md reference. Apply every checklist item.
    Report findings in the structured format with severity levels."

Agent call 2:
  subagent_type: "compact-core:reviewer"
  description: "Review security & crypto"
  prompt: "You are reviewing category: Security & Cryptographic Correctness.
    Files to review: [file list].
    Load the compact-core:compact-review skill and read the
    security-review.md reference. Apply every checklist item.
    Report findings in the structured format with severity levels."

[...Agent calls 3-11 follow the same pattern for remaining categories...]

CRITICAL: All 11 calls MUST be in the same message to run in parallel.
```

#### Step 4: Consolidated Report

Collect all reviewer results and produce:

```markdown
# Compact Code Review Report

## Summary
- Total issues found: N
- Critical: N | High: N | Medium: N | Low: N | Suggestions: N
- Files reviewed: [list]

## Privacy & Disclosure
[Privacy findings shown FIRST, always]

### Critical
- **[Issue]** (`file:line`) ...

### High
...

## Security & Cryptographic Correctness
[Then remaining categories ordered by highest severity found]
...

## Positive Highlights
[Aggregated from all reviewers]
```

**Report ordering rules:**
1. Privacy & Disclosure is always the first category
2. Remaining categories ordered by highest severity issue found (categories with Critical issues before those with only Medium, etc.)
3. Within each category: Critical → High → Medium → Low → Suggestions
4. Duplicate issues found by multiple reviewers are deduplicated
5. Positive highlights aggregated at the end

## File Structure

```
plugins/compact-core/
├── .claude-plugin/
│   └── plugin.json (update with new keywords)
├── agents/
│   └── reviewer.md
├── commands/
│   └── review-compact.md
└── skills/
    ├── compact-review/
    │   ├── SKILL.md
    │   └── references/
    │       ├── privacy-review.md
    │       ├── security-review.md
    │       ├── token-security-review.md
    │       ├── concurrency-review.md
    │       ├── compilation-review.md
    │       ├── performance-review.md
    │       ├── witness-consistency-review.md
    │       ├── architecture-review.md
    │       ├── code-quality-review.md
    │       ├── testing-review.md
    │       └── documentation-review.md
    ├── compact-structure/
    ├── compact-ledger/
    ├── compact-privacy-disclosure/
    ├── compact-tokens/
    ├── compact-language-ref/
    ├── compact-standard-library/
    └── compact-witness-ts/
```

## Review Scope

The agent reviews the full stack:
- `.compact` contract files
- TypeScript witness implementations
- Test files

## Data Sources

The reference files draw from:
- Existing compact-core skill knowledge (common mistakes tables, privacy anti-patterns, compiler error references)
- Midnight MCP server research (security test vectors, economic attack vectors, contention patterns)
- Official Midnight documentation (explicit disclosure mechanics, ZK proof fundamentals)
- OpenZeppelin Compact contracts (token security patterns, authorization patterns)
- Community examples (real-world Compact contract patterns)
