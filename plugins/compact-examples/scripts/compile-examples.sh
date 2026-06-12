#!/usr/bin/env bash
# Compile every example .compact file standalone and fail if any expected-to-compile
# file fails. Run in CI on ubuntu-latest (a CASE-SENSITIVE filesystem) so that
# import-path case mismatches — e.g. `import Crypto;` resolving to `crypto.compact`
# only on case-insensitive macOS — are caught before they reach users.
#
# Requires the `compact` toolchain on PATH (see midnight-tooling:install-cli).
set -uo pipefail

EXAMPLES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../skills/code-examples/examples" && pwd)"

# Building-block modules that intentionally `import` a module living in a SIBLING
# directory (resolved only when the module is copied into an application — e.g.
# midnight-rwa bundles a local Crypto). They are exercised in-context via the
# applications/mocks that consume them, not compiled standalone here.
SKIP=(
  "modules/identity/passportidentity.compact"
)

is_skipped() {
  local f="$1" s
  for s in "${SKIP[@]}"; do [ "$f" = "$s" ] && return 0; done
  return 1
}

if ! command -v compact >/dev/null 2>&1; then
  echo "error: 'compact' not found on PATH. Install via the compact-installer (see midnight-tooling:install-cli)." >&2
  exit 127
fi

cd "$EXAMPLES_DIR"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

compiled=0 skipped=0 failed=0
while IFS= read -r f; do
  rel="${f#./}"
  if is_skipped "$rel"; then
    echo "skip (building-block module, compiled in context): $rel"
    skipped=$((skipped + 1))
    continue
  fi
  out_dir="$tmp/$(printf '%s' "$rel" | tr '/' '_')"
  if compact compile --skip-zk "$rel" "$out_dir" >"$tmp/log" 2>&1; then
    compiled=$((compiled + 1))
  else
    echo "::error file=plugins/compact-examples/skills/code-examples/examples/$rel::compile failed"
    echo "----- $rel -----"
    tail -8 "$tmp/log" | sed 's/^/    /'
    failed=$((failed + 1))
  fi
done < <(find . -name '*.compact' | sort)

echo ""
echo "compiled=$compiled  skipped=$skipped  failed=$failed"
[ "$failed" -eq 0 ]
