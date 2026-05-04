---
name: midnight-status-codes:status-codes-lookup
description: >-
  Fast script-based lookup of Midnight error codes, status codes, and error
  types across all ecosystem components. Supports exact code lookup, regex
  search, source filtering, and category browsing. Use when you need to
  quickly identify what an error code means without reading full reference
  files.
---

# Midnight Status Code Lookup

A script-based tool for fast error code identification across the Midnight ecosystem.

## Script Location

```
${CLAUDE_SKILL_DIR}/scripts/lookup.sh
```

The script requires `jq` to be installed. It reads `codes.json` from the same directory.

## Modes

### Exact Code Lookup

Find a specific error by its code number, error name, or known alias:

```bash
bash ${CLAUDE_SKILL_DIR}/scripts/lookup.sh --code 166
bash ${CLAUDE_SKILL_DIR}/scripts/lookup.sh --code ContractRuntimeError
bash ${CLAUDE_SKILL_DIR}/scripts/lookup.sh --code "InvalidTransaction::Custom(166)"
```

Matching is case-insensitive. Searches across `code`, `name`, and `aliases` fields.

### Regex Search

Search across names, descriptions, aliases, codes, and categories using a regex pattern:

```bash
bash ${CLAUDE_SKILL_DIR}/scripts/lookup.sh --search "network.*id"
bash ${CLAUDE_SKILL_DIR}/scripts/lookup.sh --search "insufficient"
bash ${CLAUDE_SKILL_DIR}/scripts/lookup.sh --search "dust.*spend"
```

If 5 or fewer results match, each is shown in full detail. If more than 5 match, results are shown as a compact table.

### List by Source

List all error codes emitted by a specific component:

```bash
bash ${CLAUDE_SKILL_DIR}/scripts/lookup.sh --source midnight-node
bash ${CLAUDE_SKILL_DIR}/scripts/lookup.sh --source compact-compiler
```

Available sources: `compact-compiler`, `compact-js-sdk`, `dapp-connector`, `jsonrpc-2.0`, `midnight-indexer`, `midnight-js`, `midnight-node`, `midnight-wallet`, `partner-chains`, `proof-server`, `substrate`.

### List All Sources

Show all available sources with entry counts:

```bash
bash ${CLAUDE_SKILL_DIR}/scripts/lookup.sh --sources
```

### List by Category

List all error codes in a specific category:

```bash
bash ${CLAUDE_SKILL_DIR}/scripts/lookup.sh --category transaction-malformed
bash ${CLAUDE_SKILL_DIR}/scripts/lookup.sh --category deserialization
```

## Output Format

### Detailed Match (from `--code` or `--search` with ≤5 results)

```
=== MATCH: <source> / <code> ===
Code: <code>
Name: <name>
Source: <source>
Category: <group name>
Category Description: <group description>
Severity: <error|warning|info>
Description: <what this error means>
Fixes:
  - <actionable fix suggestion>
  - <another suggestion>
Aliases: <comma-separated alternative names>
See Also: <related codes>
===
```

### Compact Table (from `--source`, `--category`, or `--search` with >5 results)

```
=== SOURCE: <name> (<N> entries) ===
Code | Name | Category | Severity
---- | ---- | -------- | --------
166  | InvalidNetworkId | transaction-malformed | error
...
===
```

## Interpreting Results

- **Source** tells you which component emitted the error. This determines where to investigate.
- **Category** groups related errors. The **Category Description** explains what all errors in that group have in common.
- **Fixes** are ordered by likelihood -- try the first suggestion first.
- **Aliases** are alternative names the same error is known by in different contexts (e.g., the Rust path vs. the Substrate encoding).
- **See Also** points to related errors that often co-occur or share root causes.
- **Severity**: `error` = must be resolved, `warning` = should investigate, `info` = informational status.

## When to Use This vs. Reference Files

Use this lookup when you have a specific error code or message and need a quick answer. Use the `midnight-status-codes:status-codes` skill's reference files when you need deep context about an error category, want to understand the error hierarchy, or need to browse all errors from a component.
