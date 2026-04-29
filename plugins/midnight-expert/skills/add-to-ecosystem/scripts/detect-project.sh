#!/usr/bin/env bash
# Scan the current working directory and emit a JSON summary of
# Midnight-relevant project signals plus a category recommendation.
# Output: a single JSON object on stdout. No prose, no logs.
# Errors go to stderr. Exit 0 on success, non-zero only on hard failure.
set -u

if ! command -v jq >/dev/null 2>&1; then
  echo "detect-project.sh: jq is required but not installed" >&2
  exit 2
fi

# --- helpers ---

# json_bool: turn 0/non-empty exit code into JSON true/false
json_bool() {
  if "$@" >/dev/null 2>&1; then echo "true"; else echo "false"; fi
}

# Find candidate package.json files (excluding node_modules)
package_jsons() {
  find . -name 'package.json' \
    -not -path '*/node_modules/*' \
    -not -path '*/.git/*' \
    -not -path '*/dist/*' \
    -not -path '*/build/*' \
    2>/dev/null
}

# Match a regex against any package.json's deps + devDeps
any_pkg_dep_matches() {
  local pattern="$1"
  local p
  while IFS= read -r p; do
    [ -z "$p" ] && continue
    jq -e --arg pat "$pattern" '
      ((.dependencies // {}) + (.devDependencies // {}))
      | keys
      | map(test($pat))
      | any
    ' "$p" >/dev/null 2>&1 && return 0
  done < <(package_jsons)
  return 1
}

# Find compact source files
compact_files_list() {
  find . -name '*.compact' \
    -not -path '*/node_modules/*' \
    -not -path '*/.git/*' \
    -not -path '*/dist/*' \
    -not -path '*/build/*' \
    -not -path '*/target/*' \
    2>/dev/null
}

# --- signals ---

HAS_COMPACT_FILES=$(json_bool test -n "$(compact_files_list | head -n1)")

HAS_PRAGMA="false"
if [ "$HAS_COMPACT_FILES" = "true" ]; then
  if compact_files_list | xargs -I{} grep -l 'pragma language_version' "{}" 2>/dev/null | head -n1 | grep -q .; then
    HAS_PRAGMA="true"
  fi
fi

HAS_COMPACT_NPM=$(json_bool any_pkg_dep_matches '^@midnight-ntwrk/(compact-runtime|compactc)$')
HAS_RUNTIME_NPM=$(json_bool any_pkg_dep_matches '^@midnight-ntwrk/midnight-js-(contracts|node-zk-config-provider|fetch-zk-config-provider|http-client-proof-provider)$')
HAS_WALLET_NPM=$(json_bool any_pkg_dep_matches '^@midnight-ntwrk/(wallet[^/]*|dapp-connector-api)$')
HAS_DAPP_CONN_NPM=$(json_bool any_pkg_dep_matches '^@midnight-ntwrk/dapp-connector-api$')

# is_claude_plugin
IS_PLUGIN="false"
if [ -f .claude-plugin/plugin.json ] || ls plugins/*/.claude-plugin/plugin.json >/dev/null 2>&1; then
  IS_PLUGIN="true"
fi

# is_cli_tool: package.json bin field, Cargo [[bin]], or pyproject [project.scripts]
IS_CLI="false"
while IFS= read -r p; do
  [ -z "$p" ] && continue
  if jq -e '.bin' "$p" >/dev/null 2>&1; then IS_CLI="true"; break; fi
done < <(package_jsons)
if [ "$IS_CLI" = "false" ] && [ -f Cargo.toml ] && grep -q '^\[\[bin\]\]' Cargo.toml 2>/dev/null; then
  IS_CLI="true"
fi
if [ "$IS_CLI" = "false" ] && [ -f pyproject.toml ] && grep -q '^\[project\.scripts\]' pyproject.toml 2>/dev/null; then
  IS_CLI="true"
fi

# is_template
IS_TEMPLATE="false"
REPO_NAME="$(basename "$(pwd)")"
if echo "$REPO_NAME" | grep -qiE 'template|starter|scaffold'; then
  IS_TEMPLATE="true"
fi
if [ "$IS_TEMPLATE" = "false" ] && [ -f README.md ]; then
  if head -c 500 README.md | grep -qiE 'template|starter|scaffold'; then
    IS_TEMPLATE="true"
  fi
fi

# --- recommendation ---

ADD_COMPACT_TOPIC="false"
if [ "$HAS_COMPACT_FILES" = "true" ] && [ "$HAS_PRAGMA" = "true" ]; then
  ADD_COMPACT_TOPIC="true"
fi

if [ "$HAS_COMPACT_FILES" = "true" ] || [ "$HAS_RUNTIME_NPM" = "true" ]; then
  CATEGORY="built-on"
elif [ "$IS_PLUGIN" = "true" ] || [ "$IS_CLI" = "true" ] || [ "$IS_TEMPLATE" = "true" ]; then
  CATEGORY="extends"
elif [ "$HAS_WALLET_NPM" = "true" ] || [ "$HAS_DAPP_CONN_NPM" = "true" ]; then
  CATEGORY="integrates"
else
  CATEGORY="built-on"
fi

# --- emit JSON ---

jq -n \
  --argjson has_compact_files "$HAS_COMPACT_FILES" \
  --argjson has_pragma_language_version "$HAS_PRAGMA" \
  --argjson has_compact_npm_dep "$HAS_COMPACT_NPM" \
  --argjson has_runtime_npm_dep "$HAS_RUNTIME_NPM" \
  --argjson has_wallet_sdk_npm_dep "$HAS_WALLET_NPM" \
  --argjson has_dapp_connector_npm_dep "$HAS_DAPP_CONN_NPM" \
  --argjson is_claude_plugin "$IS_PLUGIN" \
  --argjson is_cli_tool "$IS_CLI" \
  --argjson is_template "$IS_TEMPLATE" \
  --argjson add_compact_topic "$ADD_COMPACT_TOPIC" \
  --arg category "$CATEGORY" \
  '{
     has_compact_files: $has_compact_files,
     has_pragma_language_version: $has_pragma_language_version,
     has_compact_npm_dep: $has_compact_npm_dep,
     has_runtime_npm_dep: $has_runtime_npm_dep,
     has_wallet_sdk_npm_dep: $has_wallet_sdk_npm_dep,
     has_dapp_connector_npm_dep: $has_dapp_connector_npm_dep,
     is_claude_plugin: $is_claude_plugin,
     is_cli_tool: $is_cli_tool,
     is_template: $is_template,
     recommendation: {
       add_compact_topic: $add_compact_topic,
       category: $category
     }
   }'
