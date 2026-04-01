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
