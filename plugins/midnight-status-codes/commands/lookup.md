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
| `--status active\|retired\|all` | Global filter on entry `.status` (default: `all`). Use `active` to suppress retired umbrella entries when working on new code paths. |
| `--json` | Global flag — emit a JSON array of matched entries verbatim from `codes.json` instead of the `=== MATCH ===` text format. |

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

**Source name matching:** Match freeform names to canonical sources. The canonical source enum is fixed (see `--sources`). When a user names something that is not its own source — e.g. "ledger errors" or "zk codes" are surfaced *by* the node, compiler, runtime, and SDK rather than published as a standalone source — fall through to `--search` instead of inventing a source.

| Freeform | Route |
|----------|-------|
| node, midnight node, midnight-node | `--source midnight-node` |
| sdk, compact-js, compact js | `--source compact-js-sdk` |
| js, midnight-js, midnight js | `--source midnight-js` |
| wallet, midnight-wallet | `--source midnight-wallet` |
| compiler, compact compiler | `--source compact-compiler` |
| runtime, compact runtime, compact-runtime | `--source compact-runtime` |
| proof server, prover, proof-server | `--source proof-server` |
| indexer, midnight-indexer, graphql | `--source midnight-indexer` |
| dapp connector, lace, dapp-connector | `--source dapp-connector` |
| substrate | `--source substrate` |
| jsonrpc, json-rpc, jsonrpc-2.0 | `--source jsonrpc-2.0` |
| partner chains, partner-chains | `--source partner-chains` |
| zk, proof, zero knowledge, midnight-zk | `--search '(?i)\bzk\|zero[- ]?knowledge\|proof\b'` *(no standalone `midnight-zk` source — ZK codes live across compact-compiler, compact-js-sdk, midnight-node)* |
| ledger, midnight-ledger | `--search '(?i)ledger'` *(no standalone `midnight-ledger` source — ledger codes live in midnight-node, midnight-wallet, compact-compiler)* |

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
