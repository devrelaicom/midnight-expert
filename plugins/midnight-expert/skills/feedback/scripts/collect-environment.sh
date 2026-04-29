#!/usr/bin/env bash
# Output environment metadata as JSON to stdout.
# Any value the script can't determine is emitted as null.
# Session-level fields (model, effort) are always null — SKILL.md fills them
# from the parsed session metadata.

set -uo pipefail

if ! command -v jq >/dev/null 2>&1; then
  printf '{"error":"jq not found; install jq and re-run"}\n' >&2
  exit 1
fi

INSTALLED_PLUGINS="$HOME/.claude/plugins/installed_plugins.json"
MARKETPLACE_FILE="$HOME/.claude/plugins/marketplaces/midnight-expert/.claude-plugin/marketplace.json"

# Helper: emit a string as JSON (escaped) or null if empty.
to_json_str() {
  local v="$1"
  if [ -z "$v" ]; then
    printf 'null'
  else
    printf '%s' "$v" | jq -R .
  fi
}

# Marketplace version
mp_version="null"
if [ -f "$MARKETPLACE_FILE" ]; then
  mp_version="$(jq -c '.metadata.version // null' "$MARKETPLACE_FILE" 2>/dev/null || echo null)"
fi

# Claude Code version
cc_raw="$(claude --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+[^ ]*' | head -1 || true)"
cc_version="$(to_json_str "$cc_raw")"

# OS
os_raw="$(uname -srm)"
os_json="$(to_json_str "$os_raw")"

# External tools
compact_raw="$(compact --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+[^ ]*' | head -1 || true)"
compact_json="$(to_json_str "$compact_raw")"

gh_raw="$(gh --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+[^ ]*' | head -1 || true)"
gh_json="$(to_json_str "$gh_raw")"

# Plugins: read installed_plugins.json, extract { "<plugin>": "<version>" }
# only for entries whose key matches *@midnight-expert.
plugins_json="{}"
if [ -f "$INSTALLED_PLUGINS" ]; then
  plugins_json="$(jq -c '
    .plugins // {}
    | to_entries
    | map(select(.key | endswith("@midnight-expert")))
    | map({ ((.key | split("@")[0])): (.value[0].version // null) })
    | add // {}
  ' "$INSTALLED_PLUGINS" 2>/dev/null || echo "{}")"
fi

# Note: midnightSdk version detection deferred — no stable CLI flag yet.
# Output combined JSON
jq -nc \
  --argjson mp "$mp_version" \
  --argjson cc "$cc_version" \
  --argjson os "$os_json" \
  --argjson compact "$compact_json" \
  --argjson gh "$gh_json" \
  --argjson plugins "$plugins_json" \
  '{
    marketplaceVersion: $mp,
    claudeCodeVersion: $cc,
    model: null,
    effort: null,
    os: $os,
    plugins: $plugins,
    tools: {
      compact: $compact,
      midnightSdk: null,
      gh: $gh
    }
  }'
