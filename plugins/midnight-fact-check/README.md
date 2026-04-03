# midnight-fact-check

<p align="center">
  <img src="assets/mascot.png" alt="midnight-fact-check mascot" width="200" />
</p>

Fact-checking pipeline for Midnight content -- extracts testable claims from any source (markdown, code, PDFs, URLs, GitHub repos), classifies them by domain (Compact, SDK, ZKIR, Witness), and verifies each claim using the midnight-verify framework. Produces structured JSON artifacts and human-readable reports.

## Skills

### midnight-fact-check:fact-check-extraction

Defines what constitutes a testable claim in Midnight content and how to extract them. Covers identification of verifiable statements about Compact syntax, types, APIs, compiler behavior, and runtime errors, with a JSON output schema for structured claim lists.

### midnight-fact-check:fact-check-classification

Defines the four verification domains (Compact, SDK, ZKIR, Witness) and how to tag claims with their domain. Covers domain boundaries, classification confidence, cross-domain claims, and boundary case resolution.

### midnight-fact-check:fact-check-reporting

Defines the markdown report template, terminal summary format, and GitHub issue templates for fact-check results. Covers executive summaries, per-domain result tables, refuted claim details, and issue creation for per-claim, per-file, and summary reports.

## Commands

### midnight-fact-check:check

Fact-check content against the Midnight ecosystem through a full staged pipeline: extract claims, classify by domain, verify via midnight-verify, and produce a report.

#### Output

A markdown report with an executive summary, results grouped by domain, and a detailed table of refuted claims. Also produces structured JSON artifacts (extracted claims, classified claims, verification results) in a timestamped run directory.

#### Invokes

- midnight-fact-check:fact-check-extraction (skill, via claim-extractor agent)
- midnight-fact-check:fact-check-classification (skill, via domain-classifier agent)
- midnight-fact-check:fact-check-reporting (skill)
- midnight-verify:verify-correctness (skill, from midnight-verify plugin)

### midnight-fact-check:fast-check

Fast fact-check content against the Midnight ecosystem using a streamlined pipeline that skips domain classification and execution-based verification, relying on source inspection only.

#### Output

A markdown report with verification results and a terminal summary. Faster and cheaper than the full check command but may miss claims that require compilation or execution to verify.

#### Invokes

- midnight-fact-check:fact-check-extraction (skill, via claim-extractor agent)
- midnight-fact-check:fact-check-reporting (skill)
- midnight-verify:verify-correctness (skill, from midnight-verify plugin)

## Agents

### claim-extractor

Extracts testable claims from a chunk of Midnight-related content. Reads assigned content files, identifies all verifiable statements, and returns them as a structured JSON array.

#### When to use

Dispatched by the /midnight-fact-check:check command in Stage 1, one instance per content chunk, running in parallel.

### domain-classifier

Classifies extracted claims by verification domain (compact, sdk, zkir, or witness). Reads the claims file, tags claims belonging to its assigned domain, and writes the updated file.

#### When to use

Dispatched by the /midnight-fact-check:check command in Stage 2, one instance per domain, running in parallel.
