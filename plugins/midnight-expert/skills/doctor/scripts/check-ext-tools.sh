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
  node_latest="$(curl -sf --max-time 5 "https://nodejs.org/dist/index.json" 2>/dev/null \
    | grep -oE '"version":"v[0-9]+\.[0-9]+\.[0-9]+"' | head -1 | sed 's/.*"v//;s/"//')" || node_latest=""
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

# --- jq ---
if command -v jq >/dev/null 2>&1; then
  jq_ver="$(extract_version "$(jq --version 2>&1)")"
  emit "jq" "pass" "v${jq_ver}"
else
  emit "jq" "warn" "not installed — needed for JSON parsing in several plugins"
  fail=1
fi

# --- OS info ---
emit "platform" "info" "$OS ($(uname -m))"

if [ "$fail" -eq 0 ]; then
  emit "ALL_TOOLS_PASS" "pass" "all required tools installed"
fi
