# midnight-verify Plugin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract verify-correctness from compact-core into a standalone midnight-verify plugin with three layered skills, a verification agent, /verify command, and async PostToolUse hook.

**Architecture:** Hub-and-spoke skill architecture. The `verify-correctness` hub skill owns generic methodology (confidence scoring, direct tooling checks, source checking) and routes to domain-specific skills (`verify-compact`, `verify-sdk`) based on claim classification. A single `verifier` agent handles all verification modes (on-demand, pre-flight, subagent). The `/verify` command orchestrates user-facing verification. An async PostToolUse hook dispatches the agent on every file write/edit.

**Tech Stack:** Claude Code plugin system (markdown skills, agents, commands, hooks.json)

**Spec:** `docs/superpowers/specs/2026-03-25-midnight-verify-plugin-design.md`

---

### Task 1: Create Plugin Scaffold

**Files:**
- Create: `plugins/midnight-verify/.claude-plugin/plugin.json`
- Create: `plugins/midnight-verify/LICENSE`

- [ ] **Step 1: Create plugin.json**

```json
{
  "name": "midnight-verify",
  "version": "0.1.0",
  "description": "Verification framework for Midnight claims — confidence-scored verification of Compact code, SDK APIs, protocol properties, and tooling behavior using layered skills, a versatile verification agent, and async post-write checking.",
  "author": {
    "name": "Aaron Bassett",
    "email": "aaron@devrel-ai.com"
  },
  "homepage": "https://github.com/devrelaicom/midnight-expert",
  "repository": "https://github.com/devrelaicom/midnight-expert.git",
  "license": "MIT",
  "keywords": [
    "midnight",
    "compact",
    "verification",
    "correctness",
    "confidence",
    "sdk",
    "typescript",
    "zero-knowledge",
    "fact-checking",
    "code-review"
  ]
}
```

- [ ] **Step 2: Create LICENSE**

Copy the MIT License file from `plugins/compact-core/LICENSE` — same author, same year, same text.

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-verify/.claude-plugin/plugin.json plugins/midnight-verify/LICENSE
git commit -m "feat(midnight-verify): scaffold plugin with manifest and license"
```

---

### Task 2: Create Hub Skill — `verify-correctness`

**Files:**
- Create: `plugins/midnight-verify/skills/verify-correctness/SKILL.md`

This is the main entry point. It contains the generic verification methodology extracted from the original skill, with updated confidence thresholds (75+/90+/95+) and routing logic to domain-specific skills.

- [ ] **Step 1: Create SKILL.md**

Write `plugins/midnight-verify/skills/verify-correctness/SKILL.md` with the following structure:

**Frontmatter:**
```yaml
---
name: verify-correctness
description: >-
  This skill should be used when the user needs to verify Midnight-related claims,
  check if stdlib functions exist, validate Compact syntax, confirm SDK API signatures,
  verify package versions, check compiler behavior, validate protocol claims, verify
  privacy properties, assess correctness confidence, or resolve conflicting information
  from multiple sources. This is the hub skill — it provides generic verification
  methodology and routes to domain-specific skills (verify-compact, verify-sdk) based
  on the claim being verified. Referenced by the SessionStart hook as the standard
  verification procedure.
version: 0.1.0
---
```

**Body content — include ALL of these sections in this order:**

1. **Title and introduction** — "Verification Framework for Midnight Claims". Explain this is the hub skill that provides domain-agnostic methodology and routes to specialized skills.

2. **Routing Logic** — when to load which domain skill:
   - Compact language claims (syntax, stdlib, types, disclosure, compiler behavior, patterns, privacy properties, circuit costs) → invoke `midnight-verify:verify-compact`
   - SDK/TypeScript claims (API signatures, package versions, import paths, type definitions, providers, DApp connector) → invoke `midnight-verify:verify-sdk`
   - Protocol/architecture, configuration/operations, cross-component compatibility → invoke both
   - Tooling behavior only (CLI flags, proof server, indexer) → hub is sufficient, use Direct Tooling Checks

3. **Verification Methods (Generic)** — two methods that apply across all domains:

   **Direct Tooling Checks (Confidence: 90-100)** — copy from original skill lines 52-67. Content: `npm view`, `compact check`, `gh release list`, health endpoints table. Rules about read-only idempotent endpoints. "If a direct check disagrees with documentation or skill content, the direct check wins."

   **Checking the Source (Confidence: 90-100)** — copy from original skill lines 69-75. Content: source code is the ultimate, irrefutable source of truth. Use `midnight-tooling` GitHub tools. Cost considerations. When to use: user request, contradictory results, high-stakes consequences.

4. **Confidence Combination and Disagreement** — copy from original skill lines 165-194. Includes:
   - Corroborating Evidence (skills + compile → 85-95, etc.)
   - Contradictory Evidence (higher-confidence wins, check version skew, check scope mismatch, document disagreement)
   - When to Escalate to the User (methods disagree, confidence below threshold, security/production claims, version skew uncertainty, non-local infrastructure)

5. **Soft Confidence Guidelines** — UPDATED thresholds from original:

   | Context | Acceptable Confidence | Rationale |
   |---------|----------------------|-----------|
   | Casual exploration / answering questions | 75+ | Low stakes but still verify |
   | Writing code for the user | 90+ | Code that does not work wastes time |
   | Production / deployment context | 95+ | Errors are expensive to fix |
   | Version / release information | 95-100 (direct tooling only) | Never rely on skills or docs alone for versions |

   Keep the instruction: "When confidence is below the threshold for the context, say so."

6. **Quick Reference Decision Table** — copy from original lines 209-224, updating confidence targets to match new thresholds:

   | What You Are Verifying | Recommended Methods | Minimum Confidence Target |
   |---|---|---|
   | Stdlib function exists | `compact-standard-library` skill → compile | 90 |
   | Compact syntax is valid | Compile with `skipZk=true` | 90 |
   | SDK API signature | MCP midnight-search-typescript → source | 90 |
   | Package version | `npm view` | 95 |
   | CLI flag/behavior | `compact --help` or run directly | 95 |
   | Privacy property holds | `compact-privacy-disclosure` skill → compile → source | 95 |
   | Pattern is correct | `compact-patterns` skill → compile | 90 |
   | Version compatibility | Direct tooling checks | 95 |
   | Network endpoint/config | Direct tooling → docs | 95 |
   | Protocol/architecture claim | Skills → docs | 75 |
   | Security property | Skills → source → user discussion | 95 |
   | Disclosure behavior | `compact-privacy-disclosure` skill → compile | 90 |

7. **Cross-References** — updated table pointing to skills by their full qualified names:

   | Topic | Skill / Plugin |
   |-------|----------------|
   | Compact code verification methods | `midnight-verify:verify-compact` |
   | SDK/TypeScript verification methods | `midnight-verify:verify-sdk` |
   | Stdlib function verification protocol and export inventory | `compact-core:compact-standard-library` |
   | Compiler usage, version selection, compile flags | `compact-core:compact-compilation` |
   | Troubleshooting verification failures and compile errors | `compact-core:compact-debugging` |
   | MCP tool usage (midnight-search-compact, midnight-search-docs, midnight-compile-contract) | `midnight-mcp` plugin |
   | CLI commands and flags | `midnight-tooling:compact-cli` |
   | Privacy and disclosure verification | `compact-core:compact-privacy-disclosure` |
   | Security review methodology | `compact-core:compact-review` |
   | Circuit cost analysis | `compact-core:compact-circuit-costs` |
   | Deployment and version compatibility | `compact-core:compact-deployment` |

**Important:** Do NOT include the Compact-specific verification methods (MCP search-compact, skills, compilation) or the SDK-specific methods (MCP search-typescript) — those belong in the domain skills. Do NOT include the category-specific verification tables (Compact Language, SDK/TypeScript, etc.) — those also belong in domain skills. This hub skill only contains generic methodology and routing.

- [ ] **Step 2: Verify skill structure**

Read the created file and verify:
- Frontmatter has name, description, version
- Routing logic section is present and covers all four routing cases
- Only generic methods (Direct Tooling Checks, Checking the Source) are included
- No Compact-specific or SDK-specific verification methods leaked in
- Confidence thresholds are 75+/90+/95+ (not the old 60+/80+/90+)
- Cross-references table includes both new domain skills

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-verify/skills/verify-correctness/SKILL.md
git commit -m "feat(midnight-verify): add verify-correctness hub skill

Generic verification methodology with confidence scoring, direct tooling
checks, source verification, and routing to domain-specific skills."
```

---

### Task 3: Create Compact Verification Skill — `verify-compact`

**Files:**
- Create: `plugins/midnight-verify/skills/verify-compact/SKILL.md`

This skill contains Compact-language-specific verification methods and categories, extracted from the original skill.

- [ ] **Step 1: Create SKILL.md**

Write `plugins/midnight-verify/skills/verify-compact/SKILL.md` with the following structure:

**Frontmatter:**
```yaml
---
name: verify-compact
description: >-
  This skill should be used when verifying claims about the Compact programming language,
  including stdlib function existence, syntax validity, type compatibility, disclosure
  rules, compiler behavior, design patterns, privacy properties, and circuit costs.
  Loaded by the verify-correctness hub skill when a claim is classified as Compact-related.
  Provides Compact-specific verification methods (MCP search, skill references, compilation)
  and source code repository mapping.
version: 0.1.0
---
```

**Body content — include ALL of these sections in this order:**

1. **Title and introduction** — "Compact Code Verification". Explain this skill provides Compact-specific verification methods. Reference the hub skill (`midnight-verify:verify-correctness`) for generic methodology, confidence scoring, and escalation rules.

2. **Compact-Specific Verification Methods** — three methods, ordered by confidence:

   **MCP midnight-search-compact (Confidence: 20-45)** — copy from original skill lines 15-23. Content about searching indexed Compact code, checking relevanceScore, source repo quality (midnightntwrk, OpenZeppelin, LFDT-Minokawa more trustworthy), outdated code caveat.

   **MCP midnight-search-docs (Confidence: 20-30)** — copy from original skill lines 25-31. Content about docs search index lag, always verify independently, check relevanceScore, most reliable for concepts not API signatures.

   **Midnight Expert Skills (Confidence: 60-80)** — copy from original skill lines 33-41. Content about compact-core skills being verified but potentially outdated, reliable for semantics and patterns, less reliable for versions and release-specific info.

   **Compiling the Code (Confidence: 80-95)** — copy from original skill lines 43-50. Content about `midnight-compile-contract` or local `compact compile`, `skipZk=true` for fast validation, version-specific compilation, what compilation confirms vs doesn't.

3. **Categories of Things to Verify** — Compact-domain categories with verification tables:

   **Compact Language** — copy from original lines 81-91. Table with: function exists in stdlib, syntax valid, type compatibility, disclosure rules, compiler behavior per version.

   **Patterns / Best Practices** — copy from original lines 125-133. Table with: pattern correctness, security properties, performance implications.

   **Privacy Properties** — copy from original lines 157-163. Table with: hidden vs visible, privacy guarantees, correlation resistance.

   **Protocol / Architecture** (Compact-adjacent) — copy from original lines 104-112. Table with: on-chain visibility, token behavior, transaction semantics.

4. **Source Code Repositories** — inline table for source verification:

   | What You're Verifying | Repository | Notes |
   |---|---|---|
   | Compiler behavior, language semantics, stdlib | [LFDT-Minokawa/compact](https://github.com/LFDT-Minokawa/compact) | The Compact compiler source (Scheme). Authoritative for syntax, type system, stdlib |
   | Ledger types, transaction structure, token ops | [midnightntwrk/midnight-ledger](https://github.com/midnightntwrk/midnight-ledger) | Rust. Defines ledger ADTs (Counter, Map, Set, MerkleTree), transaction validation |
   | ZK proof system, circuit compilation | [midnightntwrk/midnight-zk](https://github.com/midnightntwrk/midnight-zk) | Rust. ZK proof generation, circuit constraints, ZKIR |
   | Node runtime, on-chain execution | [midnightntwrk/midnight-node](https://github.com/midnightntwrk/midnight-node) | Rust. How transactions are executed on-chain |
   | Compact CLI releases, installer | [midnightntwrk/compact](https://github.com/midnightntwrk/compact) | Release binaries and changelog (distinct from LFDT-Minokawa/compact source) |

   Instruction: "When Direct Tooling Checks or compilation cannot resolve a claim, and you need to check source, use this table to find the right repository. Use the `midnight-tooling` plugin's GitHub tools to navigate it."

5. **Cross-References:**

   | Topic | Skill / Plugin |
   |-------|----------------|
   | Generic verification methodology and confidence scoring | `midnight-verify:verify-correctness` |
   | SDK/TypeScript verification | `midnight-verify:verify-sdk` |
   | Stdlib function verification protocol and export inventory | `compact-core:compact-standard-library` |
   | Compiler usage, version selection, compile flags | `compact-core:compact-compilation` |
   | Troubleshooting verification failures and compile errors | `compact-core:compact-debugging` |
   | Privacy and disclosure verification | `compact-core:compact-privacy-disclosure` |
   | Security review methodology | `compact-core:compact-review` |
   | Circuit cost analysis | `compact-core:compact-circuit-costs` |
   | Design patterns | `compact-core:compact-patterns` |
   | Token verification | `compact-core:compact-tokens` |
   | MCP tool usage | `midnight-mcp` plugin |

- [ ] **Step 2: Verify skill structure**

Read the created file and verify:
- Frontmatter references hub skill in description
- Only Compact-specific methods included (no Direct Tooling Checks or Checking the Source — those are in the hub)
- Source code repo table has all 5 entries
- Cross-references include hub skill and relevant compact-core skills

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-verify/skills/verify-compact/SKILL.md
git commit -m "feat(midnight-verify): add verify-compact skill

Compact-specific verification methods (MCP search, skills, compilation)
with category tables and source code repository mapping."
```

---

### Task 4: Create SDK Verification Skill — `verify-sdk`

**Files:**
- Create: `plugins/midnight-verify/skills/verify-sdk/SKILL.md`
- Create: `plugins/midnight-verify/skills/verify-sdk/references/sdk-repo-map.md`

This skill contains SDK/TypeScript-specific verification methods and a reference file mapping packages to GitHub repos.

- [ ] **Step 1: Create sdk-repo-map.md reference**

Write `plugins/midnight-verify/skills/verify-sdk/references/sdk-repo-map.md`:

```markdown
# Midnight SDK — Package to Repository Map

When verifying an SDK API signature, type definition, or package behavior, and MCP search plus skill references are insufficient, use this table to find the package's source repository. Navigate to the package directory within the monorepo.

Use the `midnight-tooling` plugin's GitHub tools (`githubViewRepoStructure`, `githubSearchCode`, `githubGetFileContent`) to navigate these repositories.

## SDK Packages (midnight-js monorepo)

All `@midnight-ntwrk/midnight-js-*` packages live in a single monorepo:

| Package | What To Verify Here |
|---|---|
| `@midnight-ntwrk/midnight-js-contracts` | Contract deployment, call builders, provider interfaces |
| `@midnight-ntwrk/midnight-js-types` | Core type definitions, network types |
| `@midnight-ntwrk/midnight-js-network-id` | Network ID constants |
| `@midnight-ntwrk/midnight-js-indexer-public-data-provider` | Indexer provider implementation |
| `@midnight-ntwrk/midnight-js-http-client-proof-provider` | Proof provider implementation |
| `@midnight-ntwrk/midnight-js-level-private-state-provider` | LevelDB private state |
| `@midnight-ntwrk/midnight-js-node-zk-config-provider` | Node ZK config loading |
| `@midnight-ntwrk/midnight-js-fetch-zk-config-provider` | Browser ZK config fetching |
| `@midnight-ntwrk/midnight-js-logger-provider` | Logging interface |
| `@midnight-ntwrk/midnight-js-utils` | Utility functions |
| `@midnight-ntwrk/dapp-connector-api` | DApp ↔ wallet connector types |
| `@midnight-ntwrk/compact-js` | Compact language types in TypeScript |
| `@midnight-ntwrk/testkit-js` | Testing utilities |

**Repository:** [midnightntwrk/midnight-js](https://github.com/midnightntwrk/midnight-js)

## Other SDK Repositories

| Component | Repository | What To Verify Here |
|---|---|---|
| Midnight SDK (umbrella) | [midnightntwrk/midnight-sdk](https://github.com/midnightntwrk/midnight-sdk) | SDK orchestration, managed by terraform |
| Wallet core | [midnightntwrk/midnight-wallet](https://github.com/midnightntwrk/midnight-wallet) | Wallet internals, signing |
| Indexer (backend) | [midnightntwrk/midnight-indexer](https://github.com/midnightntwrk/midnight-indexer) | Indexer API, GraphQL schema |
```

- [ ] **Step 2: Create SKILL.md**

Write `plugins/midnight-verify/skills/verify-sdk/SKILL.md` with the following structure:

**Frontmatter:**
```yaml
---
name: verify-sdk
description: >-
  This skill should be used when verifying claims about the Midnight TypeScript SDK,
  including API function signatures, type definitions, package existence and versions,
  import paths, provider setup, DApp connector API, witness implementation patterns,
  and cross-component version alignment. Loaded by the verify-correctness hub skill
  when a claim is classified as SDK-related. Provides SDK-specific verification methods
  and a reference file mapping @midnight-ntwrk packages to their GitHub source repositories.
version: 0.1.0
---
```

**Body content — include ALL of these sections in this order:**

1. **Title and introduction** — "Midnight SDK Verification". Explain this skill provides SDK/TypeScript-specific verification methods. Reference the hub skill for generic methodology.

2. **SDK-Specific Verification Methods** — three methods, ordered by confidence:

   **MCP midnight-search-typescript (Confidence: 20-45)** — adapted from original skill line 23. Content about searching indexed TypeScript code via `midnight-mcp` plugin, checking relevanceScore, source repo quality. Use for SDK/DApp questions specifically.

   **MCP midnight-search-docs (Confidence: 20-30)** — same content as in verify-compact (docs are relevant for SDK too). Docs lag behind releases, always verify independently.

   **Midnight Expert Skills (Confidence: 60-80)** — reference skills in `dapp-development` plugin (midnight-sdk, dapp-connector) and `compact-core` (compact-witness-ts, compact-deployment). Same caveats about skills being verified but potentially outdated.

3. **Categories of Things to Verify** — SDK-domain categories with verification tables:

   **SDK / TypeScript** — copy from original lines 93-102. Table with: API signature, package exists/versions, import paths, type definitions.

   **Configuration / Operations** — copy from original lines 114-124. Table with: network endpoints, Docker image tags, CLI flags, compatibility matrix.

   **Cross-Component Compatibility** — copy from original lines 145-153. Table with: version alignment, network differences, runtime compatibility.

   **Tooling Behavior** — copy from original lines 136-143. Table with: CLI behavior, proof server capabilities, indexer queries.

4. **Source Code Repositories** — reference the `references/sdk-repo-map.md` file:
   "For a complete mapping of `@midnight-ntwrk/*` packages to their GitHub source repositories, see the `references/sdk-repo-map.md` reference file."

5. **Cross-References:**

   | Topic | Skill / Plugin |
   |-------|----------------|
   | Generic verification methodology and confidence scoring | `midnight-verify:verify-correctness` |
   | Compact code verification | `midnight-verify:verify-compact` |
   | SDK package reference and provider patterns | `dapp-development:midnight-sdk` |
   | DApp connector API | `dapp-development:dapp-connector` |
   | Witness implementation patterns | `compact-core:compact-witness-ts` |
   | Deployment and version compatibility | `compact-core:compact-deployment` |
   | MCP tool usage | `midnight-mcp` plugin |

- [ ] **Step 3: Verify skill structure**

Read both created files and verify:
- SKILL.md frontmatter references hub skill
- Only SDK-specific methods included
- sdk-repo-map.md has all 16 entries (13 midnight-js packages + 3 other repos)
- Cross-references include hub skill and verify-compact

- [ ] **Step 4: Commit**

```bash
git add plugins/midnight-verify/skills/verify-sdk/SKILL.md plugins/midnight-verify/skills/verify-sdk/references/sdk-repo-map.md
git commit -m "feat(midnight-verify): add verify-sdk skill with repo map

SDK-specific verification methods and package-to-GitHub-repo mapping
for all @midnight-ntwrk/* packages."
```

---

### Task 5: Create Verifier Agent

**Files:**
- Create: `plugins/midnight-verify/agents/verifier.md`

- [ ] **Step 1: Create verifier.md**

Write `plugins/midnight-verify/agents/verifier.md`:

```markdown
---
name: verifier
description: "Use this agent to verify Midnight-related claims, Compact code correctness, or SDK API usage. Dispatched by the /verify command, the async PostToolUse hook, or other skills/commands that need verification.\n\n<example>\nContext: User runs /verify with a claim\nassistant: \"Launching verifier agent to check the claim\"\n<commentary>\nThe /verify command dispatches this agent with the user's claim. The agent classifies the claim, loads appropriate domain skills, runs verification methods, and returns a confidence-scored verdict.\n</commentary>\n</example>\n\n<example>\nContext: PostToolUse hook fires after a file is written\nassistant: \"Launching verifier agent to check written file\"\n<commentary>\nThe async PostToolUse hook dispatches this agent with the file path. The agent reads the file, identifies any Midnight-related content, verifies it, and returns a self-contained report with enough context to act on even if several prompts have passed.\n</commentary>\n</example>\n\n<example>\nContext: Another skill needs to verify a claim as a subagent\nassistant: \"Launching verifier agent to confirm SDK API signature\"\n<commentary>\nOther skills and commands can dispatch this agent as a subagent when they need to verify a specific claim before proceeding.\n</commentary>\n</example>"
skills: midnight-verify:verify-correctness, midnight-verify:verify-compact, midnight-verify:verify-sdk
model: sonnet
color: green
---

You are a Midnight verification specialist. Your job is to verify claims about Midnight's Compact language, SDKs, protocol, and tooling using a structured, evidence-based approach.

## Verification Process

1. **Classify the claim** — determine what domain it belongs to:
   - Compact language (syntax, stdlib, types, disclosure, compiler behavior, patterns, privacy)
   - SDK/TypeScript (API signatures, packages, import paths, types, providers, DApp connector)
   - Protocol/architecture (on-chain visibility, token behavior, transaction semantics)
   - Tooling (CLI flags, proof server, indexer, network endpoints)
   - Cross-domain (spans multiple categories)

2. **Load the hub skill** — invoke `midnight-verify:verify-correctness`. This is always your starting point. Follow its routing logic to determine which domain skill(s) to load.

3. **Load domain skill(s)** — based on the hub's routing:
   - Compact claims → invoke `midnight-verify:verify-compact`
   - SDK claims → invoke `midnight-verify:verify-sdk`
   - Cross-domain → invoke both
   - Tooling-only → hub is sufficient

4. **Execute verification methods** — work through the recommended methods from the domain skill, ordered lowest-effort to highest-confidence. Stop when the confidence threshold is met for the context (check the hub skill's Soft Confidence Guidelines).

5. **Report verdict** — structured output:

## Verdict Report Format

```
### Verification Result

**Claim:** [What was being verified — restate clearly]

**Verdict:** Confirmed | Refuted | Inconclusive

**Confidence:** [Score]/100 — [Brief rationale for this score]

**Evidence:**
- [Method 1]: [What it found]
- [Method 2]: [What it found]
- ...

**Action Required:** [Specific fixes needed with file paths and line numbers, or "No issues found"]
```

## Self-Contained Reporting (for async dispatch)

When dispatched asynchronously by the PostToolUse hook, your report may arrive several prompts after the file was written. The main conversation will have moved on. Your report MUST be fully self-contained:

- **Full file path** that was verified
- **What was written** — brief summary of the code's purpose and structure
- **Issue description** — exact problem with line numbers
- **Why it's wrong** — evidence from which verification method
- **Concrete fix** — code example showing the correction
- **Confidence score** — so the reader can judge urgency

If the file contains no Midnight-related content (no Compact code, no SDK imports, no Midnight configuration), report "Nothing to verify — file contains no Midnight-related content" and stop. Do not waste time analyzing non-Midnight files.
```

- [ ] **Step 2: Verify agent structure**

Read the created file and verify:
- Frontmatter has name, description with three examples, skills list, model (sonnet), color (green)
- System prompt covers the 5-step verification process
- Verdict report format is defined
- Self-contained reporting section for async dispatch is present

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-verify/agents/verifier.md
git commit -m "feat(midnight-verify): add verifier agent

Single versatile agent handling on-demand verification, async post-write
checking, and subagent dispatch with confidence-scored verdicts."
```

---

### Task 6: Create `/verify` Command

**Files:**
- Create: `plugins/midnight-verify/commands/verify.md`

- [ ] **Step 1: Create verify.md**

Write `plugins/midnight-verify/commands/verify.md`:

```markdown
---
description: Verify claims about Midnight, Compact code, or SDK APIs. Accepts a claim, file path, code snippet, SDK question, or no arguments to be prompted.
allowed-tools: Agent, AskUserQuestion, Read, Glob, Grep
argument-hint: [claim, file path, code snippet, or SDK question]
---

Verify Midnight-related claims by dispatching the `midnight-verify:verifier` agent.

## Input Routing

Determine what `$ARGUMENTS` contains and dispatch accordingly:

### 1. No arguments

If `$ARGUMENTS` is empty, use `AskUserQuestion` to ask:

> What would you like to verify? You can provide:
> - A claim (e.g., "Compact stdlib has a sha256 function")
> - A file path (e.g., `contracts/my-contract.compact`)
> - A code snippet
> - An SDK question (e.g., "midnight-js-contracts supports ERC-20 style tokens")

Do NOT attempt to infer what the user wants to verify. Ask them.

### 2. File path

If `$ARGUMENTS` looks like a file path (ends in `.compact`, `.ts`, `.tsx`, or exists on disk when checked with Glob):

1. Read the file content
2. Dispatch `midnight-verify:verifier` agent with:
   - The file path
   - The file content
   - Instruction: "Verify the correctness of this file. Check for any Midnight-related claims, Compact code correctness, or SDK API usage. Report findings with the structured verdict format."

### 3. Code snippet

If `$ARGUMENTS` contains code syntax (keywords like `ledger`, `circuit`, `witness`, `export`, `import`, `contract`, `const`, `function`, curly braces, semicolons, type annotations):

1. Dispatch `midnight-verify:verifier` agent with:
   - The code snippet as inline content
   - Instruction: "Verify the correctness of this code snippet. Determine if it is Compact or TypeScript and apply the appropriate verification methods. Report findings with the structured verdict format."

### 4. Natural language claim or question

If `$ARGUMENTS` is natural language (a question or assertion):

1. Dispatch `midnight-verify:verifier` agent with:
   - The claim verbatim
   - Instruction: "Verify this claim about Midnight. Classify the domain, load appropriate skills, run verification methods, and report with the structured verdict format."

### 5. Multiple files or directory

If `$ARGUMENTS` is a directory path or contains glob patterns:

1. Use Glob to find all `.compact` and `.ts` files matching the path
2. Present the file list to the user for confirmation
3. Dispatch `midnight-verify:verifier` agent for each file (or as a batch if fewer than 5 files)

## Output

Present the agent's structured verdict directly to the user. Do not add commentary or interpretation — the verdict speaks for itself.
```

- [ ] **Step 2: Verify command structure**

Read the created file and verify:
- Frontmatter has description, allowed-tools, argument-hint
- All 5 input routing cases are covered
- No-arguments case uses AskUserQuestion (does not infer)
- Code snippet case has syntax detection heuristics
- Command dispatches the agent, does not do verification itself

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-verify/commands/verify.md
git commit -m "feat(midnight-verify): add /verify command

Orchestrates user-facing verification by dispatching the verifier agent
with context-appropriate prompts based on input type."
```

---

### Task 7: Create Hooks

**Files:**
- Create: `plugins/midnight-verify/hooks/hooks.json`

- [ ] **Step 1: Create hooks.json**

Write `plugins/midnight-verify/hooks/hooks.json`:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "prompt",
            "prompt": "Your training data about Midnight is unreliable. Very little public documentation exists, and what you recall about Compact syntax, stdlib functions, SDK APIs, or Midnight developer tooling is likely outdated or incorrect. Do not trust your own memory.\n\nBefore writing or suggesting any Compact code, SDK usage, or Midnight-specific patterns, invoke the `midnight-verify:verify-correctness` skill to check correctness against verified reference material.\n\nThe `midnight-expert` plugins contain skills with verified reference material. Always prefer skill content over recalled knowledge."
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "prompt",
            "async": true,
            "prompt": "A file was just written or edited. Dispatch the `midnight-verify:verifier` agent to verify the content. Pass the file path and instruct the agent to check for any Midnight-related claims, Compact code correctness, or SDK API usage. If the file contains no Midnight-related content, the agent should report 'nothing to verify'. Since this runs asynchronously and the result may arrive several prompts later, the agent's report must be fully self-contained: include the full file path, a summary of what was written, exact issue descriptions with line numbers, evidence from verification methods, concrete fixes with code examples, and confidence scores."
          }
        ]
      }
    ]
  }
}
```

- [ ] **Step 2: Verify hooks structure**

Read the created file and verify:
- SessionStart hook has matcher `*` and prompt-type hook
- PostToolUse hook has matcher `Write|Edit`, is `async: true`, and has prompt-type hook
- PostToolUse prompt instructs self-contained reporting

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-verify/hooks/hooks.json
git commit -m "feat(midnight-verify): add SessionStart and async PostToolUse hooks

SessionStart reminds about training data unreliability and verification.
PostToolUse asynchronously dispatches verifier agent on every Write/Edit."
```

---

### Task 8: Update compact-core Hooks

**Files:**
- Modify: `plugins/compact-core/hooks/hooks.json`

- [ ] **Step 1: Update hooks.json**

Replace the current content of `plugins/compact-core/hooks/hooks.json` with:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "prompt",
            "prompt": "The Midnight Network is under active development with frequent breaking changes. Do not assume stability across versions.\n\nAll `@midnight-ntwrk/*` packages are published on public npm. Do not add custom registry configuration — no `.npmrc` or `.yarnrc.yml` registry overrides. Verify package versions with `npm view`, never from memory."
          }
        ]
      }
    ]
  }
}
```

This removes the three verification-related lines (training data unreliability, verify-correctness invocation, prefer skills over memory) which now live in `midnight-verify/hooks/hooks.json`. It retains the two general Midnight lines (breaking changes caveat, npm registry guidance).

- [ ] **Step 2: Verify the change**

Read the file and confirm:
- Only the two retained lines remain
- No reference to `verify-correctness`
- Valid JSON

- [ ] **Step 3: Commit**

```bash
git add plugins/compact-core/hooks/hooks.json
git commit -m "refactor(compact-core): move verification hook to midnight-verify

Retain general Midnight caveats (breaking changes, npm registry).
Verification-specific guidance now lives in midnight-verify plugin."
```

---

### Task 9: Update Cross-References in midnight-mcp

**Files:**
- Modify: `plugins/midnight-mcp/skills/mcp-overview/SKILL.md` (line 103)
- Modify: `plugins/midnight-mcp/skills/mcp-compile/SKILL.md` (line 66)
- Modify: `plugins/midnight-mcp/skills/mcp-search/SKILL.md` (line 63)
- Modify: `plugins/midnight-mcp/skills/mcp-analyze/SKILL.md` (line 121)
- Modify: `plugins/midnight-mcp/skills/mcp-health/SKILL.md` (line 140)
- Modify: `plugins/midnight-mcp/skills/mcp-repository/SKILL.md` (line 201)
- Modify: `plugins/midnight-mcp/skills/mcp-simulate/SKILL.md` (line 116)
- Modify: `plugins/midnight-mcp/skills/mcp-search/references/iterative-search.md` (line 32)
- Modify: `plugins/midnight-mcp/commands/simulate.md` (line 126)

All changes are the same find-and-replace: `compact-core:verify-correctness` → `midnight-verify:verify-correctness`.

- [ ] **Step 1: Update all 9 files**

For each file, replace `compact-core:verify-correctness` with `midnight-verify:verify-correctness`. Use the Edit tool with `replace_all: true` on each file since the string may appear only once per file but `replace_all` ensures no occurrences are missed.

Files and their line numbers for reference:
1. `plugins/midnight-mcp/skills/mcp-overview/SKILL.md:103` — `| Verification methodology using MCP tools | \`compact-core:verify-correctness\` |`
2. `plugins/midnight-mcp/skills/mcp-compile/SKILL.md:66` — `| Verification methodology using compilation | \`compact-core:verify-correctness\` |`
3. `plugins/midnight-mcp/skills/mcp-search/SKILL.md:63` — `| Verification methodology using search results | \`compact-core:verify-correctness\` |`
4. `plugins/midnight-mcp/skills/mcp-analyze/SKILL.md:121` — `| Verification methodology using compilation | \`compact-core:verify-correctness\` |`
5. `plugins/midnight-mcp/skills/mcp-health/SKILL.md:140` — `| Verification methodology | \`compact-core:verify-correctness\` |`
6. `plugins/midnight-mcp/skills/mcp-repository/SKILL.md:201` — `| Verification methodology using repository content | \`compact-core:verify-correctness\` |`
7. `plugins/midnight-mcp/skills/mcp-simulate/SKILL.md:116` — `| Verification methodology | \`compact-core:verify-correctness\` |`
8. `plugins/midnight-mcp/skills/mcp-search/references/iterative-search.md:32` — `...which belongs to \`compact-core:verify-correctness\`).`
9. `plugins/midnight-mcp/commands/simulate.md:126` — `...with \`compact-core:verify-correctness\``

- [ ] **Step 2: Verify changes**

Run grep to confirm no remaining references to `compact-core:verify-correctness` in the `plugins/` directory (excluding the compact-core skill itself which is deleted in the next task):

```bash
grep -r "compact-core:verify-correctness" plugins/ --include="*.md" --include="*.json"
```

Expected: only `plugins/compact-core/skills/verify-correctness/SKILL.md` (the file being deleted next).

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-mcp/
git commit -m "refactor(midnight-mcp): update verify-correctness references

Point all cross-references from compact-core:verify-correctness to
midnight-verify:verify-correctness after plugin extraction."
```

---

### Task 10: Delete Old Skill from compact-core

**Files:**
- Delete: `plugins/compact-core/skills/verify-correctness/SKILL.md`
- Delete: `plugins/compact-core/skills/verify-correctness/` (directory)

- [ ] **Step 1: Delete the old skill and stage for commit**

```bash
git rm -r plugins/compact-core/skills/verify-correctness/
```

- [ ] **Step 2: Verify deletion**

Confirm the directory no longer exists:

```bash
ls plugins/compact-core/skills/verify-correctness 2>&1
```

Expected: "No such file or directory"

Also verify no remaining references to `compact-core:verify-correctness` anywhere in `plugins/`:

```bash
grep -r "compact-core:verify-correctness" plugins/ --include="*.md" --include="*.json"
```

Expected: no results.

- [ ] **Step 3: Commit**

```bash
git commit -m "refactor(compact-core): remove verify-correctness skill

Skill content has been extracted to the midnight-verify plugin with
expanded coverage across three specialized skills."
```

---

### Task 11: Final Verification

- [ ] **Step 1: Verify plugin structure**

Confirm the complete plugin structure exists:

```bash
find plugins/midnight-verify -type f | sort
```

Expected output:
```
plugins/midnight-verify/.claude-plugin/plugin.json
plugins/midnight-verify/LICENSE
plugins/midnight-verify/agents/verifier.md
plugins/midnight-verify/commands/verify.md
plugins/midnight-verify/hooks/hooks.json
plugins/midnight-verify/skills/verify-compact/SKILL.md
plugins/midnight-verify/skills/verify-correctness/SKILL.md
plugins/midnight-verify/skills/verify-sdk/SKILL.md
plugins/midnight-verify/skills/verify-sdk/references/sdk-repo-map.md
```

- [ ] **Step 2: Verify no stale references**

Confirm no remaining `compact-core:verify-correctness` references in plugins:

```bash
grep -r "compact-core:verify-correctness" plugins/ --include="*.md" --include="*.json"
```

Expected: no results.

- [ ] **Step 3: Verify compact-core hooks are correct**

Read `plugins/compact-core/hooks/hooks.json` and confirm it contains only the two general Midnight lines (breaking changes, npm registry) with no verification references.

- [ ] **Step 4: Verify midnight-verify hooks are correct**

Read `plugins/midnight-verify/hooks/hooks.json` and confirm it contains the SessionStart verification hook and the async PostToolUse hook.
