# Expert Doctor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create the `expert` plugin with an `expert:doctor` skill that performs comprehensive health checks on the midnight-expert ecosystem — plugins, MCP servers, external tools, cross-plugin references, and NPM registry.

**Architecture:** Script-heavy approach matching `midnight-tooling:doctor`. Five bash scripts each handle one check category, outputting structured `CHECK_NAME | STATUS | DETAIL` lines. The SKILL.md orchestrates by launching parallel background agents, optionally delegating to `midnight-tooling:doctor`, then assembling a unified report and offering fixes.

**Tech Stack:** Bash scripts, Claude Code plugin system (SKILL.md), `claude mcp list` CLI, GitHub API (for version checks), npm registry API.

---

### Task 1: Plugin Scaffold

**Files:**
- Create: `plugins/expert/.claude-plugin/plugin.json`

- [ ] **Step 1: Create plugin directory structure**

```bash
mkdir -p plugins/expert/.claude-plugin
mkdir -p plugins/expert/skills/doctor/scripts
mkdir -p plugins/expert/skills/doctor/references
```

- [ ] **Step 2: Write plugin.json**

Create `plugins/expert/.claude-plugin/plugin.json`:

```json
{
  "name": "expert",
  "version": "0.1.0",
  "description": "Meta-plugin for the midnight-expert marketplace. Provides comprehensive diagnostics and health reporting for the entire midnight-expert ecosystem — plugin installation, MCP server connectivity, external CLI tools, cross-plugin references, and NPM registry access.",
  "author": {
    "name": "Aaron Bassett",
    "email": "aaron@devrel-ai.com"
  },
  "homepage": "https://github.com/devrelaicom/midnight-expert",
  "repository": "https://github.com/devrelaicom/midnight-expert.git",
  "license": "MIT",
  "keywords": [
    "midnight",
    "diagnostics",
    "health-check",
    "plugin-management",
    "doctor"
  ]
}
```

- [ ] **Step 3: Commit scaffold**

```bash
git add plugins/expert/.claude-plugin/plugin.json
git commit -m "feat(expert): scaffold expert plugin with plugin.json

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 2: check-plugins.sh

**Files:**
- Create: `plugins/expert/skills/doctor/scripts/check-plugins.sh`

This script reads `~/.claude/plugins/installed_plugins.json` and `~/.claude/settings.json` to check the 9 published midnight-expert marketplace plugins. For each: installed? enabled? version?

- [ ] **Step 1: Write check-plugins.sh**

Create `plugins/expert/skills/doctor/scripts/check-plugins.sh`:

```bash
#!/usr/bin/env bash
set -u

emit() {
  local name="$1"
  local status="$2"
  local detail="$3"
  detail="$(printf '%s' "$detail" | tr '\n' ';' | sed 's/  */ /g; s/; */; /g; s/; $//')"
  printf '%s | %s | %s\n' "$name" "$status" "$detail"
}

INSTALLED_PLUGINS="$HOME/.claude/plugins/installed_plugins.json"
SETTINGS="$HOME/.claude/settings.json"

# The 9 published plugins in the midnight-expert marketplace
PLUGINS=(
  "compact-core"
  "compact-examples"
  "core-concepts"
  "midnight-plugin-utils"
  "midnight-tooling"
  "midnight-verify"
  "midnight-cq"
  "midnight-wallet"
  "midnight-fact-check"
)

MARKETPLACE="midnight-expert"

if [ ! -f "$INSTALLED_PLUGINS" ]; then
  emit "Plugin registry" "critical" "~/.claude/plugins/installed_plugins.json not found"
  exit 0
fi

if [ ! -f "$SETTINGS" ]; then
  emit "Settings file" "critical" "~/.claude/settings.json not found"
  exit 0
fi

fail=0

for plugin in "${PLUGINS[@]}"; do
  key="${plugin}@${MARKETPLACE}"

  # Check if installed — look for the key in the JSON
  install_path=""
  version=""
  if command -v python3 >/dev/null 2>&1; then
    install_info="$(python3 -c "
import json, sys
with open('$INSTALLED_PLUGINS') as f:
    data = json.load(f)
entries = data.get('plugins', {}).get('$key', [])
if entries:
    e = entries[0]
    print(e.get('installPath', ''))
    print(e.get('version', ''))
" 2>/dev/null)" || install_info=""
    install_path="$(printf '%s' "$install_info" | sed -n '1p')"
    version="$(printf '%s' "$install_info" | sed -n '2p')"
  else
    # Fallback: grep-based check
    if grep -q "\"$key\"" "$INSTALLED_PLUGINS" 2>/dev/null; then
      install_path="found"
      version="unknown (python3 not available for version parsing)"
    fi
  fi

  if [ -z "$install_path" ]; then
    emit "$plugin" "critical" "not installed"
    fail=1
    continue
  fi

  # Check if enabled
  enabled=""
  if command -v python3 >/dev/null 2>&1; then
    enabled="$(python3 -c "
import json
with open('$SETTINGS') as f:
    data = json.load(f)
ep = data.get('enabledPlugins', {})
print('true' if ep.get('$key', False) else 'false')
" 2>/dev/null)" || enabled="unknown"
  else
    if grep -q "\"$key\": true" "$SETTINGS" 2>/dev/null; then
      enabled="true"
    elif grep -q "\"$key\"" "$SETTINGS" 2>/dev/null; then
      enabled="false"
    else
      enabled="false"
    fi
  fi

  if [ "$enabled" = "false" ]; then
    emit "$plugin" "warn" "installed (v${version}) but not enabled"
    fail=1
    continue
  fi

  # Read actual version from plugin.json at install path
  actual_version="$version"
  if [ -n "$install_path" ] && [ -f "$install_path/.claude-plugin/plugin.json" ]; then
    if command -v python3 >/dev/null 2>&1; then
      pv="$(python3 -c "
import json
with open('$install_path/.claude-plugin/plugin.json') as f:
    data = json.load(f)
print(data.get('version', ''))
" 2>/dev/null)" || pv=""
      if [ -n "$pv" ]; then
        actual_version="$pv"
      fi
    fi
  fi

  emit "$plugin" "pass" "v${actual_version}"
done

if [ "$fail" -eq 0 ]; then
  emit "ALL_PLUGINS_PASS" "pass" "all midnight-expert plugins installed and enabled"
fi
```

- [ ] **Step 2: Make script executable and run it**

```bash
chmod +x plugins/expert/skills/doctor/scripts/check-plugins.sh
bash plugins/expert/skills/doctor/scripts/check-plugins.sh
```

Expected: lines in `CHECK_NAME | STATUS | DETAIL` format, one per plugin. Plugins that are installed and enabled show `pass`, missing ones show `critical`, disabled ones show `warn`.

- [ ] **Step 3: Commit**

```bash
git add plugins/expert/skills/doctor/scripts/check-plugins.sh
git commit -m "feat(expert): add check-plugins.sh diagnostic script

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 3: check-mcp-servers.sh

**Files:**
- Create: `plugins/expert/skills/doctor/scripts/check-mcp-servers.sh`

Checks whether the 4 MCP servers used across the ecosystem are configured in Claude Code.

- [ ] **Step 1: Write check-mcp-servers.sh**

Create `plugins/expert/skills/doctor/scripts/check-mcp-servers.sh`:

```bash
#!/usr/bin/env bash
set -u

emit() {
  local name="$1"
  local status="$2"
  local detail="$3"
  detail="$(printf '%s' "$detail" | tr '\n' ';' | sed 's/  */ /g; s/; */; /g; s/; $//')"
  printf '%s | %s | %s\n' "$name" "$status" "$detail"
}

# Expected MCP servers and their add commands
# Format: name|search_pattern|add_command|used_by
SERVERS=(
  "midnight|midnight|claude mcp add midnight -- npx -y github:devrelaicom/midnight-mcp|compact-core"
  "octocode|octocode|claude mcp add octocode-mcp -- npx octocode-mcp|midnight-tooling, midnight-verify, midnight-fact-check"
  "midnight-devnet|midnight-devnet|claude mcp add midnight-devnet -- npx -y @aaronbassett/midnight-local-devnet|midnight-tooling"
  "midnight-wallet|midnight-wallet|claude mcp add midnight-wallet -- npx -y -p midnight-wallet-cli@latest midnight-wallet-mcp|midnight-wallet"
)

mcp_list="$(claude mcp list 2>&1)" || mcp_list=""

if [ -z "$mcp_list" ]; then
  emit "MCP server listing" "warn" "could not retrieve MCP server list from Claude Code"
  exit 0
fi

fail=0

for entry in "${SERVERS[@]}"; do
  IFS='|' read -r name pattern add_cmd used_by <<< "$entry"

  if printf '%s' "$mcp_list" | grep -qi "$pattern"; then
    # Check connection status from the output
    server_line="$(printf '%s' "$mcp_list" | grep -i "$pattern" | head -1)"
    if printf '%s' "$server_line" | grep -q "Connected"; then
      emit "MCP: $name" "pass" "configured and connected; used by $used_by"
    elif printf '%s' "$server_line" | grep -q "authentication"; then
      emit "MCP: $name" "warn" "configured but needs authentication; used by $used_by"
      fail=1
    else
      emit "MCP: $name" "warn" "configured but not connected; used by $used_by"
      fail=1
    fi
  else
    emit "MCP: $name" "critical" "not configured; used by $used_by; add with: $add_cmd"
    fail=1
  fi
done

if [ "$fail" -eq 0 ]; then
  emit "ALL_MCP_PASS" "pass" "all MCP servers configured and connected"
fi
```

- [ ] **Step 2: Make script executable and run it**

```bash
chmod +x plugins/expert/skills/doctor/scripts/check-mcp-servers.sh
bash plugins/expert/skills/doctor/scripts/check-mcp-servers.sh
```

Expected: one line per MCP server showing `pass`, `warn`, or `critical` status.

- [ ] **Step 3: Commit**

```bash
git add plugins/expert/skills/doctor/scripts/check-mcp-servers.sh
git commit -m "feat(expert): add check-mcp-servers.sh diagnostic script

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 4: check-ext-tools.sh

**Files:**
- Create: `plugins/expert/skills/doctor/scripts/check-ext-tools.sh`

Checks availability and versions of external CLI tools, with live queries for latest versions.

- [ ] **Step 1: Write check-ext-tools.sh**

Create `plugins/expert/skills/doctor/scripts/check-ext-tools.sh`:

```bash
#!/usr/bin/env bash
set -u

emit() {
  local name="$1"
  local status="$2"
  local detail="$3"
  detail="$(printf '%s' "$detail" | tr '\n' ';' | sed 's/  */ /g; s/; */; /g; s/; $//')"
  printf '%s | %s | %s\n' "$name" "$status" "$detail"
}

# Detect OS for fix suggestions
OS="unknown"
case "$(uname -s)" in
  Darwin*) OS="macos" ;;
  Linux*)  OS="linux" ;;
esac

# Helper: fetch latest GitHub release tag
gh_latest() {
  local owner="$1"
  local repo="$2"
  curl -sf --max-time 5 "https://api.github.com/repos/$owner/$repo/releases/latest" 2>/dev/null \
    | grep '"tag_name"' | head -1 | sed 's/.*"tag_name": *"//;s/".*//' | sed 's/^v//'
}

# Helper: extract version number from a version string
extract_version() {
  printf '%s' "$1" | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1
}

fail=0

# --- Node.js ---
if command -v node >/dev/null 2>&1; then
  node_ver="$(extract_version "$(node --version 2>&1)")"
  node_latest="$(curl -sf --max-time 5 "https://registry.npmjs.org/node/latest" 2>/dev/null \
    | grep '"version"' | head -1 | sed 's/.*"version": *"//;s/".*//')" || node_latest=""
  if [ -z "$node_latest" ]; then
    # Fallback: try nvm ls-remote
    node_latest="$(nvm ls-remote --lts 2>/dev/null | tail -1 | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | sed 's/^v//')" || node_latest=""
  fi
  if [ -n "$node_latest" ] && [ "$node_ver" != "$node_latest" ]; then
    emit "node" "info" "installed: $node_ver; latest LTS: $node_latest"
  else
    emit "node" "pass" "v${node_ver}"
  fi
else
  emit "node" "critical" "not installed"
  fail=1
fi

# --- npm ---
if command -v npm >/dev/null 2>&1; then
  npm_ver="$(extract_version "$(npm --version 2>&1)")"
  emit "npm" "pass" "v${npm_ver}"
else
  emit "npm" "critical" "not installed (comes with Node.js)"
  fail=1
fi

# --- npx ---
if command -v npx >/dev/null 2>&1; then
  npx_ver="$(extract_version "$(npx --version 2>&1)")"
  emit "npx" "pass" "v${npx_ver}"
else
  emit "npx" "critical" "not installed (comes with Node.js)"
  fail=1
fi

# --- git ---
if command -v git >/dev/null 2>&1; then
  git_ver="$(extract_version "$(git --version 2>&1)")"
  git_latest="$(gh_latest "git" "git")" || git_latest=""
  if [ -n "$git_latest" ] && [ "$git_ver" != "$git_latest" ]; then
    emit "git" "info" "installed: $git_ver; latest: $git_latest"
  else
    emit "git" "pass" "v${git_ver}"
  fi
else
  emit "git" "critical" "not installed"
  fail=1
fi

# --- gh (GitHub CLI) ---
if command -v gh >/dev/null 2>&1; then
  gh_ver="$(extract_version "$(gh --version 2>&1)")"
  gh_latest_ver="$(gh_latest "cli" "cli")" || gh_latest_ver=""
  if [ -n "$gh_latest_ver" ] && [ "$gh_ver" != "$gh_latest_ver" ]; then
    emit "gh" "info" "installed: $gh_ver; latest: $gh_latest_ver"
  else
    emit "gh" "pass" "v${gh_ver}"
  fi

  # Check auth
  if gh auth status >/dev/null 2>&1; then
    emit "gh auth" "pass" "authenticated"
  else
    emit "gh auth" "warn" "not authenticated — run 'gh auth login'"
    fail=1
  fi
else
  emit "gh" "warn" "not installed — needed by midnight-tooling"
  fail=1
fi

# --- docker ---
if command -v docker >/dev/null 2>&1; then
  docker_ver="$(extract_version "$(docker --version 2>&1)")"
  emit "docker" "pass" "v${docker_ver}"

  # Check daemon
  if docker info >/dev/null 2>&1; then
    emit "docker daemon" "pass" "running"
  else
    emit "docker daemon" "warn" "not running"
    fail=1
  fi
else
  emit "docker" "warn" "not installed — needed for devnet and proof server"
  fail=1
fi

# --- python3 ---
if command -v python3 >/dev/null 2>&1; then
  py_ver="$(extract_version "$(python3 --version 2>&1)")"
  emit "python3" "pass" "v${py_ver}"
else
  emit "python3" "warn" "not installed — install uv then run 'uv python install'"
  fail=1
fi

# --- curl ---
if command -v curl >/dev/null 2>&1; then
  curl_ver="$(extract_version "$(curl --version 2>&1)")"
  emit "curl" "pass" "v${curl_ver}"
else
  emit "curl" "warn" "not installed"
  fail=1
fi

# --- tsc (TypeScript) ---
if command -v tsc >/dev/null 2>&1; then
  tsc_ver="$(extract_version "$(tsc --version 2>&1)")"
  tsc_latest="$(curl -sf --max-time 5 "https://registry.npmjs.org/typescript/latest" 2>/dev/null \
    | grep '"version"' | head -1 | sed 's/.*"version": *"//;s/".*//')" || tsc_latest=""
  if [ -n "$tsc_latest" ] && [ "$tsc_ver" != "$tsc_latest" ]; then
    emit "tsc" "info" "installed: $tsc_ver; latest: $tsc_latest"
  else
    emit "tsc" "pass" "v${tsc_ver}"
  fi
else
  emit "tsc" "warn" "not installed — run 'npm install -g typescript'"
  fail=1
fi

# --- jq (optional) ---
if command -v jq >/dev/null 2>&1; then
  jq_ver="$(extract_version "$(jq --version 2>&1)")"
  emit "jq" "pass" "v${jq_ver}"
else
  emit "jq" "info" "not installed (optional — fallback exists in some plugins)"
fi

# --- OS info ---
emit "platform" "info" "$OS ($(uname -m))"

if [ "$fail" -eq 0 ]; then
  emit "ALL_TOOLS_PASS" "pass" "all required tools installed"
fi
```

- [ ] **Step 2: Make script executable and run it**

```bash
chmod +x plugins/expert/skills/doctor/scripts/check-ext-tools.sh
bash plugins/expert/skills/doctor/scripts/check-ext-tools.sh
```

Expected: one or more lines per tool showing installed version and optionally latest version. `pass` for up to date, `info` for outdated (not an error), `warn` for important missing tools, `critical` for core missing tools.

- [ ] **Step 3: Commit**

```bash
git add plugins/expert/skills/doctor/scripts/check-ext-tools.sh
git commit -m "feat(expert): add check-ext-tools.sh diagnostic script

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 5: check-cross-refs.sh

**Files:**
- Create: `plugins/expert/skills/doctor/scripts/check-cross-refs.sh`

Validates that cross-plugin skill and agent references actually resolve. Hardcodes the known dependency map from the design spec research.

- [ ] **Step 1: Write check-cross-refs.sh**

Create `plugins/expert/skills/doctor/scripts/check-cross-refs.sh`:

```bash
#!/usr/bin/env bash
set -u

emit() {
  local name="$1"
  local status="$2"
  local detail="$3"
  detail="$(printf '%s' "$detail" | tr '\n' ';' | sed 's/  */ /g; s/; */; /g; s/; $//')"
  printf '%s | %s | %s\n' "$name" "$status" "$detail"
}

INSTALLED_PLUGINS="$HOME/.claude/plugins/installed_plugins.json"

if [ ! -f "$INSTALLED_PLUGINS" ]; then
  emit "Plugin registry" "critical" "~/.claude/plugins/installed_plugins.json not found"
  exit 0
fi

# Helper: resolve install path for a plugin key (name@marketplace)
resolve_path() {
  local key="$1"
  python3 -c "
import json
with open('$INSTALLED_PLUGINS') as f:
    data = json.load(f)
entries = data.get('plugins', {}).get('$key', [])
if entries:
    print(entries[0].get('installPath', ''))
" 2>/dev/null
}

# Helper: get version from plugin.json at a given path
get_version() {
  local path="$1"
  if [ -f "$path/.claude-plugin/plugin.json" ]; then
    python3 -c "
import json
with open('$path/.claude-plugin/plugin.json') as f:
    data = json.load(f)
print(data.get('version', 'unknown'))
" 2>/dev/null
  fi
}

# Helper: check if a skill exists at a plugin install path
check_skill() {
  local install_path="$1"
  local skill_name="$2"
  [ -f "$install_path/skills/$skill_name/SKILL.md" ]
}

# Helper: check if an agent exists at a plugin install path
check_agent() {
  local install_path="$1"
  local agent_name="$2"
  [ -f "$install_path/agents/$agent_name.md" ]
}

fail=0

# Resolve all unique target plugins upfront into a temp file (avoids bash 4+ associative arrays)
CACHE_FILE="$(mktemp)"
trap 'rm -f "$CACHE_FILE"' EXIT

resolve_and_cache() {
  local key="$1"
  # Check if already cached
  if grep -q "^$key|" "$CACHE_FILE" 2>/dev/null; then
    return
  fi
  local rpath
  rpath="$(resolve_path "$key")"
  local rver=""
  if [ -n "$rpath" ]; then
    rver="$(get_version "$rpath")"
    rver="${rver:-unknown}"
  fi
  printf '%s|%s|%s\n' "$key" "$rpath" "$rver" >> "$CACHE_FILE"
}

get_cached_path() {
  grep "^$1|" "$CACHE_FILE" 2>/dev/null | head -1 | cut -d'|' -f2
}

get_cached_version() {
  grep "^$1|" "$CACHE_FILE" 2>/dev/null | head -1 | cut -d'|' -f3
}

# Cross-plugin reference map
# Format: source_plugin|target_plugin@marketplace|ref_type|ref_name
# ref_type: skill or agent
REFS=(
  # compact-core → midnight-tooling
  "compact-core|midnight-tooling@midnight-expert|skill|compact-cli"
  "compact-core|midnight-tooling@midnight-expert|skill|troubleshooting"
  "compact-core|midnight-tooling@midnight-expert|skill|doctor"
  # compact-core → devs (external)
  "compact-core|devs@agent-foundry|skill|code-review"
  "compact-core|devs@agent-foundry|skill|typescript-core"
  "compact-core|devs@agent-foundry|skill|security-core"
  # midnight-verify → compact-core
  "midnight-verify|compact-core@midnight-expert|skill|compact-standard-library"
  "midnight-verify|compact-core@midnight-expert|skill|compact-structure"
  "midnight-verify|compact-core@midnight-expert|skill|compact-language-ref"
  "midnight-verify|compact-core@midnight-expert|skill|compact-privacy-disclosure"
  "midnight-verify|compact-core@midnight-expert|skill|compact-compilation"
  "midnight-verify|compact-core@midnight-expert|skill|compact-witness-ts"
  "midnight-verify|compact-core@midnight-expert|skill|compact-review"
  "midnight-verify|compact-core@midnight-expert|skill|compact-deployment"
  # midnight-verify → midnight-tooling
  "midnight-verify|midnight-tooling@midnight-expert|skill|compact-cli"
  "midnight-verify|midnight-tooling@midnight-expert|skill|devnet"
  "midnight-verify|midnight-tooling@midnight-expert|skill|install-cli"
  # midnight-verify → devs (external)
  "midnight-verify|devs@agent-foundry|agent|deps-maintenance"
  # midnight-fact-check → midnight-verify (agents)
  "midnight-fact-check|midnight-verify@midnight-expert|agent|contract-writer"
  "midnight-fact-check|midnight-verify@midnight-expert|agent|source-investigator"
  "midnight-fact-check|midnight-verify@midnight-expert|agent|type-checker"
  "midnight-fact-check|midnight-verify@midnight-expert|agent|cli-tester"
  "midnight-fact-check|midnight-verify@midnight-expert|agent|sdk-tester"
  "midnight-fact-check|midnight-verify@midnight-expert|agent|witness-verifier"
  "midnight-fact-check|midnight-verify@midnight-expert|agent|zkir-checker"
  # midnight-cq → compact-core
  "midnight-cq|compact-core@midnight-expert|skill|compact-testing"
  "midnight-cq|compact-core@midnight-expert|skill|compact-witness-ts"
  # midnight-cq → midnight-tooling
  "midnight-cq|midnight-tooling@midnight-expert|skill|compact-cli"
  "midnight-cq|midnight-tooling@midnight-expert|skill|devnet"
)

# Pre-resolve all unique targets
for ref in "${REFS[@]}"; do
  target="$(printf '%s' "$ref" | cut -d'|' -f2)"
  resolve_and_cache "$target"
done

for ref in "${REFS[@]}"; do
  IFS='|' read -r source target ref_type ref_name <<< "$ref"

  target_path="$(get_cached_path "$target")"
  target_ver="$(get_cached_version "$target")"
  target_name="${target%%@*}"

  # Check if target plugin is installed
  if [ -z "$target_path" ]; then
    emit "$source → $target_name:$ref_name" "critical" "$target_name not installed"
    fail=1
    continue
  fi

  # Check if specific skill/agent exists
  if [ "$ref_type" = "skill" ]; then
    if check_skill "$target_path" "$ref_name"; then
      emit "$source → $target_name:$ref_name" "pass" "$ref_type found ($target_name v$target_ver)"
    else
      emit "$source → $target_name:$ref_name" "warn" "$ref_type not found in $target_name v$target_ver — update may be needed"
      fail=1
    fi
  elif [ "$ref_type" = "agent" ]; then
    if check_agent "$target_path" "$ref_name"; then
      emit "$source → $target_name:$ref_name" "pass" "$ref_type found ($target_name v$target_ver)"
    else
      emit "$source → $target_name:$ref_name" "warn" "$ref_type not found in $target_name v$target_ver — update may be needed"
      fail=1
    fi
  fi
done

if [ "$fail" -eq 0 ]; then
  emit "ALL_REFS_PASS" "pass" "all cross-plugin references resolved"
fi
```

- [ ] **Step 2: Make script executable and run it**

```bash
chmod +x plugins/expert/skills/doctor/scripts/check-cross-refs.sh
bash plugins/expert/skills/doctor/scripts/check-cross-refs.sh
```

Expected: one line per cross-plugin reference showing whether it resolves, with the target plugin version.

- [ ] **Step 3: Commit**

```bash
git add plugins/expert/skills/doctor/scripts/check-cross-refs.sh
git commit -m "feat(expert): add check-cross-refs.sh diagnostic script

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 6: check-npm.sh

**Files:**
- Create: `plugins/expert/skills/doctor/scripts/check-npm.sh`

Checks NPM registry reachability and `@midnight-ntwrk` scope accessibility.

- [ ] **Step 1: Write check-npm.sh**

Create `plugins/expert/skills/doctor/scripts/check-npm.sh`:

```bash
#!/usr/bin/env bash
set -u

emit() {
  local name="$1"
  local status="$2"
  local detail="$3"
  detail="$(printf '%s' "$detail" | tr '\n' ';' | sed 's/  */ /g; s/; */; /g; s/; $//')"
  printf '%s | %s | %s\n' "$name" "$status" "$detail"
}

if ! command -v npm >/dev/null 2>&1; then
  emit "npm available" "critical" "npm not found in PATH — cannot check registry"
  exit 0
fi

# Check registry reachability
if npm ping --registry https://registry.npmjs.org >/dev/null 2>&1; then
  emit "npm registry" "pass" "registry.npmjs.org reachable"
else
  emit "npm registry" "critical" "registry.npmjs.org not reachable — check network or proxy settings"
  exit 0
fi

# Check @midnight-ntwrk scope accessibility (canary package)
canary_version="$(npm view @midnight-ntwrk/compact-runtime version 2>/dev/null)" || canary_version=""
if [ -n "$canary_version" ]; then
  emit "@midnight-ntwrk scope" "pass" "accessible (compact-runtime v${canary_version})"
else
  emit "@midnight-ntwrk scope" "warn" "could not resolve @midnight-ntwrk/compact-runtime — check npm config (no custom registry needed)"
fi
```

- [ ] **Step 2: Make script executable and run it**

```bash
chmod +x plugins/expert/skills/doctor/scripts/check-npm.sh
bash plugins/expert/skills/doctor/scripts/check-npm.sh
```

Expected: 2 lines — registry reachability and scope accessibility.

- [ ] **Step 3: Commit**

```bash
git add plugins/expert/skills/doctor/scripts/check-npm.sh
git commit -m "feat(expert): add check-npm.sh diagnostic script

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 7: fix-table.md Reference

**Files:**
- Create: `plugins/expert/skills/doctor/references/fix-table.md`

Contains the fix recipes for all issue types, organized by category with platform-specific commands.

- [ ] **Step 1: Write fix-table.md**

Create `plugins/expert/skills/doctor/references/fix-table.md`:

```markdown
# Fix Table

Reference for resolving issues found by expert:doctor. Each section maps diagnostic output to actionable fixes.

## Auto-Fix Classification

### Applied silently with --auto-fix
- Installing missing marketplaces and plugins
- Enabling disabled plugins
- Adding MCP servers via `claude mcp add`
- Installing missing CLI tools
- Initiating `gh auth login` (still interactive)

### Always prompts (even with --auto-fix)
- Upgrading outdated CLI tools
- Adding MCP server to local `.mcp.json` vs global
- Docker Desktop installation
- Docker daemon start on macOS
- Network/proxy configuration

## Plugin Issues

| Issue | Fix |
|-------|-----|
| midnight-expert marketplace not installed | `claude plugin install-marketplace devrelaicom/midnight-expert` |
| agent-foundry marketplace not installed | `claude plugin install-marketplace aaronbassett/agent-foundry` |
| Plugin not installed | Ensure marketplace is installed first, then `claude plugin install <name>` |
| Plugin installed but not enabled | `claude plugin enable <name>` |

## MCP Server Issues

| Issue | Fix |
|-------|-----|
| midnight not configured | `claude mcp add midnight -- npx -y github:devrelaicom/midnight-mcp` |
| octocode not configured | `claude mcp add octocode-mcp -- npx octocode-mcp` |
| midnight-devnet not configured | `claude mcp add midnight-devnet -- npx -y @aaronbassett/midnight-local-devnet` |
| midnight-wallet not configured | `claude mcp add midnight-wallet -- npx -y -p midnight-wallet-cli@latest midnight-wallet-mcp` |
| MCP server not responding | Restart Claude Code to reconnect MCP servers |

For any MCP server add, also ask: "Would you prefer to add this to the local project only? I can write it to `.mcp.json` instead."

## External Tool Issues — Install

| Tool | macOS | Linux |
|------|-------|-------|
| node | `nvm install --lts` (install nvm first: https://github.com/nvm-sh/nvm) | `nvm install --lts` (install nvm first: https://github.com/nvm-sh/nvm) |
| npm/npx | Reinstall Node.js via nvm | Reinstall Node.js via nvm |
| git | `brew install git` | `apt install git` |
| gh | `brew install gh` | See https://cli.github.com/ |
| gh auth | `gh auth login` | `gh auth login` |
| docker | Install Docker Desktop: https://www.docker.com/products/docker-desktop/ | Install Docker Desktop: https://www.docker.com/products/docker-desktop/ |
| docker daemon | Start Docker Desktop application | `sudo systemctl start docker` |
| python3 | Install uv: `curl -LsSf https://astral.sh/uv/install.sh \| sh` then `uv python install` | Install uv: `curl -LsSf https://astral.sh/uv/install.sh \| sh` then `uv python install` |
| curl | `brew install curl` | `apt install curl` |
| jq (optional) | `brew install jq` | `apt install jq` |
| tsc | `npm install -g typescript` | `npm install -g typescript` |

## External Tool Issues — Outdated

Always prompt the user before upgrading, even with --auto-fix.

| Tool | macOS | Linux |
|------|-------|-------|
| node | `nvm install --lts && nvm use --lts` | `nvm install --lts && nvm use --lts` |
| git | `brew upgrade git` | `apt upgrade git` |
| gh | `brew upgrade gh` | `gh upgrade` |
| docker | Update Docker Desktop | Follow Docker docs for your distribution |
| python3 | `uv python install <latest>` | `uv python install <latest>` |
| tsc | `npm update -g typescript` | `npm update -g typescript` |

## Cross-Plugin Reference Issues

| Issue | Fix |
|-------|-----|
| Target marketplace not installed | Install the marketplace first (see Plugin Issues) |
| Target plugin not installed | Install from the correct marketplace |
| Skill/agent not found in installed plugin | Plugin may be outdated — run `claude plugin update <name>` |

## NPM Issues

| Issue | Fix |
|-------|-----|
| Registry unreachable | Check network connection and proxy settings |
| @midnight-ntwrk scope inaccessible | Check npm config — no custom registry configuration is needed for @midnight-ntwrk packages |
```

- [ ] **Step 2: Commit**

```bash
git add plugins/expert/skills/doctor/references/fix-table.md
git commit -m "feat(expert): add fix-table.md reference for doctor remediation

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 8: SKILL.md

**Files:**
- Create: `plugins/expert/skills/doctor/SKILL.md`

The orchestration skill that launches parallel agents, optionally delegates to midnight-tooling:doctor, assembles the report, and offers fixes.

- [ ] **Step 1: Write SKILL.md**

Create `plugins/expert/skills/doctor/SKILL.md`:

```markdown
---
name: expert:doctor
description: This skill should be used when the user asks to "check my setup", "run diagnostics", "doctor", "health check", "verify my installation", "are my plugins working", "check plugin status", "what's broken", "fix my setup", or invokes /expert:doctor. Provides comprehensive health reporting for the midnight-expert ecosystem — plugin installation, MCP servers, external tools, cross-plugin references, and NPM registry.
version: 0.1.0
---

# Expert Doctor

Comprehensive diagnostic and health report for the midnight-expert ecosystem.

## Usage

- `/expert:doctor` — run diagnostics interactively, offer fixes one at a time
- `/expert:doctor --auto-fix` — install missing dependencies silently, prompt only for upgrades and preference choices

## Step 1: Launch & Ask (concurrent)

Launch **all 5 diagnostic agents in background** AND ask the user a question — in a **single message** with 6 tool calls (5 Agent + 1 AskUserQuestion).

Each agent has `subagent_type: "general-purpose"` and `run_in_background: true`. Each agent must run its bash command and return **only** the raw output lines. Do not include markdown fences or any other text in the agent prompt beyond the instruction.

### Agent 1 — Plugin Health

> Run the following command and return only the output. No other text.
>
> ```
> bash "${CLAUDE_SKILL_DIR}/scripts/check-plugins.sh"
> ```

### Agent 2 — MCP Servers

> Run the following command and return only the output. No other text.
>
> ```
> bash "${CLAUDE_SKILL_DIR}/scripts/check-mcp-servers.sh"
> ```

### Agent 3 — External Tools

> Run the following command and return only the output. No other text.
>
> ```
> bash "${CLAUDE_SKILL_DIR}/scripts/check-ext-tools.sh"
> ```

### Agent 4 — Cross-Plugin References

> Run the following command and return only the output. No other text.
>
> ```
> bash "${CLAUDE_SKILL_DIR}/scripts/check-cross-refs.sh"
> ```

### Agent 5 — NPM Registry

> Run the following command and return only the output. No other text.
>
> ```
> bash "${CLAUDE_SKILL_DIR}/scripts/check-npm.sh"
> ```

### AskUserQuestion

> Would you also like to check Midnight Tooling status? (Compact CLI, compiler, devnet, proof server)

## Step 2: Handle Response

- If the user says **yes**: invoke the `midnight-tooling:doctor` skill (via Skill tool) and wait for it and all 5 background agents to complete.
- If the user says **no**: wait for the 5 background agents to complete.

## Step 3: Present Health Report

Parse all agent output. Each script outputs lines in the format:

```
CHECK_NAME | STATUS | DETAIL
```

Map each STATUS to an emoji:
- `pass` → PASS
- `warn` → WARN
- `critical` → FAIL
- `info` → INFO

Present a single formatted report. Omit any section where all checks pass and there is an `ALL_*_PASS` summary line — only show sections with issues or mixed results. If ALL sections pass, show a brief "all clear" summary.

```
## Midnight Expert — Health Report

### Midnight Tooling (only if user opted in)
(include the delegated report from midnight-tooling:doctor)

### Plugins
| Check | Status | Details |
|-------|--------|---------|
| plugin-name | STATUS | details... |

### MCP Servers
| Check | Status | Details |
|-------|--------|---------|
| server-name | STATUS | details... |

### External Tools
| Check | Status | Details |
|-------|--------|---------|
| tool-name | STATUS | details... |

### Cross-Plugin References
| Check | Status | Details |
|-------|--------|---------|
| source → target:ref | STATUS | details... |

### NPM Registry
| Check | Status | Details |
|-------|--------|---------|
| check-name | STATUS | details... |
```

Do **not** show any intermediate bash output to the user. The report above is the only user-facing output.

## Step 4: Offer Fixes

Read `references/fix-table.md` for the fix recipes.

For each FAIL or WARN item in the report, determine the appropriate fix from the fix-table. Use the `platform` info line from check-ext-tools.sh to select macOS vs Linux commands.

**If `$ARGUMENTS` contains `--auto-fix`:**
- Apply auto-fixable items silently (installs, enables, MCP adds via `claude mcp add`)
- Always prompt before upgrading outdated tools — show current vs latest version
- Always prompt for MCP server scope (global vs local `.mcp.json`)
- Log each action taken

**If no `--auto-fix`:**
- Present each fix one at a time using AskUserQuestion with confirm/skip options
- Group related fixes when possible (e.g., "3 plugins need installing — install all?")

## Step 5: Verify & Summary

After applying any fixes, re-run **only the scripts whose checks had issues** to confirm resolution. Do not re-run passing scripts.

Present a final summary:

```
### Summary
- FAIL: N
- WARN: N
- PASS: N
- INFO: N

[If issues were fixed] Fixed N issue(s) this session.
[If remaining issues] N issue(s) require manual intervention.
[If all green] Midnight Expert ecosystem is healthy and ready for development.
```

## Additional Resources

### Scripts
- `${CLAUDE_SKILL_DIR}/scripts/check-plugins.sh` — Plugin installation and version checks
- `${CLAUDE_SKILL_DIR}/scripts/check-mcp-servers.sh` — MCP server configuration and connectivity
- `${CLAUDE_SKILL_DIR}/scripts/check-ext-tools.sh` — External CLI tool availability and versions
- `${CLAUDE_SKILL_DIR}/scripts/check-cross-refs.sh` — Cross-plugin skill/agent reference validation
- `${CLAUDE_SKILL_DIR}/scripts/check-npm.sh` — NPM registry and @midnight-ntwrk scope checks

### References
- `references/fix-table.md` — Fix recipes for all issue types with platform-specific commands
```

- [ ] **Step 2: Commit**

```bash
git add plugins/expert/skills/doctor/SKILL.md
git commit -m "feat(expert): add doctor SKILL.md orchestration

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 9: Add to Marketplace

**Files:**
- Modify: `.claude-plugin/marketplace.json`

- [ ] **Step 1: Add expert plugin to marketplace.json**

Add the expert plugin entry to the `plugins` array in `.claude-plugin/marketplace.json`:

```json
{
  "name": "expert",
  "source": "./plugins/expert"
}
```

Add it as the first entry in the array (it's the meta-plugin, so it makes sense at the top).

- [ ] **Step 2: Commit**

```bash
git add .claude-plugin/marketplace.json
git commit -m "feat(expert): add expert plugin to marketplace

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 10: Manual Testing

- [ ] **Step 1: Run each script individually**

```bash
bash plugins/expert/skills/doctor/scripts/check-plugins.sh
bash plugins/expert/skills/doctor/scripts/check-mcp-servers.sh
bash plugins/expert/skills/doctor/scripts/check-ext-tools.sh
bash plugins/expert/skills/doctor/scripts/check-cross-refs.sh
bash plugins/expert/skills/doctor/scripts/check-npm.sh
```

Verify each produces correctly formatted `CHECK_NAME | STATUS | DETAIL` output with no stray text or errors.

- [ ] **Step 2: Verify SKILL.md structure**

Check the SKILL.md:
- Has valid YAML frontmatter with `name`, `description`, and `version`
- Description uses third person and includes trigger phrases
- Body uses imperative form
- References all 5 scripts and the fix-table reference
- Is under 3,000 words

- [ ] **Step 3: Run the full doctor skill**

Invoke `/expert:doctor` and verify:
- 5 background agents launch
- User is asked about Midnight Tooling check
- Report is assembled correctly
- Fixes are offered for any issues found

- [ ] **Step 4: Test --auto-fix**

Invoke `/expert:doctor --auto-fix` and verify:
- Auto-fixable items are applied silently
- Upgrades still prompt
- MCP scope preference still prompts
- Actions are logged
