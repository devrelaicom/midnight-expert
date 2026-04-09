# midnight-status-codes Plugin Design

**Date:** 2026-04-09
**Status:** Approved

## Overview

A new plugin (`midnight-status-codes`) that catalogs all error codes, status codes, and error types across the Midnight ecosystem. Provides two complementary access patterns: reference files for deep reading and a script-based lookup for fast answers.

## Problem

Agents encountering Midnight errors (e.g., "error 166" from a node) have no way to identify what the error means, what component produced it, or how to fix it. Error definitions are scattered across 15+ repositories in different languages (Rust, TypeScript, Scheme) with no unified catalog.

## Research Findings

10 parallel explore agents mined error codes from all Midnight repos. Key findings:

- **midnight-node**: The only source with structured numeric error codes — `LedgerApiError` maps to `u8` (0-255) and surfaces via Substrate's `InvalidTransaction::Custom(u8)`. ~95 assigned codes across well-defined ranges.
- **midnight-js, midnight-sdk, midnight-wallet**: Use semantic error types (TypeScript classes, Effect tagged errors) with no numeric codes. ~12 SDK classes, ~29 wallet error tags.
- **Compact compiler**: ~200+ diagnostic message templates organized by compiler phase. 4 exit codes (0, 1, 254, 255).
- **midnight-zk**: 5 error enums, all named variants, no numeric codes.
- **midnight-ledger**: Richest error taxonomy — 50+ `MalformedTransaction` variants, 17 `OnchainProgramError` variants, etc.
- **Proof server**: HTTP status mappings (400, 428, 429, 500, 503).
- **Indexer**: GraphQL Client/Server error split, HTTP status codes (200, 400, 413, 503).
- **DApp Connector**: 5 string error codes (`Disconnected`, `InternalError`, `InvalidRequest`, `PermissionRejected`, `Rejected`).
- **partner-chains**: 14 pallet dispatch errors, 17 fatal inherent errors.

The ecosystem uses a mix of numeric codes (node), string codes (DApp Connector), semantic types (SDK/wallet), and message patterns (compiler). The design must handle all of these.

## Approach: Multi-Key Lookup Catalog

The JSON catalog is keyed by multiple lookup strategies: numeric code, error tag/name, alias, and searchable description. Lookup accepts any of these. When multiple sources share the same code, all matches are returned.

## Plugin Structure

```
plugins/midnight-status-codes/
├── skills/
│   ├── status-codes/
│   │   ├── SKILL.md
│   │   └── references/
│   │       ├── node-errors.md
│   │       ├── sdk-errors.md
│   │       ├── wallet-errors.md
│   │       ├── compiler-errors.md
│   │       ├── zk-errors.md
│   │       ├── ledger-errors.md
│   │       ├── proof-server-errors.md
│   │       ├── indexer-errors.md
│   │       └── dapp-connector-errors.md
│   └── status-codes-lookup/
│       ├── SKILL.md
│       └── scripts/
│           ├── lookup.sh
│           └── codes.json
├── commands/
│   └── lookup.md
└── settings.json
```

### Skill: `status-codes`

**Purpose:** Routing skill. When an agent encounters an error, this skill directs it to the correct reference file(s) based on the error source or characteristics.

**SKILL.md contents:**
- Decision tree: "If the error is a numeric code 0-255 from a node → read `references/node-errors.md`"
- "If the error is a TypeScript class name ending in `Error` from `@midnight-ntwrk/midnight-js-*` → read `references/sdk-errors.md`"
- "If the error is a tagged Effect error with `_tag` like `Wallet.*` → read `references/wallet-errors.md`"
- "If the error is a compiler message with source location → read `references/compiler-errors.md`"
- "If the error mentions proof/PLONK/circuit → read `references/zk-errors.md`"
- "If the error mentions transaction validation/malformed → read `references/ledger-errors.md`"
- "If the error is an HTTP status from the proof server → read `references/proof-server-errors.md`"
- "If the error is from a GraphQL/indexer query → read `references/indexer-errors.md`"
- "If the error is a DApp Connector `APIError` → read `references/dapp-connector-errors.md`"
- "If unsure, use the `/midnight-status-codes:lookup` command for fast cross-source search"

**Trigger description:** "Use when an agent encounters a Midnight error code, error message, or error type and needs to identify what it means, what component produced it, and how to fix it."

### Skill: `status-codes-lookup`

**Purpose:** Script-based fast lookup. Contains instructions for calling `lookup.sh` and interpreting structured output.

**SKILL.md contents:**
- Script location: `${CLAUDE_SKILL_DIR}/scripts/lookup.sh`
- Script modes and flags
- Output format documentation
- Guidance on interpreting results and presenting them to users

### Reference Files

Each reference file is organized with:

1. **Source header** — what component emits these errors, when you'd encounter them
2. **Group summaries** — for well-organized code ranges (like the node's 0-11 deserialization range), a description of the group
3. **Error tables** — code, name, description, possible fixes

#### `node-errors.md`

The most structured file. Organized by code range:

| Section | Code Range | Description |
|---------|-----------|-------------|
| Deserialization Errors | 0-11 | Data that couldn't be deserialized from the wire format |
| Serialization Errors | 50-63 | Data that couldn't be serialized for storage or transmission |
| Transaction Invalid | 100-109, 193-200 | Transaction applied to state but rejected by ledger rules |
| Transaction Malformed | 110-139, 166-192 | Transaction structurally invalid before state application |
| Infrastructure | 150-165 | Node infrastructure errors (cache, state, fees) |
| System Transaction | 201-210 | Governance/bridge system transaction errors |
| Host API | 255 | Host API processing error |

Also includes:
- Pallet error table (pallet index + variant index → error name)
- JSON-RPC error codes (-32602, -32603)
- `InvalidTransaction` standard variants (`Call`, `ExhaustsResources`, `Custom(u8)`)

#### `sdk-errors.md`

Organized by package:
- `@midnight-ntwrk/compact-js`: `ContractConfigurationError`, `ContractRuntimeError`, `ZKConfigurationReadError`
- `@midnight-ntwrk/compact-js-command`: `ConfigError`, `ConfigCompilationError`
- `@midnight-ntwrk/midnight-js-contracts`: `TxFailedError` hierarchy (Deploy, Call, etc.), `ContractTypeError`
- `@midnight-ntwrk/midnight-js-types`: `PrivateStateImportError` hierarchy, `InvalidProtocolSchemeError`
- `@midnight-ntwrk/midnight-js-indexer-public-data-provider`: `IndexerFormattedError`
- Transaction status enums: `TxStatus`, `SegmentStatus`, `TransactionResultStatus`

#### `wallet-errors.md`

Organized by wallet package:
- Node client errors (7 tagged types: `SubmissionError`, `ConnectionError`, etc.)
- Shielded wallet errors (8 types)
- Unshielded wallet errors (11 types)
- Dust wallet errors (4 types)
- Capabilities errors (`ProvingError`, `SubmissionError`)
- Utilities errors (`LedgerError`, `URLError`, `ClientError`, `ServerError`)
- Pallet errors (auto-generated `augment-api-errors.ts`)

#### `compiler-errors.md`

Organized by compiler phase:
- Exit codes (0, 1, 254, 255)
- Lexer errors (6 templates)
- Parser errors (generic template + file I/O)
- Frontend pass errors (8 templates)
- Name resolution errors (~15 templates)
- Type checking errors (~80+ templates, grouped by sub-category)
- Circuit pass errors
- ZKIR generation errors
- TypeScript generation errors
- Runtime errors (`CompactError`, `assert`, `typeError`)

For the compiler, "possible fixes" are especially valuable since these are what developers hit most often.

#### `zk-errors.md`

- PLONK errors (13 variants including `Synthesis`, `NotEnoughRowsAvailable`, `SrsError`)
- Table errors (4 variants)
- Polynomial commitment errors (3 variants)
- ZKIR errors (7 variants + embedded `Other` messages)
- IVC errors (6 variants)
- MockProver `VerifyFailure` (6 variants)
- Error conversion chains

#### `ledger-errors.md`

- `MalformedTransaction` (50+ variants)
- `TransactionInvalid` (19 variants)
- `OnchainProgramError` (17 variants — the Impact VM)
- `TranscriptRejected` (5 variants)
- Zswap errors (`TransactionInvalid`, `MalformedOffer`, `OfferCreationFailed`)
- Merkle tree errors (`InvalidIndex`, `InvalidUpdate`)
- Fee calculation errors
- Dust state errors
- Transaction construction/proving errors

#### `proof-server-errors.md`

- Worker pool HTTP mappings (429, 428, 400, 500, 503)
- Work errors (`BadInput`, `InternalError`, `CancelledUnexpectedly`)
- Job status enum
- Health endpoint status

#### `indexer-errors.md`

- GraphQL client error messages (verbatim strings)
- HTTP status codes (200, 400, 413, 503)
- Address format errors (bech32m HRP validation)
- Chain indexer streaming errors
- Protocol version errors

#### `dapp-connector-errors.md`

- v4.0.x error codes (5 codes with semantic distinctions)
- v3.0.0 legacy codes (3 codes)
- `APIError` structure and detection pattern
- Transaction status types (`finalized`, `confirmed`, `pending`, `discarded`)

### JSON Catalog Schema (`codes.json`)

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
        "description": "Structural validity errors caught before applying the transaction to ledger state. These indicate the transaction itself is malformed — not that the ledger rejected it."
      },
      "description": "The transaction specifies a network ID that doesn't match the node's configured network.",
      "fixes": [
        "Verify your networkId matches the target network",
        "Check setNetworkId() is called with the correct value",
        "Ensure wallet and DApp are configured for the same network"
      ],
      "aliases": [
        "InvalidTransaction::Custom(166)",
        "MalformedTransaction::InvalidNetworkId"
      ],
      "severity": "error",
      "see_also": ["0", "151"]
    }
  ]
}
```

Fields:
- **code**: Primary lookup key. Numeric string for node codes, error name for semantic types.
- **name**: Human-readable error name.
- **source**: Component that emits this error (`midnight-node`, `compact-js-sdk`, `midnight-js`, `midnight-wallet`, `compact-compiler`, `midnight-zk`, `midnight-ledger`, `proof-server`, `midnight-indexer`, `dapp-connector`).
- **category**: Grouping key within the source.
- **group**: Object with `name` and `description` for the category this code belongs to.
- **description**: What this error means.
- **fixes**: Array of actionable fix suggestions.
- **aliases**: Alternative names/paths this error is known by (for cross-reference lookup).
- **severity**: `error`, `warning`, or `info`.
- **see_also**: Array of related code keys (optional).

### Lookup Script (`lookup.sh`)

Modes:

```bash
# Exact code lookup (numeric or string)
lookup.sh --code 166
lookup.sh --code ContractRuntimeError

# Regex search across name, description, aliases
lookup.sh --search "network.*id"

# List all codes for a source
lookup.sh --source midnight-node

# List all sources
lookup.sh --sources

# List all codes in a category
lookup.sh --category transaction-malformed
```

Implementation: `jq`-based filtering of `codes.json`. The script reads `codes.json` from the same directory (`$(dirname "$0")/codes.json`).

Output format (structured, parseable):

```
=== MATCH: midnight-node / 166 ===
Code: 166
Name: InvalidNetworkId
Source: midnight-node
Category: Transaction Malformed (110-139, 166-192)
Category Description: Structural validity errors caught before applying the transaction to ledger state.
Severity: error
Description: The transaction specifies a network ID that doesn't match the node's configured network.
Fixes:
  - Verify your networkId matches the target network
  - Check setNetworkId() is called with the correct value
  - Ensure wallet and DApp are configured for the same network
Aliases: InvalidTransaction::Custom(166), MalformedTransaction::InvalidNetworkId
See Also: 0 (NetworkId deserialization), 151 (NoLedgerState)
===
```

Multiple matches separated by `===` blocks. When `--source` or `--category` returns many results, output is a compact table:

```
=== SOURCE: midnight-node (95 codes) ===
Code | Name                    | Category            | Severity
0    | NetworkId               | deserialization     | error
1    | Transaction             | deserialization     | error
...
===
```

### Command (`lookup.md`)

Frontmatter:
```yaml
name: midnight-status-codes:lookup
description: Look up Midnight error codes, status codes, and error types across all components
allowed-tools: Bash, Skill
argument-hint: "<code|search|--source name|--category name|natural language query>"
```

The command:
1. Loads the `status-codes-lookup` skill
2. Parses `$ARGUMENTS` — detects structured flags (`--code`, `--source`, `--search`, `--category`) or interprets freeform natural language
3. Translates freeform to the appropriate flag:
   - Pure number → `--code <number>`
   - Known error name (PascalCase/camelCase ending in Error) → `--code <name>`
   - "show all codes from/returned by X" → `--source <x>`
   - "find/search errors about X" → `--search <pattern>`
   - Otherwise → `--search <keywords as regex>`
4. Runs the script
5. Presents results using the skill's formatting guidance

### Maintenance

The `codes.json` file is the single source of truth for the lookup script. Reference files are the single source of truth for deep reading. When new error codes are added to the Midnight ecosystem:

1. Add entries to `codes.json`
2. Update the relevant reference file
3. Both should stay in sync but serve different purposes (quick lookup vs. deep context)

### Plugin Settings (`settings.json`)

```json
{
  "name": "midnight-status-codes",
  "version": "0.1.0",
  "description": "Catalog and lookup for all Midnight ecosystem error codes, status codes, and error types"
}
```

No hooks or MCP servers required. The plugin is purely skill/command/script-based.

## Out of Scope

- Automatic detection/extraction of new error codes from upstream repos (future enhancement)
- Integration with the Compact compiler's error output format (future: could parse compiler stderr)
- Localization of error descriptions
