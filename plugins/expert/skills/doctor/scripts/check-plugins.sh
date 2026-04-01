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
