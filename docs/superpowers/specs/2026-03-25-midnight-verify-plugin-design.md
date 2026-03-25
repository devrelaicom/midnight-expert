# Design: `midnight-verify` Plugin

**Date:** 2026-03-25
**Status:** Approved
**Branch:** feat/verify-subagent

## Summary

Extract the `verify-correctness` skill from `compact-core` into a standalone `midnight-verify` plugin. Expand it into three specialized skills covering generic verification techniques, Compact code verification, and Midnight SDK verification. Add a versatile verification agent, a `/verify` command, and hooks for session-start guidance and async post-write verification.

## Motivation

The existing `verify-correctness` skill is a monolithic blob inside `compact-core` that covers generic methodology, Compact-specific verification, and SDK verification all in one file. Extracting it into its own plugin:

- Makes verification a first-class, independently installable concern
- Enables a layered skill architecture where the generic hub routes to domain-specific skills
- Creates a home for a verification agent and command that don't belong in `compact-core`
- Allows the async PostToolUse hook to verify all written files, not just Compact

## Plugin Structure

```
plugins/midnight-verify/
  .claude-plugin/plugin.json
  skills/
    verify-correctness/
      SKILL.md                    # Hub: generic methods, confidence, routing
    verify-compact/
      SKILL.md                    # Compact-specific verification methods
    verify-sdk/
      SKILL.md                    # SDK-specific verification methods
      references/
        sdk-repo-map.md           # Package -> GitHub repo mapping
  agents/
    verifier.md                   # Single versatile agent
  commands/
    verify.md                     # /verify command
  hooks/
    hooks.json                    # SessionStart + PostToolUse
  LICENSE
```

## Skills

### 1. `verify-correctness` (Hub Skill)

The main entry point and router. Owns all domain-agnostic verification methodology.

**Content:**

- **Confidence scoring system** — 20-100 scale with defined ranges per verification method
- **Corroborating vs contradictory evidence** — how to combine evidence from multiple sources, resolve contradictions, version skew detection
- **Escalation rules** — when to stop guessing and ask the user
- **Soft confidence guidelines:**
  - Casual exploration / answering questions: 75+
  - Writing code for the user: 90+
  - Production / deployment context: 95+
  - Version / release information: 95-100 (direct tooling only)
- **Direct Tooling Checks** (confidence 90-100) — `npm view`, `compact check`, `gh release list`, health endpoints. Authoritative for the specific version/instance being queried
- **Checking the Source** (confidence 90-100) — source code as the ultimate, irrefutable source of truth. When to use (contradictory results, high-stakes claims, user request). Cost considerations
- **Quick reference decision table** — updated with new skill names

**Routing logic** — explicit instructions:
- Claim is about Compact language (syntax, stdlib, types, disclosure, compiler behavior, patterns, privacy properties, circuit costs) -> load `midnight-verify:verify-compact`
- Claim is about SDK/TypeScript (API signatures, package versions, import paths, type definitions, providers, DApp connector) -> load `midnight-verify:verify-sdk`
- Claim is about protocol/architecture, configuration/operations, or cross-component compatibility -> load both
- Claim is purely about tooling behavior (CLI flags, proof server, indexer) -> hub is sufficient, use Direct Tooling Checks

### 2. `verify-compact` (Compact Code Verification)

Compact-language-specific verification methods only.

**Content:**

- **MCP midnight-search-compact** (confidence 20-45) — searching indexed Compact code, checking relevanceScore and source repo quality
- **Midnight Expert Skills** (confidence 60-80) — using compact-core skill references for language semantics, patterns, architecture
- **Compiling the Code** (confidence 80-95) — using MCP `midnight-compile-contract` or local `compact compile`, `skipZk=true` for fast validation, version-specific compilation guidance

**Categories with verification tables:**
- Compact Language — stdlib function existence, syntax validity, type compatibility, disclosure rules, compiler behavior per version
- Patterns / Best Practices — pattern correctness, security properties, performance implications
- Privacy Properties — hidden vs visible, privacy guarantees, correlation resistance

**Source code reference table (inline):**

| What You're Verifying | Repository | Notes |
|---|---|---|
| Compiler behavior, language semantics, stdlib | LFDT-Minokawa/compact | The Compact compiler source (Scheme). Authoritative for syntax, type system, stdlib |
| Ledger types, transaction structure, token ops | midnightntwrk/midnight-ledger | Rust. Defines ledger ADTs (Counter, Map, Set, MerkleTree), transaction validation |
| ZK proof system, circuit compilation | midnightntwrk/midnight-zk | Rust. ZK proof generation, circuit constraints, ZKIR |
| Node runtime, on-chain execution | midnightntwrk/midnight-node | Rust. How transactions are executed on-chain |
| Compact CLI releases, installer | midnightntwrk/compact | Release binaries and changelog (distinct from LFDT-Minokawa/compact source) |

Instruction: "When Direct Tooling Checks or compilation cannot resolve a claim, and you need to check source, use this table to find the right repository. Use the `midnight-tooling` plugin's GitHub tools to navigate it."

**Cross-references** to compact-core skills (stdlib, compilation, debugging, privacy-disclosure, review, circuit-costs) and to the hub skill.

### 3. `verify-sdk` (SDK Verification)

SDK/TypeScript-specific verification methods.

**Content:**

- **MCP midnight-search-typescript** (confidence 20-45) — searching indexed TypeScript code, checking relevanceScore and source repo
- **Midnight Expert Skills** (confidence 60-80) — using dapp-development and compact-core skill references for SDK patterns, witness implementation, providers

**Categories with verification tables:**
- API signatures, type definitions, import paths
- Package existence/versions/compatibility
- Provider setup (indexer, proof, private state, ZK config)
- DApp connector API
- Witness implementation patterns
- Cross-component version alignment (SDK <-> compiler <-> proof server)

**Reference file: `references/sdk-repo-map.md`**

Maps every `@midnight-ntwrk/*` package to its GitHub repository with a "What To Verify Here" column:

| Package(s) | Repository | What To Verify Here |
|---|---|---|
| `@midnight-ntwrk/midnight-js-contracts` | midnightntwrk/midnight-js | Contract deployment, call builders, provider interfaces |
| `@midnight-ntwrk/midnight-js-types` | midnightntwrk/midnight-js | Core type definitions, network types |
| `@midnight-ntwrk/midnight-js-network-id` | midnightntwrk/midnight-js | Network ID constants |
| `@midnight-ntwrk/midnight-js-indexer-public-data-provider` | midnightntwrk/midnight-js | Indexer provider implementation |
| `@midnight-ntwrk/midnight-js-http-client-proof-provider` | midnightntwrk/midnight-js | Proof provider implementation |
| `@midnight-ntwrk/midnight-js-level-private-state-provider` | midnightntwrk/midnight-js | LevelDB private state |
| `@midnight-ntwrk/midnight-js-node-zk-config-provider` | midnightntwrk/midnight-js | Node ZK config loading |
| `@midnight-ntwrk/midnight-js-fetch-zk-config-provider` | midnightntwrk/midnight-js | Browser ZK config fetching |
| `@midnight-ntwrk/midnight-js-logger-provider` | midnightntwrk/midnight-js | Logging interface |
| `@midnight-ntwrk/midnight-js-utils` | midnightntwrk/midnight-js | Utility functions |
| `@midnight-ntwrk/dapp-connector-api` | midnightntwrk/midnight-js | DApp <-> wallet connector types |
| `@midnight-ntwrk/compact-js` | midnightntwrk/midnight-js | Compact language types in TS |
| `@midnight-ntwrk/testkit-js` | midnightntwrk/midnight-js | Testing utilities |
| Midnight SDK (umbrella) | midnightntwrk/midnight-sdk | SDK orchestration |
| Wallet core | midnightntwrk/midnight-wallet | Wallet internals, signing |
| Indexer (backend) | midnightntwrk/midnight-indexer | Indexer API, GraphQL schema |

Instruction: "When verifying an SDK API signature or type definition, and MCP search + skill references are insufficient, use this table to find the package's source repo. Navigate to the package directory within the monorepo."

**Cross-references** to dapp-development plugin skills and to the hub skill.

## Agent: `verifier`

A single versatile agent that handles three modes based on caller context.

**Frontmatter:**
- **name:** verifier
- **description:** Examples covering all three dispatch modes — by `/verify` command (claim, file, snippet, SDK question), by PostToolUse hook (async verification of written files), and as a subagent for other skills/commands needing verification
- **skills:** `midnight-verify:verify-correctness`, `midnight-verify:verify-compact`, `midnight-verify:verify-sdk`
- **model:** sonnet
- **color:** green

**System prompt defines this process:**

1. **Classify the claim** — Compact language, SDK/TypeScript, protocol/architecture, tooling, or cross-domain
2. **Load hub skill** — always loaded via skills list
3. **Load domain skill if needed** — follow hub routing logic
4. **Execute verification methods** — lowest-effort to highest-confidence, stop when threshold met
5. **Report verdict** — structured output:
   - **Claim:** what was verified
   - **Verdict:** confirmed / refuted / inconclusive
   - **Confidence:** numeric score with rationale
   - **Evidence:** methods used, what each found
   - **Action required:** specific fixes needed, or "no issues found"

Mode-specific behavior comes from the caller's prompt, not from agent branching logic. The command, hook, and other subagent callers each tailor the dispatch prompt to their context.

For async PostToolUse dispatch, the report must be **self-contained** since it may arrive several prompts after the write occurred:
- Full file path that was verified
- Brief summary of what was written (code purpose/structure)
- Exact issue description with line numbers
- Why it's wrong (evidence from verification methods)
- Concrete fix with code example
- Confidence score

## Command: `/verify`

**Frontmatter:**
- **description:** Verify claims about Midnight, Compact code, or SDK APIs. Accepts a claim, file path, code snippet, SDK question, or no arguments to be prompted.
- **allowed-tools:** Agent, AskUserQuestion, Read, Glob, Grep
- **argument-hint:** [claim, file path, code snippet, or SDK question]

**Input routing:**

1. **No arguments** -> use `AskUserQuestion` to ask "What would you like to verify?" — do not infer
2. **Argument looks like a file path** (ends in `.compact`, `.ts`, or exists on disk) -> read the file, dispatch verifier agent
3. **Argument looks like a code snippet** (contains Compact or TypeScript syntax — keywords like `ledger`, `circuit`, `export`, `import`, braces, semicolons) -> dispatch verifier agent with the snippet as inline code to verify
4. **Argument is a claim or question** (natural language) -> dispatch verifier agent with the claim verbatim
5. **Multiple files / directory path** -> glob for relevant files, dispatch verifier agent for each or as a batch

The command dispatches `midnight-verify:verifier` agent. It does not do verification itself — purely an orchestrator.

**Output:** Presents the agent's structured verdict directly to the user.

## Hooks

### `hooks.json`

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

### Updated `compact-core/hooks/hooks.json`

Retains only non-verification content:

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

## Cross-Reference Updates

All references to `compact-core:verify-correctness` updated to `midnight-verify:verify-correctness`.

**Files to update (~12):**

Skills in `midnight-mcp`:
- `skills/mcp-overview/SKILL.md`
- `skills/mcp-compile/SKILL.md`
- `skills/mcp-search/SKILL.md`
- `skills/mcp-analyze/SKILL.md`
- `skills/mcp-health/SKILL.md`
- `skills/mcp-repository/SKILL.md`
- `skills/mcp-simulate/SKILL.md`
- `skills/mcp-search/references/iterative-search.md`

Commands:
- `midnight-mcp/commands/simulate.md`

Any cross-reference tables within `compact-core` skills that point to `compact-core:verify-correctness`.

**Deletion:**
- `plugins/compact-core/skills/verify-correctness/SKILL.md` — removed entirely

**Hook update:**
- `plugins/compact-core/hooks/hooks.json` — verification lines removed, general Midnight lines retained

## Out of Scope

- Docs/specs/plans referencing the old skill name are not updated (they are planning artifacts frozen in time)
- No changes to the verification methodology itself beyond restructuring — confidence thresholds updated but verification methods and categories are preserved from the original skill
