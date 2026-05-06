#!/usr/bin/env bash
# Test runner for compact-core hook scripts. Executed by CI
# (.github/workflows/ci-compact-core-hooks.yml) and locally.

set -euo pipefail

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"

FAILED=()

run_step() {
  local label="$1"; shift
  echo
  echo "==> $label"
  if "$@"; then
    echo "    OK: $label"
  else
    echo "    FAIL: $label"
    FAILED+=("$label")
  fi
}

run_step "test-sessionstart-snapshots-hashes.sh" \
  bash "$TESTS_DIR/test-sessionstart-snapshots-hashes.sh"
run_step "test-stop-blocks-on-modified.sh" \
  bash "$TESTS_DIR/test-stop-blocks-on-modified.sh"
run_step "test-stop-passes-with-compile.sh" \
  bash "$TESTS_DIR/test-stop-passes-with-compile.sh"
run_step "test-stop-cooldown-2h.sh" \
  bash "$TESTS_DIR/test-stop-cooldown-2h.sh"
run_step "test-stop-defers-on-stop-hook-active.sh" \
  bash "$TESTS_DIR/test-stop-defers-on-stop-hook-active.sh"
run_step "test-stop-clears-stale-queue-when-clean.sh" \
  bash "$TESTS_DIR/test-stop-clears-stale-queue-when-clean.sh"
run_step "test-sessionend-persists-unchecked.sh" \
  bash "$TESTS_DIR/test-sessionend-persists-unchecked.sh"
run_step "test-sessionstart-surfaces-prev-and-clears.sh" \
  bash "$TESTS_DIR/test-sessionstart-surfaces-prev-and-clears.sh"
run_step "test-userpromptsubmit-prints-and-drains.sh" \
  bash "$TESTS_DIR/test-userpromptsubmit-prints-and-drains.sh"
run_step "test-userpromptsubmit-noop-when-empty.sh" \
  bash "$TESTS_DIR/test-userpromptsubmit-noop-when-empty.sh"

echo
if [ "${#FAILED[@]}" -gt 0 ]; then
  echo "FAILED steps: ${#FAILED[@]}"
  printf '  - %s\n' "${FAILED[@]}"
  exit 1
fi
echo "All checks passed."
