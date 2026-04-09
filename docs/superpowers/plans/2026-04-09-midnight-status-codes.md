# midnight-status-codes Plugin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a new plugin that catalogs all Midnight ecosystem error codes and provides both reference-file routing and script-based fast lookup across all error sources.

**Architecture:** Two skills (routing + lookup), one command, one shell script, one JSON catalog, and nine reference files. The routing skill directs agents to reference files; the lookup skill wraps a `jq`-based script that searches a unified JSON catalog. The command is a user-facing wrapper that translates natural language or structured flags into script calls.

**Tech Stack:** Bash/jq (lookup script), Markdown (skills, references, command), JSON (catalog)

**Spec:** `docs/superpowers/specs/2026-04-09-midnight-status-codes-design.md`

**Error data sources:** All error data was mined by 10 parallel explore agents from 15 cloned repos in `/tmp/midnight-error-mining/`. The agent results from the brainstorming conversation contain the exhaustive findings per repo. Use those results as the source of truth when writing reference files and JSON entries.

---

## File Map

| File | Purpose |
|------|---------|
| `plugins/midnight-status-codes/settings.json` | Plugin manifest |
| `plugins/midnight-status-codes/skills/status-codes/SKILL.md` | Routing skill — decision tree to reference files |
| `plugins/midnight-status-codes/skills/status-codes/references/node-errors.md` | Node LedgerApiError u8 codes, pallet errors, JSON-RPC |
| `plugins/midnight-status-codes/skills/status-codes/references/sdk-errors.md` | compact-js + midnight-js error classes |
| `plugins/midnight-status-codes/skills/status-codes/references/wallet-errors.md` | Wallet tagged Effect errors |
| `plugins/midnight-status-codes/skills/status-codes/references/compiler-errors.md` | Compact compiler diagnostics by phase |
| `plugins/midnight-status-codes/skills/status-codes/references/zk-errors.md` | PLONK, ZKIR, IVC, MockProver errors |
| `plugins/midnight-status-codes/skills/status-codes/references/ledger-errors.md` | Ledger validation, Zswap, Impact VM errors |
| `plugins/midnight-status-codes/skills/status-codes/references/proof-server-errors.md` | Proof server HTTP mappings, job errors |
| `plugins/midnight-status-codes/skills/status-codes/references/indexer-errors.md` | GraphQL errors, HTTP codes, address format errors |
| `plugins/midnight-status-codes/skills/status-codes/references/dapp-connector-errors.md` | DApp Connector API error codes |
| `plugins/midnight-status-codes/skills/status-codes-lookup/SKILL.md` | Lookup skill — script usage + output interpretation |
| `plugins/midnight-status-codes/skills/status-codes-lookup/scripts/lookup.sh` | Multi-mode jq-based lookup script |
| `plugins/midnight-status-codes/skills/status-codes-lookup/scripts/codes.json` | Unified JSON error catalog |
| `plugins/midnight-status-codes/commands/lookup.md` | Slash command wrapper |

---

### Task 1: Plugin Scaffold

Create the directory structure and plugin manifest.

**Files:**
- Create: `plugins/midnight-status-codes/settings.json`

- [ ] **Step 1: Create plugin directory and settings.json**

```bash
mkdir -p plugins/midnight-status-codes/{skills/{status-codes/references,status-codes-lookup/scripts},commands}
```

Write `plugins/midnight-status-codes/settings.json`:

```json
{
  "name": "midnight-status-codes",
  "version": "0.1.0",
  "description": "Catalog and lookup for all Midnight ecosystem error codes, status codes, and error types"
}
```

- [ ] **Step 2: Verify structure**

```bash
find plugins/midnight-status-codes -type d | sort
```

Expected output:
```
plugins/midnight-status-codes
plugins/midnight-status-codes/commands
plugins/midnight-status-codes/skills
plugins/midnight-status-codes/skills/status-codes
plugins/midnight-status-codes/skills/status-codes/references
plugins/midnight-status-codes/skills/status-codes-lookup
plugins/midnight-status-codes/skills/status-codes-lookup/scripts
```

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-status-codes/settings.json
git commit -m "feat(midnight-status-codes): scaffold plugin directory structure"
```

---

### Task 2: Lookup Script (`lookup.sh`)

The core script that searches `codes.json`. Write and test it against a small seed JSON before the full catalog exists.

**Files:**
- Create: `plugins/midnight-status-codes/skills/status-codes-lookup/scripts/lookup.sh`

- [ ] **Step 1: Create a minimal test `codes.json` with 3 entries**

Write `plugins/midnight-status-codes/skills/status-codes-lookup/scripts/codes.json`:

```json
{
  "version": "1.0.0",
  "generated": "2026-04-09",
  "entries": [
    {
      "code": "166",
      "name": "InvalidNetworkId",
      "source": "midnight-node",
      "category": "transaction-malformed",
      "group": {
        "name": "Transaction Malformed (110-139, 166-192)",
        "description": "Structural validity errors caught before applying the transaction to ledger state."
      },
      "description": "The transaction specifies a network ID that doesn't match the node's configured network.",
      "fixes": [
        "Verify your networkId matches the target network",
        "Check setNetworkId() is called with the correct value",
        "Ensure wallet and DApp are configured for the same network"
      ],
      "aliases": ["InvalidTransaction::Custom(166)", "MalformedTransaction::InvalidNetworkId"],
      "severity": "error",
      "see_also": ["0"]
    },
    {
      "code": "0",
      "name": "NetworkId",
      "source": "midnight-node",
      "category": "deserialization",
      "group": {
        "name": "Deserialization Errors (0-11)",
        "description": "Data that couldn't be deserialized from the wire format."
      },
      "description": "Failed to deserialize the network ID from the transaction payload.",
      "fixes": [
        "Ensure the transaction was serialized with a compatible SDK version",
        "Check that the network ID format matches the node's expected encoding"
      ],
      "aliases": ["Deserialization(NetworkId)"],
      "severity": "error",
      "see_also": ["166"]
    },
    {
      "code": "ContractRuntimeError",
      "name": "ContractRuntimeError",
      "source": "compact-js-sdk",
      "category": "contract-execution",
      "group": {
        "name": "Contract Execution Errors",
        "description": "Errors raised during contract constructor or circuit execution."
      },
      "description": "A general runtime error occurred while executing a constructor or circuit of an executable contract.",
      "fixes": [
        "Check the error message for specifics — it wraps the underlying cause",
        "Verify circuit arguments match the contract's expected types",
        "Ensure the contract state is valid before invoking circuits"
      ],
      "aliases": ["compact-js/effect/ContractRuntimeError"],
      "severity": "error",
      "see_also": []
    }
  ]
}
```

- [ ] **Step 2: Write `lookup.sh`**

Write `plugins/midnight-status-codes/skills/status-codes-lookup/scripts/lookup.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# lookup.sh — Multi-mode error code lookup for the Midnight ecosystem
#
# Usage:
#   lookup.sh --code <code>         Exact match on code, name, or aliases
#   lookup.sh --search <regex>      Regex search across name, description, aliases
#   lookup.sh --source <name>       List all codes for a source
#   lookup.sh --sources             List all available sources
#   lookup.sh --category <name>     List all codes in a category
#
# Reads codes.json from the same directory as this script.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CODES_FILE="${SCRIPT_DIR}/codes.json"

if [ ! -f "$CODES_FILE" ]; then
  echo "ERROR: codes.json not found at ${CODES_FILE}" >&2
  exit 1
fi

if ! command -v jq &>/dev/null; then
  echo "ERROR: jq is required but not installed" >&2
  exit 1
fi

MODE=""
QUERY=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --code)    MODE="code";     QUERY="$2"; shift 2 ;;
    --search)  MODE="search";   QUERY="$2"; shift 2 ;;
    --source)  MODE="source";   QUERY="$2"; shift 2 ;;
    --sources) MODE="sources";  shift ;;
    --category) MODE="category"; QUERY="$2"; shift 2 ;;
    *)
      echo "Unknown argument: $1" >&2
      echo "Usage: lookup.sh --code|--search|--source|--sources|--category <query>" >&2
      exit 1
      ;;
  esac
done

if [ -z "$MODE" ]; then
  echo "Usage: lookup.sh --code|--search|--source|--sources|--category <query>" >&2
  exit 1
fi

# Format a single entry as a detailed block
format_entry() {
  jq -r '
    "=== MATCH: \(.source) / \(.code) ===",
    "Code: \(.code)",
    "Name: \(.name)",
    "Source: \(.source)",
    "Category: \(.group.name)",
    "Category Description: \(.group.description)",
    "Severity: \(.severity)",
    "Description: \(.description)",
    (if (.fixes | length) > 0 then
      "Fixes:\n" + (.fixes | map("  - " + .) | join("\n"))
    else empty end),
    (if (.aliases | length) > 0 then
      "Aliases: " + (.aliases | join(", "))
    else empty end),
    (if (.see_also | length) > 0 then
      "See Also: " + (.see_also | join(", "))
    else empty end),
    "==="
  '
}

# Format entries as a compact table
format_table() {
  local header="$1"
  local count
  count=$(jq -r 'length')
  echo "=== ${header} (${count} entries) ==="
  echo "Code | Name | Category | Severity"
  echo "---- | ---- | -------- | --------"
  jq -r '.[] | "\(.code) | \(.name) | \(.category) | \(.severity)"'
  echo "==="
}

case "$MODE" in
  code)
    QUERY_LOWER=$(echo "$QUERY" | tr '[:upper:]' '[:lower:]')
    RESULTS=$(jq --arg q "$QUERY" --arg ql "$QUERY_LOWER" '
      .entries | map(select(
        (.code | ascii_downcase) == $ql or
        (.name | ascii_downcase) == $ql or
        (.aliases | map(ascii_downcase) | any(. == $ql))
      ))
    ' "$CODES_FILE")

    COUNT=$(echo "$RESULTS" | jq 'length')
    if [ "$COUNT" -eq 0 ]; then
      echo "No matches found for code: ${QUERY}"
      exit 0
    fi

    echo "$RESULTS" | jq -c '.[]' | while IFS= read -r entry; do
      echo "$entry" | format_entry
      echo ""
    done
    ;;

  search)
    RESULTS=$(jq --arg q "$QUERY" '
      .entries | map(select(
        (.name | test($q; "i")) or
        (.description | test($q; "i")) or
        (.aliases | any(test($q; "i"))) or
        (.code | test($q; "i")) or
        (.category | test($q; "i"))
      ))
    ' "$CODES_FILE")

    COUNT=$(echo "$RESULTS" | jq 'length')
    if [ "$COUNT" -eq 0 ]; then
      echo "No matches found for search: ${QUERY}"
      exit 0
    fi

    if [ "$COUNT" -le 5 ]; then
      echo "$RESULTS" | jq -c '.[]' | while IFS= read -r entry; do
        echo "$entry" | format_entry
        echo ""
      done
    else
      echo "$RESULTS" | format_table "SEARCH: ${QUERY}"
    fi
    ;;

  source)
    QUERY_LOWER=$(echo "$QUERY" | tr '[:upper:]' '[:lower:]')
    RESULTS=$(jq --arg q "$QUERY_LOWER" '
      .entries | map(select(
        (.source | ascii_downcase) == $q or
        (.source | ascii_downcase | test($q))
      ))
    ' "$CODES_FILE")

    COUNT=$(echo "$RESULTS" | jq 'length')
    if [ "$COUNT" -eq 0 ]; then
      echo "No entries found for source: ${QUERY}"
      echo ""
      echo "Available sources:"
      jq -r '.entries | map(.source) | unique | .[]' "$CODES_FILE"
      exit 0
    fi

    echo "$RESULTS" | format_table "SOURCE: ${QUERY}"
    ;;

  sources)
    echo "=== AVAILABLE SOURCES ==="
    jq -r '
      .entries | group_by(.source) | map({
        source: .[0].source,
        count: length
      }) | sort_by(.source) | .[] |
      "\(.source) (\(.count) entries)"
    ' "$CODES_FILE"
    echo "==="
    ;;

  category)
    QUERY_LOWER=$(echo "$QUERY" | tr '[:upper:]' '[:lower:]')
    RESULTS=$(jq --arg q "$QUERY_LOWER" '
      .entries | map(select(
        (.category | ascii_downcase) == $q or
        (.category | ascii_downcase | test($q))
      ))
    ' "$CODES_FILE")

    COUNT=$(echo "$RESULTS" | jq 'length')
    if [ "$COUNT" -eq 0 ]; then
      echo "No entries found for category: ${QUERY}"
      echo ""
      echo "Available categories:"
      jq -r '.entries | map(.category) | unique | sort | .[]' "$CODES_FILE"
      exit 0
    fi

    echo "$RESULTS" | format_table "CATEGORY: ${QUERY}"
    ;;
esac
```

- [ ] **Step 3: Make script executable**

```bash
chmod +x plugins/midnight-status-codes/skills/status-codes-lookup/scripts/lookup.sh
```

- [ ] **Step 4: Test all modes against seed data**

Run each mode and verify output:

```bash
SCRIPT=plugins/midnight-status-codes/skills/status-codes-lookup/scripts/lookup.sh

# Test --code (numeric)
$SCRIPT --code 166
# Expected: MATCH block with InvalidNetworkId

# Test --code (string, case-insensitive)
$SCRIPT --code contractruntimeerror
# Expected: MATCH block with ContractRuntimeError

# Test --code (alias match)
$SCRIPT --code "InvalidTransaction::Custom(166)"
# Expected: MATCH block with InvalidNetworkId

# Test --code (no match)
$SCRIPT --code 999
# Expected: "No matches found for code: 999"

# Test --search
$SCRIPT --search "network"
# Expected: Both NetworkId (code 0) and InvalidNetworkId (code 166)

# Test --source
$SCRIPT --source midnight-node
# Expected: Table with 2 entries

# Test --sources
$SCRIPT --sources
# Expected: compact-js-sdk (1 entries), midnight-node (2 entries)

# Test --category
$SCRIPT --category deserialization
# Expected: Table with 1 entry (code 0)
```

- [ ] **Step 5: Commit**

```bash
git add plugins/midnight-status-codes/skills/status-codes-lookup/scripts/
git commit -m "feat(midnight-status-codes): add lookup script with seed test data"
```

---

### Task 3: Lookup Skill (`status-codes-lookup/SKILL.md`)

**Files:**
- Create: `plugins/midnight-status-codes/skills/status-codes-lookup/SKILL.md`

- [ ] **Step 1: Write the lookup skill**

Write `plugins/midnight-status-codes/skills/status-codes-lookup/SKILL.md`:

```markdown
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

Available sources: `midnight-node`, `compact-js-sdk`, `midnight-js`, `midnight-wallet`, `compact-compiler`, `midnight-zk`, `midnight-ledger`, `proof-server`, `midnight-indexer`, `dapp-connector`.

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
- **Fixes** are ordered by likelihood — try the first suggestion first.
- **Aliases** are alternative names the same error is known by in different contexts (e.g., the Rust path vs. the Substrate encoding).
- **See Also** points to related errors that often co-occur or share root causes.
- **Severity**: `error` = must be resolved, `warning` = should investigate, `info` = informational status.

## When to Use This vs. Reference Files

Use this lookup when you have a specific error code or message and need a quick answer. Use the `midnight-status-codes:status-codes` skill's reference files when you need deep context about an error category, want to understand the error hierarchy, or need to browse all errors from a component.
```

- [ ] **Step 2: Commit**

```bash
git add plugins/midnight-status-codes/skills/status-codes-lookup/SKILL.md
git commit -m "feat(midnight-status-codes): add status-codes-lookup skill"
```

---

### Task 4: Routing Skill (`status-codes/SKILL.md`)

**Files:**
- Create: `plugins/midnight-status-codes/skills/status-codes/SKILL.md`

- [ ] **Step 1: Write the routing skill**

Write `plugins/midnight-status-codes/skills/status-codes/SKILL.md`:

```markdown
---
name: midnight-status-codes:status-codes
description: >-
  Use when an agent encounters a Midnight error code, error message, or
  error type and needs to identify what it means, what component produced
  it, and how to fix it. Routes to the correct reference file based on
  error source and characteristics. Covers numeric node error codes
  (0-255), TypeScript SDK error classes, Effect tagged wallet errors,
  Compact compiler diagnostics, ZK proof errors, ledger validation
  errors, proof server HTTP errors, indexer GraphQL errors, and DApp
  Connector API errors.
---

# Midnight Error Code Routing

When you encounter a Midnight error, use this decision tree to find the right reference file.

## Quick Lookup

For the fastest path, use the lookup command instead of reading reference files:

```
/midnight-status-codes:lookup <code-or-search-term>
```

## Decision Tree

### 1. Numeric code (0-255) from a node or transaction submission

→ Read `references/node-errors.md`

These are `LedgerApiError` codes that surface via Substrate's `InvalidTransaction::Custom(u8)`. The reference file has the complete code table organized by range.

**Recognise by:** A bare number in an error message from the Midnight node, transaction pool rejection, or `DispatchError::Module` output.

### 2. TypeScript error class from `@midnight-ntwrk/midnight-js-*`

→ Read `references/sdk-errors.md`

**Recognise by:** Error class names like `TxFailedError`, `DeployTxFailedError`, `CallTxFailedError`, `ContractTypeError`, `InvalidProtocolSchemeError`, `PrivateStateImportError`, `IndexerFormattedError`. These are standard JavaScript `Error` subclasses thrown by the midnight-js SDK packages.

### 3. Effect tagged error with `_tag` like `Wallet.*`

→ Read `references/wallet-errors.md`

**Recognise by:** Error objects with a `_tag` field matching patterns like `Wallet.Other`, `Wallet.InsufficientFunds`, `Wallet.Transacting`, `SubmissionError`, `ConnectionError`, `TransactionInvalidError`. These are Effect `Data.TaggedError` instances from the wallet SDK.

### 4. Effect typed error from `@midnight-ntwrk/compact-js`

→ Read `references/sdk-errors.md`

**Recognise by:** Error type names `ContractRuntimeError`, `ContractConfigurationError`, `ZKConfigurationReadError`, `ConfigError`, `ConfigCompilationError`, `ParseError`. These use `Symbol.for()` TypeIds and are part of the compact-js Effect error system.

### 5. Compact compiler message with source location

→ Read `references/compiler-errors.md`

**Recognise by:** Error messages with file path, line number, and character position (e.g., `/path/to/file.compact line 42 char 5:`). Also compiler exit codes (0, 1, 254, 255) and messages like "unbound identifier", "parse error: found X looking for Y", "potential witness-value disclosure".

### 6. ZK proof error mentioning PLONK, circuit, ZKIR, or verification

→ Read `references/zk-errors.md`

**Recognise by:** Error messages containing "Synthesis error", "constraint system", "NotEnoughRowsAvailable", "wrong arity", PLONK-related terms, or proof verification failures.

### 7. Transaction validation or malformed transaction error (Rust-level)

→ Read `references/ledger-errors.md`

**Recognise by:** Rust error names like `MalformedTransaction`, `TransactionInvalid`, `OnchainProgramError`, `TranscriptRejected`, `MalformedOffer`, or messages about binding commitments, sequencing checks, effects mismatches.

### 8. HTTP status code from the proof server

→ Read `references/proof-server-errors.md`

**Recognise by:** HTTP status codes (400, 428, 429, 500, 503) from requests to port 6300 or a proof server URL. Also job status messages like "job queue full" or "bad input".

### 9. GraphQL error or HTTP status from the indexer

→ Read `references/indexer-errors.md`

**Recognise by:** GraphQL error responses from port 8088 or an indexer URL. Messages like "invalid block hash", "invalid viewing key", "indexer has not yet caught up with the node". HTTP status codes 400, 413, 503 from the indexer API.

### 10. DApp Connector `APIError`

→ Read `references/dapp-connector-errors.md`

**Recognise by:** Error objects with `type: 'DAppConnectorAPIError'` and a `code` field matching `Disconnected`, `InternalError`, `InvalidRequest`, `PermissionRejected`, or `Rejected`.

### 11. Not sure which source

If the error doesn't clearly match any category above:

1. Try the lookup command: `/midnight-status-codes:lookup <error-text-or-code>`
2. Search by keyword: `/midnight-status-codes:lookup --search "<key-phrase>"`
3. If still not found, the error may be from a dependency (Substrate, Effect, Polkadot.js) rather than Midnight-specific code.
```

- [ ] **Step 2: Commit**

```bash
git add plugins/midnight-status-codes/skills/status-codes/SKILL.md
git commit -m "feat(midnight-status-codes): add status-codes routing skill"
```

---

### Task 5: Command (`lookup.md`)

**Files:**
- Create: `plugins/midnight-status-codes/commands/lookup.md`

- [ ] **Step 1: Write the command**

Write `plugins/midnight-status-codes/commands/lookup.md`:

```markdown
---
name: midnight-status-codes:lookup
description: Look up Midnight error codes, status codes, and error types across all components
allowed-tools: Bash, Skill
argument-hint: "<code|--code N|--search regex|--source name|--sources|--category name|natural language>"
---

Look up error codes, status codes, and error types across all Midnight ecosystem components.

## Step 1: Load Context

Read the `midnight-status-codes:status-codes-lookup` skill for script location and output format.

## Step 2: Parse Arguments

Parse `$ARGUMENTS` to determine the lookup mode. The script supports these flags:

| Flag | Purpose |
|------|---------|
| `--code <value>` | Exact match on code, name, or alias |
| `--search <regex>` | Regex search across all fields |
| `--source <name>` | List all codes from a source |
| `--sources` | List all available sources |
| `--category <name>` | List all codes in a category |

### Structured Input

If `$ARGUMENTS` contains a recognized flag (`--code`, `--search`, `--source`, `--sources`, `--category`), pass it through directly to the script.

### Freeform Input

If `$ARGUMENTS` does not contain a recognized flag, interpret it:

| Pattern | Interpretation |
|---------|---------------|
| Pure integer (e.g., `166`) | `--code 166` |
| PascalCase or camelCase name ending in `Error` (e.g., `ContractRuntimeError`) | `--code ContractRuntimeError` |
| Contains "from", "returned by", "emitted by", or "all codes" + a source name | `--source <matched-source>` |
| Contains "list sources" or "what sources" or "which components" | `--sources` |
| Contains "find", "search", "about", "related to", "involving" | `--search <extracted-keywords-as-regex>` |
| Anything else | `--search <arguments-as-regex>` |

**Source name matching:** Match freeform names to canonical source names:

| Freeform | Canonical Source |
|----------|-----------------|
| node, midnight node, midnight-node | `midnight-node` |
| sdk, compact-js, compact js | `compact-js-sdk` |
| js, midnight-js, midnight js | `midnight-js` |
| wallet, midnight-wallet | `midnight-wallet` |
| compiler, compact, compact compiler | `compact-compiler` |
| zk, proof, zero knowledge, midnight-zk | `midnight-zk` |
| ledger, midnight-ledger | `midnight-ledger` |
| proof server, prover, proof-server | `proof-server` |
| indexer, midnight-indexer, graphql | `midnight-indexer` |
| dapp connector, lace, dapp-connector | `dapp-connector` |

## Step 3: Execute Lookup

Run the script using the determined flags:

```bash
bash ${CLAUDE_SKILL_DIR}/../status-codes-lookup/scripts/lookup.sh <flags>
```

**Important:** The script path is relative to the `status-codes-lookup` skill directory, not this command's directory. Use the path shown in the `status-codes-lookup` skill.

## Step 4: Present Results

Present the script output directly to the user. The output is already formatted for readability.

For detailed match results (`=== MATCH ===` blocks):
- Present each match as-is — the format is designed for both human and agent consumption
- If there are multiple matches from different sources, note this explicitly

For table results (`=== SOURCE ===` or `=== CATEGORY ===` blocks):
- Present the table as-is
- If the user seems to want details on a specific entry, offer to look up that specific code

If no results are found:
- Suggest trying a broader search term
- Suggest checking `/midnight-status-codes:lookup --sources` to see available sources
- Note that the error may be from a non-Midnight dependency
```

- [ ] **Step 2: Commit**

```bash
git add plugins/midnight-status-codes/commands/lookup.md
git commit -m "feat(midnight-status-codes): add lookup slash command"
```

---

### Task 6: Reference File — Node Errors

The largest and most structured reference file. Contains all ~95 numeric `LedgerApiError` codes, pallet errors, and JSON-RPC codes.

**Files:**
- Create: `plugins/midnight-status-codes/skills/status-codes/references/node-errors.md`

- [ ] **Step 1: Write the node errors reference**

Write `plugins/midnight-status-codes/skills/status-codes/references/node-errors.md`.

**Content source:** The midnight-node agent results from the brainstorming session contain the exhaustive `LedgerApiError` code table (codes 0-255), pallet error table, and JSON-RPC error codes. Use those results as the source of truth.

The file must include:

1. **Source header:** Explain that these are `LedgerApiError` codes mapped to `u8`, surfaced via `InvalidTransaction::Custom(u8)` in Substrate transaction validation. Defined in `midnight-node/ledger/src/versions/common/types.rs`.

2. **Deserialization Errors (0-11):** Group description + table with all 12 codes. Each row: Code, Name, Description, Fixes.

3. **Serialization Errors (50-63):** Group description + table with all 14 codes.

4. **Transaction Invalid (100-109, 193-200):** Group description ("Transaction applied to state but rejected by ledger rules") + table with all 18 codes. Include descriptions like "EffectsMismatch — declared effects don't match computed effects" and fixes.

5. **Transaction Malformed (110-139, 166-192):** Group description ("Structural validity errors caught before state application") + table with all ~57 codes. This is the largest group. Include code 166 (InvalidNetworkId) with detailed fixes.

6. **Infrastructure (150-155, 165):** Group description + table with codes 150-155 and 165.

7. **System Transaction (201-210):** Group description + table with all 10 codes.

8. **Host API Error (255):** Single entry.

9. **Reserved Ranges:** Note that codes 12-49, 64-99, 140-149, 156-164, 211-254 are unassigned/reserved.

10. **Pallet Errors:** Table mapping pallet index + variant index to error name. Cover pallet indices 5, 6, 13, 44, 45, 50.

11. **JSON-RPC Errors:** Table with -32602 (INVALID_PARAMS) and -32603 (INTERNAL_ERROR) with contexts where each is used.

12. **Standard InvalidTransaction Variants:** `Custom(u8)`, `Call`, `ExhaustsResources` with descriptions.

- [ ] **Step 2: Commit**

```bash
git add plugins/midnight-status-codes/skills/status-codes/references/node-errors.md
git commit -m "feat(midnight-status-codes): add node errors reference (~95 codes)"
```

---

### Task 7: Reference File — SDK Errors

**Files:**
- Create: `plugins/midnight-status-codes/skills/status-codes/references/sdk-errors.md`

- [ ] **Step 1: Write the SDK errors reference**

**Content source:** The midnight-sdk and midnight-js agent results.

The file must include:

1. **Source header:** Covers `@midnight-ntwrk/compact-js`, `@midnight-ntwrk/compact-js-command`, `@midnight-ntwrk/platform-js`, `@midnight-ntwrk/midnight-js-contracts`, `@midnight-ntwrk/midnight-js-types`, `@midnight-ntwrk/midnight-js-indexer-public-data-provider`.

2. **compact-js Effect errors:** `ContractConfigurationError`, `ContractRuntimeError`, `ZKConfigurationReadError` (with TypeId symbols, fields, guard functions, known instantiation messages, fixes).

3. **compact-js-command errors:** `ConfigError`, `ConfigCompilationError`.

4. **platform-js errors:** `ParseError` (hex parsing).

5. **midnight-js-contracts errors:** `TxFailedError` hierarchy (5 subclasses), `ContractTypeError`, `IncompleteCallTxPrivateStateConfig`, `IncompleteFindContractPrivateStateConfig`. Include error class hierarchy diagram.

6. **midnight-js-types errors:** `PrivateStateImportError` hierarchy (3 subclasses), `InvalidProtocolSchemeError`, `PrivateStateExportError`, `SigningKeyExportError`.

7. **Indexer public data provider:** `IndexerFormattedError`.

8. **Transaction status enums:** `TxStatus` (`FailEntirely`, `FailFallible`, `SucceedEntirely`), `SegmentStatus`, `TransactionResultStatus`.

9. **compact-runtime errors:** `CompactError`, `assert`, `typeError`.

Each error entry must include: name, package, description, known messages, and fixes.

- [ ] **Step 2: Commit**

```bash
git add plugins/midnight-status-codes/skills/status-codes/references/sdk-errors.md
git commit -m "feat(midnight-status-codes): add SDK errors reference"
```

---

### Task 8: Reference File — Wallet Errors

**Files:**
- Create: `plugins/midnight-status-codes/skills/status-codes/references/wallet-errors.md`

- [ ] **Step 1: Write the wallet errors reference**

**Content source:** The midnight-wallet agent results.

Organize by package: node-client (7 types), shielded-wallet (8 types), unshielded-wallet (11 types), dust-wallet (4 types), capabilities (3 types), utilities (5 types), runtime (1 type), address-format errors, pallet errors from `augment-api-errors.ts`. Include the complete tag registry table at the end.

Each entry: tag name, fields, description, known messages, fixes.

- [ ] **Step 2: Commit**

```bash
git add plugins/midnight-status-codes/skills/status-codes/references/wallet-errors.md
git commit -m "feat(midnight-status-codes): add wallet errors reference"
```

---

### Task 9: Reference File — Compiler Errors

**Files:**
- Create: `plugins/midnight-status-codes/skills/status-codes/references/compiler-errors.md`

- [ ] **Step 1: Write the compiler errors reference**

**Content source:** The Compact compiler agent results.

Organize by phase: exit codes, lexer, parser, frontend passes, name resolution, type checking (sub-grouped by: type bounds, function calls, type compatibility, structs/enums/tuples, casts, witness/disclosure, ADT/ledger, purity/sealed), circuit passes, ZKIR generation, TypeScript generation, runtime errors.

For each error template: the message pattern, what triggers it, and specific fixes. The compiler errors reference is where "possible fixes" are most valuable — these are what developers hit constantly.

Focus on the ~30-40 most commonly encountered errors with detailed fixes. List remaining errors in compact tables.

- [ ] **Step 2: Commit**

```bash
git add plugins/midnight-status-codes/skills/status-codes/references/compiler-errors.md
git commit -m "feat(midnight-status-codes): add compiler errors reference"
```

---

### Task 10: Reference File — ZK Errors

**Files:**
- Create: `plugins/midnight-status-codes/skills/status-codes/references/zk-errors.md`

- [ ] **Step 1: Write the ZK errors reference**

**Content source:** The midnight-zk agent results.

Include: PLONK `Error` (13 variants), `TableError` (4 variants), polynomial commitment `Error` (3 variants), ZKIR `Error` (7 variants + `Other` messages), `IvcError` (6 variants), `VerifyFailure` (6 variants), `FailureLocation` (2 variants), `NotInFieldError`, inline `io::Error` messages, error conversion chains diagram.

- [ ] **Step 2: Commit**

```bash
git add plugins/midnight-status-codes/skills/status-codes/references/zk-errors.md
git commit -m "feat(midnight-status-codes): add ZK errors reference"
```

---

### Task 11: Reference File — Ledger Errors

**Files:**
- Create: `plugins/midnight-status-codes/skills/status-codes/references/ledger-errors.md`

- [ ] **Step 1: Write the ledger errors reference**

**Content source:** The midnight-ledger agent results.

Include: `MalformedTransaction` (50+ variants), `TransactionInvalid` (19 variants), `OnchainProgramError` (17 variants), `TranscriptRejected` (5 variants), `FeeCalculationError`, `MalformedContractDeploy`, `SequencingCheckError`, `DisjointCheckError`, `EffectsCheckError`, `TransactionApplicationError`, `QueryFailed`, `TransactionConstructionError`, `TransactionProvingError`, `PartitionFailure`, `EventReplayError`, `DustLocalStateError`, `DustStateError`, Zswap errors (`TransactionInvalid`, `MalformedOffer`, `OfferCreationFailed`), Merkle tree errors, `TransactionResult` enum.

Note the error hierarchy chain: `MalformedTransaction` → `zswap::MalformedOffer` → `TranscriptRejected` → `OnchainProgramError` → `InvalidBuiltinDecode`.

- [ ] **Step 2: Commit**

```bash
git add plugins/midnight-status-codes/skills/status-codes/references/ledger-errors.md
git commit -m "feat(midnight-status-codes): add ledger errors reference"
```

---

### Task 12: Reference File — Proof Server Errors

**Files:**
- Create: `plugins/midnight-status-codes/skills/status-codes/references/proof-server-errors.md`

- [ ] **Step 1: Write the proof server errors reference**

**Content source:** The midnight-ledger agent results (proof-server crate section).

Include: `WorkerPoolError` (4 variants with HTTP mappings: 429, 428, 400, 500), `WorkError` (4 variants with HTTP mappings), `JobStatus` enum, health endpoint `Status` (200, 503). This is a compact file.

- [ ] **Step 2: Commit**

```bash
git add plugins/midnight-status-codes/skills/status-codes/references/proof-server-errors.md
git commit -m "feat(midnight-status-codes): add proof server errors reference"
```

---

### Task 13: Reference File — Indexer Errors

**Files:**
- Create: `plugins/midnight-status-codes/skills/status-codes/references/indexer-errors.md`

- [ ] **Step 1: Write the indexer errors reference**

**Content source:** The midnight-indexer agent results.

Include: GraphQL client error messages (verbatim list), HTTP status codes (200, 400, 413, 503), `ApiError` Client/Server distinction, domain errors (`InvalidNetworkIdError`, `ProtocolVersionError`, `ledger::Error` 13 variants), address format errors, `SubxtNodeError` (22 variants), infrastructure errors (NATS, database, cipher).

- [ ] **Step 2: Commit**

```bash
git add plugins/midnight-status-codes/skills/status-codes/references/indexer-errors.md
git commit -m "feat(midnight-status-codes): add indexer errors reference"
```

---

### Task 14: Reference File — DApp Connector Errors

**Files:**
- Create: `plugins/midnight-status-codes/skills/status-codes/references/dapp-connector-errors.md`

- [ ] **Step 1: Write the DApp Connector errors reference**

**Content source:** The midnight-docs agent results (Section 1).

Include: v4.0.x error codes (5 codes with semantic distinctions between `Rejected` and `PermissionRejected`), v3.0.0 legacy codes (3 codes), `APIError` type structure and detection pattern (`error.type === 'DAppConnectorAPIError'`, not `instanceof`), transaction status types. This is a compact file.

- [ ] **Step 2: Commit**

```bash
git add plugins/midnight-status-codes/skills/status-codes/references/dapp-connector-errors.md
git commit -m "feat(midnight-status-codes): add DApp Connector errors reference"
```

---

### Task 15: Full JSON Catalog (`codes.json`)

Replace the seed data with the complete catalog. This is the largest single task — every error that should be quickly lookupable needs an entry.

**Files:**
- Modify: `plugins/midnight-status-codes/skills/status-codes-lookup/scripts/codes.json`

- [ ] **Step 1: Write the full catalog**

Replace the seed `codes.json` with the complete catalog. Prioritize entries that agents are most likely to look up:

**Must include (high-priority):**
- All ~95 node `LedgerApiError` codes (0-255 assigned range)
- All 5 DApp Connector error codes
- All SDK error classes (~12 from midnight-js + ~7 from compact-js)
- All wallet error tags (~29)
- Proof server HTTP codes (5 entries)
- Indexer HTTP codes (4 entries)
- JSON-RPC codes (2 entries)
- Compiler exit codes (4 entries)
- Pallet dispatch errors (~35 from midnight-node, ~14 from partner-chains)
- `InvalidTransaction` standard variants (3 entries)

**Should include (medium-priority):**
- Most common compiler diagnostic patterns (~20-30 most frequent)
- ZK error variants (~40 across all enums)
- Ledger error variants (~20 most commonly surfaced)
- Impact VM errors (17 `OnchainProgramError` variants)

**Nice to have (lower-priority, add if feasible):**
- Full compiler diagnostic catalog (200+ entries would bloat the JSON)
- Internal infrastructure errors (NATS, database, etc.)

Each entry follows the schema from the spec. Use the agent mining results as the data source.

- [ ] **Step 2: Validate JSON**

```bash
jq '.' plugins/midnight-status-codes/skills/status-codes-lookup/scripts/codes.json > /dev/null && echo "Valid JSON"
jq '.entries | length' plugins/midnight-status-codes/skills/status-codes-lookup/scripts/codes.json
# Expected: 200+ entries
```

- [ ] **Step 3: Verify no duplicate codes within same source**

```bash
jq '
  .entries | group_by(.source) | .[] |
  {source: .[0].source, dupes: (group_by(.code) | map(select(length > 1)) | map(.[0].code))} |
  select(.dupes | length > 0)
' plugins/midnight-status-codes/skills/status-codes-lookup/scripts/codes.json
# Expected: no output (no duplicates within a source)
```

- [ ] **Step 4: Test lookup against full catalog**

```bash
SCRIPT=plugins/midnight-status-codes/skills/status-codes-lookup/scripts/lookup.sh

# Test the original error 166 that started this project
$SCRIPT --code 166

# Test a wallet tag
$SCRIPT --code "Wallet.InsufficientFunds"

# Test a DApp Connector code
$SCRIPT --code Rejected

# Test cross-source search
$SCRIPT --search "insufficient"

# Test source listing
$SCRIPT --sources
```

- [ ] **Step 5: Commit**

```bash
git add plugins/midnight-status-codes/skills/status-codes-lookup/scripts/codes.json
git commit -m "feat(midnight-status-codes): populate full error code catalog"
```

---

### Task 16: Final Verification

End-to-end test of the complete plugin.

- [ ] **Step 1: Verify all files exist**

```bash
find plugins/midnight-status-codes -type f | sort
```

Expected:
```
plugins/midnight-status-codes/commands/lookup.md
plugins/midnight-status-codes/settings.json
plugins/midnight-status-codes/skills/status-codes-lookup/SKILL.md
plugins/midnight-status-codes/skills/status-codes-lookup/scripts/codes.json
plugins/midnight-status-codes/skills/status-codes-lookup/scripts/lookup.sh
plugins/midnight-status-codes/skills/status-codes/SKILL.md
plugins/midnight-status-codes/skills/status-codes/references/compiler-errors.md
plugins/midnight-status-codes/skills/status-codes/references/dapp-connector-errors.md
plugins/midnight-status-codes/skills/status-codes/references/indexer-errors.md
plugins/midnight-status-codes/skills/status-codes/references/ledger-errors.md
plugins/midnight-status-codes/skills/status-codes/references/node-errors.md
plugins/midnight-status-codes/skills/status-codes/references/proof-server-errors.md
plugins/midnight-status-codes/skills/status-codes/references/sdk-errors.md
plugins/midnight-status-codes/skills/status-codes/references/wallet-errors.md
plugins/midnight-status-codes/skills/status-codes/references/zk-errors.md
```

- [ ] **Step 2: Test the scenario that started this project**

Simulate the original problem: an agent encountering "error 166" from a node.

```bash
# The fast path — slash command
plugins/midnight-status-codes/skills/status-codes-lookup/scripts/lookup.sh --code 166
```

Verify the output includes:
- Source: midnight-node
- Name: InvalidNetworkId
- Category: Transaction Malformed
- Meaningful description and fixes

- [ ] **Step 3: Test cross-source collision scenario**

If any codes exist in multiple sources, verify the script returns all matches:

```bash
# "ConnectionError" might appear in both wallet and node-client contexts
plugins/midnight-status-codes/skills/status-codes-lookup/scripts/lookup.sh --search "ConnectionError"
```

- [ ] **Step 4: Verify routing skill references resolve**

Check that every reference file mentioned in the routing skill's decision tree exists:

```bash
for ref in node-errors sdk-errors wallet-errors compiler-errors zk-errors ledger-errors proof-server-errors indexer-errors dapp-connector-errors; do
  if [ -f "plugins/midnight-status-codes/skills/status-codes/references/${ref}.md" ]; then
    echo "OK: ${ref}.md"
  else
    echo "MISSING: ${ref}.md"
  fi
done
```

Expected: all OK.
