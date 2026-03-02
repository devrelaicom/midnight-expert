#!/usr/bin/env bash
set -u

emit() {
  local name="$1"
  local status="$2"
  local detail="$3"
  detail="$(printf '%s' "$detail" | tr '\n' ';' | sed 's/  */ /g; s/; */; /g; s/; $//')"
  printf '%s | %s | %s\n' "$name" "$status" "$detail"
}

fail=0

if ! curl --version >/dev/null 2>&1; then
  emit "curl" "warn" "not installed — used by /midnight-tooling:install-cli, /midnight-tooling:devnet, /midnight-tooling:doctor"
  fail=1
fi

node_ok=0
if ! node --version >/dev/null 2>&1; then
  emit "Node.js" "warn" "not installed — required to run the octocode MCP server (affects /midnight-tooling:view-release-notes, /midnight-tooling:doctor breaking change checks)"
  fail=1
else
  node_ok=1
fi

if [ "$node_ok" -eq 1 ]; then
  if ! npx --version >/dev/null 2>&1; then
    emit "npx" "warn" "not found — required to run the octocode MCP server"
    fail=1
  fi
fi

if ! command -v gh >/dev/null 2>&1; then
  emit "GitHub CLI (gh)" "warn" "not installed — required for GitHub API access by the octocode MCP server (affects /midnight-tooling:view-release-notes, /midnight-tooling:doctor breaking change checks)"
  fail=1
else
  if ! gh auth status >/dev/null 2>&1; then
    emit "GitHub CLI auth" "warn" "not authenticated — run 'gh auth login' (affects /midnight-tooling:view-release-notes, /midnight-tooling:doctor breaking change checks)"
    fail=1
  fi
fi

octo_list="$(claude mcp list 2>&1)" || octo_list=""
if ! printf '%s' "$octo_list" | grep -qi "octocode"; then
  emit "octocode MCP server" "warn" "not configured in Claude Code — required by /midnight-tooling:view-release-notes, /midnight-tooling:doctor breaking change checks. Check that the midnight-tooling plugin is installed and its MCP server is enabled."
  fail=1
fi

if ! printf '%s' "$octo_list" | grep -qi "midnight-devnet"; then
  emit "midnight-devnet MCP server" "warn" "not configured in Claude Code — required by /midnight-tooling:devnet for local network management. Check that the midnight-tooling plugin is installed and its MCP server is enabled."
  fail=1
fi

if [ "$fail" -eq 0 ]; then
  emit "ALL_PASS" "pass" "all plugin dependencies satisfied"
fi
