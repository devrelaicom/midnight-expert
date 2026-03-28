# Midnight Wallet Plugin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a new `midnight-wallet` plugin wrapping the midnight-wallet-cli MCP server, with wallet alias system, test wallet setup skill, hooks for error prevention and version checking, and cleanup of the funding skill from midnight-tooling.

**Architecture:** New plugin at `plugins/midnight-wallet/` with MCP server config (npx, no global install), two skills (wallet-cli knowledge + setup-test-wallets orchestration), one command (fund-mnemonic), and 6 hooks (PreToolUse guards, PostToolUse guidance, SessionStart health check). A `wallet-aliases.sh` script provides the nickname→address lookup layer.

**Tech Stack:** Bash scripts, jq, Markdown, Claude Code plugin hooks (prompt + command types), MCP server via npx

**Spec:** `docs/superpowers/specs/2026-03-27-midnight-wallet-plugin-design.md`

---

### Task 1: Plugin Scaffold

**Files:**
- Create: `plugins/midnight-wallet/.claude-plugin/plugin.json`
- Create: `plugins/midnight-wallet/.mcp.json`

- [ ] **Step 1: Create plugin.json**

Write to `plugins/midnight-wallet/.claude-plugin/plugin.json`:

```json
{
  "name": "midnight-wallet",
  "version": "0.1.0",
  "description": "Wallet management, token operations, and test wallet workflows for Midnight Network development — wraps the midnight-wallet-cli MCP server for balance checking, transfers, airdrop, dust registration, and multi-wallet test setups.",
  "author": {
    "name": "Aaron Bassett",
    "email": "aaron@devrel-ai.com"
  },
  "homepage": "https://github.com/devrelaicom/midnight-expert",
  "repository": "https://github.com/devrelaicom/midnight-expert.git",
  "license": "MIT",
  "keywords": [
    "midnight",
    "wallet",
    "night-tokens",
    "dust-tokens",
    "transfer",
    "airdrop",
    "balance",
    "mcp",
    "test-wallets",
    "devnet",
    "funding",
    "bip39",
    "mnemonic"
  ]
}
```

- [ ] **Step 2: Create .mcp.json**

Write to `plugins/midnight-wallet/.mcp.json`:

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

- [ ] **Step 3: Verify directory structure**

Run: `find plugins/midnight-wallet -type f | sort`
Expected:
```
plugins/midnight-wallet/.claude-plugin/plugin.json
plugins/midnight-wallet/.mcp.json
```

- [ ] **Step 4: Commit**

```bash
git add plugins/midnight-wallet/.claude-plugin/plugin.json plugins/midnight-wallet/.mcp.json
git commit -m "feat(midnight-wallet): scaffold plugin with MCP server config"
```

---

### Task 2: Wallet Aliases Script

**Files:**
- Create: `plugins/midnight-wallet/skills/setup-test-wallets/scripts/wallet-aliases.sh`

This is the foundation script used by the setup-test-wallets skill, the nickname resolution hook, and the session-start health check.

- [ ] **Step 1: Write wallet-aliases.sh**

Write to `plugins/midnight-wallet/skills/setup-test-wallets/scripts/wallet-aliases.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# wallet-aliases.sh — Manage wallet nickname → address mappings
#
# Usage:
#   wallet-aliases.sh get <name> [--network <net>] [--file <path>]
#   wallet-aliases.sh reverse <address> [--file <path>]
#   wallet-aliases.sh set <name> --network <net> --address <addr> [--file <path>] [--global]
#   wallet-aliases.sh set <name> --addresses '<json>' [--file <path>] [--global]
#   wallet-aliases.sh list [--file <path>]
#   wallet-aliases.sh remove <name> [--file <path>]
#   wallet-aliases.sh path [--global]
#   wallet-aliases.sh random-name [--file <path>]
#
# Search order (get/reverse): --file > project-local > global
# Write destination: project-local (default), global (--global), custom (--file)
#
# Exit codes: 0=found/success, 1=not found, 2=invalid args

# --- Constants ---
LOCAL_DIR=".claude/midnight-wallet"
LOCAL_FILE="$LOCAL_DIR/wallets.local.json"
GLOBAL_DIR="$HOME/.claude/midnight-wallet"
GLOBAL_FILE="$GLOBAL_DIR/wallets.json"

EMPTY_WALLETS='{"_warning":"Test wallet addresses only. Do NOT store secrets here.","wallets":{}}'

# --- Wordlists for random name generation ---
ADJECTIVES=(
  swift bright calm cool dark fast glad keen mild neat
  pale pure bold deep fair firm free gold good half
  high iron just kind last lean live long lost main
  next open rare real rich safe slim soft tall thin
  true warm wide wild wise blue cold dry flat full
  gray hard hot raw red shy wet young fresh crisp
)

NOUNS=(
  falcon coral ember frost cedar brook flame pearl ridge stone
  spark drift creek blaze maple grove cedar arrow delta frost
  haven crest lunar plume quartz raven terra vapor atlas bloom
  comet dusk fern glade heron ivory jade knoll larch mesa
  north onyx pine quill reef sage thorn umber vale wisp
)

# --- Helpers ---
die() { echo "Error: $1" >&2; exit 2; }

resolve_files() {
  local custom_file="${1:-}"
  if [[ -n "$custom_file" ]]; then
    echo "$custom_file"
    return
  fi
  # Project-local first, then global
  local files=()
  [[ -f "$LOCAL_FILE" ]] && files+=("$LOCAL_FILE")
  [[ -f "$GLOBAL_FILE" ]] && files+=("$GLOBAL_FILE")
  printf '%s\n' "${files[@]}"
}

resolve_write_file() {
  local custom_file="${1:-}"
  local use_global="${2:-false}"
  if [[ -n "$custom_file" ]]; then
    echo "$custom_file"
  elif [[ "$use_global" == "true" ]]; then
    echo "$GLOBAL_FILE"
  else
    echo "$LOCAL_FILE"
  fi
}

ensure_file() {
  local file="$1"
  local dir
  dir=$(dirname "$file")
  if [[ ! -d "$dir" ]]; then
    mkdir -p "$dir"
  fi
  if [[ ! -f "$file" ]]; then
    echo "$EMPTY_WALLETS" | jq . > "$file"
  fi
}

# --- Commands ---

cmd_get() {
  local name="" network="" custom_file=""
  shift # remove 'get'
  [[ $# -lt 1 ]] && die "Usage: wallet-aliases.sh get <name> [--network <net>] [--file <path>]"
  name="$1"; shift
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --network) network="${2:-}"; shift 2 ;;
      --file) custom_file="${2:-}"; shift 2 ;;
      *) die "Unknown flag: $1" ;;
    esac
  done

  local files
  files=$(resolve_files "$custom_file")
  [[ -z "$files" ]] && { echo "No alias files found" >&2; exit 1; }

  while IFS= read -r file; do
    if [[ -n "$network" ]]; then
      local addr
      addr=$(jq -r --arg n "$name" --arg net "$network" '.wallets[$n][$net] // empty' "$file")
      if [[ -n "$addr" ]]; then
        echo "$addr"
        return 0
      fi
    else
      local entry
      entry=$(jq -r --arg n "$name" '.wallets[$n] // empty' "$file")
      if [[ -n "$entry" && "$entry" != "null" ]]; then
        echo "$entry"
        return 0
      fi
    fi
  done <<< "$files"

  echo "Alias not found: $name" >&2
  exit 1
}

cmd_reverse() {
  local address="" custom_file=""
  shift # remove 'reverse'
  [[ $# -lt 1 ]] && die "Usage: wallet-aliases.sh reverse <address> [--file <path>]"
  address="$1"; shift
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --file) custom_file="${2:-}"; shift 2 ;;
      *) die "Unknown flag: $1" ;;
    esac
  done

  local files
  files=$(resolve_files "$custom_file")
  [[ -z "$files" ]] && { echo "No alias files found" >&2; exit 1; }

  while IFS= read -r file; do
    local name
    name=$(jq -r --arg addr "$address" '
      .wallets | to_entries[] |
      select(.value | to_entries[] | .value == $addr) |
      .key
    ' "$file" 2>/dev/null | head -1)
    if [[ -n "$name" ]]; then
      echo "$name"
      return 0
    fi
  done <<< "$files"

  echo "No alias found for address: $address" >&2
  exit 1
}

cmd_set() {
  local name="" network="" address="" addresses="" custom_file="" use_global="false"
  shift # remove 'set'
  [[ $# -lt 1 ]] && die "Usage: wallet-aliases.sh set <name> --network <net> --address <addr> | --addresses '<json>'"
  name="$1"; shift
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --network) network="${2:-}"; shift 2 ;;
      --address) address="${2:-}"; shift 2 ;;
      --addresses) addresses="${2:-}"; shift 2 ;;
      --file) custom_file="${2:-}"; shift 2 ;;
      --global) use_global="true"; shift ;;
      *) die "Unknown flag: $1" ;;
    esac
  done

  [[ -z "$name" ]] && die "Name is required"

  local file
  file=$(resolve_write_file "$custom_file" "$use_global")
  ensure_file "$file"

  if [[ -n "$addresses" ]]; then
    # Bulk set: --addresses '{"undeployed":"addr1","preprod":"addr2"}'
    echo "$addresses" | jq . > /dev/null 2>&1 || die "Invalid JSON for --addresses"
    local tmp
    tmp=$(jq --arg n "$name" --argjson addrs "$addresses" '
      .wallets[$n] = (.wallets[$n] // {}) + $addrs
    ' "$file")
    echo "$tmp" | jq . > "$file"
  elif [[ -n "$network" && -n "$address" ]]; then
    # Single set: --network undeployed --address mn_addr_...
    local tmp
    tmp=$(jq --arg n "$name" --arg net "$network" --arg addr "$address" '
      .wallets[$n] = (.wallets[$n] // {}) + {($net): $addr}
    ' "$file")
    echo "$tmp" | jq . > "$file"
  else
    die "Provide either --network + --address, or --addresses '<json>'"
  fi

  echo "Saved alias: $name → $file"
}

cmd_list() {
  local custom_file=""
  shift # remove 'list'
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --file) custom_file="${2:-}"; shift 2 ;;
      *) die "Unknown flag: $1" ;;
    esac
  done

  local files
  files=$(resolve_files "$custom_file")
  if [[ -z "$files" ]]; then
    echo "No alias files found" >&2
    exit 1
  fi

  # Merge all files, later files don't override earlier ones
  local merged="{}"
  while IFS= read -r file; do
    local wallets
    wallets=$(jq '.wallets // {}' "$file")
    merged=$(echo "$merged" | jq --argjson new "$wallets" '. + $new')
  done <<< "$files"

  echo "$merged" | jq .
}

cmd_remove() {
  local name="" custom_file=""
  shift # remove 'remove'
  [[ $# -lt 1 ]] && die "Usage: wallet-aliases.sh remove <name> [--file <path>]"
  name="$1"; shift
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --file) custom_file="${2:-}"; shift 2 ;;
      *) die "Unknown flag: $1" ;;
    esac
  done

  # Remove from all writable files
  local files
  files=$(resolve_files "$custom_file")
  [[ -z "$files" ]] && die "No alias files found"

  local found=false
  while IFS= read -r file; do
    local exists
    exists=$(jq -r --arg n "$name" '.wallets | has($n)' "$file")
    if [[ "$exists" == "true" ]]; then
      local tmp
      tmp=$(jq --arg n "$name" 'del(.wallets[$n])' "$file")
      echo "$tmp" | jq . > "$file"
      echo "Removed alias: $name from $file"
      found=true
    fi
  done <<< "$files"

  if [[ "$found" == "false" ]]; then
    echo "Alias not found: $name" >&2
    exit 1
  fi
}

cmd_path() {
  local use_global="false"
  shift # remove 'path'
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --global) use_global="true"; shift ;;
      *) die "Unknown flag: $1" ;;
    esac
  done

  if [[ "$use_global" == "true" ]]; then
    echo "$GLOBAL_FILE"
  else
    echo "$LOCAL_FILE"
  fi
}

cmd_random_name() {
  local custom_file=""
  shift # remove 'random-name'
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --file) custom_file="${2:-}"; shift 2 ;;
      *) die "Unknown flag: $1" ;;
    esac
  done

  # Get existing names to avoid collisions
  local existing=""
  local files
  files=$(resolve_files "$custom_file" 2>/dev/null || true)
  if [[ -n "$files" ]]; then
    while IFS= read -r file; do
      existing="$existing $(jq -r '.wallets | keys[]' "$file" 2>/dev/null || true)"
    done <<< "$files"
  fi

  # Generate random name, retry on collision (max 50 attempts)
  local attempts=0
  while [[ $attempts -lt 50 ]]; do
    local adj_idx=$(( RANDOM % ${#ADJECTIVES[@]} ))
    local noun_idx=$(( RANDOM % ${#NOUNS[@]} ))
    local candidate="${ADJECTIVES[$adj_idx]}-${NOUNS[$noun_idx]}"

    if ! echo "$existing" | grep -qw "$candidate"; then
      echo "$candidate"
      return 0
    fi
    attempts=$((attempts + 1))
  done

  # Fallback: append random number
  local adj_idx=$(( RANDOM % ${#ADJECTIVES[@]} ))
  local noun_idx=$(( RANDOM % ${#NOUNS[@]} ))
  echo "${ADJECTIVES[$adj_idx]}-${NOUNS[$noun_idx]}-$RANDOM"
}

# --- Main dispatch ---
[[ $# -lt 1 ]] && die "Usage: wallet-aliases.sh <get|reverse|set|list|remove|path|random-name> [args...]"

case "$1" in
  get) cmd_get "$@" ;;
  reverse) cmd_reverse "$@" ;;
  set) cmd_set "$@" ;;
  list) cmd_list "$@" ;;
  remove) cmd_remove "$@" ;;
  path) cmd_path "$@" ;;
  random-name) cmd_random_name "$@" ;;
  *) die "Unknown command: $1. Valid: get, reverse, set, list, remove, path, random-name" ;;
esac
```

- [ ] **Step 2: Make executable**

Run: `chmod +x plugins/midnight-wallet/skills/setup-test-wallets/scripts/wallet-aliases.sh`

- [ ] **Step 3: Test the script**

Run a basic smoke test:

```bash
SCRIPT="plugins/midnight-wallet/skills/setup-test-wallets/scripts/wallet-aliases.sh"
TESTFILE="/tmp/test-wallets.json"
rm -f "$TESTFILE"

# Test set
"$SCRIPT" set alice --network undeployed --address mn_addr_undeployed1alice --file "$TESTFILE"
"$SCRIPT" set bob --addresses '{"undeployed":"mn_addr_undeployed1bob","preprod":"mn_addr_preprod1bob"}' --file "$TESTFILE"

# Test get
"$SCRIPT" get alice --network undeployed --file "$TESTFILE"
# Expected: mn_addr_undeployed1alice

# Test get all networks
"$SCRIPT" get bob --file "$TESTFILE"
# Expected: JSON with undeployed and preprod addresses

# Test reverse
"$SCRIPT" reverse mn_addr_undeployed1bob --file "$TESTFILE"
# Expected: bob

# Test list
"$SCRIPT" list --file "$TESTFILE"
# Expected: JSON with alice and bob

# Test random-name
"$SCRIPT" random-name --file "$TESTFILE"
# Expected: adjective-noun format, not "alice" or "bob"

# Test remove
"$SCRIPT" remove alice --file "$TESTFILE"
"$SCRIPT" list --file "$TESTFILE"
# Expected: only bob

# Test not found
"$SCRIPT" get charlie --file "$TESTFILE" 2>/dev/null && echo "FAIL: should not find charlie" || echo "OK: charlie not found (exit 1)"

# Cleanup
rm -f "$TESTFILE"
echo "All tests passed"
```

Expected: All operations succeed with correct output.

- [ ] **Step 4: Commit**

```bash
git add plugins/midnight-wallet/skills/setup-test-wallets/scripts/wallet-aliases.sh
git commit -m "feat(midnight-wallet): add wallet-aliases.sh for nickname→address management"
```

---

### Task 3: wallet-cli Skill — SKILL.md

**Files:**
- Create: `plugins/midnight-wallet/skills/wallet-cli/SKILL.md`

- [ ] **Step 1: Write SKILL.md**

Write to `plugins/midnight-wallet/skills/wallet-cli/SKILL.md`. Consult the spec at `docs/superpowers/specs/2026-03-27-midnight-wallet-plugin-design.md` for the detailed body structure, terminology, workflows, and MCP tool table. The SKILL.md must include:

1. **Frontmatter** with name `wallet-cli` and description matching the trigger phrases from the spec
2. **Terminology section** — NIGHT (6 decimals), DUST (15 decimals, requires registration), genesis wallet (seed `0x00...01`), wallet aliases (`#name` syntax)
3. **Common Workflows section** — exactly as specified in the spec (set up test wallets, transfer between wallets, fund existing address, check statuses, restore from mnemonic)
4. **Wallet Nicknames section** — explains `#name` resolves from alias file, project-local then global search
5. **Quick MCP Tool Reference** — table of all 25 tools from the spec, with `DO NOT USE` warnings on `midnight_localnet_*` tools (except `status`)
6. **Reference Files index** — table pointing to `mcp-tools.md`, `wallet-management.md`, `transactions.md`, `devnet-integration.md`, `troubleshooting.md`

- [ ] **Step 2: Commit**

```bash
git add plugins/midnight-wallet/skills/wallet-cli/SKILL.md
git commit -m "feat(midnight-wallet): add wallet-cli SKILL.md with workflows and MCP tool reference"
```

---

### Task 4: wallet-cli References

**Files:**
- Create: `plugins/midnight-wallet/skills/wallet-cli/references/mcp-tools.md`
- Create: `plugins/midnight-wallet/skills/wallet-cli/references/wallet-management.md`
- Create: `plugins/midnight-wallet/skills/wallet-cli/references/transactions.md`
- Create: `plugins/midnight-wallet/skills/wallet-cli/references/devnet-integration.md`
- Create: `plugins/midnight-wallet/skills/wallet-cli/references/troubleshooting.md`

- [ ] **Step 1: Write mcp-tools.md**

Reference doc covering all 25 MCP tools. For each tool, document: name, description, parameters (with types), example request, example response. Use the spec's MCP tools table as the index. Source the parameter schemas from the decompiled source at `https://gist.github.com/aaronbassett/f878ed93a57abbd1b2f5361fafc18cb1` (file: `codex-mcp-server.js`, search for tool definitions starting around line 4093). Include the `DO NOT USE` warnings for `midnight_localnet_*` tools.

- [ ] **Step 2: Write wallet-management.md**

Reference doc covering: wallet generate (with `--seed`, `--mnemonic`, `--force`), wallet list, wallet use, wallet remove, wallet info. Document wallet file structure (`~/.midnight/wallets/<name>.json` with seed, mnemonic, addresses, createdAt). Cover BIP-39 (256-bit / 24 words), HD derivation (Account 0 → NightExternal → key index), multi-network addressing, file permissions (dirs 0700, files 0600). Add troubleshooting table for wallet-specific errors.

- [ ] **Step 3: Write transactions.md**

Reference doc covering: balance checking (GraphQL subscription to indexer), transfers (require dust, use `midnight_transfer`), airdrop (undeployed only, genesis seed `0x00...01`), dust registration and status. Document NIGHT (6 decimals) and DUST (15 decimals). Cover JSON output mode. List all error codes from the spec: INVALID_ARGS, WALLET_NOT_FOUND, NETWORK_ERROR, INSUFFICIENT_BALANCE, TX_REJECTED, STALE_UTXO, PROOF_TIMEOUT, DUST_REQUIRED, CANCELLED. Add troubleshooting table.

- [ ] **Step 4: Write devnet-integration.md**

Reference doc covering: how wallet-cli auto-detects devnet (image-name `docker ps` parsing), standard ports (9944, 8088, 6300), why `midnight localnet` commands conflict with `/devnet` (different container names: `node`/`indexer`/`proof-server` vs `midnight-node`/`midnight-indexer`/`midnight-proof-server`, different compose files, same ports). Document `undeployed` network ID, config overrides via `midnight_config_set`. Emphasize: use `/devnet start` for lifecycle, wallet tools for operations.

- [ ] **Step 5: Write troubleshooting.md**

Reference doc with exit codes table (0=success through 7=cancelled) from the spec. Error messages by category. Network issues section pointing to `midnight-tooling` devnet skill:
```
If wallet operations fail with network errors and the active network is
`undeployed`, the local devnet is likely not running or unhealthy:
- `/devnet status` — check container state
- `/devnet health` — verify service responsiveness
- `/devnet logs` — inspect service logs
- `/devnet restart` — restart if degraded
```

- [ ] **Step 6: Commit**

```bash
git add plugins/midnight-wallet/skills/wallet-cli/references/
git commit -m "feat(midnight-wallet): add wallet-cli reference docs"
```

---

### Task 5: setup-test-wallets Skill

**Files:**
- Create: `plugins/midnight-wallet/skills/setup-test-wallets/SKILL.md`

- [ ] **Step 1: Write SKILL.md**

Write to `plugins/midnight-wallet/skills/setup-test-wallets/SKILL.md`. This is an orchestration skill, not a knowledge skill. The SKILL.md must include:

1. **Frontmatter** with name `setup-test-wallets` and description matching: "setup test wallets", "create test accounts", "generate test wallets", "alice bob charlie", "fund test accounts", "test wallet setup", "development wallets"
2. **Input handling table** from the spec:
   - (nothing) → random name, generate, fund, register dust, save alias
   - `alice` → check alias, if not found generate new
   - `mn_addr_...` → reverse lookup, if no alias assign random name
   - `alice mn_addr_...` → use as-is
   - `alice bob charlie` → batch mode
3. **Flow for each wallet**: resolve → generate if needed via `midnight_wallet_generate` → fund via `midnight_airdrop` (if undeployed) → register dust via `midnight_dust_register` → save via `wallet-aliases.sh set`
4. **Security warning**: aliases store public addresses only, test wallets in `~/.midnight/wallets/` contain seeds, development use only
5. **Script reference**: `${CLAUDE_SKILL_DIR}/scripts/wallet-aliases.sh` for alias operations
6. **Random name format**: `adjective-noun` from embedded wordlist via `wallet-aliases.sh random-name`

- [ ] **Step 2: Commit**

```bash
git add plugins/midnight-wallet/skills/setup-test-wallets/SKILL.md
git commit -m "feat(midnight-wallet): add setup-test-wallets orchestration skill"
```

---

### Task 6: fund-mnemonic Command

**Files:**
- Create: `plugins/midnight-wallet/commands/fund-mnemonic.md`

- [ ] **Step 1: Write fund-mnemonic.md**

Write to `plugins/midnight-wallet/commands/fund-mnemonic.md`:

```markdown
---
description: Derive a wallet from a BIP-39 mnemonic, fund it, and register dust
argument-hint: <name> "<24-word mnemonic>"
---

Derive a wallet from a BIP-39 mnemonic and set it up for use on the active network.

## Flow

1. Call `midnight_wallet_generate` with the provided name and `--mnemonic` flag
2. Extract the generated wallet's address for the active network from the response
3. Hand off to the `setup-test-wallets` skill: `/setup-test-wallets <name> <address>`

The setup-test-wallets skill will fund via airdrop (if on undeployed network), register dust, and save the wallet alias.

## Usage

```
/fund-mnemonic alice "word1 word2 word3 ... word24"
```

## Arguments

- `<name>` — Name for the wallet (used as both wallet-cli name and alias)
- `<mnemonic>` — 24-word BIP-39 mnemonic (must be quoted)

## Error Handling

- If the mnemonic is invalid, `midnight_wallet_generate` will return an error. Report it to the user.
- If a wallet with the given name already exists in wallet-cli, the generate step will fail. Suggest using a different name or `midnight_wallet_remove` first.
- If the network is not `undeployed`, the airdrop step in setup-test-wallets will be skipped (user needs to fund via faucet).
```

- [ ] **Step 2: Commit**

```bash
git add plugins/midnight-wallet/commands/fund-mnemonic.md
git commit -m "feat(midnight-wallet): add fund-mnemonic command"
```

---

### Task 7: Hooks — hooks.json

**Files:**
- Create: `plugins/midnight-wallet/hooks/hooks.json`

- [ ] **Step 1: Write hooks.json**

Write to `plugins/midnight-wallet/hooks/hooks.json`:

```json
{
  "description": "Wallet operation guards, error guidance, nickname resolution, and session health checks",
  "hooks": {
    "SessionStart": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/scripts/session-start-health.sh",
            "timeout": 60,
            "async": true
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "mcp__midnight-wallet__midnight_.*",
        "hooks": [
          {
            "type": "prompt",
            "prompt": "A midnight wallet MCP tool is about to be called. Before it executes, check: is the tool input referencing the 'undeployed' network (check via midnight_config_get or the tool's network parameter)? If so, verify the local devnet is running by checking if Docker containers with midnight-related images are active. If the devnet does not appear to be running, add a warning: 'The local devnet does not appear to be running. Use /devnet start from the midnight-tooling plugin to start it.' Do NOT block the call — just warn.",
            "timeout": 15
          }
        ]
      },
      {
        "matcher": "mcp__midnight-wallet__midnight_transfer|mcp__midnight-wallet__midnight_balance",
        "hooks": [
          {
            "type": "prompt",
            "prompt": "A wallet tool that takes an address is about to be called. Check if any address argument in the tool input lacks the 'mn_addr_' prefix — this indicates a wallet nickname (e.g., 'alice', 'bob'). If you find a nickname, resolve it by running: bash ${CLAUDE_PLUGIN_ROOT}/skills/setup-test-wallets/scripts/wallet-aliases.sh get <nickname> --network <active-network>. If found, use the resolved address in the tool call. If not found, warn the user that the nickname is not in the alias file and suggest running /setup-test-wallets.",
            "timeout": 15
          }
        ]
      },
      {
        "matcher": "mcp__midnight-wallet__midnight_airdrop",
        "hooks": [
          {
            "type": "prompt",
            "prompt": "The midnight_airdrop tool is about to be called. Airdrop ONLY works on the 'undeployed' (local devnet) network. Check the active network. If the network is NOT 'undeployed', BLOCK this call and tell the user: 'Airdrop only works on the local devnet (undeployed network). For testnet tokens, use the faucet: preprod: https://faucet.preprod.midnight.network/ — preview: https://faucet.preview.midnight.network/'. Return permissionDecision: 'deny'.",
            "timeout": 10
          }
        ]
      },
      {
        "matcher": "mcp__midnight-wallet__midnight_transfer",
        "hooks": [
          {
            "type": "prompt",
            "prompt": "The midnight_transfer tool is about to send tokens. Check if the recipient address in the tool input matches the active wallet's address (you can check via midnight_wallet_info or from recent context). If the recipient is the same as the sender, warn: 'The recipient address matches the active wallet. This would transfer tokens to yourself — is this intentional?' Do NOT block — just add the warning as a systemMessage.",
            "timeout": 10
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "mcp__midnight-wallet__midnight_transfer",
        "hooks": [
          {
            "type": "prompt",
            "prompt": "The midnight_transfer tool just completed. Check the result: did it fail? If so, inspect the error message:\n- If the error mentions 'dust', 'DUST_REQUIRED', or insufficient dust: suggest 'Run midnight_dust_register first — dust tokens are required for transaction fees.'\n- If the error mentions 'stale utxo', 'STALE_UTXO', or error code 115: suggest 'This UTXO was spent in a concurrent transaction. Wait a few seconds and retry the transfer.'\n- Otherwise: pass through the error as-is.\nDo not modify the result, just add guidance as a systemMessage.",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add plugins/midnight-wallet/hooks/hooks.json
git commit -m "feat(midnight-wallet): add hooks for devnet check, nickname resolution, error guidance"
```

---

### Task 8: SessionStart Health Check Script

**Files:**
- Create: `plugins/midnight-wallet/hooks/scripts/session-start-health.sh`

- [ ] **Step 1: Write session-start-health.sh**

Write to `plugins/midnight-wallet/hooks/scripts/session-start-health.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# session-start-health.sh — Async SessionStart hook
# Checks wallet health, SDK version alignment, and ledger version cross-check
# Returns JSON with additionalContext and systemMessage

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ALIASES_SCRIPT="$PLUGIN_ROOT/skills/setup-test-wallets/scripts/wallet-aliases.sh"

context_parts=()
warnings=()

# --- Check A: Wallet health ---
wallet_health() {
  local aliases
  aliases=$("$ALIASES_SCRIPT" list 2>/dev/null || echo "{}")

  if [[ "$aliases" == "{}" ]]; then
    context_parts+=("No wallet aliases found. Use /setup-test-wallets to create test wallets.")
    return
  fi

  # Check if devnet is reachable before querying balances
  local can_query=true
  if ! npx -y midnight-wallet-cli@latest balance --json 2>/dev/null | head -c 1 | grep -q '{'; then
    can_query=false
  fi

  local wallet_statuses=()
  for name in $(echo "$aliases" | jq -r 'keys[]'); do
    local addr
    addr=$(echo "$aliases" | jq -r --arg n "$name" '.[$n].undeployed // .[$n] | to_entries[0].value // empty')
    if [[ -z "$addr" || "$addr" == "null" ]]; then
      wallet_statuses+=("#$name (no address)")
      continue
    fi

    if [[ "$can_query" == "false" ]]; then
      wallet_statuses+=("#$name ($addr)")
      continue
    fi

    # Check balance
    local balance_json
    balance_json=$(npx -y midnight-wallet-cli@latest balance "$addr" --json 2>/dev/null || echo '{}')
    local night
    night=$(echo "$balance_json" | jq -r '.balances.NIGHT // "unknown"' 2>/dev/null || echo "unknown")

    # Check dust — switch wallet, check dust status
    local dust_status="unknown"
    # Dust check requires active wallet context, skip for speed in session start
    # Just report balance
    wallet_statuses+=("#$name ($night NIGHT)")
  done

  if [[ ${#wallet_statuses[@]} -gt 0 ]]; then
    context_parts+=("Wallet aliases loaded: $(IFS=', '; echo "${wallet_statuses[*]}").")
  fi
}

# --- Check B: SDK version alignment ---
sdk_version_check() {
  local deps
  deps=$(npm view midnight-wallet-cli@latest dependencies 2>/dev/null || echo "")
  [[ -z "$deps" ]] && return

  # Extract @midnight-ntwrk/* dependencies
  local midnight_deps
  midnight_deps=$(echo "$deps" | grep -oE "'@midnight-ntwrk/[^']+': '[^']+'" 2>/dev/null || echo "$deps" | grep -oE "@midnight-ntwrk/[^:]+: [^ ]+" 2>/dev/null || true)
  [[ -z "$midnight_deps" ]] && return

  # For each dependency, check if wallet-cli's version is behind latest stable
  while IFS= read -r line; do
    local pkg ver
    pkg=$(echo "$line" | grep -oE "@midnight-ntwrk/[a-zA-Z0-9_-]+" || true)
    ver=$(echo "$line" | grep -oE "'?\^?[0-9]+\.[0-9]+\.[0-9]+[^']*'?" | tr -d "'^" || true)
    [[ -z "$pkg" || -z "$ver" ]] && continue

    local latest_stable
    latest_stable=$(npm view "$pkg" versions --json 2>/dev/null | jq -r '[.[] | select(test("^[0-9]+\\.[0-9]+\\.[0-9]+$"))] | last // empty' 2>/dev/null || true)
    [[ -z "$latest_stable" ]] && continue

    # Extract major versions for comparison
    local dep_major latest_major
    dep_major=$(echo "$ver" | cut -d. -f1)
    latest_major=$(echo "$latest_stable" | cut -d. -f1)

    if [[ "$dep_major" != "$latest_major" ]]; then
      warnings+=("midnight-wallet-cli depends on ${pkg}@^${ver} but latest stable is ${latest_stable} — major version mismatch")
    fi
  done <<< "$midnight_deps"
}

# --- Check C: Ledger version cross-check ---
ledger_cross_check() {
  # Get compact compiler ledger version
  local compact_ledger
  compact_ledger=$(compact compile -- --ledger-version 2>/dev/null || echo "")
  [[ -z "$compact_ledger" ]] && {
    context_parts+=("Compact CLI not installed — skipping ledger version cross-check.")
    return
  }

  # Extract major version from compact (e.g., "ledger-8.0.2" → "8")
  local compact_major
  compact_major=$(echo "$compact_ledger" | grep -oE '[0-9]+' | head -1)
  [[ -z "$compact_major" ]] && return

  # Get wallet-cli's ledger dependency version
  local wallet_ledger_dep
  wallet_ledger_dep=$(npm view midnight-wallet-cli@latest dependencies 2>/dev/null | grep -oE "@midnight-ntwrk/ledger-v[0-9]+[^']*'[^']+'" | grep -oE "[0-9]+\.[0-9]+\.[0-9]+" | head -1 || true)
  [[ -z "$wallet_ledger_dep" ]] && return

  local wallet_major
  wallet_major=$(echo "$wallet_ledger_dep" | cut -d. -f1)

  if [[ "$compact_major" != "$wallet_major" ]]; then
    warnings+=("Compact compiler targets ledger-${compact_ledger} but wallet CLI targets ledger-v${wallet_major} — MAJOR VERSION MISMATCH. Compiled contracts may be incompatible with wallet transactions.")
  else
    context_parts+=("Compact compiler ledger version (${compact_ledger}) matches wallet CLI ledger dependency (v${wallet_ledger_dep}).")
  fi
}

# --- Run checks ---
wallet_health
sdk_version_check
ledger_cross_check

# --- Build output ---
additional_context=""
system_message=""

if [[ ${#context_parts[@]} -gt 0 ]]; then
  additional_context=$(IFS=' '; echo "${context_parts[*]}")
fi

if [[ ${#warnings[@]} -gt 0 ]]; then
  warning_text=$(printf "WARNING: %s\n" "${warnings[@]}")
  additional_context="$additional_context $warning_text"
  system_message="$warning_text"
fi

# Output JSON for Claude Code hook system
jq -n \
  --arg ctx "$additional_context" \
  --arg msg "$system_message" \
  '{additionalContext: $ctx, systemMessage: $msg}'
```

- [ ] **Step 2: Make executable**

Run: `chmod +x plugins/midnight-wallet/hooks/scripts/session-start-health.sh`

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-wallet/hooks/scripts/session-start-health.sh
git commit -m "feat(midnight-wallet): add session-start health check script"
```

---

### Task 9: Tooling Plugin Cleanup

**Files:**
- Delete: `plugins/midnight-tooling/skills/funding/` (entire directory)
- Modify: `plugins/midnight-tooling/.claude-plugin/plugin.json`
- Modify: `plugins/midnight-tooling/skills/devnet/SKILL.md`

- [ ] **Step 1: Delete the funding skill**

```bash
git rm -r plugins/midnight-tooling/skills/funding/
```

- [ ] **Step 2: Update plugin.json — remove funding/wallet keywords**

Read `plugins/midnight-tooling/.claude-plugin/plugin.json` and remove these keywords: `"funding"`, `"wallet"`, `"accounts"`. Also update the description to remove funding/wallet language.

New description: `"Installs, configures, and manages the Midnight Network development toolchain — Compact CLI, compiler version switching, local devnet (node, indexer, proof server), diagnostics, and release notes for all Midnight components."`

New keywords (remove `"funding"`, `"wallet"`, `"accounts"`):
```json
[
  "midnight", "compact", "cli", "toolchain", "proof-server",
  "docker", "devnet", "local-network", "node", "indexer",
  "development-environment", "troubleshooting", "statusline", "release-notes"
]
```

- [ ] **Step 3: Add cross-reference to devnet SKILL.md**

Read `plugins/midnight-tooling/skills/devnet/SKILL.md` and add a note after the Common Issues section (before Reference Files):

```markdown
## Wallet Operations

For wallet management, funding, balance checking, transfers, and dust registration, use the `midnight-wallet` plugin. The wallet plugin's MCP tools work with any running devnet — it auto-detects the services by Docker image name.
```

- [ ] **Step 4: Check for other funding references in tooling**

Run: `grep -rl "funding\|fund-mnemonic\|fund-account\|genesis.*wallet" plugins/midnight-tooling/ --include="*.md" | grep -v funding/`

For each file found, update references to point to the `midnight-wallet` plugin instead.

- [ ] **Step 5: Verify no broken references**

Run: `grep -r "skills/funding" plugins/midnight-tooling/ --include="*.md"`
Expected: No results (all references to funding skill removed)

- [ ] **Step 6: Commit**

```bash
git add plugins/midnight-tooling/
git commit -m "chore(midnight-tooling): remove funding skill, add cross-references to midnight-wallet plugin"
```

---

### Task 10: Final Verification

- [ ] **Step 1: Verify complete plugin structure**

Run: `find plugins/midnight-wallet -type f | sort`

Expected:
```
plugins/midnight-wallet/.claude-plugin/plugin.json
plugins/midnight-wallet/.mcp.json
plugins/midnight-wallet/commands/fund-mnemonic.md
plugins/midnight-wallet/hooks/hooks.json
plugins/midnight-wallet/hooks/scripts/session-start-health.sh
plugins/midnight-wallet/skills/setup-test-wallets/SKILL.md
plugins/midnight-wallet/skills/setup-test-wallets/scripts/wallet-aliases.sh
plugins/midnight-wallet/skills/wallet-cli/SKILL.md
plugins/midnight-wallet/skills/wallet-cli/references/devnet-integration.md
plugins/midnight-wallet/skills/wallet-cli/references/mcp-tools.md
plugins/midnight-wallet/skills/wallet-cli/references/transactions.md
plugins/midnight-wallet/skills/wallet-cli/references/troubleshooting.md
plugins/midnight-wallet/skills/wallet-cli/references/wallet-management.md
```

- [ ] **Step 2: Verify funding skill is removed**

Run: `ls plugins/midnight-tooling/skills/funding/ 2>&1`
Expected: `No such file or directory`

- [ ] **Step 3: Verify wallet-aliases.sh is executable**

Run: `test -x plugins/midnight-wallet/skills/setup-test-wallets/scripts/wallet-aliases.sh && echo "OK" || echo "FAIL"`
Expected: `OK`

- [ ] **Step 4: Verify hooks.json is valid JSON**

Run: `jq . plugins/midnight-wallet/hooks/hooks.json > /dev/null && echo "Valid JSON" || echo "INVALID"`
Expected: `Valid JSON`

- [ ] **Step 5: Verify plugin.json is valid JSON**

Run: `jq . plugins/midnight-wallet/.claude-plugin/plugin.json > /dev/null && echo "Valid JSON" || echo "INVALID"`
Expected: `Valid JSON`

- [ ] **Step 6: Verify git status is clean**

Run: `git status`
Expected: Nothing to commit, working tree clean
