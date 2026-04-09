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
| compiler, compact compiler | `compact-compiler` |
| zk, proof, zero knowledge, midnight-zk | `midnight-zk` |
| ledger, midnight-ledger | `midnight-ledger` |
| proof server, prover, proof-server | `proof-server` |
| indexer, midnight-indexer, graphql | `midnight-indexer` |
| dapp connector, lace, dapp-connector | `dapp-connector` |

## Step 3: Execute Lookup

Run the script using the determined flags:

```bash
bash <skill-dir>/scripts/lookup.sh <flags>
```

To get the script path, read the `midnight-status-codes:status-codes-lookup` skill which documents the `${CLAUDE_SKILL_DIR}/scripts/lookup.sh` path.

## Step 4: Present Results

Present the script output directly to the user. The output is already formatted for readability.

For detailed match results (`=== MATCH ===` blocks):
- Present each match as-is -- the format is designed for both human and agent consumption
- If there are multiple matches from different sources, note this explicitly

For table results (`=== SOURCE ===` or `=== CATEGORY ===` blocks):
- Present the table as-is
- If the user seems to want details on a specific entry, offer to look up that specific code

If no results are found:
- Suggest trying a broader search term
- Suggest checking `/midnight-status-codes:lookup --sources` to see available sources
- Note that the error may be from a non-Midnight dependency
