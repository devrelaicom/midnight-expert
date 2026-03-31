# Tooling Verification — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Compact CLI verification domain to the midnight-verify plugin with a dedicated cli-tester agent.

**Architecture:** One new domain skill (routing table), one new method skill (CLI execution workflow), one new agent (cli-tester). Three modifications to existing components (verifier orchestrator, verify-correctness hub, source-investigator). All files in the midnight-verify plugin.

**Tech Stack:** Markdown skill/agent files following existing midnight-verify patterns. No runtime code.

**Spec:** `docs/superpowers/specs/2026-03-31-tooling-verification-design.md`

---

## File Map

### midnight-verify plugin (`plugins/midnight-verify/`)

| Action | File | Responsibility |
|--------|------|----------------|
| Create | `skills/verify-tooling/SKILL.md` | Domain skill — claim classification and routing for Compact CLI claims |
| Create | `skills/verify-by-cli-execution/SKILL.md` | Method skill — CLI execution workflow (run command, check output) |
| Create | `agents/cli-tester.md` | New agent — runs Compact CLI commands and interprets output |
| Modify | `agents/verifier.md` | Add tooling domain, dispatch rules, examples |
| Modify | `skills/verify-correctness/SKILL.md` | Add Tooling to domain classification, verdict qualifiers |
| Modify | `agents/source-investigator.md` | Add tooling example |

---

## Important Context for Implementers

### Plugin path

All files are relative to `plugins/midnight-verify/`.

### Existing patterns

**Skill files** use YAML frontmatter (`name`, `description`, `version`) then markdown body.

**Agent files** use YAML frontmatter (`name`, `description`, `skills`, `model`, `color`) then markdown body with instructions. The `tools` field is optional — only include it if the agent needs specific tools beyond the defaults.

### Key distinction

**verify-tooling** handles claims about the CLI tool ("--skip-zk skips PLONK key generation"). **verify-compact** handles claims about the Compact language ("tuples are 0-indexed"). If the claim is about what the language allows, it's Compact. If it's about what the CLI does when you run it, it's tooling.

### Compact CLI commands

- `compact` — CLI wrapper (shell script)
- `compact compile` — invokes `compactc` (the compiler binary)
- `compact compile --skip-zk` — compile without generating PLONK keys
- `compact compile --language-version` — print the current language version
- `compact --version` — print CLI version
- `compactc` — the underlying compiler binary (can be run directly)

---

## Task 1: Create verify-tooling domain skill

**Files:**
- Create: `plugins/midnight-verify/skills/verify-tooling/SKILL.md`

- [ ] **Step 1: Create the skill directory**

```bash
mkdir -p plugins/midnight-verify/skills/verify-tooling
```

- [ ] **Step 2: Write the domain skill file**

Create `plugins/midnight-verify/skills/verify-tooling/SKILL.md` with this exact content:

```markdown
---
name: midnight-verify:verify-tooling
description: >-
  Compact CLI tooling claim classification and method routing. Determines what
  kind of CLI claim is being verified and which verification method applies:
  CLI execution (primary for behavioral claims) or source investigation
  (for internal/architectural claims). Handles claims about compact compile
  flags, compactc behavior, compiler output structure, error messages, exit
  codes, version management, and CLI installation. Loaded by the verifier
  agent alongside the hub skill.
version: 0.1.0
---

# Tooling Claim Classification

This skill classifies Compact CLI tooling claims and determines which verification method to use. The verifier (orchestrator) agent loads this alongside the hub skill (`verify-correctness`).

## Distinction from verify-compact

- **verify-compact** handles claims about the Compact *language* — syntax, types, stdlib, disclosure rules, patterns
- **verify-tooling** handles claims about the CLI *tool* — flags, output structure, error messages, versions, installation

**Routing rule:** If the claim is about what the language allows/disallows, route to verify-compact. If the claim is about what the CLI does when you run it, route here.

**Overlap:** "The compiler rejects X" could be either. If the claim is about a language rule ("you can't assign Field to Uint<8>"), it's Compact. If the claim is about CLI behavior ("the compiler exits with code 1 on syntax errors"), it's tooling.

## Verification Flow

CLI execution is the default. Source investigation is for when you genuinely can't run a command to answer the question.

1. **CLI execution (primary)** — dispatch cli-tester. Run the command, observe stdout/stderr/exit code/filesystem. This is the most authoritative evidence for behavioral claims.
2. **Source investigation (secondary)** — dispatch source-investigator (uses existing `verify-by-source`). For internal/architectural claims about how the compiler works under the hood.

## Claim Type → Method Routing

| Claim Type | Example | Primary | Secondary |
|---|---|---|---|
| Flag existence | "--skip-zk is a valid flag" | cli-tester (run --help, check output) | — |
| Flag behavior | "--skip-zk skips PLONK key generation" | cli-tester (compile with/without, compare output dirs) | source-investigator |
| Output structure | "Compilation produces build/contract/index.js" | cli-tester (compile, inspect filesystem) | — |
| Error messages | "Undeclared variables produce 'not in scope' error" | cli-tester (feed bad input, check stderr) | source-investigator |
| Exit codes | "Compilation errors exit with non-zero" | cli-tester (run, check $?) | — |
| Version info | "--language-version returns the current version" | cli-tester (run, parse output) | — |
| Installation | "compact is installed via npm" | cli-tester (check which compact) | source-investigator |
| CLI vs compactc | "compact compile invokes compactc" | cli-tester (run both, compare) | source-investigator |
| Compiler internals | "The compiler is written in Scheme" | source-investigator | — |
| CLI wrapper internals | "compact is a shell script wrapper" | source-investigator | cli-tester (file type check) |

### Routing Rules

**When in doubt:**
- If you can answer the question by running a command → cli-tester
- If you need to read source code to understand internal behavior → source-investigator
- If both apply → dispatch both concurrently

**CLI execution is preferred whenever possible.** The command ran and produced this output — that's more authoritative than reading source code about what the output *should* be.

## Hints from Existing Skills

The cli-tester may consult this skill for context. It is a **hint only** — never cite it as evidence.

- `midnight-tooling:compact-cli` — expected flags, compilation patterns, version management
```

- [ ] **Step 3: Verify the file was created correctly**

```bash
head -5 plugins/midnight-verify/skills/verify-tooling/SKILL.md
```

Expected: YAML frontmatter with `name: midnight-verify:verify-tooling`.

- [ ] **Step 4: Commit**

```bash
git add plugins/midnight-verify/skills/verify-tooling/SKILL.md
git commit -m "feat(midnight-verify): add verify-tooling domain skill

Routing table for Compact CLI tooling claims. Routes behavioral claims
to cli-tester (CLI execution) and internal claims to source-investigator.
Clear boundary with verify-compact: language vs tool.

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

## Task 2: Create verify-by-cli-execution method skill

**Files:**
- Create: `plugins/midnight-verify/skills/verify-by-cli-execution/SKILL.md`

- [ ] **Step 1: Create the skill directory**

```bash
mkdir -p plugins/midnight-verify/skills/verify-by-cli-execution
```

- [ ] **Step 2: Write the method skill file**

Create `plugins/midnight-verify/skills/verify-by-cli-execution/SKILL.md` with this exact content:

```markdown
---
name: midnight-verify:verify-by-cli-execution
description: >-
  Verification by running Compact CLI commands and observing output. Checks
  CLI availability, runs commands, captures stdout/stderr/exit code, inspects
  filesystem changes, and interprets results. Covers flag existence, flag
  behavior, output structure, error messages, exit codes, version info,
  and CLI-vs-compactc comparisons. Loaded by the cli-tester agent.
version: 0.1.0
---

# Verify by CLI Execution

You are verifying a Compact CLI claim by running the actual command and observing what happens. Follow these steps in order.

## Critical Rule

**CLI output is primary evidence.** The command ran and produced this output — that's definitive for behavioral claims. Source code is secondary evidence for internal claims that can't be observed via CLI.

## Using midnight-tooling Skills as Hints

You may consult `midnight-tooling:compact-cli` to understand what flags exist and how the CLI works. This is a **hint only** — the CLI output is your evidence, not the skill content.

## Step 1: Check CLI Availability

```bash
compact --version 2>&1
compactc --version 2>&1
```

If **both** commands fail (command not found), report **Inconclusive (cli unavailable)** and stop:

```
The Compact CLI is not installed or not on PATH. Install it via
midnight-tooling:install-cli and retry.
```

If only one is available, note which one and proceed — some claims are about `compact` specifically vs `compactc`.

## Step 2: Determine the Test Approach

Based on the claim, choose the appropriate test:

### Flag Existence

Check if a flag appears in help output:

```bash
compact compile --help 2>&1 | grep -i '<flag-name>'
```

If found → flag exists. If not found → flag does not exist.

### Flag Behavior

Compile a minimal contract with and without the flag, compare results:

```bash
# Get language version
LANG_VER=$(compact compile --language-version 2>&1)

# Create job directory
JOB_ID=$(uuidgen | tr '[:upper:]' '[:lower:]')
mkdir -p .midnight-expert/verify/compact-workspace/jobs/$JOB_ID

# Write minimal contract
cat > .midnight-expert/verify/compact-workspace/jobs/$JOB_ID/test.compact << COMPACT_EOF
pragma language_version $LANG_VER;
import CompactStandardLibrary;

export circuit test(): Field {
  0
}
COMPACT_EOF

# Compile WITHOUT the flag
compact compile .midnight-expert/verify/compact-workspace/jobs/$JOB_ID/test.compact \
  > .midnight-expert/verify/compact-workspace/jobs/$JOB_ID/stdout-without.txt 2>&1
ls -R .midnight-expert/verify/compact-workspace/jobs/$JOB_ID/test/build/ \
  > .midnight-expert/verify/compact-workspace/jobs/$JOB_ID/listing-without.txt 2>&1

# Clean compiled output
rm -rf .midnight-expert/verify/compact-workspace/jobs/$JOB_ID/test/

# Compile WITH the flag
compact compile --skip-zk .midnight-expert/verify/compact-workspace/jobs/$JOB_ID/test.compact \
  > .midnight-expert/verify/compact-workspace/jobs/$JOB_ID/stdout-with.txt 2>&1
ls -R .midnight-expert/verify/compact-workspace/jobs/$JOB_ID/test/build/ \
  > .midnight-expert/verify/compact-workspace/jobs/$JOB_ID/listing-with.txt 2>&1
```

Compare the two directory listings to identify what the flag changed.

### Output Structure

Compile a minimal contract and inspect the build directory:

```bash
# After compilation
find .midnight-expert/verify/compact-workspace/jobs/$JOB_ID/test/build/ -type f | sort
```

Compare the actual file tree against the claimed structure.

### Error Messages

Feed invalid input and capture stderr:

```bash
# Write intentionally invalid contract
cat > .midnight-expert/verify/compact-workspace/jobs/$JOB_ID/bad.compact << 'COMPACT_EOF'
<intentionally invalid code targeting the claimed error>
COMPACT_EOF

compact compile .midnight-expert/verify/compact-workspace/jobs/$JOB_ID/bad.compact 2>&1
echo "Exit code: $?"
```

Check that stderr contains the claimed error message (or doesn't, if refuting).

### Exit Codes

Run the command and capture the exit code:

```bash
compact compile <args> 2>&1
echo "Exit code: $?"
```

### Version Info

```bash
compact --version 2>&1
compact compile --language-version 2>&1
compactc --version 2>&1
```

Parse and compare against the claim.

### CLI vs compactc

Run both and compare behavior:

```bash
# Via wrapper
compact compile <args> > stdout-compact.txt 2>&1
echo "compact exit: $?"

# Via compactc directly
compactc <args> > stdout-compactc.txt 2>&1
echo "compactc exit: $?"

# Compare
diff stdout-compact.txt stdout-compactc.txt
```

## Step 3: Interpret and Report

Compare the actual output against the claim.

**Report format:**

```
### CLI Execution Report

**Claim:** [verbatim]

**Command(s) run:**
\`\`\`bash
[exact commands with arguments]
\`\`\`

**Exit code:** [0 / non-zero value]

**stdout:**
\`\`\`
[captured output — full, not truncated]
\`\`\`

**stderr:**
\`\`\`
[captured output — full, not truncated]
\`\`\`

**Filesystem changes:** [new files/directories created, or "N/A" if not relevant]

**Interpretation:** [Confirmed / Refuted / Inconclusive] — [explanation of how the output matches or contradicts the claim]
```

## Step 4: Clean Up

Remove the job directory if one was created:

```bash
rm -rf .midnight-expert/verify/compact-workspace/jobs/$JOB_ID
```

Do NOT remove the base compact-workspace — it is shared across jobs.
```

- [ ] **Step 3: Verify the file was created correctly**

```bash
head -5 plugins/midnight-verify/skills/verify-by-cli-execution/SKILL.md
```

Expected: YAML frontmatter with `name: midnight-verify:verify-by-cli-execution`.

- [ ] **Step 4: Commit**

```bash
git add plugins/midnight-verify/skills/verify-by-cli-execution/SKILL.md
git commit -m "feat(midnight-verify): add verify-by-cli-execution method skill

CLI execution workflow: check availability, run commands, capture
stdout/stderr/exit code, inspect filesystem, interpret results.
Covers flags, output structure, errors, versions, and CLI vs compactc.

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

## Task 3: Create cli-tester agent

**Files:**
- Create: `plugins/midnight-verify/agents/cli-tester.md`

- [ ] **Step 1: Write the agent file**

Create `plugins/midnight-verify/agents/cli-tester.md` with this exact content:

```markdown
---
name: cli-tester
description: >-
  Use this agent to verify Compact CLI tooling claims by running commands
  and observing output. Checks CLI availability, runs compact/compactc
  commands, captures stdout/stderr/exit codes, inspects filesystem changes,
  and interprets results. Dispatched by the verifier orchestrator agent.

  Example 1: Claim "--skip-zk skips PLONK key generation" — compiles a
  minimal contract with and without --skip-zk, compares output directories
  (no keys/ directory when --skip-zk is used).

  Example 2: Claim "compact compile --language-version returns the current
  version" — runs the command, captures stdout, confirms it outputs a
  version string.

  Example 3: Claim "compactc rejects undeclared variables with exit code 1"
  — writes a contract with an undeclared variable, compiles with compactc,
  checks exit code is non-zero and stderr contains the expected error.
skills: midnight-verify:verify-by-cli-execution
model: sonnet
color: orange
---

You are a Compact CLI tester.

Load the `midnight-verify:verify-by-cli-execution` skill and follow it step by step. It tells you exactly how to:

1. Check CLI availability (compact and compactc)
2. Determine the test approach based on claim type
3. Run the command(s) and capture all output
4. Interpret the results
5. Clean up

Follow the skill precisely. The CLI output is your evidence. Do not guess what a command does — run it and observe.

You may load `midnight-tooling:compact-cli` as a hint for understanding CLI flags, compilation patterns, and version management. But the CLI output is your evidence, not the skill content.

**Important:** Always capture full stdout, stderr, and exit code for every command you run. Partial output is not acceptable — the verifier needs the complete picture to synthesize a verdict.
```

- [ ] **Step 2: Verify the file was created correctly**

```bash
head -5 plugins/midnight-verify/agents/cli-tester.md
```

Expected: YAML frontmatter with `name: cli-tester`.

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-verify/agents/cli-tester.md
git commit -m "feat(midnight-verify): add cli-tester agent

New agent for verifying Compact CLI claims by running commands and
observing output. Uses sonnet model, loads verify-by-cli-execution skill.

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

## Task 4: Update verifier orchestrator agent

**Files:**
- Modify: `plugins/midnight-verify/agents/verifier.md`

- [ ] **Step 1: Add tooling examples to the description**

In the YAML frontmatter `description` field, after the existing Example 11 about ledger TypeScript API (the line containing "optionally runs ledger-v8 execution to call the function and observe output."), add:

```yaml

  Example 12: User runs /verify "--skip-zk skips PLONK key generation" — the
  orchestrator classifies this as a tooling claim, dispatches the cli-tester
  agent to compile with and without --skip-zk and compare output directories.

  Example 13: User runs /verify "The Compact compiler is written in Scheme" —
  the orchestrator classifies this as an internal tooling claim, dispatches
  the source-investigator to search the LFDT-Minokawa/compact repository.
```

- [ ] **Step 2: Add verify-tooling to the skills list**

Append `, midnight-verify:verify-tooling` to the end of the `skills:` line.

- [ ] **Step 3: Add tooling to the domain routing in the body**

In the body's domain routing list (under "Based on the claim domain:"), after "Ledger/Protocol claims → load `midnight-verify:verify-ledger`", add:

```markdown
   - Tooling claims → load `midnight-verify:verify-tooling`
```

- [ ] **Step 4: Add tooling dispatch rules to the body**

In "## Dispatching Sub-Agents", after the ledger/protocol verification subsection (ending with "Dispatch source-investigator first; dispatch secondary agents concurrently if the claim is testable.") and BEFORE "**When multiple methods are needed...**", add:

```markdown
**Tooling verification:**
- CLI execution (primary) → dispatch `midnight-verify:cli-tester` for behavioral claims (flags, output, errors, versions)
- Source investigation (secondary) → dispatch `midnight-verify:source-investigator` for internal/architectural claims about the compiler or CLI wrapper

**For tooling claims, prefer CLI execution whenever possible.** The CLI is on the machine — running the command is more authoritative than reading source code. Use source investigation only for claims about internals that can't be observed via CLI output.
```

- [ ] **Step 5: Commit**

```bash
git add plugins/midnight-verify/agents/verifier.md
git commit -m "feat(midnight-verify): add tooling domain to verifier orchestrator

Add tooling dispatch rules, examples, and skill reference. Tooling
claims dispatch cli-tester as primary and source-investigator for
internal claims.

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

## Task 5: Update verify-correctness hub skill

**Files:**
- Modify: `plugins/midnight-verify/skills/verify-correctness/SKILL.md`

- [ ] **Step 1: Add Tooling to the domain classification table**

In "### 1. Classify the Domain", add a new row to the table after the "Ledger/Protocol" row:

```markdown
| **Tooling** | Compact CLI commands (compact compile, compactc), CLI flags (--skip-zk, --language-version, --help), compiler output structure, compiler error messages, exit codes, CLI version/installation, CLI wrapper vs compactc distinction | Load `midnight-verify:verify-tooling` |
```

- [ ] **Step 2: Add tooling dispatch rules to section 3**

In "### 3. Dispatch Sub-Agents", after the ledger/protocol verification subsection and before "**Multiple methods needed**" or the line starting with "- **Multiple methods needed**", add:

```markdown
**Tooling verification:**
- CLI execution (primary) → dispatch `midnight-verify:cli-tester` agent for behavioral claims
- Source investigation (secondary) → dispatch `midnight-verify:source-investigator` agent for internal/architectural claims

**For tooling claims, prefer CLI execution.** Running the command is more authoritative than reading source.
```

- [ ] **Step 3: Add tooling verdict qualifiers to section 4**

In "### 4. Synthesize the Verdict", in the verdict options table, after the ledger domain rows, add:

```markdown
| **Confirmed** | (cli-tested) | Ran the CLI command, output matches the claim (tooling domain) |
| **Confirmed** | (cli-tested + source-verified) | CLI output and source code both confirm (tooling domain) |
| **Confirmed** | (source-verified) | Internal claim verified via source, not testable via CLI (tooling domain) |
| **Refuted** | (cli-tested) | Ran the CLI command, output contradicts the claim (tooling domain) |
| **Refuted** | (source-verified) | Source contradicts the internal claim (tooling domain) |
| **Inconclusive** | (cli unavailable) | Compact CLI not installed or not on PATH (tooling domain) |
```

- [ ] **Step 4: Commit**

```bash
git add plugins/midnight-verify/skills/verify-correctness/SKILL.md
git commit -m "feat(midnight-verify): add tooling domain to verify-correctness hub

Add Tooling to domain classification table, dispatch rules, and
verdict qualifiers including Confirmed (cli-tested) and Inconclusive
(cli unavailable).

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

## Task 6: Update source-investigator agent

**Files:**
- Modify: `plugins/midnight-verify/agents/source-investigator.md`

- [ ] **Step 1: Add tooling example to description**

In the YAML frontmatter `description` field, after the existing Example 5 about ledger CoinCommitment (the line containing "Uses verify-by-ledger-source for Rust crate-level routing."), add:

```yaml

  Example 6: Claim "The Compact compiler is written in Scheme" — searches
  LFDT-Minokawa/compact for the compiler source code, examines file
  extensions and directory structure. Uses the general verify-by-source
  skill (tooling source claims route to existing repos).
```

- [ ] **Step 2: Commit**

```bash
git add plugins/midnight-verify/agents/source-investigator.md
git commit -m "feat(midnight-verify): add tooling example to source-investigator

Tooling internal claims use existing verify-by-source routing to
LFDT-Minokawa/compact and midnightntwrk/compact repos.

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

## Task 7: Bump version and final verification

- [ ] **Step 1: Bump midnight-verify plugin version**

In `plugins/midnight-verify/.claude-plugin/plugin.json`, change `"version": "0.6.0"` to `"version": "0.7.0"`.

- [ ] **Step 2: Bump marketplace version**

In `.claude-plugin/marketplace.json`, change `"version": "0.12.0"` to `"version": "0.13.0"`.

- [ ] **Step 3: Commit version bumps**

```bash
git add plugins/midnight-verify/.claude-plugin/plugin.json .claude-plugin/marketplace.json
git commit -m "chore: bump versions for tooling verification release

midnight-verify 0.6.0 → 0.7.0
marketplace 0.12.0 → 0.13.0

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

- [ ] **Step 4: Verify all new files exist**

```bash
echo "=== New files ==="
ls -la plugins/midnight-verify/skills/verify-tooling/SKILL.md
ls -la plugins/midnight-verify/skills/verify-by-cli-execution/SKILL.md
ls -la plugins/midnight-verify/agents/cli-tester.md
```

Expected: all 3 files exist.

- [ ] **Step 5: Verify YAML frontmatter**

```bash
for f in \
  plugins/midnight-verify/skills/verify-tooling/SKILL.md \
  plugins/midnight-verify/skills/verify-by-cli-execution/SKILL.md \
  plugins/midnight-verify/agents/cli-tester.md; do
  echo "--- $f ---"
  head -3 "$f"
  echo ""
done
```

Expected: each starts with `---` and has a `name:` field.

- [ ] **Step 6: Count agents**

```bash
ls plugins/midnight-verify/agents/
```

Expected: 8 agent files (7 existing + cli-tester.md).

- [ ] **Step 7: Verify git status is clean**

```bash
git status
```

Expected: clean working tree.
