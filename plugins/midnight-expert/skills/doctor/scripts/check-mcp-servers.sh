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
  "octocode|octocode|claude mcp add octocode-mcp -- npx octocode-mcp|midnight-tooling, midnight-verify, midnight-fact-check"
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
