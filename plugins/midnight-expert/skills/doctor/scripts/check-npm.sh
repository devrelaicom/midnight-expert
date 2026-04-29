#!/usr/bin/env bash
# Registry-level npm checks: reachability and per-package availability.
# CLI presence (npm/npx) is checked by check-ext-tools.sh; this script
# silently bails if npm is unavailable so the same finding is not
# reported twice.

set -u

emit() {
  local name="$1"
  local status="$2"
  local detail="$3"
  detail="$(printf '%s' "$detail" | tr '\n' ';' | sed 's/  */ /g; s/; */; /g; s/; $//')"
  printf '%s | %s | %s\n' "$name" "$status" "$detail"
}

# Silently bail if npm is missing — check-ext-tools.sh has already
# reported this; reporting twice creates noise.
if ! command -v npm >/dev/null 2>&1; then
  exit 0
fi

# Check registry reachability
if npm ping --registry https://registry.npmjs.org >/dev/null 2>&1; then
  emit "npm registry" "pass" "registry.npmjs.org reachable"
else
  emit "npm registry" "critical" "registry.npmjs.org not reachable — check network or proxy settings"
  exit 0
fi

# Helper: probe a package's published version, emit a row.
# Args: <pkg> <reason-needed>
check_package() {
  local pkg="$1"
  local needed_by="$2"
  local ver
  ver="$(npm view "$pkg" version 2>/dev/null)" || ver=""
  if [ -n "$ver" ]; then
    emit "$pkg" "pass" "v${ver} on npm"
  else
    emit "$pkg" "critical" "not published — $needed_by will fail"
  fi
}

# Canary check on @midnight-ntwrk scope (no custom registry config required).
canary_version="$(npm view @midnight-ntwrk/compact-runtime version 2>/dev/null)" || canary_version=""
if [ -n "$canary_version" ]; then
  emit "@midnight-ntwrk scope" "pass" "accessible (compact-runtime v${canary_version})"
else
  emit "@midnight-ntwrk scope" "warn" "could not resolve @midnight-ntwrk/compact-runtime — check npm config (no custom registry needed)"
fi

# Workflow-published utility packages used by plugin commands.
check_package "@aaronbassett/midnight-fact-checker-utils" "midnight-fact-check commands (check, fast-check)"
check_package "@aaronbassett/template-engine" "compact-cli-dev:init"
