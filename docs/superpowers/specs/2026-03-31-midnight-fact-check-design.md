# midnight-fact-check Plugin Design

**Date:** 2026-03-31
**Status:** Draft
**Author:** Aaron Bassett + Claude

## Overview

A Claude Code plugin that fact-checks any content against the Midnight ecosystem by extracting testable claims, classifying them by domain, and verifying them using the existing midnight-verify framework. Accepts any content Claude Code can read: markdown files, code, PDFs, URLs, GitHub repos, directories, glob patterns.

## Architecture

### Approach: Command-Driven Staged Pipeline (Approach B)

The `/midnight-fact-check:check` command acts as the pipeline orchestrator. Each stage runs as a step in the command. Parallelism happens within stages (concurrent agents), but stages run sequentially. Artifacts are written to disk between stages, providing natural checkpointing.

Subagents cannot spawn subagents (Claude Code hard restriction), so the command in the main conversation context is the only place that can dispatch agents. This makes Approach B the only viable architecture.

### Pipeline Stages

```
/midnight-fact-check:check <targets...>
    │
    ├── Preflight: verify midnight-verify plugin is installed
    │
    ├── Stage 0: Input Resolution (main context)
    │   └── resolve targets → readable content → resolved-content.json
    │
    ├── Stage 1: Claims Extraction (parallel agents)
    │   └── split content into chunks → dispatch extractors → merge → extracted-claims.json
    │
    ├── Stage 2: Domain Classification (parallel agents)
    │   └── one classifier per domain → copy/update/merge → classified-claims.json
    │
    ├── Stage 3: Verification (parallel agents per domain-batch)
    │   └── batch by domain → dispatch verifiers with /verify skill → merge → verification-results.json
    │
    ├── Stage 4: Report Assembly (main context)
    │   └── read results → generate report.md → print terminal summary
    │
    └── Stage 5: GitHub Issues (conditional, main context)
        └── if source is GitHub + refuted claims → ask user → create issues via gh
```

### Parallel Stage Merge Pattern

Every parallel stage (1, 2, 3) uses the same merge pattern to avoid race conditions:

1. Command writes the stage input file (e.g., `extracted-claims.json`)
2. Each agent gets an isolated copy (e.g., `extracted-claims.compact-classifier.json`)
3. Agent reads its copy, makes updates, writes updated copy, returns summary to main thread
4. Once all agents complete, command runs the merge script:
   - Reads all agent copies + original
   - Combines updates into a new file
   - Validates: valid JSON, same claim count
   - If valid: overwrites original with merged version
   - If invalid: errors out, all copies preserved for debugging

## Plugin Structure

```
plugins/midnight-fact-check/
├── .claude-plugin/
│   └── plugin.json
├── commands/
│   └── check.md                        # Pipeline orchestrator
├── agents/
│   ├── claim-extractor.md              # Extracts testable claims from content chunks
│   ├── domain-classifier.md            # Tags claims with domain(s)
│   └── claim-verifier.md               # Verifies a batch via midnight-verify
├── skills/
│   ├── fact-check-extraction/
│   │   └── SKILL.md                    # What is a testable claim, output schema, examples
│   ├── fact-check-classification/
│   │   └── SKILL.md                    # Domain definitions, tagging rules, cross-domain handling
│   └── fact-check-reporting/
│       └── SKILL.md                    # Report template, terminal summary, GitHub issue templates
└── README.md
```

The plugin is pure markdown — no scripts, no dependencies. All utility logic lives in a separate npm package.

## npm Package: @aaronbassett/midnight-fact-checker-utils

A single npm package with three subcommands, called via `npx`:

| Subcommand | Purpose | Example |
|------------|---------|---------|
| `discover` | Glob-based file discovery with .gitignore support | `npx @aaronbassett/midnight-fact-checker-utils discover "**/*.md"` |
| `extract-url` | Fetch URL(s), extract readable content, output Markdown | `npx @aaronbassett/midnight-fact-checker-utils extract-url https://example.com` |
| `merge` | Merge agent JSON copies with validation | `npx @aaronbassett/midnight-fact-checker-utils merge --mode update --original original.json -o merged.json copy1.json copy2.json` |

### discover

- Wraps `globby` v16 (85M weekly downloads, last release Mar 2026)
- Accepts a glob pattern, returns JSON with matched and unmatched files per directory
- Unmatched files include reason: `GLOB_MISS` or `GIT_IGNORED`
- Uses `isGitIgnored()` from globby for classification
- `--no-gitignore` flag to disable .gitignore filtering

### extract-url

- Wraps `@mozilla/readability` + `turndown` + `jsdom`
- Both libraries: 11K+ stars, active through Mar 2026
- Accepts one or more URLs
- Extracts readable content using Firefox Reader View algorithm (strips nav, headers, footers, ads, sidebars)
- Outputs clean Markdown
- No Puppeteer dependency

### merge

- No external dependencies (stdlib only)
- Two modes:
  - **Concat mode** (`--mode concat`): Combines multiple independent JSON arrays into one. Used in Stage 1 where each extractor produces distinct claims. Validation: output is valid JSON.
  - **Update mode** (`--mode update`, default): Merges updates to the same claim set by `id`. Used in Stages 2-3 where classifiers/verifiers update fields on existing claims. Validation: output is valid JSON and contains the same number of claims as the original.
- Accepts original JSON file + N agent-copy JSON files + output path
- Exits non-zero on validation failure

User grants permission once for `npx @aaronbassett/midnight-fact-checker-utils*` and all subcommands work.

### Package Location & Publishing

- Source lives at `./packages/midnight-fact-checker-utils/` in the project root (alongside `./plugins/` and `./docs/`)
- A dedicated GitHub Actions workflow (`.github/workflows/publish-fact-checker-utils.yml`) automates publishing to npm
- The workflow triggers on pushes to `main` that change files in `packages/midnight-fact-checker-utils/`
- It compares the `version` field in `package.json` against the latest published version on npm
- If the version has changed: run tests, build, and publish to npm with the `@aaronbassett` scope
- If the version has not changed: skip publishing
- Requires an `NPM_TOKEN` repository secret for authentication

## Command Flow: check.md

### Step 1: Preflight

- Check that the midnight-verify plugin directory exists at `plugins/midnight-verify/` relative to the project root
- Verify the key skill file exists: `plugins/midnight-verify/skills/verify-correctness/SKILL.md`
- If either check fails, abort with message: "midnight-verify plugin is required but not found. Install it before running fact-check."
- Fail fast — no point resolving inputs if verification can't happen

### Step 2: Initialize Run

- Generate run directory: `.midnight-expert/fact-checker/(mm)-(yy)/(run-short-name)-(unique-short-id)/`
  - `(mm)-(yy)`: current month and year (e.g., `03-26`)
  - `(run-short-name)`: short name describing the source content (e.g., `compact-core-plugin`)
  - `(unique-short-id)`: 3-5 character random alphanumeric string (e.g., `1t3We`)
  - Example: `.midnight-expert/fact-checker/03-26/compact-core-plugin-1t3We/`
- Write `run-metadata.json` (targets, timestamp, settings)

### Step 3: Resolve Inputs (Stage 0)

Parse `$ARGUMENTS` and classify each target:

| Input Type | Detection | Resolution |
|------------|-----------|------------|
| Local file | Path exists, is file | Read directly. PDFs >20 pages: chunk into page ranges. |
| Local directory | Path exists, is dir, no plugin.json | Run `discover` subcommand. Show file list, user confirms. |
| Plugin directory | Path contains `.claude-plugin/plugin.json` | Use plugin structure to scope: skills (SKILL.md + references/), commands, agents. Group by skill. |
| URL(s) | Starts with `http(s)://`, not GitHub | Run `extract-url` subcommand on each URL. Save Markdown to run dir. |
| GitHub file URL | Matches `github.com/.../blob/...` | `raw.githubusercontent.com` → wget. Otherwise → octocode MCP. Record repo info for issue creation. |
| GitHub dir/repo URL | Matches `github.com/.../tree/...` or bare repo URL | `git clone --depth=1` to `/tmp/`. Then treat as local directory. |
| Glob pattern | Contains `*`, `?`, `[`, or `{` | Run `discover` subcommand with user's pattern as-is. |

No file extension filtering — let the Read tool reject what it can't handle. Extraction agents skip unreadable content.

Show resolved file list to user for confirmation. Write `resolved-content.json`.

### Step 4: Extract Claims (Stage 1)

- Read `resolved-content.json`. Split content into chunks:
  - Plugin input → one chunk per skill (SKILL.md + references/)
  - Large single file → split by sections/headings or page ranges (PDF)
  - Multiple files → group by parent directory
  - Small inputs → single chunk, single agent
- Dispatch parallel `claim-extractor` agents (one per chunk)
- Each extractor reads its assigned content and returns extracted claims as JSON
- Run merge script to combine all extractor outputs
- Assign sequential IDs (`claim-001`, `claim-002`, ...)
- Write `extracted-claims.json`
- Print progress: `"Extracted N claims from M content chunks"`

### Step 5: Classify Claims (Stage 2)

- Read `extracted-claims.json`
- Create one copy per domain: `extracted-claims.compact-classifier.json`, etc.
- Dispatch parallel `domain-classifier` agents (one per domain: compact, sdk, zkir, witness)
- Each classifier reads its copy, tags claims belonging to its domain, writes updated copy, returns summary
- Run merge script to combine all copies. Validate.
- Write `classified-claims.json`
- Print progress: `"Classified N claims — compact: X, sdk: Y, zkir: Z, witness: W, cross-domain: V, unclassified: U"`
- Unclassified claims (tagged by no domain) are included in the report with verdict `inconclusive` and reason `"no-domain-match"`. They skip Stage 3 verification.

### Step 6: Verify Claims (Stage 3)

- Read `classified-claims.json`. Group by primary domain.
- Batching rules:
  - Target ~10-15 claims per batch
  - Domain with ≤15 claims → 1 batch
  - Domain with 16-30 claims → 2 batches
  - Domain with 30+ claims → split into batches of ~10
  - Cross-domain claims: batch separately
- Create copies of `classified-claims.json` for each batch agent
- Dispatch parallel `claim-verifier` agents. Each loads `midnight-verify:verify-correctness` skill and processes its batch sequentially.
- Each verifier writes updated copy with verdicts, returns summary
- Run merge script. Validate.
- Write `verification-results.json`
- Print progress: `"Verified N claims — confirmed: X, refuted: Y, inconclusive: Z"`

### Step 7: Generate Report (Stage 4)

- Load `fact-check-reporting` skill for templates
- Read `verification-results.json`
- Generate `report.md`:
  - Executive summary (verdict counts, run metadata)
  - Per-domain tables (verdict | qualifier | claim | evidence)
  - Refuted claims highlighted at top
- Print terminal summary: verdict counts + list of any refuted claims with one-line evidence
- Print run artifacts path

### Step 8: GitHub Issues (conditional)

- Only if source was GitHub-hosted AND there are refuted claims
- Ask user: `"Found N refuted claims across M files. Create issues per-claim, per-file, or a single summary?"`
- Create issues via `gh issue create` with appropriate template
- Print created issue URLs

## Agents

### claim-extractor

- **Model:** sonnet
- **Skills:** `fact-check-extraction`
- **Role:** Reads assigned content chunk. Extracts all testable claims as JSON. Returns claims to main thread.
- **Dispatched:** Stage 1, one per content chunk, in parallel.

### domain-classifier

- **Model:** sonnet
- **Skills:** `fact-check-classification`
- **Role:** Reads its copy of the claims file. Tags each claim with its assigned domain. Writes updated copy. Returns summary.
- **Dispatched:** Stage 2, one per domain (compact, sdk, zkir, witness), in parallel. Each instance receives its domain assignment in the dispatch prompt.

### claim-verifier

- **Model:** sonnet
- **Skills:** `midnight-verify:verify-correctness`
- **Role:** Receives a batch of pre-classified claims for a specific domain. Loads the `/verify` skill. Verifies each claim sequentially. Writes updated copy with verdicts. Returns summary.
- **Dispatched:** Stage 3, one per domain-batch, in parallel.

## Claim JSON Schema

### After Stage 1 (extracted-claims.json)

```json
{
  "id": "claim-001",
  "claim": "persistentHash<T>() returns Bytes<32>",
  "source": {
    "file": "skills/compact-language-ref/references/stdlib.md",
    "line_range": [42, 44],
    "context": "In the section on hashing functions..."
  },
  "extraction": {
    "agent_id": "extractor-3",
    "extracted_at": "2026-03-31T10:23:00Z"
  }
}
```

### After Stage 2 (classified-claims.json)

Adds domain classification fields:

```json
{
  "...": "...all Stage 1 fields...",
  "domains": ["compact"],
  "classification": {
    "primary_domain": "compact",
    "confidence": "high",
    "notes": "stdlib function claim, testable by execution"
  }
}
```

- `domains`: array — supports cross-domain claims (e.g., `["compact", "witness"]`)
- `classification.primary_domain`: determines which verification batch the claim enters

### After Stage 3 (verification-results.json)

Adds verification result fields:

```json
{
  "...": "...all Stage 2 fields...",
  "verification": {
    "verdict": "confirmed",
    "qualifier": "tested",
    "evidence_summary": "Contract compiled and executed. persistentHash returned Bytes<32> as expected.",
    "agent_id": "compact-verifier-1",
    "verified_at": "2026-03-31T10:45:00Z"
  }
}
```

Follows midnight-verify's existing verdict schema: `verdict` (confirmed | refuted | inconclusive), `qualifier` (tested | source-verified | type-checked | etc.), `evidence_summary`.

## Run Artifacts

All artifacts for a run are stored in:

```
.midnight-expert/fact-checker/(mm)-(yy)/(run-short-name)-(unique-short-id)/
├── run-metadata.json              # Targets, timestamp, settings
├── resolved-content.json          # Stage 0: resolved file list
├── extracted-claims.json          # Stage 1: raw claims
├── classified-claims.json         # Stage 2: domain-tagged claims
├── verification-results.json      # Stage 3: claims with verdicts
└── report.md                      # Stage 4: human-readable report
```

Agent working copies (e.g., `extracted-claims.compact-classifier.json`) are also preserved in the run directory for debugging.

## Error Handling

| Scenario | Behavior |
|----------|----------|
| midnight-verify not installed | Abort at preflight with install guidance. Fail fast. |
| No readable files found | Abort after Stage 0 with clear message. |
| User rejects file list | Abort cleanly. |
| Extractor agent fails | Other extractors complete. Report which chunks failed. Ask user to continue with partial claims or abort. |
| Zero claims extracted | Report and stop. Not an error — content may not contain verifiable claims. |
| Merge validation fails | All agent copies preserved. Report failure, point to copies for debugging. |
| Verifier agent fails | Other verifiers complete. Claims from failed batches marked as `inconclusive` with reason `"verification-agent-failed"`. |
| `gh` not authenticated | Skip issue creation, tell user to run `gh auth login`. |

## Dependencies

### Plugin Dependencies

- **midnight-verify** plugin — required for verification (preflight check)

### npm Package Dependencies

`@aaronbassett/midnight-fact-checker-utils`:
- `globby` v16 — file discovery with .gitignore support
- `@mozilla/readability` — content extraction (Reader View algorithm)
- `turndown` — HTML to Markdown conversion
- `jsdom` — DOM parsing for readability

### External Tools

- `git` — for cloning GitHub repos
- `wget` — for fetching raw.githubusercontent.com URLs
- `gh` — for creating GitHub issues (optional)
- `npx` — for running the utilities package
