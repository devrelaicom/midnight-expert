#!/usr/bin/env bash
set -euo pipefail

# SessionStart hook for the compact-core plugin.
# Checks compact CLI availability, compiler version, and language version.
# Outputs JSON to stdout for the hook system.

COMMON_CONTEXT='The Midnight Network is under active development with frequent breaking changes. Do not assume stability across versions.

All `@midnight-ntwrk/*` packages are published on public npm. Do not add custom registry configuration — no `.npmrc` or `.yarnrc.yml` registry overrides. Verify package versions with `npm view`, never from memory.

You should check for new compact developer tools, compact compiler, and Midnight SDK versions regularly.

```
compact check # check for new compact compiler versions (cached with 15m TTL)
compact self check # check for new compact developer tools versions (cached with 15m TTL)
npm view <package-name> version # check for latest version of <package-name>
```'

# --- Check 1: Is the compact CLI installed? ---
if ! command -v compact >/dev/null 2>&1; then
  msg="Could not find the compact developer tools. Use the \`/midnight-tooling:install-cli\` command to install them.

${COMMON_CONTEXT}"

  jq -n \
    --arg ctx "$msg" \
    '{
      "continue": true,
      "hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": $ctx
      }
    }'
  exit 0
fi

# --- Check 2: Is the compiler up to date? ---
check_output="$(compact check 2>&1 || true)"
current_version="$(compact compile --version 2>/dev/null || echo "unknown")"

if echo "$check_output" | grep -qi "Up to date"; then
  # Compiler is current — get the language version
  lang_version="$(compact compile --language-version 2>/dev/null || echo "unknown")"

  msg="You are using the most recent version of the compact compiler v${current_version}, \`pragma language_version >= ${lang_version%.*};\`. Remember to always use the most recent language version when writing new compact code as the ecosystem moves very quickly.

${COMMON_CONTEXT}"
else
  # Update available — try to extract the latest version from check output
  # compact check output format: "compact: <arch> -- <status> -- <version>"
  latest_version="$(echo "$check_output" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | tail -1 || echo "unknown")"

  msg="A compact compiler update is available. Your current version is v${current_version}, the latest version available is v${latest_version}. Use the \`/midnight-tooling:compact-cli\` skill to upgrade your version. You should upgrade your compiler version before writing any compact code.

${COMMON_CONTEXT}"
fi

jq -n \
  --arg ctx "$msg" \
  '{
    "continue": true,
    "hookSpecificOutput": {
      "hookEventName": "SessionStart",
      "additionalContext": $ctx
    }
  }'
