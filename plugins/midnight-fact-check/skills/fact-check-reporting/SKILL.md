---
name: midnight-fact-check:fact-check-reporting
description: >-
  This skill should be used when generating fact-check reports, formatting
  terminal summaries of verification results, or creating GitHub issues for
  refuted claims. Covers the markdown report template (executive summary,
  results by domain, refuted claims table), the terminal summary block,
  and GitHub issue templates (per-claim, per-file, and summary). Triggered
  by queries like "generate the fact-check report", "format verification
  results", "create a GitHub issue for refuted claims", or "what does the
  terminal summary look like". Used in Stage 4 of the midnight-fact-check
  pipeline to assemble final output from verification results.
version: 0.1.0
---

# Report Generation

## Placeholder Reference

| Placeholder | Source | Example |
|-------------|--------|---------|
| `[run-short-name]` | Run directory basename | `fast-run-core-concepts-qoMk` |
| `[timestamp]` | ISO 8601 timestamp from run metadata | `2026-04-02T12:00:00Z` |
| `[target descriptions]` | Comma-separated list of input file paths or skill names | `compact-core/skills/compact-tokens/SKILL.md` |
| `[full run directory path]` | Absolute path to run artifacts directory | `.midnight-expert/fact-checker/04-02/fast-run-...` |
| `[claim text]` | The `claim` field from the extracted claim object | `persistentHash returns Bytes<32>` |
| `[domain]` | The `primary_domain` from classification | `compact` |
| `[evidence_summary]` | The evidence summary from the verification result | `Compiled and executed — hash length is 32 bytes` |
| `[file:lines]` | Source file path and line range | `SKILL.md:42-44` |
| `[qualifier]` | Verification method used | `tested`, `source-inspected`, `type-checked` |
| `claim-XXX` | Sequential claim ID from the extraction order | `claim-001` |

## Truncation Rules

When truncating text for terminal or issue titles:
- Truncate at the last word boundary before the character limit
- Append `...` (the limit includes the ellipsis)
- Terminal claim text: 80 characters
- Terminal evidence: 100 characters
- Issue title claim text: 60 characters

## Edge Cases

- **Zero refuted claims**: Omit the "REFUTED CLAIMS" section from the terminal summary. The report still includes all domains.
- **Zero claims in a domain**: Omit that domain section from the report entirely.
- **Missing evidence summary**: Use `"No evidence collected"` as the fallback.
- **Zero total claims**: Report an empty summary table and note "No testable claims found in the provided content."

## Domains

The six domain categories used in reports:
- **Compact** — Compact language syntax, types, stdlib, compiler behavior
- **SDK** — TypeScript SDK packages, APIs, DApp development
- **ZKIR** — Zero-knowledge intermediate representation, circuit structure
- **Witness** — TypeScript witness implementations, type mappings
- **Cross-Domain** — Claims tagged by multiple domain classifiers
- **Unclassified** — Claims no domain classifier tagged (reported as inconclusive)

## Markdown Report Template (report.md)

Generate a report using this structure:

```markdown
# Fact-Check Report: [run-short-name]

**Date:** [timestamp]
**Source:** [target descriptions]
**Run ID:** [full run directory path]

## Executive Summary

| Verdict | Count |
|---------|-------|
| Confirmed | N |
| Refuted | N |
| Inconclusive | N |
| **Total** | **N** |

## Refuted Claims

_List refuted claims first — these are the actionable findings._

| # | Claim | Domain | Evidence |
|---|-------|--------|----------|
| claim-XXX | [claim text] | [domain] | [evidence_summary] |

## Results by Domain

### Compact (N claims)

| Verdict | Qualifier | Claim | Source | Evidence |
|---------|-----------|-------|--------|----------|
| Confirmed | tested | [claim] | [file:lines] | [evidence] |
| Refuted | tested | [claim] | [file:lines] | [evidence] |

### SDK (N claims)

[Same table format]

### ZKIR (N claims)

[Same table format]

### Witness (N claims)

[Same table format]

### Cross-Domain (N claims)

[Same table format]

### Unclassified (N claims)

[Claims that no domain classifier tagged — listed as inconclusive]
```

## Verdict Indicators

Use these badges in terminal output and issue titles:
- Confirmed → `[CONFIRMED]`
- Refuted → `[REFUTED]`
- Inconclusive → `[INCONCLUSIVE]`

## Terminal Summary Format

Print this to the terminal after writing the report:

```
═══════════════════════════════════════════
  Fact-Check Complete: [run-short-name]
═══════════════════════════════════════════

  Confirmed:    NN
  Refuted:      NN
  Inconclusive: NN
  ─────────────
  Total:        NN

  [If refuted > 0:]
  REFUTED CLAIMS:
    - [claim-XXX] [claim text (truncated to 80 chars)]
      Evidence: [evidence_summary (truncated to 100 chars)]
    - [claim-YYY] ...

  Artifacts: [full run directory path]
  Report:    [path to report.md]
═══════════════════════════════════════════
```

## GitHub Issue Templates

### Per-Claim Issue

```markdown
Title: [REFUTED] [claim text (truncated to 60 chars)]

Body:
## Refuted Claim

**Claim:** [full claim text]
**Source:** [file path, line range]
**Domain:** [domain]

## Verification Evidence

**Verdict:** Refuted ([qualifier])
**Evidence:** [full evidence_summary]

## Context

This claim was identified by the midnight-fact-check pipeline.
- **Run:** [run directory]
- **Source file:** [link to file if GitHub URL available]

---
_Generated by midnight-fact-check_
```

### Per-File Issue

```markdown
Title: Fact-check findings: [filename] ([N] refuted claims)

Body:
## Fact-Check Results for [full file path]

[N] claims were refuted in this file.

### Refuted Claims

- [ ] **[claim-XXX]:** [claim text]
  - Evidence: [evidence_summary]
  - Line(s): [line_range]

- [ ] **[claim-YYY]:** [claim text]
  - Evidence: [evidence_summary]
  - Line(s): [line_range]

## Run Details

- **Run:** [run directory]
- **Total claims checked:** [N]
- **Confirmed:** [N] | **Refuted:** [N] | **Inconclusive:** [N]

---
_Generated by midnight-fact-check_
```

### Summary Issue

```markdown
Title: Fact-check report: [N] refuted claims across [M] files

Body:
## Fact-Check Summary

| File | Refuted | Confirmed | Inconclusive |
|------|---------|-----------|--------------|
| [file1] | N | N | N |
| [file2] | N | N | N |

### All Refuted Claims

| # | File | Claim | Evidence |
|---|------|-------|----------|
| claim-XXX | [file] | [claim] | [evidence] |

## Run Details

- **Run:** [run directory]
- **Full report:** [path to report.md]

---
_Generated by midnight-fact-check_
```
