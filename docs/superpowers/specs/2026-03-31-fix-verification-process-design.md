# Fix Verification Process Design

**Date:** 2026-03-31
**Status:** Approved

## Problem

The midnight-verify plugin's verification pipeline is broken. The `/verify` command dispatches a `verifier` orchestrator agent, which tries to dispatch domain-specific sub-agents. This fails because **subagents cannot spawn subagents** in Claude Code.

Additional issues:
- Agent references in skill files use `**bold name**` format instead of `@"plugin:agent-name (agent)"` format
- No enforcement that sub-agents actually follow their verification process (they could skip compilation/execution and use skill content as evidence)
- Skill references are ambiguous — bare names without explicit "Load the X skill" phrasing

## Solution: Command-as-Orchestrator (Approach A)

Eliminate the `verifier` agent entirely. The `/verify` command (main thread) becomes the orchestrator by loading the hub skill and domain skills directly, then dispatching sub-agents itself. SubagentStop hooks enforce process compliance.

## Design

### 1. New Verification Flow

```
/verify command (main thread)
  |-- loads midnight-verify:verify-correctness hub skill
  |-- classifies domain
  |-- loads domain skill (verify-compact, verify-sdk, etc.)
  |-- dispatches sub-agents directly
  |   |-- @"midnight-verify:contract-writer (agent)"
  |   |-- @"midnight-verify:source-investigator (agent)"
  |   |-- @"midnight-verify:type-checker (agent)"
  |   |-- @"midnight-verify:sdk-tester (agent)"
  |   |-- @"midnight-verify:cli-tester (agent)"
  |   |-- @"midnight-verify:witness-verifier (agent)"
  |   +-- @"midnight-verify:zkir-checker (agent)"
  |-- synthesizes verdicts from sub-agent reports
  +-- presents final verdict
```

Key changes:
- Delete `agents/verifier.md` entirely
- The `/verify` command loads the hub skill + domain skills and does classification/routing/dispatch/synthesis
- Sub-agents remain unchanged in individual behavior
- Main thread handles sequential flows (witness->zkir, wallet SDK conditional fallback)

### 2. `/verify` Command Rewrite

The command currently routes input types and dispatches the verifier agent. It becomes the full orchestrator:

1. **Input routing** (unchanged) -- determine if `$ARGUMENTS` is empty, file path, code snippet, natural language, or directory
2. **Load hub skill** -- `midnight-verify:verify-correctness` (new step)
3. **Classify domain** -- follow the hub skill's classification table
4. **Load domain skill** -- the appropriate `verify-compact`, `verify-sdk`, etc.
5. **Dispatch sub-agents** -- follow the domain skill's routing table, dispatching agents directly using `@"plugin:agent-name (agent)"` references
6. **Handle multi-step flows** -- witness->zkir sequential, wallet SDK conditional fallback
7. **Synthesize verdict** -- follow the hub skill's verdict table and rules
8. **Present result** -- structured verdict to user

Changes:
- Remove all references to `midnight-verify:verifier`
- Add `Skill` to `allowed-tools` (needed to load hub + domain skills)
- The command body tells the main thread to load skills and follow them

### 3. Agent & Skill Reference Updates

**Agent references -- ALL agents, including third-party:**

Every agent reference using `**bold name**` or bare name format becomes `@"plugin:agent-name (agent)"`:

| Old | New |
|---|---|
| `**contract-writer**` | `@"midnight-verify:contract-writer (agent)"` |
| `**source-investigator**` | `@"midnight-verify:source-investigator (agent)"` |
| `**type-checker**` | `@"midnight-verify:type-checker (agent)"` |
| `**sdk-tester**` | `@"midnight-verify:sdk-tester (agent)"` |
| `**cli-tester**` | `@"midnight-verify:cli-tester (agent)"` |
| `**witness-verifier**` | `@"midnight-verify:witness-verifier (agent)"` |
| `**zkir-checker**` | `@"midnight-verify:zkir-checker (agent)"` |
| `devs:deps-maintenance` | `@"devs:deps-maintenance (agent)"` |

**Skill references -- be explicit:**

Anywhere a skill is mentioned, make it clear it's a skill and what to do with it:

- "Start it with `midnight-tooling:devnet`" -> "Load the `midnight-tooling:devnet` skill for instructions on running the devnet"
- "load `midnight-verify:verify-compact`" -> "Load the `midnight-verify:verify-compact` skill"
- "instruct it to load `midnight-verify:zkir-regression`" -> "instruct it to load the `midnight-verify:zkir-regression` skill"

**Scope:** Every file in `skills/`, `agents/`, and `commands/`.

### 4. SubagentStop Hooks

One hook entry per agent type in `hooks/hooks.json`. Each runs a dedicated bash script that scans the agent's JSONL transcript (`agent_transcript_path`) for evidence of real tool usage.

**Hook structure:**

```json
{
  "SubagentStop": [
    {
      "matcher": "midnight-verify:contract-writer",
      "hooks": [{ "type": "command", "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/subagent-stop-contract-writer.sh", "timeout": 10 }]
    },
    {
      "matcher": "midnight-verify:source-investigator",
      "hooks": [{ "type": "command", "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/subagent-stop-source-investigator.sh", "timeout": 10 }]
    },
    {
      "matcher": "midnight-verify:type-checker",
      "hooks": [{ "type": "command", "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/subagent-stop-type-checker.sh", "timeout": 10 }]
    },
    {
      "matcher": "midnight-verify:cli-tester",
      "hooks": [{ "type": "command", "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/subagent-stop-cli-tester.sh", "timeout": 10 }]
    },
    {
      "matcher": "midnight-verify:sdk-tester",
      "hooks": [{ "type": "command", "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/subagent-stop-sdk-tester.sh", "timeout": 10 }]
    },
    {
      "matcher": "midnight-verify:witness-verifier",
      "hooks": [{ "type": "command", "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/subagent-stop-witness-verifier.sh", "timeout": 10 }]
    },
    {
      "matcher": "midnight-verify:zkir-checker",
      "hooks": [{ "type": "command", "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/subagent-stop-zkir-checker.sh", "timeout": 10 }]
    }
  ]
}
```

**Per-agent required evidence:**

| Agent | Required Evidence in Transcript | Rationale |
|---|---|---|
| `contract-writer` | Bash call matching `npm install @midnight-ntwrk/compact-runtime` OR `npm ls @midnight-ntwrk/compact-runtime`, AND Bash call matching `compact compile` | Must set up runtime and compile |
| `source-investigator` | Tool call matching `mcp__octocode-mcp__githubSearchCode` OR `mcp__octocode-mcp__githubGetFileContent` OR `mcp__octocode-mcp__githubViewRepoStructure` OR Bash call matching `git clone` | Must actually inspect source code |
| `type-checker` | Bash call matching `tsc` | Must run the TypeScript compiler |
| `cli-tester` | Bash call matching `compact` or `compactc` | Must run the actual CLI tool |
| `sdk-tester` | Bash call matching `mkdir -p .midnight-expert/verify/sdk-workspace` OR `mkdir -p .midnight-expert/verify/wallet-sdk-workspace`, AND Skill tool call matching `midnight-tooling:devnet` | Must create workspace and load devnet skill |
| `witness-verifier` | Bash call matching `compact compile`, AND Bash call matching `tsc` | Must compile the contract AND type-check the witness |
| `zkir-checker` | Bash call matching `compact compile`, AND Bash call matching `npm install @midnight-ntwrk/zkir-v2` OR `npm ls @midnight-ntwrk/zkir-v2` | Must compile and have the ZKIR checker available |

**Script pattern:**

```bash
#!/usr/bin/env bash
set -euo pipefail
INPUT=$(cat)
TRANSCRIPT=$(echo "$INPUT" | jq -r '.agent_transcript_path // empty')

if [ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ]; then
  exit 0  # No transcript available, allow
fi

CONTENT=$(cat "$TRANSCRIPT")

# Check for required evidence (agent-specific regex)
if ! echo "$CONTENT" | grep -qE 'PATTERN_1'; then
  cat >&2 <<'EOF'
{"decision":"block","reason":"You must follow the process as described in the `midnight-verify:verify-by-SKILL` skill. Do not attempt to take shortcuts. Only verifications which have followed the process will be accepted and not blocked."}
EOF
  exit 2
fi

# Additional checks as needed...

exit 0
```

**Block message skill references per agent:**

| Agent | Skill Referenced in Block Message |
|---|---|
| `contract-writer` | `midnight-verify:verify-by-execution` |
| `source-investigator` | `midnight-verify:verify-by-source` |
| `type-checker` | `midnight-verify:verify-by-type-check` |
| `cli-tester` | `midnight-verify:verify-by-cli-execution` |
| `sdk-tester` | `midnight-verify:verify-by-devnet` |
| `witness-verifier` | `midnight-verify:verify-by-witness` |
| `zkir-checker` | `midnight-verify:verify-by-zkir-checker` |

### 5. Cascading Changes

**verify-correctness hub skill:** Update frontmatter description from "Always loaded first by the verifier agent" to reflect it's loaded by the main thread via the `/verify` command. Body text addressing "You are the verification orchestrator" still works -- it addresses the main thread now.

**zkir-regression skill:** Currently says "For each claim, dispatch verifier agent." The main thread runs the regression loop itself -- for each claim, it follows the hub skill's classify->route->dispatch flow directly.

**verify-by-witness skill -- Phase 5:** Currently says "dispatch sdk-tester if devnet available." The witness-verifier subagent cannot dispatch other subagents. Phase 5 becomes a recommendation to the orchestrator -- the witness-verifier reports back after phases 1-4, and the main thread handles the conditional sdk-tester dispatch.

**verify-by-devnet skill:** References to loading `midnight-tooling:devnet` get the explicit treatment: "Load the `midnight-tooling:devnet` skill for devnet endpoint configuration and health check instructions."

**Agent frontmatter (7 remaining agents):** The `skills:` field is correct as-is. Any prose in agent bodies that references other agents or skills loosely gets the explicit `@"agent (agent)"` / "Load the X skill" treatment.

**Delete `agents/verifier.md`:** Removed entirely.

## Files Changed

### Deleted
- `agents/verifier.md`

### New Files
- `hooks/subagent-stop-contract-writer.sh`
- `hooks/subagent-stop-source-investigator.sh`
- `hooks/subagent-stop-type-checker.sh`
- `hooks/subagent-stop-cli-tester.sh`
- `hooks/subagent-stop-sdk-tester.sh`
- `hooks/subagent-stop-witness-verifier.sh`
- `hooks/subagent-stop-zkir-checker.sh`

### Modified
- `commands/verify.md` -- full rewrite to become orchestrator
- `hooks/hooks.json` -- add SubagentStop entries
- `skills/verify-correctness/SKILL.md` -- update frontmatter, agent/skill references
- `skills/verify-compact/SKILL.md` -- agent/skill references
- `skills/verify-sdk/SKILL.md` -- agent/skill references
- `skills/verify-witness/SKILL.md` -- agent/skill references
- `skills/verify-zkir/SKILL.md` -- agent/skill references
- `skills/verify-tooling/SKILL.md` -- agent/skill references
- `skills/verify-ledger/SKILL.md` -- agent/skill references
- `skills/verify-wallet-sdk/SKILL.md` -- agent/skill references
- `skills/verify-by-witness/SKILL.md` -- phase 5 update, skill references
- `skills/verify-by-devnet/SKILL.md` -- skill references
- `skills/verify-by-execution/SKILL.md` -- skill references (if any)
- `skills/verify-by-source/SKILL.md` -- skill references (if any)
- `skills/verify-by-type-check/SKILL.md` -- skill references (if any)
- `skills/verify-by-cli-execution/SKILL.md` -- skill references (if any)
- `skills/verify-by-ledger-source/SKILL.md` -- skill references (if any)
- `skills/verify-by-wallet-source/SKILL.md` -- skill references (if any)
- `skills/verify-by-zkir-checker/SKILL.md` -- skill references (if any)
- `skills/verify-by-zkir-inspection/SKILL.md` -- skill references (if any)
- `skills/zkir-regression/SKILL.md` -- remove verifier dispatch, update references
- `agents/contract-writer.md` -- skill references in prose
- `agents/source-investigator.md` -- skill references in prose
- `agents/type-checker.md` -- skill references in prose
- `agents/cli-tester.md` -- skill references in prose
- `agents/sdk-tester.md` -- skill references in prose
- `agents/witness-verifier.md` -- skill references in prose, phase 5 note
- `agents/zkir-checker.md` -- skill references in prose
- `.claude-plugin/plugin.json` -- version bump
