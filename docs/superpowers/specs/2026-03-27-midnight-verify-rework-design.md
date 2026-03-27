# Midnight Verify Plugin Rework — Design Spec

**Date:** 2026-03-27
**Status:** Draft
**Scope:** Complete rework of the `midnight-verify` plugin, focused on Compact verification. SDK verification is a placeholder.

## Problem

The existing verification system relies on a confidence hierarchy that includes MCP doc search (20-45%) and compact-core skills (60-80%) as verification evidence. Both sources are unreliable:

- The MCP docs server indexes documentation with too many errors to be used for verification.
- The compact-core skills may be outdated or tainted by the same incorrect docs.
- Compilation alone is insufficient — code can compile but still not behave as claimed.

The only reliable ways to verify Compact claims are:

1. **Compile and execute** — write a test contract, compile it, run the compiled output with `@midnight-ntwrk/compact-runtime`, and observe the actual behavior.
2. **Check source code** — read the actual compiler, ledger, or runtime source to verify structural or architectural claims.

## Design Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Starting point | Fresh start, not incremental rework | Too many assumptions baked into the old hierarchy |
| compact-core skills | Hints only, never evidence | May be tainted by wrong docs; useful for informing what to test |
| MCP doc search | Not used for verification | Too many errors |
| Verification methods | Compile+execute and source inspection only | Only reliable methods |
| Confidence scoring | Replaced with verdict + method qualifier | More meaningful than a number when evidence is "I ran it" |
| Architecture | Multi-agent pipeline, skills hold all logic, agents are thin wrappers | Skills are reusable and testable; agents just provide execution context (model, tools) |
| PostToolUse hook | Removed | Full verification is too heavy for async post-write; verification is explicit only |
| Stop hook | Lightweight Compact detection with cooldown | Gentle reminder, not enforcement |
| Workspace | Per-project `.midnight-expert/verify/compact-workspace/`, lazy init | Different projects may need different runtime versions; no upfront cost |
| Source code access | octocode-mcp first, local clone fallback | Quick lookups via API; clone for deep investigation |
| SDK verification | Placeholder | Tackled separately after Compact is solid |
| OpenZeppelin simulator | Not included, future enhancement | Keep initial scope focused on core compile+execute flow |
| Proof server / ZK | Not included, future enhancement | Coming later as a separate addition |
| Concurrent sub-agents | Required when both methods needed | Execution and source investigation are independent; parallel dispatch saves time |

## Architecture

### Plugin Structure

```
midnight-verify/
├── skills/
│   ├── verify-correctness/      # Hub: classify, route, synthesize verdicts
│   │   └── SKILL.md
│   ├── verify-compact/          # Compact domain: claim classification, method routing
│   │   └── SKILL.md
│   ├── verify-by-execution/     # Write test contract -> compile -> run -> interpret
│   │   └── SKILL.md
│   ├── verify-by-source/        # Find source code -> read -> interpret
│   │   └── SKILL.md
│   └── verify-sdk/              # Placeholder
│       └── SKILL.md
├── agents/
│   ├── verifier.md              # Orchestrator (sonnet)
│   ├── contract-writer.md       # Writes + compiles + runs test contracts (opus)
│   └── source-investigator.md   # Searches/reads source repos (sonnet)
├── commands/
│   └── verify.md                # Entry point, dispatches verifier agent
├── hooks/
│   ├── hooks.json               # SessionStart + Stop hooks
│   └── stop-check.sh            # Stop hook script
└── .claude-plugin/
    └── plugin.json
```

### Data Flow

```
User runs /verify "Tuples are 0-indexed"
         |
         v
   /verify command
   (input routing)
         |
         v
   verifier agent (sonnet)
   loads: verify-correctness + verify-compact
         |
         v
   Classify claim:
   "Compact behavioral claim -> needs execution"
         |
         v
   Dispatch contract-writer agent (opus)
   loads: verify-by-execution
         |
         v
   1. Write minimal test contract
   2. Compile with `compact compile --skip-zk`
   3. Write runner script (run.mjs)
   4. Execute with `node run.mjs`
   5. Interpret output
         |
         v
   Report back to verifier
         |
         v
   Verifier synthesizes verdict:
   "Confirmed (tested) — t[0] returned 10 (first element)"
```

For claims needing both methods, the verifier dispatches contract-writer and source-investigator as **concurrent sub-agents**, then cross-references their findings.

For source-only claims:

```
/verify "Compact exports 57 unique primitives"
         |
         v
   verifier -> classify -> "structural claim, needs source"
         |
         v
   Dispatch source-investigator agent (sonnet)
   loads: verify-by-source
         |
         v
   1. Search LFDT-Minokawa/compact via octocode-mcp
   2. Find midnight-natives.ss
   3. Count exports
         |
         v
   Report: "Found 55 exports, not 57"
         |
         v
   Verdict: "Refuted (source-verified)"
```

## Skill Specifications

### 1. verify-correctness (Hub Skill)

The orchestrator's brain. Loaded by the verifier agent.

**Responsibilities:**

- Classify claims by domain (Compact vs SDK vs cross-domain)
- Route to the appropriate domain skill (verify-compact for now, verify-sdk placeholder)
- Dispatch sub-agents based on method routing from the domain skill
- Dispatch both agents concurrently when the domain skill recommends both methods
- Synthesize final verdicts from sub-agent reports
- Handle disagreements between sub-agents (execution wins, disagreement noted)

**Verdict synthesis:**

| Verdict | Qualifier | Meaning |
|---|---|---|
| Confirmed | tested | Compiled, ran, output matched claim |
| Confirmed | source-verified | Source code confirms claim |
| Confirmed | tested + source-verified | Both methods agree |
| Refuted | tested | Compiled, ran, output contradicts claim |
| Refuted | source-verified | Source code contradicts claim |
| Refuted | tested + source-verified | Both methods disagree with claim |
| Refuted | tested (source disagrees) | Execution contradicts but source seems to support — execution wins |
| Inconclusive | — | Couldn't test AND couldn't find definitive source evidence |

**Inconclusive verdicts must explain:**
- Why the claim couldn't be tested via execution
- Why source inspection was insufficient
- What the user could do to resolve it

**When sub-agents disagree:** Execution evidence wins over source reading. The code ran and produced a result — that's more authoritative than interpreting source. But the disagreement is explicitly noted.

### 2. verify-compact (Compact Domain Skill)

Compact-specific claim classification. Loaded by the verifier agent alongside the hub.

**Claim classification for method routing:**

| Claim Type | Example | Method |
|---|---|---|
| Syntax validity | "You can cast with `as`" | Execution |
| Type behavior | "Uint arithmetic widens" | Execution |
| Stdlib function exists | "persistentHash is in stdlib" | Execution |
| Stdlib function behavior | "persistentHash returns Bytes<32>" | Execution |
| Return value semantics | "Tuples are 0-indexed" | Execution |
| Disclosure rules | "Ledger writes require disclose()" | Execution |
| Compiler error behavior | "Assigning Field to Uint<8> fails" | Execution |
| Language feature count | "Compact exports 57 primitives" | Source |
| Internal implementation | "Compact uses Scheme under the hood" | Source |
| Architecture/design rationale | "Compact chose Field as base type because..." | Source |
| Cross-component behavior | "Compiled output compatible with runtime v0.X" | Both (concurrent) |
| Performance claims | "MerkleTree ops cost more than Map" | Execution (partial) |

**Hints from compact-core skills:**

The verifier may consult these skills to inform what to test or where to look, but never cites them as evidence:

- `compact-core:compact-standard-library` — expected function signatures
- `compact-core:compact-structure` — how to structure test contracts
- `compact-core:compact-privacy-disclosure` — what disclosure rules to test
- `compact-core:compact-compilation` — expected compiler behavior
- `compact-core:compact-language-ref` — syntax reference for writing tests

**Negative testing:**

Some claims are best verified by testing what shouldn't work:
- "Feature X is not supported" -> write code using X, confirm compiler rejects it
- "You must use disclose() for Y" -> write code without disclose(), confirm it fails
- "Type Z can't hold values above N" -> try it, confirm the error

### 3. verify-by-execution (Execution Skill)

The contract-writer agent's brain. Full cycle: interpret claim -> write test -> compile -> run -> interpret output.

**Workspace management:**

- Base workspace: `.midnight-expert/verify/compact-workspace/` relative to project root (same level as `.claude/`)
- The agent determines project root from its working directory (or `$CLAUDE_PROJECT_DIR` when available)
- `.midnight-expert/` should be in the project's `.gitignore` (contains job artifacts, node_modules, local settings)
- Base workspace contains `package.json` with `@midnight-ntwrk/compact-runtime`
- **Lazy initialization:** workspace is only created/checked the first time a verification job needs it. No session-start setup.
- When first needed: create workspace if missing, `npm install`. If exists, quick `npm ls` integrity check, update if needed.
- Each verification job gets a temp subdirectory: `jobs/<uuid>/`
- Job directory contains: `.compact` file, compiled output (`out/`), runner script (`run.mjs`)
- Job directory is cleaned up after verification completes (success or failure)

**Step 1 — Interpret the claim and design the test:**

- Translate the claim into a testable contract
- The contract must be minimal — only what's needed to test the claim
- The test must have an observable assertion — a return value, a state change, or a specific error
- Compilation success alone is never sufficient. The output must be run and results interpreted.
- Consult compact-core skills as hints for how to write the contract, but the test result is the evidence

**Step 2 — Write the contract:**

- Write a `.compact` file in the job directory
- Include `pragma language_version` (get current version via `compact compile --language-version`, per the loaded `midnight-tooling:compact-cli` skill)
- Import `CompactStandardLibrary` when needed
- Use `export circuit` for testable pure functions where possible — easiest to call from runtime
- Name the contract descriptively (e.g., `tuple-indexing-test.compact`)

**Step 3 — Compile:**

- Use `compact compile --skip-zk` (fast, no proof generation)
- Load `midnight-tooling:compact-cli` skill (via Skill tool) for compilation flags, version management, and troubleshooting
- If compilation fails, that itself is evidence (e.g., claim says "this syntax is valid" but it doesn't compile -> Refuted (tested))
- Capture and report exact compiler error on failure

**Step 4 — Write and run the runner script:**

```javascript
// run.mjs pattern
import { pureCircuits } from './out/contract/index.js';
const result = pureCircuits.testCircuitName();
console.log(JSON.stringify({ result }));
```

- Execute with `node run.mjs`
- Capture stdout and stderr
- Output structured JSON for programmatic interpretation

**Step 5 — Interpret and report:**

- Compare actual output to expected output based on claim
- Report: what was claimed, what contract was written, what the output was, whether it confirms or refutes
- Include contract source and runner script in report for full evidence chain

**Failure modes:**

- Compilation fails unexpectedly -> report error, note it may be a hint/skill issue vs real language limitation
- Runtime throws -> capture error, distinguish "claim is wrong" from "test was poorly written"
- Output is ambiguous -> report as Inconclusive with observations
- Workspace setup fails -> report blocker clearly, don't guess

### 4. verify-by-source (Source Investigation Skill)

The source-investigator agent's brain.

**Strategy: octocode-mcp first, clone if needed:**

1. Start with `octocode-mcp` tools (`githubSearchCode`, `githubGetFileContent`, `githubViewRepoStructure`) for targeted lookups
2. If broader investigation needed (tracing multiple files, counting exports across modules), clone repo locally

**Repository routing:**

| Claim About | Primary Repo | Key Paths |
|---|---|---|
| Compiler behavior, language semantics, stdlib | `LFDT-Minokawa/compact` | `compiler/`, `midnight-natives.ss` |
| Compiler-generated docs (good secondary source) | `LFDT-Minokawa/compact` | `docs/` |
| Ledger types, transaction structure, token ops | `midnightntwrk/midnight-ledger` | Rust source |
| ZK proof system, circuit compilation | `midnightntwrk/midnight-zk` | Rust source |
| Node runtime, on-chain execution | `midnightntwrk/midnight-node` | Rust source |
| Compact CLI releases, changelog | `midnightntwrk/compact` | Release notes |

**LFDT-Minokawa/compact docs:** Generated from source code, more reliable than general Midnight docs. Not as authoritative as the code itself, but a good indicator. The skill notes when evidence comes from generated docs vs raw source.

**What counts as source evidence:**

- Function/type/export definitions in source code -> strong evidence
- Generated docs in `LFDT-Minokawa/compact/docs/` -> good evidence (note it's generated)
- Test files in repos -> good evidence (tests express intended behavior)
- Comments in source code -> supporting context, not primary evidence

**Report format:**

- The claim as stated
- Where in source evidence was found (repo, file path, line numbers, link)
- What the source actually says/shows
- Whether it confirms, refutes, or is inconclusive
- If inconclusive, what further investigation might resolve it

### 5. verify-sdk (Placeholder)

Minimal skill that states SDK verification is not yet implemented. If a claim is routed here, the verdict is:

**Inconclusive** — "SDK verification is not yet implemented. This claim requires manual verification."

## Agents

All agents are thin wrappers. Their system prompts load the relevant skill(s) and follow them.

### verifier (Orchestrator)

- **Model:** sonnet
- **Color:** green
- **Loads:** `midnight-verify:verify-correctness` + `midnight-verify:verify-compact`
- **Purpose:** Classify claims, determine verification strategy, dispatch sub-agents (concurrently when both methods needed), synthesize verdicts
- **System prompt essence:** "You are the verification orchestrator. Load the hub and domain skills. Follow the classification and routing logic. Dispatch contract-writer and/or source-investigator agents. When both are needed, dispatch them concurrently as they can run independently. Synthesize the final verdict from their reports."

### contract-writer

- **Model:** opus
- **Color:** cyan
- **Loads:** `midnight-verify:verify-by-execution`
- **Purpose:** Write minimal test contracts, compile, run, interpret output
- **Why opus:** Writing correct Compact code is the hardest part. Compact is a niche language with non-obvious syntax. Opus gives the best chance of getting it right on the first try.
- **System prompt essence:** "You are a Compact test contract writer. Load the execution skill. Follow it to write a minimal contract that tests the given claim, compile it, run it, and report what you observed."

### source-investigator

- **Model:** sonnet
- **Color:** blue
- **Loads:** `midnight-verify:verify-by-source`
- **Purpose:** Search and read source repos, interpret findings
- **System prompt essence:** "You are a source code investigator. Load the source skill. Follow it to find the relevant source code for the given claim, read it, and report what you found."

## Command

### /verify

**Description:** Verify claims about Midnight, Compact code, or SDK APIs.

**Argument hint:** `[claim, file path, code snippet, or question]`

**Input routing (5 cases):**

1. **No arguments** -> ask user what to verify
2. **File path** (ends in `.compact`, `.ts`, `.tsx`, or exists on disk) -> read file, dispatch verifier with file content
3. **Code snippet** (contains Compact/TS keywords, braces, semicolons) -> dispatch verifier with snippet
4. **Natural language** (question or assertion) -> dispatch verifier with claim verbatim
5. **Directory or glob** -> find matching files, confirm with user, dispatch verifier for each

**Output:** Present the agent's structured verdict directly. No added commentary.

## Hooks

### SessionStart Hook

**Type:** prompt
**Matcher:** `*`

Aggressively warns that Claude's training data about Midnight, Compact, and the Midnight SDK is unreliable and likely outdated or incorrect. Key points to hammer home:

- Never trust recalled knowledge about Compact syntax, stdlib functions, SDK APIs, or tooling behavior
- Your training data about Midnight contains known errors — treat everything you "know" about Compact as suspect
- Before presenting any Compact code, SDK usage, or Midnight-specific claims to the user, verify them using `/verify` or by dispatching the verification agent
- Compilation alone does not prove a claim is correct — code must be compiled AND executed
- Prefer skill content from midnight-expert plugins over recalled knowledge, but even skills are hints, not proof
- When in doubt, verify. The cost of checking is low; the cost of presenting wrong information is high.

### Stop Hook

**Type:** command
**Matcher:** `*`

Lightweight Compact code detection with cooldown. Runs `stop-check.sh`.

**State file:** `.midnight-expert/settings.local.json`

```json
{
  "verify_stop_hook": {
    "last_block_line_count": 0,
    "last_block_timestamp": null,
    "triggers_since_last_block": 0
  }
}
```

**Project root discovery:** The script uses `$CLAUDE_PROJECT_DIR` (set by Claude Code) to locate `.midnight-expert/settings.local.json`. Falls back to `cwd` from the hook input JSON.

**Script logic (`stop-check.sh`):**

```
1. Read JSON from stdin -> extract transcript_path, stop_hook_active, cwd
   Determine project root from $CLAUDE_PROJECT_DIR (preferred) or cwd (fallback)

2. If stop_hook_active is true:
   -> exit 0 (approve, don't update count — this is a reattempt)

3. Read .midnight-expert/settings.local.json
   (create with defaults if file or directory missing)

4. Increment triggers_since_last_block
   Write updated count back to settings file

5. If triggers_since_last_block < 5:
   -> exit 0 (approve, cooldown: too few triggers since last block)

6. If last_block_timestamp is less than 30 minutes ago:
   -> exit 0 (approve, cooldown: too recent)

7. Scan transcript for Compact code patterns:
   tail -n +$last_block_line_count "$transcript_path" \
     | rg -q 'pragma language_version|CompactStandardLibrary|export circuit'

8. If no match:
   -> exit 0 (approve, no Compact content found)

9. If match found:
   -> Update settings:
      last_block_line_count = current total line count of transcript
      last_block_timestamp = now (ISO 8601)
      triggers_since_last_block = 0
   -> Output block decision with gentle reminder
   -> exit 2
```

**Block message (gentle, not insistent):**

> It looks like Compact code was written or discussed in this session. You may want to run `/verify` on any Compact claims or code before finishing. This is a reminder — you decide whether verification is needed here.

The agent will not be blocked again if it immediately retries (stop_hook_active is true on reattempt). The cooldown logic ensures the reminder doesn't fire more than once per ~5 turns or 30 minutes.

## Verdict Format

Every verification produces a structured report:

```markdown
## Verdict: [Confirmed|Refuted|Inconclusive] ([method qualifier])

**Claim:** [the claim as stated]

**Method:** [tested|source-verified|tested + source-verified]

**Evidence:**
[What was done and what was observed. For execution: the test contract,
compilation result, runtime output. For source: repo, file, line numbers,
what the code shows.]

**Conclusion:**
[One or two sentences explaining why the evidence confirms, refutes,
or is inconclusive on the claim.]
```

For file verification (`/verify path/to/file.compact`), the verifier extracts individual claims from the file (assertions in comments, patterns used, stdlib functions called) and verifies each one. The report groups findings by line/section with an overall summary.

## Future Work (Not In Scope)

- **SDK verification** — full implementation of `verify-sdk` skill with its own methods
- **OpenZeppelin simulator** — richer execution environment for multi-transaction, stateful tests
- **Proof server / ZK verification** — verify ZK proof generation, not just language semantics
- **Smarter Stop hook patterns** — expand the `rg` pattern list as we learn what matters
