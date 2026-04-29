---
name: midnight-fact-check:check
description: Fact-check content against the Midnight ecosystem. Extracts claims, classifies by domain, verifies each via midnight-verify, and produces a report.
allowed-tools: Agent, AskUserQuestion, Read, Write, Glob, Grep, Bash, Skill
argument-hint: "<file, directory, URL, GitHub URL, or glob pattern>"
---

Fact-check Midnight-related content by running a staged pipeline: extract claims → classify by domain → verify → report.

## Step 1: Preflight

Check that midnight-verify is available. Use Glob to check:

```
plugins/midnight-verify/skills/verify-correctness/SKILL.md
```

If the file does not exist, tell the user:

> "midnight-verify plugin is required but not found. Install it before running fact-check."

Then stop. Do not proceed to Step 2.

## Step 2: Initialize Run

Generate a run directory:

1. Get the current month and year as `MM-YY` (e.g., `03-26`)
2. Choose a short name (2-4 words, kebab-case) describing the source content (e.g., `compact-core-plugin`, `sdk-tutorial`, `counter-contract`)
3. Generate a 4-character random alphanumeric ID (e.g., `a3Kf`)
4. Create the run directory:

```bash
RUN_DIR=".midnight-expert/fact-checker/MM-YY/run-short-name-XXXX"
mkdir -p "$RUN_DIR"
```

5. Write `run-metadata.json` to the run directory:

```json
{
  "targets": ["$ARGUMENTS"],
  "started_at": "ISO-8601 timestamp",
  "run_dir": "the full run directory path"
}
```

Tell the user: `"Run initialized: [run directory path]"`

## Step 3: Resolve Inputs (Stage 0)

Parse `$ARGUMENTS` and resolve each target to readable content. Classify each target:

### Local file
- Detected by: path exists on disk and is a file (check with Glob or Bash `test -f`)
- Read the file. If it is a PDF with >20 pages, note it for chunking in Stage 1.
- Add to the content list.

### Local directory (non-plugin)
- Detected by: path exists, is a directory, does NOT contain `.claude-plugin/plugin.json`
- Run file discovery:
  ```bash
  npx --ignore-scripts @aaronbassett/midnight-fact-checker-utils discover "**/*" --cwd "[directory path]"
  ```
- Show the matched file list to the user and ask for confirmation before proceeding.

### Plugin directory
- Detected by: path exists, is a directory, AND contains `.claude-plugin/plugin.json`
- Scope to plugin content: use Glob to find `skills/*/SKILL.md`, `skills/*/references/*.md`, `commands/*.md`, `agents/*.md`
- Group files by skill (each skill directory = one chunk for extraction).

### URL(s)
- Detected by: starts with `http://` or `https://`, does NOT match `github.com`
- For each URL, run:
  ```bash
  npx --ignore-scripts @aaronbassett/midnight-fact-checker-utils extract-url "[URL]" > "$RUN_DIR/url-content-N.md"
  ```
- Add the saved markdown files to the content list.

### GitHub file URL
- Detected by: matches `github.com/[owner]/[repo]/blob/[branch]/[path]`
- If the URL can be converted to a `raw.githubusercontent.com` URL, use:
  ```bash
  wget -q -O "$RUN_DIR/github-file.md" "[raw URL]"
  ```
- Otherwise, use the octocode MCP `githubGetFileContent` tool to fetch the file content and write it to the run directory.
- Record the repo info (owner, repo, branch, path) in `run-metadata.json` for potential issue creation in Step 8.

### GitHub directory/repo URL
- Detected by: matches `github.com/[owner]/[repo]/tree/[branch]/[path]` or `github.com/[owner]/[repo]` (bare repo)
- Clone the repo:
  ```bash
  git clone --depth=1 "[repo URL]" "/tmp/fact-check-[short-id]"
  ```
- If the URL included a path (tree/branch/path), scope to that subdirectory.
- Then treat as a local directory (run file discovery, show list, confirm).
- Record repo info in `run-metadata.json`.

### Glob pattern
- Detected by: contains `*`, `?`, `[`, or `{`
- Run file discovery:
  ```bash
  npx --ignore-scripts @aaronbassett/midnight-fact-checker-utils discover "[pattern]"
  ```
- Show matched file list to user and ask for confirmation.

### After all targets are resolved

Write `resolved-content.json` to the run directory:

```json
{
  "files": [
    {
      "path": "absolute/path/to/file.md",
      "type": "local",
      "chunk_group": "skill-name or parent-dir"
    }
  ],
  "github_source": {
    "owner": "user-or-org",
    "repo": "repo-name",
    "branch": "main",
    "paths": ["path/to/checked/content"]
  }
}
```

The `github_source` field is only present if the source was GitHub-hosted. It enables Step 8.

Tell the user: `"Resolved N files from M targets"`

## Step 4: Extract Claims (Stage 1)

1. Read `resolved-content.json`.
2. Split files into chunks for parallel extraction:
   - If files have `chunk_group` set (plugin skills), group by chunk_group
   - For large single files (>500 lines or PDF >20 pages), split into sections
   - For remaining files, group by parent directory
   - If there are 5 or fewer files total, use a single extractor
3. Dispatch one `midnight-fact-check:claim-extractor` agent per chunk, in parallel. Each agent's prompt should include:
   - The list of file paths in its chunk
   - Instruction to read the files and extract claims
4. Collect the JSON arrays returned by each extractor.
5. Write each extractor's output to the run directory: `extracted-chunk-N.json`
6. Merge all outputs using the merge script in concat mode:
   ```bash
   npx --ignore-scripts @aaronbassett/midnight-fact-checker-utils merge --mode concat -o "$RUN_DIR/extracted-claims.json" "$RUN_DIR/extracted-chunk-1.json" "$RUN_DIR/extracted-chunk-2.json" ...
   ```
7. Read the merged file. Assign sequential IDs (`claim-001`, `claim-002`, ...) to each claim. Write back.
8. Tell the user: `"Extracted N claims from M content chunks"`

If zero claims were extracted, tell the user and stop:
> "No testable claims found in the provided content. This content may not contain verifiable Midnight claims."

## Step 5: Classify Claims (Stage 2)

1. Read `extracted-claims.json`.
2. Create one copy per domain:
   ```bash
   cp "$RUN_DIR/extracted-claims.json" "$RUN_DIR/extracted-claims.compact-classifier.json"
   cp "$RUN_DIR/extracted-claims.json" "$RUN_DIR/extracted-claims.sdk-classifier.json"
   cp "$RUN_DIR/extracted-claims.json" "$RUN_DIR/extracted-claims.zkir-classifier.json"
   cp "$RUN_DIR/extracted-claims.json" "$RUN_DIR/extracted-claims.witness-classifier.json"
   ```
3. Dispatch four `midnight-fact-check:domain-classifier` agents in parallel. Each agent's prompt should include:
   - Its assigned domain (compact, sdk, zkir, or witness)
   - The path to its copy of the claims file
   - Instruction to tag claims belonging to its domain
4. Wait for all classifiers to complete.
5. Merge all copies:
   ```bash
   npx --ignore-scripts @aaronbassett/midnight-fact-checker-utils merge --mode update --original "$RUN_DIR/extracted-claims.json" -o "$RUN_DIR/classified-claims.json" "$RUN_DIR/extracted-claims.compact-classifier.json" "$RUN_DIR/extracted-claims.sdk-classifier.json" "$RUN_DIR/extracted-claims.zkir-classifier.json" "$RUN_DIR/extracted-claims.witness-classifier.json"
   ```
6. If the merge fails (validation error), tell the user:
   > "Merge validation failed. Agent copies preserved in [run directory] for debugging."
   Then stop.
7. Read `classified-claims.json`. Count claims per domain. Count unclassified (no `domains` field or empty `domains` array).
8. For unclassified claims, set:
   ```json
   {
     "verification": {
       "verdict": "inconclusive",
       "qualifier": "no-domain-match",
       "evidence_summary": "No domain classifier tagged this claim."
     }
   }
   ```
   Write the updated file.
9. Tell the user: `"Classified N claims — compact: X, sdk: Y, zkir: Z, witness: W, cross-domain: V, unclassified: U"`

## Step 6: Verify Claims (Stage 3)

### Critical Rules

- You dispatch midnight-verify agents directly — do NOT dispatch `midnight-fact-check:claim-verifier`
- midnight-verify's SubagentStop hooks enforce verification quality on all agents you dispatch
- **Each agent already has skills that define its verification method.** Do NOT include verification methodology in the dispatch prompt. The agents know how to verify — you only tell them WHAT claim to verify.
- **NEVER tell agents to cross-reference skills, read local documentation, or compare files in this repository.** That is not verification — it is checking documentation against documentation. Verification means: compiling code, running code, type-checking with tsc, inspecting actual source repositories on GitHub, or running CLI commands.

### Process

1. Read `classified-claims.json`.
2. Separate claims into two groups:
   - **Verifiable**: claims with `classification.primary_domain` set
   - **Already resolved**: claims marked inconclusive from Step 5 — skip these
3. For each verifiable claim, use the routing table to select the correct agent. **Route each claim individually** — do not batch all claims from one file to the same agent.

   | Domain | Claim About | Agent | What the Agent Does |
   |--------|------------|-------|---------------------|
   | compact | Observable behavior: syntax, types, stdlib, disclosure, compiler errors, performance | `midnight-verify:contract-writer` | Writes a Compact test contract, compiles it, executes it |
   | compact | Internal implementation, architecture, feature counts | `midnight-verify:source-investigator` | Searches actual source code on GitHub (LFDT-Minokawa/compact) |
   | compact | Circuit structure, ZKIR opcodes, compiled properties | `midnight-verify:zkir-checker` | Compiles to ZKIR, inspects circuit structure or runs PLONK checker |
   | compact | Cross-component (runtime + internals) | Both `contract-writer` + `source-investigator` concurrently | |
   | sdk | API signatures, types, imports, interfaces, error hierarchies | `midnight-verify:type-checker` | Writes TypeScript assertions, runs tsc --noEmit |
   | sdk | Runtime behavior: deploy, call, state, transactions | `midnight-verify:sdk-tester` | Runs E2E scripts against devnet |
   | sdk | Internal implementation, package internals | `midnight-verify:source-investigator` | Searches actual SDK source on GitHub |
   | sdk | Package version or existence | Run `npm view` directly — no agent needed | |
   | sdk | Both types and runtime behavior | Both `type-checker` + `sdk-tester` concurrently | |
   | zkir | Constraint behavior, proof verification, circuit properties | `midnight-verify:zkir-checker` | Compiles, runs WASM checker or inspects circuit |
   | witness | Witness correctness, type mappings, structural checks | `midnight-verify:witness-verifier` | Compiles contract, type-checks witness, runs structural analysis |
   | wallet-sdk | Any wallet SDK claim | `midnight-verify:source-investigator` (primary); `midnight-verify:type-checker` (pre-flight only) | Searches wallet SDK source on GitHub |
   | ledger | Transaction structure, token mechanics, protocol behavior | `midnight-verify:source-investigator` | Searches ledger Rust source on GitHub |
   | tooling | CLI commands, flags, output behavior | `midnight-verify:cli-tester` | Runs CLI commands, checks output |
   | tooling | Internal implementation, compiler internals | `midnight-verify:source-investigator` | Searches compiler source on GitHub |

   Most compact-domain claims about syntax, types, functions, or behavior should go to `contract-writer` — compilation and execution is the strongest evidence. Only route to `source-investigator` for claims about things that cannot be tested by writing code (e.g., "the compiler is written in Scheme").

4. Dispatch verification agents in rounds of up to 5 concurrent agents.

   **Dispatch prompt format — include ONLY these fields:**
   ```
   Verify this claim:

   Claim: "[exact claim text]"
   Domain: [compact|sdk|zkir|witness|wallet-sdk|ledger|tooling]
   Source: [file path where the claim was found, line range if available]
   ```

   Do NOT add:
   - Verification instructions (the agent's skills handle this)
   - File paths to cross-reference against
   - Suggestions for how to verify
   - Lists of other skills or documentation to read

   Use multiple Agent tool calls in a single message for concurrent dispatch within a round. Wait for all agents in a round to return before starting the next round.

5. As results return, extract the verdict from each agent's response and update the claim:
   ```json
   {
     "verification": {
       "verdict": "confirmed|refuted|inconclusive",
       "qualifier": "tested|source-verified|type-checked|zkir-checked|cli-tested|witness-verified",
       "evidence_summary": "What the agent did and observed",
       "verified_at": "ISO 8601 timestamp"
     }
   }
   ```

   When multiple agents verified the same claim:
   - Both agree → combine qualifiers (e.g., `"tested + source-verified"`)
   - They disagree → execution/testing evidence wins over source inspection; note the disagreement in `evidence_summary`
   - One failed → use the successful agent's verdict; note the failure

   If an agent dispatch fails entirely, set verdict to `"inconclusive"` with qualifier `"error"`.

6. Write `verification-results.json` to the run directory.
7. Tell the user: `"Verified N claims — confirmed: X, refuted: Y, inconclusive: Z"`

## Step 7: Generate Report (Stage 4)

1. Load the `midnight-fact-check:fact-check-reporting` skill for templates.
2. Read `verification-results.json`.
3. Generate `report.md` in the run directory following the skill's template:
   - Executive summary with verdict counts
   - Refuted claims section at the top
   - Per-domain results tables
   - Include unclassified claims in their own section
4. Write the report to `$RUN_DIR/report.md`.
5. Print the terminal summary to the user (following the skill's terminal format).
6. Print the run artifacts path.

## Step 8: GitHub Issues (conditional)

Only run this step if:
- `resolved-content.json` has a `github_source` field (source was GitHub-hosted)
- AND there are refuted claims in the verification results

If both conditions are met:

1. Count refuted claims and affected files.
2. Ask the user using AskUserQuestion:
   > "Found N refuted claims across M files in [owner/repo]. Would you like to create GitHub issues?
   > a) One issue per refuted claim
   > b) One issue per file with refuted claims
   > c) A single summary issue
   > d) No issues"
3. Based on their choice, create issues using the templates from the reporting skill:
   ```bash
   gh issue create --repo "[owner]/[repo]" --title "[title]" --body "[body]"
   ```
4. If `gh` is not authenticated, tell the user:
   > "GitHub CLI is not authenticated. Run `gh auth login` to enable issue creation."
5. Print the created issue URLs.
