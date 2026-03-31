# Tooling Verification — Design Spec

**Date:** 2026-03-31
**Status:** Approved
**Scope:** Add tooling verification domain to midnight-verify plugin for Compact CLI claims

## Overview

The Compact CLI (`compact` wrapper + `compactc` compiler binary) is the most frequently referenced tool in the Midnight ecosystem. Claims about CLI flags, compiler behavior, output structure, error messages, and version management are common and frequently wrong in training data because CLI behavior changes with every release. This spec adds a tooling verification domain that verifies these claims by actually running the CLI and observing the output.

## Design Decisions

- **Compact CLI only**: This domain covers `compact` (the CLI wrapper) and `compactc` (the underlying compiler, invoked via `compact compile`). Devnet, proof server, release notes, and troubleshooting are out of scope — their claims are better handled by existing source investigation.
- **CLI execution primary**: Running the command and observing the output is the most authoritative evidence for behavioral claims. Source investigation is the fallback for internal/architectural claims that can't be tested by running a command.
- **New method skill**: `verify-by-cli-execution` defines the CLI execution workflow (run binary, check exit code, parse stdout/stderr, inspect filesystem). This is fundamentally different from contract execution (verify-by-execution) and warrants its own skill.
- **New agent**: `cli-tester` is a dedicated agent for running CLI commands. The contract-writer's job is writing and executing Compact contracts — asking it to also run CLI diagnostic commands stretches its purpose. The cli-tester keeps responsibilities clean.
- **No new workspace**: CLI execution reuses the existing compact-workspace for job isolation when compilation is needed.
- **No midnight-cq changes**: Tooling testing is too niche for a testing guide — users don't write code that wraps the CLI.

## Part 1: verify-tooling Domain Skill

**Purpose:** Classify Compact CLI claims and route them to the correct verification methods.

**Domain indicators:**
- Compact CLI commands (`compact compile`, `compact --version`, `compactc`)
- CLI flags (`--skip-zk`, `--language-version`, `--help`)
- Compiler output structure (build directories, file layout)
- Compiler error messages and exit codes
- CLI installation and version management
- Compiler behavior (what happens when you run a command)

**Distinction from verify-compact:** verify-compact handles claims about the Compact *language* ("tuples are 0-indexed"). verify-tooling handles claims about the CLI *tool* ("--skip-zk skips PLONK key generation"). Routing rule: if the claim is about what the language allows/disallows, it's Compact. If it's about what the CLI does when you run it, it's tooling.

**Verification flow:**

| Claim Category | Primary | Secondary |
|---|---|---|
| CLI flag existence/behavior | cli-tester (run command, observe) | source-investigator (check CLI source) |
| Compiler output structure | cli-tester (compile, inspect filesystem) | — |
| Compiler error messages | cli-tester (feed bad input, check stderr) | source-investigator (check error definitions) |
| CLI version/installation | cli-tester (run --version) | — |
| Compilation behavior | cli-tester (compile test contract, observe) | contract-writer (if claim overlaps with contract correctness) |
| Internal compiler architecture | source-investigator | — |
| CLI wrapper vs compactc distinction | cli-tester (run both, compare) | source-investigator |

**Verdict qualifiers:**
- `Confirmed (cli-tested)` — ran the command, output matches the claim
- `Confirmed (cli-tested + source-verified)` — both CLI execution and source agree
- `Confirmed (source-verified)` — internal claim verified via source (can't be CLI tested)
- `Refuted (cli-tested)` — ran the command, output contradicts the claim
- `Refuted (source-verified)` — source contradicts
- `Inconclusive (cli unavailable)` — Compact CLI not installed or not on PATH

## Part 2: verify-by-cli-execution Method Skill

**Purpose:** Run Compact CLI commands and interpret results. Loaded by the cli-tester agent.

**Workflow:**

### Step 1: Check CLI Availability

Run `compact --version` and `compactc --version`. If neither is available, report `Inconclusive (cli unavailable)` and stop.

### Step 2: Determine Test Approach

| Claim Type | Approach |
|---|---|
| Flag exists | Run `compact compile --help`, check flag appears in output |
| Flag behavior | Compile a minimal contract with and without the flag, compare output directories |
| Output structure | Compile a minimal contract, inspect the build directory layout |
| Error message | Feed invalid input, capture stderr, match against claimed message |
| Exit code | Run command, check `$?` |
| Version info | Run `--version` or `--language-version`, parse output |
| CLI vs compactc | Run both, compare behavior |

### Step 3: Write Minimal Test Contract if Needed

Some claims require compilation. Use the compact-workspace at `.midnight-expert/verify/compact-workspace/` with a job directory for isolation:

```bash
JOB_ID=$(uuidgen | tr '[:upper:]' '[:lower:]')
mkdir -p .midnight-expert/verify/compact-workspace/jobs/$JOB_ID
```

Write a minimal `.compact` file targeting the specific claim. Get the current language version with `compact compile --language-version`.

### Step 4: Run the Command

Capture stdout, stderr, and exit code. Also inspect filesystem changes (new directories, file counts, file types) when relevant.

```bash
compact compile <args> > stdout.txt 2> stderr.txt
echo $? > exit_code.txt
```

### Step 5: Interpret and Report

Compare observed output against the claim.

**Report format:**

```
### CLI Execution Report

**Claim:** [verbatim]

**Command(s) run:**
\`\`\`bash
[exact commands]
\`\`\`

**Exit code:** [0 / non-zero]

**stdout:**
\`\`\`
[captured output]
\`\`\`

**stderr:**
\`\`\`
[captured output]
\`\`\`

**Filesystem changes:** [new files/directories created, if relevant]

**Interpretation:** [Confirmed / Refuted / Inconclusive] — [explanation]
```

### Step 6: Clean Up

```bash
rm -rf .midnight-expert/verify/compact-workspace/jobs/$JOB_ID
```

**Evidence rules:** CLI output is primary evidence. The command ran and produced this output — that's definitive for behavioral claims. Source code is secondary for internal claims that can't be observed via CLI.

**Hint skills:** The cli-tester may consult `midnight-tooling:compact-cli` as a hint for what flags exist and how the CLI works. This is a hint only — the CLI output is the evidence.

## Part 3: cli-tester Agent

**Purpose:** Run Compact CLI commands and interpret output to verify tooling claims.

**Frontmatter:**
- `name: cli-tester`
- `model: sonnet`
- `color: orange`
- `skills: midnight-verify:verify-by-cli-execution`
- `tools: Bash, Read, Glob, Grep`

**Instructions:**
- Load `verify-by-cli-execution` and follow it step by step
- May load `midnight-tooling:compact-cli` as a hint, but CLI output is evidence
- Always check CLI availability first
- Capture full stdout, stderr, and exit code for every command
- Use job directory under compact-workspace for compilation-dependent claims
- Clean up after yourself

**Examples:**
1. Claim "--skip-zk skips PLONK key generation" → compiles with and without `--skip-zk`, compares output directories (no `keys/` dir when skipped)
2. Claim "compact compile --language-version returns the current version" → runs the command, captures output
3. Claim "compactc rejects undeclared variables with exit code 1" → writes a contract with an undeclared variable, compiles, checks exit code and stderr

## Part 4: Changes to Existing Components

**verifier agent (`agents/verifier.md`):**
- Add tooling domain to description with examples
- Add `midnight-verify:verify-tooling` to skills list
- Add tooling dispatch rules: cli-tester (primary for behavioral claims), source-investigator (for internal claims)

**verify-correctness hub skill (`skills/verify-correctness/SKILL.md`):**
- Add "Tooling" row to domain classification table with indicators
- Add tooling dispatch rules to section 3
- Add tooling verdict qualifiers to section 4

**source-investigator agent (`agents/source-investigator.md`):**
- Add tooling example to description (e.g., "Compact CLI wrapper is a shell script" → search `midnightntwrk/compact`)
- No new method skill needed — existing verify-by-source already routes to `midnightntwrk/compact` for CLI releases and `LFDT-Minokawa/compact` for compiler source

## File Inventory

### New files (3)

| File | Purpose |
|---|---|
| `skills/verify-tooling/SKILL.md` | Domain skill — routing table for Compact CLI claims |
| `skills/verify-by-cli-execution/SKILL.md` | Method skill — CLI execution workflow |
| `agents/cli-tester.md` | New agent — runs CLI commands, interprets output |

### Modified files (3)

| File | Change |
|---|---|
| `agents/verifier.md` | Add tooling domain, dispatch rules, examples |
| `skills/verify-correctness/SKILL.md` | Add Tooling to domain classification, verdict qualifiers |
| `agents/source-investigator.md` | Add tooling example |

### Total: 3 new files, 3 modified files, 1 new agent.
