---
name: midnight-fact-check:fast-check
description: Fast fact-check content against the Midnight ecosystem. Extracts claims, verifies each via source inspection (skipping classification and execution), and produces a report.
allowed-tools: Agent, AskUserQuestion, Read, Write, Glob, Grep, Bash, Skill
argument-hint: "<file, directory, URL, GitHub URL, or glob pattern>"
---

Fast fact-check Midnight-related content by running a streamlined pipeline: extract claims → verify via source inspection → report. Skips domain classification and execution-based verification for speed.

## Step 1: Preflight

Check that midnight-verify is available. Use Glob to check:

```
plugins/midnight-verify/skills/verify-correctness/SKILL.md
```

If the file does not exist, tell the user:

> "midnight-verify plugin is required but not found. Install it before running fast-check."

Then stop. Do not proceed to Step 2.

## Step 2: Initialize Run

Generate a run directory:

1. Get the current month and year as `MM-YY` (e.g., `03-26`)
2. Choose a short name (2-4 words, kebab-case) describing the source content (e.g., `compact-core-plugin`, `sdk-tutorial`, `counter-contract`)
3. Generate a 4-character random alphanumeric ID (e.g., `a3Kf`)
4. Create the run directory:

```bash
RUN_DIR=".midnight-expert/fact-checker/MM-YY/fast-run-short-name-XXXX"
mkdir -p "$RUN_DIR"
```

5. Write `run-metadata.json` to the run directory:

```json
{
  "mode": "fast-check",
  "targets": ["$ARGUMENTS"],
  "started_at": "ISO-8601 timestamp",
  "run_dir": "the full run directory path"
}
```

Tell the user: `"Fast-check run initialized: [run directory path]"`

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
  npx @aaronbassett/midnight-fact-checker-utils discover "**/*" --cwd "[directory path]"
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
  npx @aaronbassett/midnight-fact-checker-utils extract-url "[URL]" > "$RUN_DIR/url-content-N.md"
  ```
- Add the saved markdown files to the content list.

### GitHub file URL
- Detected by: matches `github.com/[owner]/[repo]/blob/[branch]/[path]`
- If the URL can be converted to a `raw.githubusercontent.com` URL, use:
  ```bash
  wget -q -O "$RUN_DIR/github-file.md" "[raw URL]"
  ```
- Otherwise, use the octocode MCP `githubGetFileContent` tool to fetch the file content and write it to the run directory.
- Record the repo info (owner, repo, branch, path) in `run-metadata.json` for potential issue creation in Step 7.

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
  npx @aaronbassett/midnight-fact-checker-utils discover "[pattern]"
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

The `github_source` field is only present if the source was GitHub-hosted. It enables Step 7.

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
   npx @aaronbassett/midnight-fact-checker-utils merge --mode concat -o "$RUN_DIR/extracted-claims.json" "$RUN_DIR/extracted-chunk-1.json" "$RUN_DIR/extracted-chunk-2.json" ...
   ```
7. Read the merged file. Assign sequential IDs (`claim-001`, `claim-002`, ...) to each claim. Write back.
8. Tell the user: `"Extracted N claims from M content chunks"`

If zero claims were extracted, tell the user and stop:
> "No testable claims found in the provided content. This content may not contain verifiable Midnight claims."

## Step 5: Verify Claims (Stage 2)

**No classification step.** All claims go directly to source verification.

1. Read `extracted-claims.json`.
2. For each claim, dispatch @"midnight-verify:source-investigator (agent)" with:
   - The claim text verbatim
   - Source file path and line range (from extraction metadata)
   - Instruction: "Verify this claim by inspecting the relevant Midnight source repositories. Determine the most likely repo based on the claim content: Compact language → LFDT-Minokawa/compact, SDK/TypeScript → midnightntwrk/midnight-js, Wallet SDK → midnightntwrk/midnight-wallet, Ledger/Protocol → midnightntwrk/midnight-ledger, ZKIR → midnightntwrk/midnight-zk."
3. Dispatch in rounds of up to 5 concurrent agents. Wait for all agents in a round to return before starting the next round.
4. As results return, extract the verdict from each agent's response and update the claim:
   ```json
   {
     "verification": {
       "verdict": "confirmed|refuted|inconclusive",
       "qualifier": "source-verified",
       "evidence_summary": "What the agent found in source",
       "verified_at": "ISO 8601 timestamp"
     }
   }
   ```
   If an agent dispatch fails entirely, set verdict to `"inconclusive"` with qualifier `"error"`.
5. Write `verification-results.json` to the run directory.
6. Tell the user: `"Verified N claims — confirmed: X, refuted: Y, inconclusive: Z"`

## Step 6: Generate Report (Stage 3)

1. Load the `midnight-fact-check:fact-check-reporting` skill for templates.
2. Read `verification-results.json`.
3. Generate `report.md` in the run directory following the skill's template:
   - Executive summary with verdict counts
   - Refuted claims section at the top
   - Results table (no per-domain grouping — all claims in a single table since no classification was done)
   - Include a note at the top: "This report was generated using fast-check (source-only verification). For full execution-based verification, use /check."
4. Write the report to `$RUN_DIR/report.md`.
5. Print the terminal summary to the user (following the skill's terminal format).
6. Print the run artifacts path.

## Step 7: GitHub Issues (conditional)

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
