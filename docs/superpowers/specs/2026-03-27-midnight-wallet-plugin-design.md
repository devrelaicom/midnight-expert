# Midnight Wallet Plugin — Design Spec

**Date:** 2026-03-27
**Scope:** New `plugins/midnight-wallet/` plugin + cleanup of `plugins/midnight-tooling/`

## Summary

Create a new `midnight-wallet` plugin that wraps the `midnight-wallet-cli` npm package's MCP server, providing wallet management, token operations, and test wallet workflows for Midnight development. Replace the existing `funding` skill in `midnight-tooling` with this dedicated plugin. The plugin includes an alias system for test wallet nicknames, orchestrated setup commands, and hooks for common error prevention.

## Background

The `midnight-wallet-cli` npm package (v0.2.5) provides:
- CLI wallet for the Midnight blockchain (`midnight` / `mn` commands)
- MCP server (`midnight-wallet-mcp`) exposing 25 typed tools over JSON-RPC stdio
- Support for 3 networks: `undeployed` (local devnet), `preprod`, `preview`
- Wallet generation with BIP-39 mnemonics, HD key derivation
- Balance checking, transfers, airdrop (devnet only), dust registration
- DApp connector (WebSocket JSON-RPC server)
- Docker-based local network management (`localnet` commands)

The MCP server is the integration point — no global install needed, no PATH pollution, typed tools instead of shell parsing.

### Relationship to midnight-tooling

The `midnight-tooling` plugin manages the development toolchain (Compact CLI, devnet, proof server). This wallet plugin handles all wallet/funding/token operations and defers to `midnight-tooling`'s devnet skill for network lifecycle management.

The existing `funding` skill in `midnight-tooling` is superseded by this plugin and will be removed.

### Localnet conflict

The wallet-cli has its own `midnight localnet up/down/stop` commands that manage Docker containers with different container names (`node`, `indexer`, `proof-server`) than our devnet skill (`midnight-node`, `midnight-indexer`, `midnight-proof-server`). These must NOT be used when the devnet is managed by the `midnight-tooling` devnet skill — same ports, different compose files. The wallet-cli's auto-detection (image-name based `docker ps` parsing) works with either setup, so wallet operations are compatible regardless of who started the devnet.

---

## Plugin Structure

```
plugins/midnight-wallet/
├── .claude-plugin/
│   └── plugin.json
├── .mcp.json
├── skills/
│   ├── wallet-cli/
│   │   ├── SKILL.md
│   │   └── references/
│   │       ├── mcp-tools.md
│   │       ├── wallet-management.md
│   │       ├── transactions.md
│   │       ├── devnet-integration.md
│   │       └── troubleshooting.md
│   └── setup-test-wallets/
│       ├── SKILL.md
│       └── scripts/
│           └── wallet-aliases.sh
├── commands/
│   └── fund-mnemonic.md
└── hooks/
    ├── pre-tool-use-devnet-check.md
    ├── pre-tool-use-nickname-resolution.md
    ├── pre-tool-use-airdrop-network-check.md
    ├── pre-tool-use-transfer-self-check.md
    ├── post-tool-use-transfer-failure.md
    └── session-start-wallet-health.md
```

---

## MCP Server Configuration

`.mcp.json` at plugin root:

```json
{
  "mcpServers": {
    "midnight-wallet": {
      "command": "npx",
      "args": ["-y", "-p", "midnight-wallet-cli@latest", "midnight-wallet-mcp"]
    }
  }
}
```

No global install. Uses `npx` to run the MCP server binary from the package on demand.

---

## Skills

### wallet-cli/SKILL.md

Main skill documenting the MCP tools and common workflows.

**Description** should match: "wallet CLI", "midnight wallet", "wallet balance", "NIGHT tokens", "DUST tokens", "transfer NIGHT", "fund account", "test wallets", "wallet setup", "dust registration", "airdrop", "genesis address", "wallet generate", "BIP-39 mnemonic", "midnight-wallet-cli", "midnight-wallet-mcp", "MCP wallet tools", "wallet address", "check balance".

**Body structure:**

1. **Terminology** — NIGHT (native token, 6 decimals), DUST (fee token, 15 decimals, requires registration), genesis wallet (seed `0x00...01`, devnet funding source), wallet aliases (#name → address lookup)
2. **Common Workflows** — set up test wallets, transfer between wallets, fund existing address, check wallet statuses, restore from mnemonic
3. **Wallet Nicknames** — `#name` syntax resolves from alias file via `wallet-aliases.sh`, project-local then global search order
4. **Quick MCP Tool Reference** — table of all 25 tools with one-line descriptions
5. **Reference Files** — index pointing to detailed references

**Common Workflows section:**

```markdown
### Set up test wallets
> /setup-test-wallets alice bob charlie
Generates 3 wallets, airdrops NIGHT, registers dust, saves aliases.

### Transfer between test wallets
> Transfer 10 NIGHT from #alice to #bob
Agent resolves nicknames from alias file, calls midnight_transfer.

### Fund an existing address
> /setup-test-wallets myapp mn_addr_undeployed1...
Saves alias, airdrops, registers dust.

### Check all wallet statuses
> How are my test wallets doing?
Agent reads alias file, calls midnight_balance and midnight_dust_status for each.

### Restore wallet from mnemonic
> /fund-mnemonic alice "word1 word2 ... word24"
Derives wallet, hands off to /setup-test-wallets with the generated address.
```

### wallet-cli/references/

**mcp-tools.md** — All 25 MCP tools with parameter schemas and example responses:

| Tool | Description |
|------|-------------|
| `midnight_wallet_generate` | Create a named wallet |
| `midnight_wallet_list` | List all wallets |
| `midnight_wallet_use` | Set active wallet |
| `midnight_wallet_info` | Show wallet details |
| `midnight_wallet_remove` | Remove a wallet |
| `midnight_generate` | Generate a wallet (deprecated — use midnight_wallet_generate) |
| `midnight_info` | Show wallet info (no secrets) |
| `midnight_balance` | Check NIGHT balance |
| `midnight_address` | Derive address from seed |
| `midnight_genesis_address` | Show genesis wallet address |
| `midnight_inspect_cost` | Show block cost limits |
| `midnight_airdrop` | Fund wallet from genesis (undeployed only) |
| `midnight_transfer` | Send NIGHT tokens |
| `midnight_dust_register` | Register UTXOs for dust generation |
| `midnight_dust_status` | Check dust registration status |
| `midnight_config_get` | Read config value |
| `midnight_config_set` | Write config value |
| `midnight_config_unset` | Remove config value |
| `midnight_cache_clear` | Clear wallet state cache |
| `midnight_localnet_up` | Start local network (DO NOT USE — use /devnet start instead) |
| `midnight_localnet_stop` | Stop local network (DO NOT USE — use /devnet stop instead) |
| `midnight_localnet_down` | Remove local network (DO NOT USE — use /devnet stop instead) |
| `midnight_localnet_status` | Show service status (safe to use as read-only check) |
| `midnight_localnet_clean` | Remove conflicting containers (DO NOT USE without user confirmation) |

The `midnight_localnet_*` tools (except `status`) must include explicit warnings that they conflict with the `midnight-tooling` devnet skill and should not be used when the devnet is managed by `/devnet`.

**wallet-management.md** — Generate, list, use, remove, info. Wallet file structure (`~/.midnight/wallets/<name>.json`). BIP-39 mnemonic generation (256-bit / 24 words). HD derivation path (Account 0 → NightExternal role → key index). Multi-network addressing (one seed → addresses for all 3 networks). File permissions (dirs 0700, files 0600).

**transactions.md** — Balance checking (GraphQL subscription to indexer), transfers (requires dust), airdrop (undeployed only, from genesis seed `0x00...01`), dust registration and status. NIGHT has 6 decimal places, DUST has 15. JSON output mode (`--json` flag on all tools). Error codes: INVALID_ARGS, WALLET_NOT_FOUND, NETWORK_ERROR, INSUFFICIENT_BALANCE, TX_REJECTED, STALE_UTXO, PROOF_TIMEOUT, DUST_REQUIRED, CANCELLED.

**devnet-integration.md** — How wallet-cli auto-detects running devnet (image-name based `docker ps` parsing). Port mapping (9944, 8088, 6300). Why `midnight localnet` commands must not be used (different container names, different compose file, port conflicts). The `undeployed` network ID. Config overrides (`midnight_config_set` for custom endpoints).

**troubleshooting.md** — Exit codes (0=success, 1=unknown, 2=invalid args, 3=wallet not found, 4=network error, 5=insufficient balance, 6=tx rejected/stale UTXO/proof timeout, 7=cancelled). Common errors and fixes. Network issues section pointing to `midnight-tooling` devnet skill (`/devnet status`, `/devnet health`, `/devnet logs`, `/devnet restart`).

### setup-test-wallets/SKILL.md

Orchestrated skill for creating and funding test wallets.

**Description** should match: "setup test wallets", "create test accounts", "generate test wallets", "alice bob charlie", "fund test accounts", "test wallet setup", "development wallets".

**Input handling:**

| Input | Behavior |
|-------|----------|
| (nothing) | Random name from wordlist, generate new wallet, fund, register dust, save alias |
| `alice` | Check alias file for "alice" → if found, use existing; if not, generate new wallet |
| `mn_addr_undeployed1...` | Reverse lookup → if alias found, use that name; if not, assign random name |
| `alice mn_addr_undeployed1...` | Use as-is, save alias |
| `alice bob charlie` | Process each name (batch mode) |

**Flow for each wallet:**
1. Resolve name/address (generate if needed via `midnight_wallet_generate`)
2. Fund via `midnight_airdrop` (if on undeployed network)
3. Register dust via `midnight_dust_register`
4. Save alias via `wallet-aliases.sh set`

**Security warning** in SKILL.md:
> **WARNING:** Wallet aliases store public addresses only, not private keys or seeds. However, the test wallets themselves (in `~/.midnight/wallets/`) contain seeds. This system is for local development and testing only. Never use test wallets for real funds.

### setup-test-wallets/scripts/wallet-aliases.sh

Handles all alias file I/O using `jq`.

**Usage:**

```
wallet-aliases.sh get <name> [--network <net>] [--file <path>]
wallet-aliases.sh reverse <address> [--file <path>]
wallet-aliases.sh set <name> --network <net> --address <addr> [--file <path>] [--global]
wallet-aliases.sh set <name> --addresses '{"undeployed":"...","preprod":"..."}' [--file <path>] [--global]
wallet-aliases.sh list [--file <path>]
wallet-aliases.sh remove <name> [--file <path>]
wallet-aliases.sh path [--global]
```

**Search order (get/reverse):**
1. `--file <path>` if provided (only this file)
2. `.claude/midnight-wallet/wallets.local.json` (project-local)
3. `~/.claude/midnight-wallet/wallets.json` (global)

**Write destination:**
- Project-local by default (`.claude/midnight-wallet/wallets.local.json`)
- Global with `--global` flag (`~/.claude/midnight-wallet/wallets.json`)
- Custom with `--file <path>`

**File format:**
```json
{
  "_warning": "Test wallet addresses only. Do NOT store secrets here.",
  "wallets": {
    "alice": {
      "undeployed": "mn_addr_undeployed1abc...",
      "preprod": "mn_addr_preprod1abc...",
      "preview": "mn_addr_preview1abc..."
    }
  }
}
```

**Random name generation:** Embedded wordlist in the script. Format: `adjective-noun` (e.g., `swift-falcon`, `bright-coral`). Collision check against existing aliases before use.

**Exit codes:** 0=found/success, 1=not found, 2=invalid args

---

## Commands

### /fund-mnemonic

Derive wallet from BIP-39 mnemonic and hand off to setup-test-wallets.

**Usage:** `/fund-mnemonic <name> "<mnemonic>"`

**Flow:**
1. Call `midnight_wallet_generate` with `--mnemonic` to derive wallet
2. Get the generated address from the response
3. Hand off to `/setup-test-wallets <name> <address>`

---

## Hooks

### 1. PreToolUse: Devnet Running Check

**Trigger:** PreToolUse on any `midnight_*` MCP tool
**Condition:** Active network is `undeployed`
**Action:** Run `docker ps` grep for midnight devnet images. If no containers found, return warning: "The local devnet does not appear to be running. Use `/devnet start` from the midnight-tooling plugin to start it."
**Blocking:** No — advisory only

### 2. PostToolUse: Transfer Failure Guidance

**Trigger:** PostToolUse on `midnight_transfer` when result indicates failure
**Action:** Inspect error:
- If error contains "dust" or code `DUST_REQUIRED`: suggest "Run `midnight_dust_register` first — dust tokens are required for transaction fees."
- If error contains "stale utxo" or code 115 / `STALE_UTXO`: suggest "This UTXO was spent in a concurrent transaction. Wait a few seconds and retry."
- Otherwise: pass through the error unchanged
**Blocking:** No — advisory only

### 3. PreToolUse: Nickname Resolution

**Trigger:** PreToolUse on tools that take address parameters (`midnight_transfer`, `midnight_balance`, `midnight_address`)
**Action:** Check if any address argument lacks the `mn_addr_` prefix (indicating a nickname). If so, run `wallet-aliases.sh get <nickname> --network <active-network>` to resolve. If found, substitute the resolved address. If not found, warn that the nickname is not in the alias file.
**Blocking:** No — substitution or advisory

### 4. SessionStart: Wallet Health & Version Check

**Trigger:** SessionStart, async
**Action:** Run a script that performs three checks in parallel:

**Check A: Wallet health**
1. Load alias files (project-local, then global)
2. For each aliased wallet, check balance and dust status via `npx midnight-wallet-cli balance <address> --json` and `npx midnight-wallet-cli dust status --json`

**Check B: Midnight SDK version alignment**
1. Run `npm view midnight-wallet-cli@latest dependencies` to get the wallet-cli's `@midnight-ntwrk/*` dependencies
2. For each `@midnight-ntwrk/*` dependency, run `npm view <package> versions --json` and find the latest stable version (filter out any version containing `-beta`, `-rc`, `-alpha`, `-dev`, or similar pre-release suffixes)
3. Compare: if the wallet-cli depends on an older version than the latest stable, flag it

**Check C: Ledger version cross-check**
1. Run `compact compile --ledger-version` to get the local Compact compiler's target ledger version (e.g. `ledger-8.0.2`)
2. Extract the major version from the wallet-cli's `@midnight-ntwrk/ledger-*` dependency (e.g. `^8.0.3` → major `8`)
3. Compare the major versions. If they differ, this is a serious compatibility issue (contracts compiled for one ledger version won't work with a wallet targeting another). If only minor/patch differs, it's a softer warning.

**Returns `additionalContext`** combining all findings. Also shows `systemMessage` to the user for any version warnings.

**Example output (all healthy):**
`"Wallet aliases loaded: #alice (50 NIGHT, dust OK), #bob (0 NIGHT, dust NOT registered — transfers as #bob will fail), #charlie (10 NIGHT, dust OK). Active network: undeployed. Wallet CLI SDK versions are current. Compact compiler ledger version (8.0.2) matches wallet CLI ledger dependency (^8.0.3)."`

**Example output (version issues):**
`"Wallet aliases loaded: #alice (50 NIGHT, dust OK). WARNING: midnight-wallet-cli depends on @midnight-ntwrk/ledger-v8@^8.0.3 but latest stable is 8.1.0 — wallet CLI may be outdated. WARNING: Compact compiler targets ledger-7.0.0 but wallet CLI targets ledger-v8 — major version mismatch, compiled contracts may be incompatible with wallet transactions."`

**If no alias files found:** `"No wallet aliases found. Use /setup-test-wallets to create test wallets."`
**If no devnet running and network is undeployed:** Skip balance/dust checks, still run version checks.
**If compact CLI not installed:** Skip ledger cross-check, note in output.

### 5. PreToolUse: Airdrop Network Mismatch

**Trigger:** PreToolUse on `midnight_airdrop`
**Condition:** Active network is NOT `undeployed`
**Action:** Return warning: "Airdrop only works on the local devnet (undeployed network). For testnet tokens, use the faucet: preprod: https://faucet.preprod.midnight.network/ / preview: https://faucet.preview.midnight.network/"
**Blocking:** Yes — prevent the tool call (it would fail anyway)

### 6. PreToolUse: Transfer to Self

**Trigger:** PreToolUse on `midnight_transfer`
**Action:** Check if recipient address matches the active wallet's address (via `midnight_wallet_info`). If so, warn: "The recipient address matches the active wallet. This would transfer tokens to yourself."
**Blocking:** No — advisory only

---

## Tooling Plugin Cleanup

### Remove from midnight-tooling

- Delete `plugins/midnight-tooling/skills/funding/` entirely (SKILL.md, references/, scripts if any)
- Remove "wallet", "funding", "accounts" from `plugin.json` keywords

### Add cross-references

- In `plugins/midnight-tooling/skills/devnet/SKILL.md` or relevant reference, add a note: "For wallet operations, funding, and token management, see the `midnight-wallet` plugin."
- In `plugins/midnight-tooling/skills/troubleshooting/` where funding is mentioned, redirect to the wallet plugin.

### Update plugin.json description

Remove funding/wallet language from the `midnight-tooling` plugin description since that responsibility now lives in `midnight-wallet`.

---

## Dependencies

- **Runtime:** Node.js >= 20, `jq`, Docker (for devnet checks)
- **npm:** `midnight-wallet-cli` (fetched on demand via `npx`, not installed globally)
- **Plugin:** `midnight-tooling` (for devnet management — referenced but not hard-coupled)
